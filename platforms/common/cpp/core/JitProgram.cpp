#include "ByteCodeRunner.h"
#include "NativeProgram.h"
#include "GarbageCollector.h"
#include "JitProgram.h"

#include <iomanip>
#include <sstream>

using namespace asmjit;
using namespace asmjit::x86;

const unsigned long MAX_JIT_MEMORY = 256*1024*1024;

// Registers used by the C++ calling convention

#ifndef _MSC_VER
const X86Gp rArg0 = rdi;
const X86Gp rArg1 = rsi;
const X86Gp rArg2 = rdx;
const X86Gp rArg3 = rcx;
#else
const X86Gp rArg0 = rcx;
const X86Gp rArg1 = rdx;
const X86Gp rArg2 = r8;
const X86Gp rArg3 = r9;
#endif

/*
 * This JIT implementation effectively simply converts bytecodes into
 * machine code that implements them at code load time. Performance
 * improvement comes mainly from avoiding the overhead of constantly
 * decoding bytecodes, and keeping some key values in registers.
 *
 * The only true code improvement comes from some local peephole
 * optimizations that avoid redundant writes and reads to the data
 * stack by e.g. carrying the result of one opcode to the next in rax.
 *
 *
 * FLOW to FLOW calling convention:
 *
 * ARGS IN:
 *   input args: flow data stack (callee free)
 *   called slot: rax (for closure)
 * BACKTRACE:
 *   linked list on the native C stack
 * OUT:
 *   return slot: rax
 *
 * PERSISTENT REGISTER ASSIGNMENTS:
 */

/*
 * Pointer to the C++ -> JIT trampoline call frame. Used for unwinding after an error.
 */
const X86Gp rCppFrame = rbp;

/*
 * Start address of the flow memory area (includes heap).
 * It is assumed to be immovable for the duration of execution.
 *
 * Flow pointer accesses are not error checked, so reserve full 4GB
 * to guarantee that invalid flow pointers naturally segfault.
 */
const X86Gp rMemBase = rbx;

/*
 * Address of ByteCodeRunner.
 */
const X86Gp rState = r12;

/*
 * Flow data stack pointer. Stack is assumed to be immovable.
 *
 * The stack grows up, so offsets to data are negative, e.g. top is -QWORD.
 *
 * Mirrors Runner->DataStack.pos while control is in JIT code.
 */
const X86Gp rDStack = r13;

/*
 * Pointer to the current flow call frame, located on the native C stack.
 * Frames form a linked list which is used for backtrace and during GC.
 * The register contains the address of the middle of the structure due to the way
 * it is updated.
 *
 * When control is transferred from JIT generated code, it is saved into Runner->JitCallFrame.
 *
 * FLOW BACKTRACE: LINKED LIST ON NATIVE STACK
 *   ptr+08h: native return addr
 *   ptr    : link ptr = saved cframe
 *   ptr-08h: saved dframe
 *   ptr-10h: saved closure
 */
const X86Gp rCFrame = r14;

/*
 * Pointer to the start of the current flow frame within the data stack (rDStack >= rDFrame).
 *
 * Used as the base for accessing function locals.
 */
const X86Gp rDFrame = r15;

/*
 * Current flow closure pointer.
 */
const X86Gp rClosure = r11;

/*
 * Temporary registers.
 */
const X86Gp rtmp0 = r8;
const X86Gp rtmp1 = r9;
const X86Gp rtmp2 = r10;
const X86Gp rtmp0d = r8d;
const X86Gp rtmp1d = r9d;
const X86Gp rtmp2d = r10d;

const int32_t QWORD = 8;

const char * tag2string(int tag);

// Memory layout data for GDB script
FlowGdbMemoryLayout *flow_gdb_memory_layout = NULL;
uint64_t flow_gdb_memory_layout_version = 0;

/*
 * Offset to field within structure of given type.
 */
#define FIELD_OFFSET(type,field) int32_t(reinterpret_cast<intptr_t>(&(reinterpret_cast<type*>(0)->field)))

/*
 * AsmJit reference to field within structure of given type, referenced via base pointer.
 */
#define FIELD_ACCESS(base,type,field) ptr(base,FIELD_OFFSET(type,field),sizeof(reinterpret_cast<type*>(0)->field))

/*
 * Reference to field within current ByteCodeRunner instance.
 */
#define STATE(field) FIELD_ACCESS(rState, ByteCodeRunner, field)



FlowJitProgram *loadJitProgram(ostream &e, const std::string &bytecode_file, const std::string &log_file, const unsigned long memory_limit)
{
	FlowJitProgram *program = new FlowJitProgram(e, log_file, memory_limit);
    if (program->Load(bytecode_file))
        return program;

    delete program;
    return NULL;
}

void deleteJitProgram(FlowJitProgram *program)
{
    delete program;
}

FlowJitProgram::FlowJitProgram(ostream &e, const std::string &log_fn, const unsigned long memory_limit) : err(e), memory_limit(memory_limit), log_filename(log_fn)
{
    layout_info.start = layout_info.end = layout_info.num_symbols = 0;
    layout_info.next = flow_gdb_memory_layout;
    flow_gdb_memory_layout = &layout_info;

    if (!log_filename.empty())
    {
        FILE *asmlog = fopen((log_fn + ".asmlog").c_str(), "w");
        asm_logger.setStream(asmlog);
        asm_logger.addOptions(Logger::kOptionHexDisplacement | Logger::kOptionBinaryForm | Logger::kOptionHexImmediate);
    }

    alloc_flow_const_data(4);
}

FlowJitProgram::~FlowJitProgram()
{
    if (!log_filename.empty())
        fclose(asm_logger.getStream());

    FlowGdbMemoryLayout **p = &flow_gdb_memory_layout;

    while (*p)
    {
        if (*p == &layout_info)
            *p = (*p)->next;
        else
            p = &(*p)->next;
    }

    flow_gdb_memory_layout_version++;
}

namespace {
    struct JitError {};
}

bool FlowJitProgram::handleError(Error, const char* message, CodeEmitter*)
{
    err << "JIT error: " << message << std::endl;
    throw JitError();
}

bool FlowJitProgram::Load(const std::string &bytecode_file)
{
    if (!flow_code.load_file(bytecode_file))
        return false;

    try {
        return compile();
    } catch (JitError) {
        return false;
    }
}

void FlowJitProgram::InitRunner(ByteCodeRunner *runner)
{
    // Copy flow strings and other things into flow memory area
    runner->DoInit((char*)flow_constant_buffer.data(), flow_constant_buffer.size(), false);

    runner->JitCallFrame = NULL;

    runner->DataStack.reserve(ByteCodeRunner::MAX_DATA_STACK);

    init_runner_funcs(runner);
    init_runner_structs(runner);
}

void FlowJitProgram::init_runner_funcs(ByteCodeRunner *runner)
{
    for (unsigned i = 0; i < functions.size(); i++)
    {
        FunctionInfo::Ptr func = functions[i];
        NativeFunction *native_fn = NULL;

        // For natives, try linking up to them.
        if (!func->native_name.empty())
        {
            native_fn = runner->MakeNativeFunction(func->native_name.c_str(), func->num_args, !!func->native_fallback);

            if (!native_fn)
            {
                if (!func->native_fallback) {
                    runner->ReportError(UnknownNativeName, "Unknown native: \"%s\"", func->native_name.c_str());
                    return;
                }

                func = func->native_fallback;
            }
        }

        // For non-natives, allocate a wrapper using the C++ -> JIT entry thunk.
        if (!native_fn)
        {
            native_fn = new SimpleNative(func->name.c_str(), func->num_args, entry_thunk_ptr);
        }

        native_fn->debug_token_ = MakeFlowPtr(func->addr.addr - uint64_t(code_buffer.data()));

        runner->Natives.push_back(native_fn);
        runner->JitFuncs.push_back((void*)func->addr.addr);
    }

    runner->FreezeNativeFunctions(false);
}

/*
 *  When a new native is dynamically registered from C++, add a reference to the
 *  generic native thunk for JIT->C++ calls via TNativeFn.
 */
void FlowJitProgram::RegisterNative(ByteCodeRunner *runner, unsigned id, NativeFunction * /*fn*/)
{
    while (runner->JitFuncs.size() <= id)
        runner->JitFuncs.push_back(invalid_native_ptr);

    runner->JitFuncs[id] = generic_native_ptr;
}

void FlowJitProgram::FreeNative(ByteCodeRunner *runner, unsigned id)
{
    if (id < runner->JitFuncs.size())
        runner->JitFuncs[id] = invalid_native_ptr;
}

void FlowJitProgram::init_runner_structs(ByteCodeRunner *runner)
{
    assert(runner->StructDefs.empty());

    unsigned count = structs.size();
    runner->StructDefs.reserve(count);
    runner->StructSizes.reserve(count);

    for (unsigned i = 0; i < count; i++)
    {
        StructInfo::Ptr sinfo = structs[i];
        StructDef sd;
        sd.Name = sinfo->name;
        sd.NameU = parseUtf8(sinfo->name);
        sd.FieldsCount = sinfo->num_fields;
        sd.CompareIdx = sinfo->compare_idx;

        sd.IsMutable = sinfo->is_mutable;
        sd.FieldNames = sinfo->field_names;
        sd.FieldTypes = sinfo->field_types;

        sd.ByteSize = sinfo->byte_size;
        sd.EmptyPtr = MakeFlowPtr(sinfo->empty_addr);
        sd.FieldDefs = sinfo->field_defs.data();
        sd.GCFieldCount = sinfo->field_gcdefs.size();
        sd.FieldGCDefs = sinfo->field_gcdefs.data();

        runner->RegisterStructDef(i, sd);
    }
}

std::string FlowJitProgram::AddressToFunction(FlowPtr code)
{
    static std::string invalid("<invalid>");

    std::map<uint64_t,LabelAddr*>::iterator it = mapFindLE(address_map, uint64_t(code_buffer.data()) + FlowPtrToInt(code));
    if (it != address_map.end())
        return it->second->name;

    return invalid;
}

void addStackFrame(std::vector<FlowStackFrame> *vec, FlowPtr insn, unsigned stack_place,
                   unsigned frame, FlowPtr closure, FlowPtr impersonate, ExtendedDebugInfo *dbg);

/*
 * Decodes the rCFrame list into a backtrace for error reports.
 */
void FlowJitProgram::ParseCallstack(std::vector<FlowStackFrame> *vec, ByteCodeRunner *runner)
{
    void **pframe = (void**)runner->JitCallFrame;

    while (pframe)
    {
        /*
         * FLOW BACKTRACE: LINKED LIST ON NATIVE STACK
         *   ptr+08h: native return addr
         *   ptr    : link ptr = saved cframe
         *   ptr-08h: saved dframe
         *   ptr-10h: saved closure
         */
        unsigned ptr = unsigned((uint8_t*)pframe[1] - code_buffer.data());
        unsigned fp = (StackSlot*)pframe[-1] - (StackSlot*)runner->DataStack.buf;

        addStackFrame(vec, MakeFlowPtr(ptr), 0, fp, MakeFlowPtr(unsigned(uintptr_t(pframe[-2]))), MakeFlowPtr(0), NULL);
        pframe = (void**)pframe[0];
    }
}

void FlowJitProgram::ResetRunner(ByteCodeRunner * /*runner*/)
{
	// WTF?...
    // runner = runner;
}

StackSlot FlowJitProgram::GetMainFunction()
{
    return StackSlot::MakeNativeFn(0);
}

bool FlowJitProgram::compile()
{
    // Parse bytecode
    if (!disassemble())
        return false;

    if (!find_functions())
        return false;

    if (!find_structs())
        return false;

    if (!find_global_inits())
        return false;

    // Initialize generation
    next_code_off = 0;
	next_data_off = committed_data_off = std::max(std::max(memory_limit, MAX_JIT_MEMORY), (unsigned long)flow_code.size() * 25);

    if (!code_buffer.reserve(next_data_off))
        return false;

    layout_info.start = (uint64_t)code_buffer.data();
    layout_info.end = layout_info.start + next_data_off;

    asm_holder.reset(true);

    uint8_t *base = code_buffer.data() + next_code_off;

    asm_codeinfo.init(ArchInfo::kTypeX64, 0, uintptr_t(base));
    asm_holder.init(asm_codeinfo);
    asm_holder.attach(&as);
    if (!log_filename.empty())
        asm_holder.setLogger(&asm_logger);
    asm_holder.setErrorHandler(this);

    // Generate code
    assemble_utilities();
    assemble_struct_fields();
    assemble_functions();
    assemble_global_init();

    if (asm_holder.getUnresolvedLabelsCount() > 0)
    {
        err << "Unresolved labels: " << asm_holder.getUnresolvedLabelsCount() << std::endl;

        for (size_t i = 0; i < asm_holder.getLabelsCount(); i++)
        {
            LabelEntry *lbl = asm_holder._labels[i];
            if (lbl->isBound() || !lbl->_links)
                continue;

            err << "  L" << i << std::endl;
        }

        return false;
    }

    // Emit code to the output buffer
    size_t size = asm_holder.getCodeSize();
    code_buffer.commit(next_code_off, next_code_off + size);

    unsigned real_size = asm_holder.relocate(base);
    code_buffer.executable(next_code_off, next_code_off + real_size);

    next_code_off += real_size;

	if (next_code_off > next_data_off) {
		const auto pageSize = MemoryArea::page_size();
		const auto suggestedLimit = (align_up(code_buffer.size() + (next_code_off - next_data_off), pageSize) + pageSize) / 1048576 + 1;
		err << "Warning! JIT code memory overlaps JIT data memory! Please set the limit equal or higher than "
			 << suggestedLimit
			 << " MBytes by passing --jit-memory-limit key!"
			 << std::endl;

		return false;
	}

    finalize_label_addrs(base);
    finalize_jumptables(base);
    link_struct_tables();

    // Free resources
    asm_holder.reset(true);
    bytecodes.clear();
    bytecode_list.clear();
    flow_code.reset();

    if (FILE *f = asm_logger.getStream())
        fflush(f);

    // Entry points
    entry_thunk_ptr = NativeFunctionPtr(entry_thunk.addr);
    invalid_native_ptr = (void*)invalid_native_fn.addr;
    generic_native_ptr = (void*)generic_native_fn.addr;
    return true;
}

bool FlowJitProgram::disassemble()
{
    CodeMemory code((char*)flow_code.data(), 0, flow_code.size());

    FlowInstruction::Map::iterator it = bytecodes.begin();

    while (!code.Eof())
    {
        it = bytecodes.insert(it, std::make_pair(code.GetPosition(), FlowInstruction()));

        if (!code.ParseOpcode(&it->second))
        {
            err << "Couldn't parse opcode at " << std::hex << FlowPtrToInt(it->first) << std::dec << std::endl;
            return false;
        }
    }

    bytecode_list.reserve(bytecodes.size());

    for (it = bytecodes.begin(); it != bytecodes.end(); ++it)
        bytecode_list.push_back(&*it);

    return true;
}

/*
 * Scan bytecode to determine the code ranges for every function.
 *
 * Also compiles tables of all required struct field accessor types.
 */
bool FlowJitProgram::find_functions()
{
    /* Collect initial struct defs */
    size_t i = 0;

    for (; i < bytecode_list.size(); i++)
    {
        if (bytecode_list[i]->second.op != CStructDef)
            break;

        structdef_list.push_back(bytecode_list[i]);
    }

    if (i >= bytecode_list.size() || bytecode_list[i]->second.op != CDebugInfo)
    {
        err << "CDebugInfo required after CStructDefs" << std::endl;
        return false;
    }

    /* Define the init function */
    FlowPtr first_valid_addr = bytecode_list[i]->first;

    FunctionInfo::Ptr main_func(new FunctionInfo(functions.size(), first_valid_addr, MakeFlowPtr(flow_code.size()), NULL, "$init"));
    functions.push_back(main_func);

    /* Collect globals */
    GlobalInfo::Ptr cur_global;
    std::map<FlowPtr,FlowInstruction::Pair*> funcs;

    for (; i < bytecode_list.size(); i++)
    {
        FlowInstruction::Pair *ipair = bytecode_list[i];

        switch (ipair->second.op)
        {
        case CStructDef:
            structdef_list.push_back(ipair);
            break;

        case CDebugInfo:
            if (cur_global)
                cur_global->end = ipair->first;

            cur_global = GlobalInfo::Ptr(new GlobalInfo(globals.size(), ipair->first, ipair->second.StrValue));
            globals.push_back(cur_global);
            break;

        case CNativeFn:
        case COptionalNativeFn:
        {
            FunctionInfo::Ptr native_func(new FunctionInfo(functions.size(), MakeFlowPtr(0), MakeFlowPtr(0), &ipair->second, cur_global->name));

            native_func->num_args = ipair->second.IntValue;
            native_func->native_name = ipair->second.StrValue;

            functions.push_back(native_func);
            native_function_map[ipair->first] = native_func;
            break;
        }

        case CCodePointer:
        case CClosurePointer:
            if (ipair->second.PtrValue < cur_global->start || ipair->second.PtrValue >= ipair->first)
            {
                err << "Invalid function address in opcode at " << std::hex << FlowPtrToInt(ipair->first) << std::endl;
                return false;
            }

            if (funcs.count(ipair->second.PtrValue))
            {
                err << "Duplicate function definition opcode at " << std::hex << FlowPtrToInt(ipair->first) << std::endl;
                return false;
            }

            funcs[ipair->second.PtrValue] = ipair;
            break;

        case CField:
        {
            int idx = ipair->second.IntValue;
            if (!struct_field_readers_idx.count(idx))
                struct_field_readers_idx[idx] = StructAccessorTable::Ptr(new StructAccessorTable(true, stl_sprintf("%d", idx)));
            break;
        }

        case CSetMutable:
        {
            int idx = ipair->second.IntValue;
            if (!struct_field_writers_idx.count(idx))
                struct_field_writers_idx[idx] = StructAccessorTable::Ptr(new StructAccessorTable(false, stl_sprintf("%d", idx)));
            break;
        }

        case CFieldName:
        {
            std::string name = ipair->second.StrValue;
            if (!struct_field_readers_name.count(name))
                struct_field_readers_name[name] = StructAccessorTable::Ptr(new StructAccessorTable(true, name));
            break;
        }

        case CSetMutableName:
        {
            std::string name = ipair->second.StrValue;
            if (!struct_field_writers_name.count(name))
                struct_field_writers_name[name] = StructAccessorTable::Ptr(new StructAccessorTable(false, name));
            break;
        }

        default:
            break;
        }
    }

    if (cur_global)
        cur_global->end = MakeFlowPtr(flow_code.size());

    /* Collect functions */
    for (i = 0; i < globals.size(); i++)
    {
        GlobalInfo::Ptr ginfo = globals[i];
        int idx = 0;

        for (std::map<FlowPtr,FlowInstruction::Pair*>::iterator it = funcs.lower_bound(ginfo->start);
             it != funcs.upper_bound(ginfo->end); ++it)
        {
            FunctionInfo::Ptr func(new FunctionInfo(functions.size(), it->first, it->second->first, &it->second->second, ginfo->name));

            functions.push_back(func);
            function_map[it->first] = func;

            if (idx > 0)
                func->name += stl_sprintf("$%d", idx);
            idx++;

            /* Verify the "CGoto skip; ..function..; skip: C*Pointer function" pattern */
            FlowInstruction::Map::iterator ii = bytecodes.find(it->first - 5);

            if (ii == bytecodes.end() || ii->second.op != CGoto || ii->second.PtrValue != it->second->first)
            {
                err << "Function not wrapped with CGoto at " << std::hex << FlowPtrToInt(it->first) << std::endl;
                return false;
            }
            else
            {
                function_skip_map.insert(ii->first);
            }
        }
    }

    return true;
}

FlowJitProgram::StructFieldAccessor::Ptr FlowJitProgram::get_field_accessor(DataTag type, int offset)
{
    StructFieldAccessor::Key key(type, offset);
    StructFieldAccessor::Ptr &ptr = struct_field_accessors[key];
    if (!ptr)
        ptr = StructFieldAccessor::Ptr(new StructFieldAccessor(key));

    return ptr;
}

bool FlowJitProgram::find_structs()
{
    // Parse definitions and compute field layout
    unsigned max_fieldcnt = 0;

    for (size_t si = 0; si < structdef_list.size(); si++)
    {
        FlowInstruction &insn = structdef_list[si]->second;
        StructInfo::Ptr sinfo(new StructInfo(insn.IntValue));

        structs.push_back(sinfo);
        struct_by_id[sinfo->compare_idx] = sinfo;

        sinfo->name = insn.StrValue;
        sinfo->num_fields = insn.IntValue2;
        sinfo->name_string = alloc_string_constant(parseUtf8(sinfo->name));
        sinfo->byte_size = 4;

        if (sinfo->num_fields > max_fieldcnt)
            max_fieldcnt = sinfo->num_fields;

        if (sinfo->num_fields > 0)
        {
            static const FlowStructFieldDef def_bool = FLOW_FIELD_DEF(bool, 0);
            static const FlowStructFieldDef def_int = FLOW_FIELD_DEF(int, 0);
            static const FlowStructFieldDef def_double = FLOW_FIELD_DEF(double, 0);
            static const FlowStructFieldDef def_string = FLOW_FIELD_DEF(string, 0);
            static const FlowStructFieldGCDef gcdef_string = FLOW_FIELD_GC_DEF(string, 0);
            static const FlowStructFieldDef def_array = FLOW_FIELD_DEF(array, 0);
            static const FlowStructFieldGCDef gcdef_array = FLOW_FIELD_GC_DEF(array, 0);
            static const FlowStructFieldDef def_ref = FLOW_FIELD_DEF(ref, 0);
            static const FlowStructFieldGCDef gcdef_ref = FLOW_FIELD_GC_DEF(ref, 0);
            static const FlowStructFieldDef def_struct = FLOW_FIELD_DEF(struct, 0);
            static const FlowStructFieldGCDef gcdef_struct = FLOW_FIELD_GC_DEF(struct, 0);
            static const FlowStructFieldDef def_slot = FLOW_FIELD_DEF(slot, 0);
            static const FlowStructFieldGCDef gcdef_slot = FLOW_FIELD_GC_DEF(slot, 0);

            for (unsigned i = 0; i < sinfo->num_fields; i++)
            {
                FlowInstruction::Field &field = insn.fields[i];

                sinfo->field_names.push_back(field.name);
                sinfo->field_types.push_back(field.type);
                sinfo->is_mutable.push_back(field.is_mutable);

                bool has_gc = true;
                FlowStructFieldDef fdef;
                FlowStructFieldGCDef gcdef;
                int size = 4;

                switch (field.type[0]) {
                case FTBool:
                    fdef = def_bool;
                    has_gc = false;
                    break;
                case FTInt:
                    fdef = def_int;
                    has_gc = false;
                    break;
                case FTDouble:
                    size = sizeof(double);
                    fdef = def_double;
                    has_gc = false;
                    break;
                case FTString:
                    size = sizeof(FlowStructString);
                    fdef = def_string;
                    gcdef = gcdef_string;
                    break;
                case FTArray:
                case FTTypedArray:
                    size = sizeof(FlowStructArray);
                    fdef = def_array;
                    gcdef = gcdef_array;
                    break;
                case FTRefTo:
                case FTTypedRefTo:
                    size = sizeof(FlowStructRef);
                    fdef = def_ref;
                    gcdef = gcdef_ref;
                    break;
                case FTStruct:
                case FTTypedStruct:
                    size = sizeof(FlowPtr);
                    fdef = def_struct;
                    gcdef = gcdef_struct;
                    break;
                default:
                    size = STACK_SLOT_SIZE;
                    fdef = def_slot;
                    gcdef = gcdef_slot;
                }

                fdef.offset = sinfo->byte_size;
                sinfo->field_defs.push_back(fdef);
                sinfo->field_accessors.push_back(get_field_accessor(fdef.tag, fdef.offset));

                if (has_gc)
                {
                    gcdef.offset = fdef.offset;
                    sinfo->field_gcdefs.push_back(gcdef);
                }

                sinfo->byte_size += size;
            }

            if (sinfo->byte_size >= MAX_EPHEMERAL_ALLOC)
            {
                err << "Struct too big: " << sinfo->name << " size is " << sinfo->byte_size << std::endl;
                return false;
            }
        }
    }

    // Reorder according to field count
    std::stable_sort(structs.begin(), structs.end(), StructInfo::compare_fieldcnt);
    struct_fcnt_limits.resize(max_fieldcnt+1, (int)structs.size());

    for (size_t i = 0; i < structs.size(); i++)
    {
        StructInfo::Ptr sinfo = structs[i];

        sinfo->index = i;
        sinfo->type_tag = StackSlot::MakeStruct(MakeFlowPtr(0), i).slot_private.QWordVal;

        struct_fcnt_limits[sinfo->num_fields] = i+1;

        if (sinfo->num_fields == 0)
        {
            unsigned addr = sinfo->empty_addr = alloc_flow_const_data(4);
            *(uint32_t*)&flow_constant_buffer[addr] = sinfo->index;
        }
    }

    // Resize accessor tables
    std::map<std::string, StructAccessorTable::Ptr>::iterator itn;

    for (itn = struct_field_readers_name.begin(); itn != struct_field_readers_name.end(); ++itn)
        itn->second->table.resize(structs.size());
    for (itn = struct_field_writers_name.begin(); itn != struct_field_writers_name.end(); ++itn)
        itn->second->table.resize(structs.size());

    std::map<int, StructAccessorTable::Ptr>::iterator iti;

    for (iti = struct_field_readers_idx.begin(); iti != struct_field_readers_idx.end(); ++iti)
        iti->second->table.resize(struct_fcnt_limits[iti->first]);
    for (iti = struct_field_writers_idx.begin(); iti != struct_field_writers_idx.end(); ++iti)
        iti->second->table.resize(struct_fcnt_limits[iti->first]);

    // Index field accessors
    for (size_t i = 0; i < structs.size(); i++)
    {
        StructInfo::Ptr sinfo = structs[i];

        for (unsigned j = 0; j < sinfo->num_fields; j++)
        {
            iti = struct_field_readers_idx.find(j);
            if (iti != struct_field_readers_idx.end())
                iti->second->table[i] = sinfo->field_accessors[j];

            itn = struct_field_readers_name.find(sinfo->field_names[j]);
            if (itn != struct_field_readers_name.end())
                itn->second->table[i] = sinfo->field_accessors[j];

            if (sinfo->is_mutable[j])
            {
                iti = struct_field_writers_idx.find(j);
                if (iti != struct_field_writers_idx.end())
                    iti->second->table[i] = sinfo->field_accessors[j];

                itn = struct_field_writers_name.find(sinfo->field_names[j]);
                if (itn != struct_field_writers_name.end())
                    itn->second->table[i] = sinfo->field_accessors[j];
            }
        }
    }

    return true;
}

/*
 * Extract the code of a function into a linear bytecode list, skipping any nested functions.
 */
void FlowJitProgram::extract_function_code(T_bytecode_list *plist, FlowPtr start, FlowPtr end)
{
    FlowInstruction::Map::iterator it = bytecodes.find(start);

    while (it != bytecodes.end() && it->first < end)
    {
        if (it->second.op != CStructDef)
            plist->push_back(&*it);

        if (it->second.op == CGoto && function_skip_map.count(it->first))
        {
            it = bytecodes.find(it->second.PtrValue);
        }
        else
        {
            ++it;
        }
    }
}

/*
 * Extract init code for each global, and detect optional native fallbacks.
 */
bool FlowJitProgram::find_global_inits()
{
    for (size_t i = 0; i < globals.size(); ++i)
    {
        GlobalInfo::Ptr pglob = globals[i];

        extract_function_code(&pglob->init_code, pglob->start, pglob->end);

        if (pglob->init_code.empty())
            return false;

        FlowInstruction::Pair *last = pglob->init_code.back();

        switch (last->second.op)
        {
        case CCodePointer:
            pglob->global_fn = function_map[last->second.PtrValue];
            break;

        case COptionalNativeFn:
        {
            pglob->global_fn = native_function_map[last->first];

            if (pglob->init_code.size() < 2)
            {
                cerr << "COptionalNativeFn alone in global init." << std::endl;
                return false;
            }

            last = pglob->init_code[pglob->init_code.size()-2];
            if (last->second.op != CCodePointer)
            {
                cerr << "COptionalNativeFn not paired with CCodePointer." << std::endl;
                return false;
            }

            pglob->global_fn->native_fallback = function_map[last->second.PtrValue];
            if (!pglob->global_fn->native_fallback)
            {
                cerr << "COptionalNativeFn: no native fallback function." << std::endl;
                return false;
            }
            break;
        }

        case CNativeFn:
            pglob->global_fn = native_function_map[last->first];
            break;

        default:
            break;
        }
    }

    return true;
}

/*
 * Allocate space in the native code constant memory area.
 */
uint8_t *FlowJitProgram::alloc_const_data(unsigned size)
{
    next_data_off -= size;

    if (next_data_off < committed_data_off)
    {
        unsigned new_commit = align_down(next_data_off, MemoryArea::page_size());
        code_buffer.commit(new_commit, committed_data_off);
        committed_data_off = new_commit;
    }

    return code_buffer.data() + next_data_off;
}

/*
 * Allocate space in the flow constant buffer.
 */
unsigned FlowJitProgram::alloc_flow_const_data(unsigned size)
{
    unsigned offset = flow_constant_buffer.size();
    flow_constant_buffer.resize(offset + size);

    return offset;
}

StackSlot FlowJitProgram::alloc_string_constant(const unicode_string &us)
{
    if (us.empty())
        return StackSlot::MakeEmptyString();

    unsigned stroff = alloc_flow_const_data(2 * us.size());
    memcpy(&flow_constant_buffer[stroff], us.data(), 2 * us.size());

    StackSlot str;

    if (us.size() & 0xffff0000)
    {
        unsigned refoff = alloc_flow_const_data(2 * 4);
        unsigned *pref = (unsigned*)&flow_constant_buffer[refoff];

        pref[0] = us.size() & 0xffffu;
        pref[1] = stroff;
        StackSlot::InternalSetString(str, MakeFlowPtr(refoff), us.size()>>16, true);
    }
    else
    {
        StackSlot::InternalSetString(str, MakeFlowPtr(stroff), us.size(), false);
    }

    return str;
}

X86Mem FlowJitProgram::const_qword(uint64_t value)
{
    uint64_t &addr = const_qword_map[value];

    if (!addr) {
        uint8_t *ptr = alloc_const_data(8);
        *(uint64_t*)ptr = value;

        addr = uint64_t(ptr);
    }

    return ptr(addr);
}

X86Mem FlowJitProgram::LabelAddr::ptr() const
{
    if (addr)
        return asmjit::x86::ptr(addr);
    else
        return asmjit::x86::ptr(label);
}

Error FlowJitProgram::LabelAddr::call(X86Assembler &as) const
{
    if (addr)
        return as.call(addr);
    else
        return as.call(label);
}

Error FlowJitProgram::LabelAddr::jump(X86Assembler &as, asmjit::X86Inst::Id insn) const
{
    if (addr)
        return as.emit(insn, addr);
    else
        return as.emit(insn, label);
}

Error FlowJitProgram::LabelAddr::bind(Assembler &as)
{
    if (Logger *log = as.getCode()->getLogger())
        log->logf("//--- %s ---\n", name.c_str());

    return as.bind(label);
}

void FlowJitProgram::new_label_addr(LabelAddr *paddr, const std::string &name)
{
    active_addrs.push_back(paddr);

    paddr->name = name;
    paddr->label = as.newLabel();
}

void FlowJitProgram::finalize_label_addrs(uint8_t *base)
{
    for (size_t i = 0; i < active_addrs.size(); i++)
    {
        LabelAddr *paddr = active_addrs[i];
        paddr->addr = uint64_t(base + asm_holder.getLabelOffset(paddr->label));

        address_map[paddr->addr] = paddr;
    }

    active_addrs.clear();

    layout_symbols.clear();
    layout_symbols.reserve(address_map.size());

    if (!log_filename.empty())
    {
        FILE *asmmap = fopen((log_filename + ".asmmap").c_str(), "w");

        for (std::map<uint64_t,LabelAddr*>::iterator it = address_map.begin(); it != address_map.end(); ++it)
        {
            FlowGdbMemorySymbol symbol = { it->first, it->second->name.c_str() };
            layout_symbols.push_back(symbol);

            fprintf(asmmap, "%016lx: %s\n", symbol.addr, symbol.name);
        }

        fclose(asmmap);
    }

    layout_info.num_symbols = layout_symbols.size();
    layout_info.symbols = layout_symbols.data();
    flow_gdb_memory_layout_version++;
}

asmjit::X86Mem FlowJitProgram::alloc_jumptable(const std::vector<Label> &table)
{
    uint64_t *p = (uint64_t*)alloc_const_data(table.size() * QWORD);

    pending_jumptables[p] = table;

    return ptr(uint64_t(p));
}

void FlowJitProgram::finalize_jumptables(uint8_t *base)
{
    for (T_pending_jumptables::iterator it = pending_jumptables.begin(); it != pending_jumptables.end(); ++it)
    {
        for (size_t i = 0; i < it->second.size(); i++)
            it->first[i] = uint64_t(base + asm_holder.getLabelOffset(it->second[i]));
    }

    pending_jumptables.clear();
}

/* ASSEMBLER "MACROS" */

/*
 * Verify that the 64-bit slot in input is of the appropriate type via '(input.tag & mask) == check'.
 *
 * Clobbers tmp.
 */
void FlowJitProgram::CheckAssembler::asm_check_tag(X86Gp input, unsigned mask, unsigned check, DataTag tag, X86Gp tmp)
{
    X86Assembler &as = owner->as;

    Label &lbl = type_trampolines[std::make_pair(input.getId(),tag)];
    if (!lbl.isValid())
        lbl = as.newLabel();

    as.mov(tmp, input);
    as.shr(tmp, 48);

    X86Gpd tmpd = tmp.r32();

    if (mask != 0xffff)
        as.and_(tmpd, mask);

    as.cmp(tmpd, check);
    as.jne(lbl);
}

/*
 * Verify that the value in input is a double precision number.
 *
 * Clobbers tmp.
 */
void FlowJitProgram::CheckAssembler::asm_check_double(asmjit::X86Gp input, asmjit::X86Gp tmp)
{
    X86Assembler &as = owner->as;

    Label &lbl = type_trampolines[std::make_pair(input.getId(),TDouble)];
    if (!lbl.isValid())
        lbl = as.newLabel();

    Label ok = as.newLabel();
    X86Gpd tmpd = tmp.r32();

    as.mov(tmp, input);
    as.shr(tmp, 48);
    // fail if lowest 3 bits aren't 0 and the nan mask is set
    as.test(tmpd, 7);
    as.short_().jz(ok);
    as.and_(tmpd, StackSlot::TAG_NAN);
    as.cmp(tmpd, StackSlot::TAG_NAN);
    as.je(lbl);
    as.bind(ok);
}

/*
 * Verify that the function index in idx does not overrun Runner->JitFuncs.
 */
void FlowJitProgram::CheckAssembler::asm_check_funcidx(X86Gp idx, X86Gp value)
{
    X86Assembler &as = owner->as;

    Label &lbl = funcidx_trampolines[value.getId()];
    if (!lbl.isValid())
        lbl = as.newLabel();

    as.cmp(idx.r32(), STATE(JitFuncs.pos));
    as.jae(lbl);
}

/*
 * Verify that array index idx doesn't exceed size limit.
 */
void FlowJitProgram::CheckAssembler::asm_check_arridx(X86Gp idx, X86Gp limit)
{
    X86Assembler &as = owner->as;
    T_arridx_trampolines::key_type key(idx.getId(), limit.getId());

    Label &lbl = arridx_trampolines[key];
    if (!lbl.isValid())
        lbl = as.newLabel();

    as.cmp(idx.r32(), limit.r32());
    as.jae(lbl);
}

/*
 * Extract struct id index from value into idx, and verify that it is valid for the given accessor table.
 */
void FlowJitProgram::CheckAssembler::asm_check_structidx(asmjit::X86Gp idx, asmjit::X86Gp value, StructAccessorTable::Ptr table)
{
    X86Assembler &as = owner->as;
    T_structidx_trampolines::key_type key(value.getId(), table);

    Label &lbl = structidx_trampolines[key];
    if (!lbl.isValid())
        lbl = as.newLabel();

    as.mov(idx, value);
    as.shr(idx, 32);
    as.movzx(idx.r32(), idx.r16());
    as.cmp(idx.r32(), uint32_t(table ? table->table.size() : owner->structs.size()));
    as.jae(lbl);
}

bool FlowJitProgram::CheckAssembler::needs_flush() {
    return !type_trampolines.empty() ||
            !funcidx_trampolines.empty() ||
            !arridx_trampolines.empty() ||
            !structidx_trampolines.empty();
}

/*
 * Emits pending handlers for error check failures.
 *
 * Handlers can use either jump or call to invoke the actual
 * error report function; however it never returns in either
 * case so the distinction is purely for backtrace reasons.
 */
void FlowJitProgram::CheckAssembler::flush(bool use_jmp)
{
    X86Assembler &as = owner->as;

    for (T_type_trampolines::iterator it = type_trampolines.begin();
         it != type_trampolines.end(); ++it)
    {
        as.bind(it->second);
        as.mov(rArg1,  X86Gpq(it->first.first));
        as.mov(rArg2.r32(), uint32_t(it->first.second));
        if (use_jmp)
            owner->thunk_type_error.jmp(as);
        else
            owner->thunk_type_error.call(as);
    }

    for (T_funcidx_trampolines::iterator it = funcidx_trampolines.begin();
         it != funcidx_trampolines.end(); ++it)
    {
        as.bind(it->second);
        as.mov(rArg1, X86Gpq(it->first));
        if (use_jmp)
            owner->thunk_func_error.jmp(as);
        else
            owner->thunk_func_error.call(as);
    }

    for (T_arridx_trampolines::iterator it = arridx_trampolines.begin();
         it != arridx_trampolines.end(); ++it)
    {
        as.bind(it->second);
        owner->assemble_assign_args(X86Gpd(it->first.first), X86Gpd(it->first.second), rArg3);
        if (use_jmp)
            owner->thunk_arridx_error.jmp(as);
        else
            owner->thunk_arridx_error.call(as);
    }

    for (T_structidx_trampolines::iterator it = structidx_trampolines.begin();
         it != structidx_trampolines.end(); ++it)
    {
        as.bind(it->second);
        as.mov(rtmp0, X86Gpq(it->first.first));

        if (it->first.second)
        {
            if (use_jmp)
                it->first.second->fn_fail.jmp(as);
            else
                it->first.second->fn_fail.call(as);
        }
        else
        {
            as.xor_(rax, rax);

            if (use_jmp)
                owner->thunk_field_error.jmp(as);
            else
                owner->thunk_field_error.call(as);
        }
    }
}

/*
 * Generate flow function prolog that correctly forms the call frame.
 */
void FlowJitProgram::asm_enter_frame()
{
    as.push(rCFrame);
    as.mov(rCFrame, rsp);
    as.push(rDFrame);
    as.push(rClosure);
}

/*
 * Generate flow function epilog that exits the flow call frame.
 */
void FlowJitProgram::asm_leave_frame(bool ret)
{
    as.pop(rClosure);
    as.pop(rDFrame);
    as.pop(rCFrame);

    if (ret)
        as.ret();
}

/*
 * Flush data from registers into ByteCodeRunner fields before calling to C++.
 */
void FlowJitProgram::asm_leave_flow()
{
    as.mov(STATE(JitCallFrame), rCFrame);
    as.mov(STATE(DataStack.pos), rDStack);
}

/*
 * Restore appropriate state after returning to JIT code from C++, and unwind on error.
 */
void FlowJitProgram::asm_enter_flow(bool check_error)
{
    if (check_error)
    {
        as.mov(ecx, STATE(LastError));
        as.test(ecx, ecx);
        unwind_flow.jnz(as);
    }
}

/*
 * Decode the function index from a TNativeFn value and check that it is valid.
 */
void FlowJitProgram::asm_decode_funcidx(asmjit::X86Gp idx, asmjit::X86Gp value, CheckAssembler &checker)
{
    Label direct = as.newLabel();

    X86Gpd idxd = idx.r32();

    as.mov(idxd, value.r32());
    as.test(value, value);
    as.short_().jns(direct);

    as.mov(idxd, ptr(rMemBase, idx, 0, -4));
    as.bind(direct);

    checker.asm_check_funcidx(idxd, value);
}

/*
 * Decode array data pointer and size from a TArray value.
 */
void FlowJitProgram::asm_decode_arrdim(asmjit::X86Gp rptr, asmjit::X86Gp size, asmjit::X86Gp src)
{
    X86Gp srcd = src.r32();
    X86Gp sized = size.r32();

    as.mov(rptr.r32(), srcd);
    as.add(rptr, rMemBase);

    as.shr(src, 32);
    /*
    as.xor_(sized, sized);
    as.test(srcd, srcd);
    as.cmovns(srcd, sized);

    as.movzx(sized, ptr(rptr, 0, 2));
    as.shl(srcd, 16);
    as.or_(sized, srcd);
    */

    Label lbl = as.newLabel();

    as.test(srcd, srcd);
    as.movzx(sized, srcd.r16());
    as.short_().jns(lbl);

    as.movzx(srcd, ptr(rptr, 0, 2));
    as.shl(sized, 16);
    as.or_(sized, srcd);

    as.bind(lbl);
}

/* SYSTEM CALLBACKS FOR CALLS FROM JIT */

void FlowJitProgram::callback_type_error(ByteCodeRunner *runner, StackSlot value, DataTag tag)
{
    runner->ReportTagError(value, tag, "<register>", NULL);
}

void FlowJitProgram::callback_func_error(ByteCodeRunner *runner, StackSlot value)
{
    runner->ReportError(InvalidNativeId, "Invalid function %d", runner->GetNativeFnId(value));
}

void FlowJitProgram::callback_field_error(ByteCodeRunner *runner, StackSlot value, StructAccessorTable *table)
{
    if (table)
        runner->ReportFieldNameError(value, table->name.c_str(), table->is_reader ? "read" : "write");
    else
        runner->ReportError(UnknownStructDefId, "Unknown struct kind: %d", value.GetStructId());
}

void FlowJitProgram::callback_arridx_error(ByteCodeRunner *runner, int access, uint32_t size)
{
    runner->ReportError(InvalidArgument, "Array index out of bounds: %d for array of size %u", access, size);
}

uint64_t FlowJitProgram::callback_allocate(ByteCodeRunner *runner, uint32_t size)
{
    return FlowPtrToInt(runner->AllocateInner(size));
}

void FlowJitProgram::callback_register_slot_write(ByteCodeRunner *runner, uint32_t addr, int count)
{
    runner->RegisterWrite(MakeFlowPtr(addr), count);
}

void FlowJitProgram::callback_register_ref_write(ByteCodeRunner *runner, uint32_t addr)
{
    runner->RegisterWrite(MakeFlowPtr(addr+4));
}

void FlowJitProgram::callback_register_struct_write(ByteCodeRunner *runner, uint32_t addr)
{
    FlowPtr base = MakeFlowPtr(addr);
    runner->RegisterWrite(runner->Memory.GetStructPointer(base, true), base);
}

void FlowJitProgram::callback_uncaught_switch(ByteCodeRunner *runner)
{
    runner->ReportError(UncaughtSwitch, "Unexpected case in switch.");
}

void FlowJitProgram::callback_freeze_globals(ByteCodeRunner *runner)
{
    // After all globals are initialized, make the memory read only to detect improper stack usage.
    StackSlot *cur = runner->DataStack.pos;

    runner->DataStack.pos = (StackSlot*)align_up(uintptr_t(cur), MemoryArea::page_size());
    memset(cur, -1, (runner->DataStack.pos - cur) * sizeof(StackSlot));

    runner->NumFrozenDataStack = runner->DataStack.pos - runner->DataStack.data();
    runner->DataStack.readonly(runner->NumFrozenDataStack, true);
}

/* UTILITY FUNCTIONS */

/*
 * Generate critically important thunks for JIT<->C++ interaction,
 * and a set of utility functions manually implemented for use in code.
 */
void FlowJitProgram::assemble_utilities()
{
    // Register labels
    new_label_addr(&entry_thunk, "$entry_thunk");
    new_label_addr(&unwind_flow, "$unwind_flow");
    new_label_addr(&thunk_type_error, "$thunk_type_error");
    new_label_addr(&thunk_func_error, "$thunk_func_error");
    new_label_addr(&thunk_field_error, "$thunk_field_error");
    new_label_addr(&thunk_arridx_error, "$thunk_arridx_error");
    new_label_addr(&thunk_register_slot_write, "$thunk_register_slot_write");
    new_label_addr(&thunk_register_ref_write, "$thunk_register_ref_write");
    new_label_addr(&thunk_compare, "$compare");
    new_label_addr(&thunk_plus_string, "$plus_string");
    new_label_addr(&thunk_uncaught_switch, "$uncaught_switch");
    new_label_addr(&thunk_freeze_globals, "$freeze_globals");

    new_label_addr(&util_allocate, "$allocate");
    new_label_addr(&util_init_array, "$init_array");
    new_label_addr(&util_init_closure, "$init_closure");
    new_label_addr(&util_init_ref, "$init_ref");
    new_label_addr(&util_pre_struct_write, "$pre_struct_write");

    new_label_addr(&util_add, "$add");
    new_label_addr(&util_sub, "$sub");
    new_label_addr(&util_mul, "$mul");
    new_label_addr(&util_div, "$div");
    new_label_addr(&util_mod, "$mod");
    new_label_addr(&util_neg, "$neg");
    new_label_addr(&util_double2string, "$double2string");
    new_label_addr(&util_int2string, "$int2string");

    qword_tag_int = const_qword(StackSlot::MakeInt(0).slot_private.QWordVal);
    qword_tag_bool = const_qword(StackSlot::MakeBool(0).slot_private.QWordVal);

    // Main entry thunk for calling any exported flow function via TNativeFn from C++
    assemble_entry_thunk();

    // Thunks for error reporting functions
    thunk_type_error.bind(as);
    assemble_cpp_call_thunk((void*)callback_type_error, rArg1, rArg2, rArg3, true);

    thunk_func_error.bind(as);
    assemble_cpp_call_thunk((void*)callback_func_error, rArg1, rArg2, rArg3, true);

    thunk_field_error.bind(as);
    assemble_cpp_call_thunk((void*)callback_field_error, rtmp0, rax, rArg3, true);

    thunk_arridx_error.bind(as);
    assemble_cpp_call_thunk((void*)callback_arridx_error, rArg1, rArg2, rArg3, true);

    thunk_uncaught_switch.bind(as);
    assemble_cpp_call_thunk((void*)callback_uncaught_switch, rArg1, rArg2, rArg3, true);

    // Thunks for GC related operations
    thunk_register_slot_write.bind(as);
    assemble_cpp_call_thunk((void*)callback_register_slot_write, eax, ecx, rArg3);

    thunk_register_ref_write.bind(as);
    assemble_cpp_call_thunk((void*)callback_register_ref_write, eax, rArg2, rArg3);

    thunk_freeze_globals.bind(as);
    assemble_cpp_call_thunk((void*)callback_freeze_globals, rArg1, rArg2, rArg3);

    // Generic comparison
    thunk_compare.bind(as);
    assemble_compare_thunk();

    // Call to an invalid native
    new_label_addr(&invalid_native_fn, "$invalid_native");

    invalid_native_fn.bind(as);
    as.mov(rArg1, rax);
    thunk_func_error.jmp(as);

    // Thunk for calling any C++ native from JIT via TNativeFn
    new_label_addr(&generic_native_fn, "$generic_native_thunk");

    generic_native_fn.bind(as);
    assemble_generic_native_thunk();

    // Utilities
    as.align(kAlignCode, 16);
    util_allocate.bind(as);
    assemble_util_allocate();

    as.align(kAlignCode, 16);
    util_init_array.bind(as);
    assemble_util_init_array(false);

    as.align(kAlignCode, 16);
    util_init_closure.bind(as);
    assemble_util_init_array(true);

    as.align(kAlignCode, 16);
    util_init_ref.bind(as);
    assemble_util_init_ref();

    as.align(kAlignCode, 16);
    util_pre_struct_write.bind(as);
    assemble_util_pre_struct_write();

    assemble_math_ops();
}

void FlowJitProgram::assemble_entry_thunk()
{
    CheckAssembler checker(this);

    /*
     * C++ to JIT entry thunk, responsible for correctly setting up
     * the stack frame and register values, and transferring control
     * to the appropriate JIT generated function.
     *
     * Arguments (matching C++ native function):
     *   rArg0: ByteCodeRunner*
     *   rArg1: StackSlot*
     */
    entry_thunk.bind(as);

    /*
     * C++ to Flow stack frame:
     *
     * retaddr
     * rbp     <- rbp
     * rbx
     * rsi
     * rdi
     * r12
     * r13
     * r14
     * r15
     * --pad--
     * retaddr
     * cframe <- cframe
     * dframe
     * closure
     *
     */

    as.push(rbp);
    as.mov(rbp, rsp);

    as.push(rbx);
    as.push(rsi);
    as.push(rdi);
    as.push(r12);
    as.push(r13);
    as.push(r14);
    as.push(r15);
    as.push(r15); // stack alignment

    // Init common regs
    as.mov(rState, rArg0);
    as.mov(rsi, rArg1);

    as.mov(rMemBase, STATE(Memory.Buffer));
    as.mov(rDStack, STATE(DataStack.pos));
    as.mov(rCFrame, STATE(JitCallFrame));
    as.mov(rDFrame, rDStack);
    as.xor_(rClosure, rClosure);

    // Find function index
    as.mov(rax, ptr(rsi, -QWORD));

    checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_NATIVEFN, TNativeFn, rcx);

    asm_decode_funcidx(rcx, rax, checker);

    // Retrieve function and native struct
    as.mov(rtmp0, STATE(JitFuncs.buf));
    as.mov(rtmp1, STATE(Natives.buf));

    as.mov(rtmp0, ptr(rtmp0, rcx, 3));
    as.mov(rtmp1, ptr(rtmp1, rcx, 3));

    // Copy args to stack
    as.mov(ecx, ptr(rtmp1, FIELD_OFFSET(NativeFunction, num_args_)));
    as.mov(rdi, rDStack);
    as.rep().movsq();
    as.mov(rDStack, rdi);

    // Invoke
    as.call(rtmp0);

    // Exit
    as.mov(STATE(DataStack.pos), rDFrame);
    as.mov(STATE(JitCallFrame), rCFrame);

    as.pop(r15);
    as.pop(r15);
    as.pop(r14);
    as.pop(r13);
    as.pop(r12);
    as.pop(rdi);
    as.pop(rsi);
    as.pop(rbx);
    as.pop(rbp);
    as.ret();

    /*
     * Unwind helper, which immediately exits all flow code
     * up to the closest entry thunk.
     */
    unwind_flow.bind(as);

    // Reset stack to flow frame called by Invoke above
    as.lea(rsp, ptr(rbp, -11 * QWORD));

    // Exit the frame and return to Exit
    as.pop(rDFrame);
    as.pop(rCFrame);
    as.ret();

    checker.flush();
}

/*
 * Implementation of ByteCodeRunner::Allocate in assembly.
 */
void FlowJitProgram::assemble_util_allocate()
{
#if 0
    // gc stress test
#else
    Label alloc_big = as.newLabel();

    // INPUT: ecx=size
    as.mov(eax, STATE(hp));
    as.sub(eax, ecx);
    as.short_().jb(alloc_big);

    as.and_(eax, -4);
    as.cmp(eax, STATE(hpbound));
    as.short_().jb(alloc_big);

    as.cmp(ecx, MAX_EPHEMERAL_ALLOC);
    as.short_().ja(alloc_big);

    as.mov(STATE(hp), eax);
    as.ret();

    as.bind(alloc_big);
#endif

    assemble_cpp_call_thunk((void*)callback_allocate, ecx, rArg2, rArg3);
}

/*
 * Utility for copying slots from data stack to array or closure.
 * Array/closure value stored to stack.
 */
void FlowJitProgram::assemble_util_init_array(bool closure)
{
    if (closure)
    {
        // INPUT: ecx=size, edx=id, rax=closure

        // init header
        as.mov(edi, eax);
        as.lea(rdi, ptr(rMemBase, rdi, 0, 4));
        as.mov(ptr(rdi, -8), edx);
        as.movzx(edx, cx);
        as.mov(ptr(rdi, -4), edx);
    }
    else
    {
        // INPUT: ecx=size, rax=array

        // init header
        as.mov(edi, eax);
        as.movzx(edx, cx);
        as.lea(rdi, ptr(rMemBase, rdi, 0, 4));
        as.mov(ptr(rdi, -4), edx);
    }

    // move stack pointer
    as.mov(edx, ecx);
    as.neg(rdx);
    as.lea(rDStack, ptr(rDStack, rdx, 3));

    // copy stack to heap
    as.mov(rtmp0d, ecx);
    as.mov(rsi, rDStack);
    as.rep().movsq();

    // store new array slot to stack
    as.mov(ptr(rDStack), rax);
    as.add(rDStack, QWORD);

    // register write if needed
    Label do_reg = as.newLabel();
    as.cmp(eax, STATE(hp_big_pos));
    as.short_().jae(do_reg);
    as.ret();

    as.bind(do_reg);
    as.add(eax, 4);
    as.mov(ecx, rtmp0d);
    thunk_register_slot_write.jmp(as);
}

/*
 * Utility that initializes a newly allocated reference by assigning the ref id.
 * Resulting slot in rax.
 */
void FlowJitProgram::assemble_util_init_ref()
{
    as.lea(rdi, ptr(rMemBase, rax, 0));

    as.mov(ecx, STATE(NextRefId));
    as.inc(STATE(NextRefId));

    as.movzx(edx, cx);
    as.mov(ptr(rdi), edx);

    Label small = as.newLabel();
    as.shr(ecx, 16);
    as.test(ecx, ecx);
    as.short_().jz(small);

    as.or_(ecx, uint32_t(StackSlot::TAG_REFTO|StackSlot::TAG_SIGN)<<16);
    as.shl(rcx, 32);
    as.or_(rax, rcx);
    as.ret();

    as.bind(small);
    as.or_(edx, uint32_t(StackSlot::TAG_REFTO)<<16);
    as.shl(rdx, 32);
    as.or_(rax, rdx);
    as.ret();
}

/*
 * Utility that registers update to a struct with GC if necessary.
 *
 *  stack=struct rax=val => rtmp0=struct rdi=structptr
 */
void FlowJitProgram::assemble_util_pre_struct_write()
{
    Label test_register_write = as.newLabel();
    Label register_slow = as.newLabel();

    CheckAssembler checker(this);

    // Fetch struct slot, verify tag and compute memory address
    as.mov(rtmp0, ptr(rDStack, -QWORD));

    checker.asm_check_tag(rtmp0, StackSlot::TAG_NOSIGN, StackSlot::TAG_STRUCT, TStruct, rcx);

    as.mov(edi, rtmp0d);
    as.add(rdi, rMemBase);

    // No need to register if in new generation
    as.cmp(rtmp0d, STATE(hp_big_pos));
    as.short_().jae(test_register_write);
    as.ret();

    // Check the gc tag; if 0 it is already registered
    as.align(kAlignCode, 8);
    as.bind(test_register_write);
    as.mov(ecx, ptr(rdi));
    as.shr(ecx, 16);
    as.test(ecx, ecx);
    as.short_().jnz(register_slow);
    as.ret();

    checker.flush(true);

    // Call C++
    as.align(kAlignCode, 16);
    as.bind(register_slow);

    asm_enter_frame();

    as.mov(rDFrame, rDStack);
    as.mov(ptr(rDStack), rax);
    as.add(rDStack, QWORD);

    asm_leave_flow();
    as.mov(rArg1.r32(), rtmp0d);
    as.mov(rArg0, rState);

    asm_cpp_call((void*)callback_register_struct_write);

    asm_enter_flow();

    as.mov(rDStack, rDFrame);
    as.mov(rtmp0, ptr(rDStack,-QWORD));
    as.mov(rax, ptr(rDStack));

    as.mov(edi, rtmp0d);
    as.add(rdi, rMemBase);

    asm_leave_frame();
}

/*
 * Generate implementation of dynamically typed math operations.
 */
void FlowJitProgram::assemble_math_ops()
{
    // ADD
    as.align(kAlignCode, 16);
    util_add.bind(as);

    // ARGS: stack stack -> stack (both on stack because string concat uses C++ call)
    if (true) {
        CheckAssembler checker(this);
        Label not_int = as.newLabel();

        as.mov(rax, ptr(rDStack, -QWORD));

        as.mov(rcx, rax);
        as.shr(rcx, 48);
        as.cmp(ecx, StackSlot::TAG_INT);
        as.short_().jne(not_int);

        // INT
        as.mov(rdx, ptr(rDStack, -2*QWORD));
        checker.asm_check_tag(rdx, 0xffff, StackSlot::TAG_INT, TInt, rcx);

        as.add(eax, edx);
        as.or_(rax, qword_tag_int);

        as.mov(ptr(rDStack, -2*QWORD), rax);
        as.sub(rDStack, QWORD);
        as.ret();

        as.bind(not_int);
        as.and_(ecx, StackSlot::TAG_NOSIGN);
        as.cmp(ecx, StackSlot::TAG_STRING);
        as.je(thunk_plus_string.label);

        // DOUBLE
        checker.asm_check_double(rax, rcx);
        as.movq(xmm1, rax);

        as.mov(rax, ptr(rDStack, -2*QWORD));
        checker.asm_check_double(rax, rcx);
        as.movq(xmm0, rax);

        as.addsd(xmm0, xmm1);
        as.movsd(ptr(rDStack, -2*QWORD), xmm0);

        as.sub(rDStack, QWORD);
        as.ret();

        checker.flush(true);

        // STRING
        as.align(kAlignCode, 16);
        thunk_plus_string.bind(as);

        assemble_plus_string_thunk();
    }

    // SUB
    as.align(kAlignCode, 16);
    util_sub.bind(as);

    // ARGS: stack rax -> rax
    if (true) {
        CheckAssembler checker(this);
        Label not_int = as.newLabel();

        as.mov(rcx, rax);
        as.shr(rcx, 48);
        as.cmp(ecx, StackSlot::TAG_INT);
        as.short_().jne(not_int);

        // INT
        as.sub(rDStack, QWORD);
        as.mov(rdx, ptr(rDStack));
        checker.asm_check_tag(rdx, 0xffff, StackSlot::TAG_INT, TInt, rcx);

        as.sub(edx, eax);
        as.or_(rdx, qword_tag_int);

        as.mov(rax, rdx);
        as.ret();

        // DOUBLE
        as.bind(not_int);

        checker.asm_check_double(rax, rcx);
        as.movq(xmm1, rax);

        as.sub(rDStack, QWORD);
        as.mov(rax, ptr(rDStack));
        checker.asm_check_double(rax, rcx);
        as.movq(xmm0, rax);

        as.subsd(xmm0, xmm1);

        as.movq(rax, xmm0);
        as.ret();

        checker.flush(true);
    }

    // MUL
    as.align(kAlignCode, 16);
    util_mul.bind(as);

    // ARGS: stack rax -> rax
    if (true) {
        CheckAssembler checker(this);
        Label not_int = as.newLabel();

        as.mov(rcx, rax);
        as.shr(rcx, 48);
        as.cmp(ecx, StackSlot::TAG_INT);
        as.short_().jne(not_int);

        // INT
        as.sub(rDStack, QWORD);
        as.mov(rtmp0d, eax);

        as.mov(rax, ptr(rDStack));
        checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);

        as.imul(rtmp0d);
        as.or_(rax, qword_tag_int);

        as.ret();

        // DOUBLE
        as.bind(not_int);

        checker.asm_check_double(rax, rcx);
        as.movq(xmm1, rax);

        as.sub(rDStack, QWORD);
        as.mov(rax, ptr(rDStack));
        checker.asm_check_double(rax, rcx);
        as.movq(xmm0, rax);

        as.mulsd(xmm0, xmm1);

        as.movq(rax, xmm0);
        as.ret();

        checker.flush(true);
    }

    // DIV
    as.align(kAlignCode, 16);
    util_div.bind(as);

    // ARGS: stack rax -> rax
    if (true) {
        CheckAssembler checker(this);
        Label not_int = as.newLabel();

        as.mov(rcx, rax);
        as.shr(rcx, 48);
        as.cmp(ecx, StackSlot::TAG_INT);
        as.short_().jne(not_int);

        // INT
        as.sub(rDStack, QWORD);
        as.mov(rtmp0d, eax);

        as.mov(rax, ptr(rDStack));
        checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);

        as.cdq();
        as.idiv(rtmp0d);
        as.or_(rax, qword_tag_int);

        as.ret();

        // DOUBLE
        as.bind(not_int);

        checker.asm_check_double(rax, rcx);
        as.movq(xmm1, rax);

        as.sub(rDStack, QWORD);
        as.mov(rax, ptr(rDStack));
        checker.asm_check_double(rax, rcx);
        as.movq(xmm0, rax);

        as.divsd(xmm0, xmm1);

        as.movq(rax, xmm0);
        as.ret();

        checker.flush(true);
    }

    // MOD
    as.align(kAlignCode, 16);
    util_mod.bind(as);

    // ARGS: stack rax -> rax
    if (true) {
        CheckAssembler checker(this);
        Label not_int = as.newLabel();

        as.mov(rcx, rax);
        as.shr(rcx, 48);
        as.cmp(ecx, StackSlot::TAG_INT);
        as.short_().jne(not_int);

        // INT
        as.sub(rDStack, QWORD);
        as.mov(rtmp0d, eax);

        as.mov(rax, ptr(rDStack));
        checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);

        as.cdq();
        as.idiv(rtmp0d);
        as.mov(eax, edx);
        as.or_(rax, qword_tag_int);

        as.ret();

        // DOUBLE
        as.bind(not_int);

        checker.asm_check_double(rax, rcx);
        as.movq(xmm1, rax);

        as.sub(rDStack, QWORD);
        as.mov(rax, ptr(rDStack));
        checker.asm_check_double(rax, rcx);
        as.movq(xmm0, rax);

        // call fmod(xmm0,xmm1)->xmm0
        asm_enter_frame();
        asm_leave_flow();
#ifdef _MSC_VER
        double (*_fmod)(double, double) = &fmod;
        uint64_t addr = uint64_t(_fmod);

        asm_cpp_call((void*)addr);
#else
	double (*_fmod)(double, double) = &fmod;
        asm_cpp_call((void*)_fmod);
#endif
        as.movq(rax, xmm0);

        asm_enter_flow(false);
        asm_leave_frame();

        checker.flush(true);
    }

    // NEG
    as.align(kAlignCode, 16);
    util_neg.bind(as);

    // ARGS: rax -> rax
    if (true) {
        CheckAssembler checker(this);
        Label not_int = as.newLabel();

        as.mov(rcx, rax);
        as.shr(rcx, 48);
        as.cmp(ecx, StackSlot::TAG_INT);
        as.short_().jne(not_int);

        // INT
        as.neg(eax);
        as.or_(rax, qword_tag_int);
        as.ret();

        // DOUBLE
        as.bind(not_int);
        checker.asm_check_double(rax, rcx);
        as.movq(xmm1, rax);

        as.xorpd(xmm0, xmm0);
        as.subsd(xmm0, xmm1);

        as.movq(rax, xmm0);
        as.ret();

        checker.flush(true);
    }

    // DOUBLE -> STRING
    as.align(kAlignCode, 16);
    util_double2string.bind(as);

    {
        asm_enter_frame();
        asm_leave_flow();
        as.lea(rArg1, ptr(rDStack, -QWORD));
        as.mov(rArg0, rState);
        asm_cpp_call((void*)ByteCodeRunner::DoDouble2String);
        asm_enter_flow();
        as.sub(rDStack, QWORD);
        asm_leave_frame();
    }

    // INT -> STRING
    as.align(kAlignCode, 16);
    util_int2string.bind(as);

    {
        asm_enter_frame();
        asm_leave_flow();
        as.lea(rArg1, ptr(rDStack, -QWORD));
        as.mov(rArg0, rState);
        asm_cpp_call((void*)ByteCodeRunner::DoInt2String);
        asm_enter_flow();
        as.sub(rDStack, QWORD);
        asm_leave_frame();
    }
}

/*
 * Generate code to copy values in the specified input registers to those
 * matching the C++ calling convention.
 */
void FlowJitProgram::assemble_assign_args(X86Gp arg1, X86Gp arg2, X86Gp arg3)
{
    X86Gp rargs[3] = { rArg1, rArg2, rArg3 };
    X86Gp args[3] = { arg1, arg2, arg3 };
    bool blocked[16] = { false };

    blocked[arg1.getId()] = true;
    blocked[arg2.getId()] = true;
    blocked[arg3.getId()] = true;

    // Find a copy order that doesn't clobber any values not yet copied.
    while (true) {
        int i;

        for (i = 0; i < 3; i++) {
            uint32_t id = rargs[i].getId();
            if (args[i] != rargs[i] && (!blocked[id] || id == args[i].getId()))
                break;
        }

        if (i < 3) {
            if (args[i].getSize() == rargs[i].getSize())
                as.mov(rargs[i], args[i]);
            else
                as.mov(rargs[i].r32(), args[i]);

            blocked[args[i].getId()] = false;
            args[i] = rargs[i];
        }
        else {
            break;
        }
    }

    for (int i = 0; i < 3; i++)
    {
        if (args[i] != rargs[i])
        {
            err << "Could not copy arguments in assemble_cpp_call_thunk." << std::endl;
            abort();
        }
    }
}

/*
 * Generate a raw call to C++ callable.
 */
void FlowJitProgram::asm_cpp_call(void *callable)
{
    // Windows calling convention requires free space on stack
#ifdef _MSC_VER
    as.sub(rsp, 4*QWORD);
#endif

    uint64_t addr = uint64_t(callable);

    if (addr & 0xffffffff00000000UL)
        as.mov(rax, addr);
    else
        as.mov(eax, uint32_t(addr));

    as.call(rax);

#ifdef _MSC_VER
    as.add(rsp, 4*QWORD);
#endif
}

/*
 * Generate a call to C++, including appropriate argument passing and error checking.
 */
void FlowJitProgram::assemble_cpp_call_thunk(void *callable, asmjit::X86Gp arg1, asmjit::X86Gp arg2, asmjit::X86Gp arg3, bool unwind)
{
    asm_enter_frame();
    asm_leave_flow();

    assemble_assign_args(arg1, arg2, arg3);
    as.mov(rArg0, rState);

    asm_cpp_call(callable);

    if (unwind)
    {
        // This function should never return, so unwind immediately
        unwind_flow.jmp(as);
    }
    else
    {
        asm_enter_flow();
        asm_leave_frame();
    }
}

/*
 * Generate a call thunk for ByteCodeRunner::Compare
 */
void FlowJitProgram::assemble_compare_thunk()
{
    asm_enter_frame();
    as.lea(rDFrame, ptr(rDStack, -2*QWORD));

    asm_leave_flow();

    as.mov(rArg0, rState);
    as.mov(rArg1, rDFrame);
    as.lea(rArg2, ptr(rDFrame, QWORD));

    int (*pf)(ByteCodeRunner*,const StackSlot&,const StackSlot&) = ByteCodeRunner::Compare;
    asm_cpp_call((void*)pf);

    asm_enter_flow();
    as.mov(rDStack, rDFrame);
    asm_leave_frame();
}

/*
 * Generate a call thunk for ByteCodeRunner::DoPlusString
 */
void FlowJitProgram::assemble_plus_string_thunk()
{
    asm_enter_frame();
    asm_leave_flow();

    as.mov(rArg0, rState);
    as.lea(rArg1, ptr(rDStack, -2*QWORD));
    as.lea(rArg2, ptr(rDStack, -QWORD));

    void (*pf)(ByteCodeRunner*,StackSlot&,const StackSlot&) = ByteCodeRunner::DoPlusString;
    asm_cpp_call((void*)pf);

    asm_enter_flow();
    as.sub(rDStack, QWORD);
    asm_leave_frame();
}

/*
 * Generate a JIT -> C++ thunk for calling a specific native.
 */
void FlowJitProgram::assemble_native_call_thunk(int index, int nargs)
{
    asm_enter_frame();

    // Shift arguments and store the called value
    as.lea(rDFrame, ptr(rDStack, -nargs*QWORD));
    as.add(rDStack, QWORD);

    for (int i = nargs-1; i >= 0; i--)
    {
        as.mov(rdx, ptr(rDFrame, i*QWORD));
        as.mov(ptr(rDFrame, (i+1)*QWORD), rdx);
    }

    as.mov(ptr(rDFrame), rax);

    // Find NativeFunction
    as.mov(rdx, STATE(Natives.buf));
    as.mov(rdx, ptr(rdx, index*QWORD));
    as.mov(STATE(CurNativeFn), rdx);

    // Prepare native call
    as.mov(rax, FIELD_ACCESS(rdx, NativeFunction, func_));

    as.mov(rArg0, rState);
    as.lea(rArg1, ptr(rDFrame,QWORD));

    asm_leave_flow();

#ifdef _MSC_VER
    as.sub(rsp, 4*QWORD);
#endif

    as.call(rax);

#ifdef _MSC_VER
    as.add(rsp, 4*QWORD);
#endif

    asm_enter_flow();
    as.mov(rDStack, rDFrame);
    asm_leave_frame();
}

/*
 * Generate a JIT -> C++ thunk for calling any native.
 */
void FlowJitProgram::assemble_generic_native_thunk()
{
    asm_enter_frame();

    // Find the native function object
    CheckAssembler checker(this);

    checker.asm_check_funcidx(rcx, rax);

    as.mov(rdx, STATE(Natives.buf));
    as.mov(rdx, ptr(rdx, rcx, 3));
    as.mov(STATE(CurNativeFn), rdx);

    // Shift arguments
    as.mov(ecx, FIELD_ACCESS(rdx, NativeFunction, num_args_));

    as.mov(rsi, rDStack);
    as.sub(rsi, QWORD);

    as.mov(rdi, rDStack);
    as.add(rDStack, QWORD);

    as.std();
    as.rep().movsq();
    as.cld();

    // Store the callee value
    as.mov(rDFrame, rdi);
    as.mov(ptr(rDFrame), rax);

    // Prepare native call
    as.mov(rax, FIELD_ACCESS(rdx, NativeFunction, func_));

    as.mov(rArg0, rState);
    as.lea(rArg1, ptr(rDFrame,QWORD));

    asm_leave_flow();

    // Call the function
#ifdef _MSC_VER
    as.sub(rsp, 4*QWORD);
#endif

    as.call(rax);

#ifdef _MSC_VER
    as.add(rsp, 4*QWORD);
#endif

    asm_enter_flow();
    as.mov(rDStack, rDFrame);
    asm_leave_frame();

    checker.flush();
}

/*
 * Emit a manually written assembly implementation for certain natives.
 */
bool FlowJitProgram::assemble_native_substitute(const std::string &name)
{
    if (name == "Native.strlen")
    {
        CheckAssembler checker(this);

        as.sub(rDStack, QWORD);
        as.mov(rax, ptr(rDStack));

        checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_STRING, TString, rcx);

        asm_decode_arrdim(rsi, rcx, rax);

        as.mov(rax, StackSlot::MakeInt(0).slot_private.QWordVal);
        as.or_(rax, rcx);
        as.ret();

        checker.flush(true);
        return true;
    }
    else if (name == "Native.length")
    {
        CheckAssembler checker(this);

        as.sub(rDStack, QWORD);
        as.mov(rax, ptr(rDStack));

        checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_ARRAY, TString, rcx);

        asm_decode_arrdim(rsi, rcx, rax);

        as.mov(rax, StackSlot::MakeInt(0).slot_private.QWordVal);
        as.or_(rax, rcx);
        as.ret();

        checker.flush(true);
        return true;
    }

    return false;
}

/*
 * Generate struct field accessors - tiny functions that help in accessing fields
 * in a polymorphic manner via lookup tables.
 *
 * Readers copy from field in [rsi+offset] to rax. Writers move from rax to [rdi+offset].
 * Pack and unpack functions move from rsi to rdi, converting between slots and packed.
 */
void FlowJitProgram::assemble_struct_fields()
{
    // Assemble individual field accessors
    for (StructFieldAccessor::Map::iterator it = struct_field_accessors.begin(); it != struct_field_accessors.end(); ++it)
    {
        StructFieldAccessor::Ptr acc = it->second;

        new_label_addr(&acc->fn_read, stl_sprintf("@read@%s:%d", tag2string(acc->key.first), acc->key.second));
        new_label_addr(&acc->fn_write, stl_sprintf("@write@%s:%d", tag2string(acc->key.first), acc->key.second));

        CheckAssembler checker(this);

        as.align(kAlignCode, 16);
        acc->fn_read.bind(as);
        assemble_field_read(acc->key.first, acc->key.second);
        as.ret();

        as.align(kAlignCode, 8);
        acc->fn_write.bind(as);
        assemble_field_write(acc->key.first, acc->key.second, checker);
        as.ret();

        checker.flush(true);
    }

    // Assemble field access failure trampolines
    std::map<std::string, StructAccessorTable::Ptr>::iterator itn;

    as.align(kAlignCode, 16);

    for (itn = struct_field_readers_name.begin(); itn != struct_field_readers_name.end(); ++itn)
        assemble_fail_func(itn->second);
    for (itn = struct_field_writers_name.begin(); itn != struct_field_writers_name.end(); ++itn)
        assemble_fail_func(itn->second);

    std::map<int, StructAccessorTable::Ptr>::iterator iti;

    for (iti = struct_field_readers_idx.begin(); iti != struct_field_readers_idx.end(); ++iti)
        assemble_fail_func(iti->second);
    for (iti = struct_field_writers_idx.begin(); iti != struct_field_writers_idx.end(); ++iti)
        assemble_fail_func(iti->second);

    // Allocate name table and assemble struct pack/unpack functions
    struct_name_table = (StackSlot*)alloc_const_data(sizeof(StackSlot) * structs.size());

    for (size_t i = 0; i < structs.size(); i++)
    {
        StructInfo::Ptr sinfo = structs[i];

        struct_name_table[i] = sinfo->name_string;

        if (sinfo->num_fields > 0)
        {
            new_label_addr(&sinfo->cb_unpack, "@unpack@"+sinfo->name);
            new_label_addr(&sinfo->cb_pack, "@pack@"+sinfo->name);

            CheckAssembler checker(this);

            as.align(kAlignCode, 16);
            sinfo->cb_unpack.bind(as);

            for (unsigned j = 0; j < sinfo->num_fields; j++)
            {
                assemble_field_read(sinfo->field_defs[j].tag, sinfo->field_defs[j].offset);
                as.mov(ptr(rdi, j*QWORD), rax);
            }

            as.ret();

            as.align(kAlignCode, 16);
            sinfo->cb_pack.bind(as);

            for (unsigned j = 0; j < sinfo->num_fields; j++)
            {
                as.mov(rax, ptr(rsi, j*QWORD));
                assemble_field_write(sinfo->field_defs[j].tag, sinfo->field_defs[j].offset, checker);
            }

            as.ret();

            checker.flush(true);
        }
    }
}

/*
 * Generate pseudo-accessors that report an invalid field error.
 */
void FlowJitProgram::assemble_fail_func(StructAccessorTable::Ptr table)
{
    new_label_addr(&table->fn_fail, (table->is_reader ? "@read-fail@" : "@write-fail@") + table->name);

    table->fn_fail.bind(as);
    as.mov(rax, uint64_t(table.get()));
    thunk_field_error.jmp(as);

    table->table_data = (uint64_t*)alloc_const_data(sizeof(uint64_t)*table->table.size());
}

/*
 * Fill the lookup tables with actual addresses after code is emitted.
 */
void FlowJitProgram::link_struct_tables()
{
    std::map<std::string, StructAccessorTable::Ptr>::iterator itn;

    for (itn = struct_field_readers_name.begin(); itn != struct_field_readers_name.end(); ++itn)
        link_accessor_table(itn->second);
    for (itn = struct_field_writers_name.begin(); itn != struct_field_writers_name.end(); ++itn)
        link_accessor_table(itn->second);

    std::map<int, StructAccessorTable::Ptr>::iterator iti;

    for (iti = struct_field_readers_idx.begin(); iti != struct_field_readers_idx.end(); ++iti)
        link_accessor_table(iti->second);
    for (iti = struct_field_writers_idx.begin(); iti != struct_field_writers_idx.end(); ++iti)
        link_accessor_table(iti->second);
}

void FlowJitProgram::link_accessor_table(StructAccessorTable::Ptr table)
{
    for (size_t i = 0; i < table->table.size(); i++)
    {
        StructFieldAccessor::Ptr acc = table->table[i];
        if (acc)
            table->table_data[i] = table->is_reader ? acc->fn_read.addr : acc->fn_write.addr;
        else
            table->table_data[i] = table->fn_fail.addr;
    }
}

/*
 * Generate a struct field reader body.
 */
void FlowJitProgram::assemble_field_read(DataTag tag, int offset)
{
    switch (tag)
    {
    case TInt:
        as.mov(eax, ptr(rsi, offset));
        as.or_(rax, const_qword(uint64_t(StackSlot::TAG_INT)<<48));
        break;

    case TBool:
        as.movzx(eax, ptr(rsi, offset, 1));
        as.or_(rax, const_qword(uint64_t(StackSlot::TAG_BOOL)<<48));
        break;

    case TStruct:
        as.mov(eax, ptr(rsi, offset));
        as.movzx(ecx, ptr(rMemBase, rax, 0, 0, 2));
        as.or_(ecx, StackSlot::TAG_STRUCT<<16);
        as.shl(rcx, 32);
        as.or_(rax, rcx);
        break;

    default:
        as.mov(rax, ptr(rsi, offset));
    }
}

/*
 * Generate a struct field writer body.
 */
void FlowJitProgram::assemble_field_write(DataTag tag, int offset, CheckAssembler &checker)
{
    switch (tag)
    {
    case TInt:
        checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
        as.mov(ptr(rdi, offset), eax);
        break;

    case TBool:
        checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_BOOL, TBool, rcx);
        as.mov(ptr(rdi, offset), al);
        break;

    case TStruct:
        checker.asm_check_tag(rax, 0x7fff, StackSlot::TAG_STRUCT, TStruct, rcx);
        as.mov(ptr(rdi, offset), eax);
        break;

    case TArray:
        checker.asm_check_tag(rax, 0x7fff, StackSlot::TAG_ARRAY, TArray, rcx);
        as.mov(ptr(rdi, offset), rax);
        break;

    case TString:
        checker.asm_check_tag(rax, 0x7fff, StackSlot::TAG_STRING, TString, rcx);
        as.mov(ptr(rdi, offset), rax);
        break;

    case TRefTo:
        checker.asm_check_tag(rax, 0x7fff, StackSlot::TAG_REFTO, TRefTo, rcx);
        as.mov(ptr(rdi, offset), rax);
        break;

    default:
        as.mov(ptr(rdi, offset), rax);
    }
}

/*
 * Loop through all functions and generate them.
 */
void FlowJitProgram::assemble_functions()
{
    for (size_t i = 0; i < functions.size(); i++)
    {
        FunctionInfo::Ptr func = functions[i];
        new_label_addr(&func->addr, func->name);
    }

    for (size_t i = 1; i < functions.size(); i++)
    {
        FunctionInfo::Ptr func = functions[i];

        as.align(kAlignCode, 16);
        func->addr.bind(as);

        switch (func->definer->op)
        {
        case CNativeFn:
        case COptionalNativeFn:
            if (!assemble_native_substitute(func->definer->StrValue))
                assemble_native_call_thunk(func->index, func->definer->IntValue);
            break;

        case CCodePointer:
        case CClosurePointer:
        {
            T_bytecode_list function_code;
            extract_function_code(&function_code, func->start, func->end);
            bool is_closure = (func->definer->op == CClosurePointer);

            FunctionAssembler fasm(this, function_code, func->end);

            asm_enter_frame();

            if (!function_code.empty() && function_code[0]->second.op == CReserveLocals)
                fasm.enter_func(is_closure, function_code[0]->second.IntValue2, function_code[0]->second.IntValue);
            else
                fasm.enter_func(is_closure, 0, 0);

            func->num_args = fasm.num_args;

            fasm.preprocess();
            fasm.generate();

            fasm.checker.flush();
            break;
        }

        default:
            break;
        }
    }
}

/*
 * Generate the special initializer function by looping through all global init code.
 */
void FlowJitProgram::assemble_global_init()
{
    FunctionInfo::Ptr func = functions[0];

    as.align(kAlignCode, 16);
    func->addr.bind(as);

    asm_enter_frame();
    as.mov(rDFrame, rDStack);

    bool frozen = false;

    for (size_t i = 0; i < globals.size(); i++)
    {
        GlobalInfo::Ptr global = globals[i];

        new_label_addr(&global->init_addr, global->name+"$init");
        global->init_addr.bind(as);

        if (global->name == "--end--")
        {
            // Make memory holding globals read-only. This aligns the stack pos up to page boundary.
            thunk_freeze_globals.call(as);
            as.mov(rDStack, STATE(DataStack.pos));
            as.mov(rDFrame, rDStack);
            frozen = true;
        }

        FunctionAssembler fasm(this, global->init_code, global->end);

        fasm.preprocess();
        fasm.generate();

        if (fasm.checker.needs_flush())
        {
            Label skip = as.newLabel();
            as.jmp(skip);

            fasm.checker.flush();

            as.bind(skip);
        }
    }

    if (!frozen)
    {
        thunk_freeze_globals.call(as);
        as.mov(rDFrame, STATE(DataStack.pos));
    }

    // Special leave frame code that doesn't restore rDFrame
    as.pop(rClosure);
    as.pop(rax);
    as.pop(rCFrame);
    as.ret();
}

FlowJitProgram::FunctionAssembler::FunctionAssembler(FlowJitProgram *owner, const T_bytecode_list &code, FlowPtr end_addr)
    : owner(owner), as(owner->as), checker(owner), code_in(code), end_addr(end_addr)
{
    is_closure = false;
    num_args = num_locals = 0;
}

/*
 * Generate function prologue, properly initializing the stack frame.
 */
void FlowJitProgram::FunctionAssembler::enter_func(bool is_closure, int num_args, int num_locals)
{
    this->is_closure = is_closure;

    if (is_closure)
        as.mov(rClosure.r32(), eax);

    this->num_args = num_args;
    this->num_locals = num_locals;

    if (num_args)
        as.lea(rDFrame, ptr(rDStack, -num_args*QWORD));
    else
        as.mov(rDFrame, rDStack);

    if (num_locals)
    {
        as.mov(rax, -1);

        if (num_locals < 5) {
            for (int i = 0; i < num_locals; i++)
                as.mov(ptr(rDStack, i*QWORD), rax);

            as.add(rDStack, num_locals*QWORD);
        } else {
            as.mov(rdi, rDStack);
            as.mov(ecx, num_locals);
            as.rep().stosq();
            as.mov(rDStack, rdi);
        }
    }
}

/*
 * Scan the code, collecting preliminary data for simple peephole
 * optimizations performed during generation.
 *
 * The main optimization is elimination of data stack push+pop pairs,
 * which can be performed if two sequential instructions are not separated
 * by jumps, and can leave/accept the result in rax.
 *
 * A more complicated optimization speeds up creation of closures by
 * copying data to the closure directly from the original locals without
 * going via the stack.
 */
void FlowJitProgram::FunctionAssembler::preprocess()
{
    // Allocate labels for instructions jumped to
    for (size_t i = 0; i < code_in.size(); i++)
    {
        FlowInstruction::Pair *ipair = code_in[i];
        FlowInstruction &insn = ipair->second;

        switch (insn.op)
        {
        case CGoto:
            // don't count jump to next instruction - it's skipped at code generation
            if (i+1 < code_in.size() && insn.PtrValue == code_in[i+1]->first)
                continue;
            /* fall through */
        case CIfFalse:
            jump_targets[insn.PtrValue] = as.newLabel();
            break;

        case CSwitch:
        case CSimpleSwitch:
            if (insn.IntValue == 0)
            {
                // Eliminate useless switch instructions
                insn.op = CPop;
            }
            else
            {
                for (int k = 0; k < insn.IntValue; ++k)
                    jump_targets[insn.cases[k].target] = as.newLabel();
            }
            break;

        default:
            break;
        }
    }

    // Copy instructions, removing in some specific cases
    code.reserve(code_in.size());

    for (size_t i = 0; i < code_in.size(); i++)
    {
        FlowInstruction::Pair *ipair = code_in[i];
        FlowInstruction &insn = ipair->second;

        bool skip = false;

        switch (insn.op)
        {
        case CGoto:
            // skip goto to next instruction that is not jumped to
            if (i+1 < code_in.size() && insn.PtrValue == code_in[i+1]->first && !jump_targets.count(ipair->first))
                skip = true;
            break;

        case CClosurePointer:
            // merge CClosurePointer, preceeded by simple var fetch instructions
            if (insn.IntValue > 0 && !jump_targets.count(ipair->first))
            {
                T_bytecode_list args;
                int pos = code.size()-1, cnt = insn.IntValue;

                while (cnt > 0 && pos >= 0)
                {
                    OpCode op = code[pos]->second.op;

                    // Only certaint types of args
                    if (op != CGetLocal && op != CGetFreeVar)
                        break;

                    args.push_back(code[pos]);

                    // Can only proceed to next iteration if not jumped to
                    if (--cnt > 0)
                    {
                        if (jump_targets.count(code[pos]->first))
                            break;

                        pos--;
                    }
                }

                if (cnt == 0)
                {
                    if (jump_targets.count(code[pos]->first))
                        jump_targets[ipair->first] = jump_targets[code[pos]->first];

                    code.resize(pos);

                    T_bytecode_list &out = closure_args[ipair->first];
                    out.insert(out.end(), args.rbegin(), args.rend());
                }
            }
            break;

        default:;
        }

        if (!skip)
            code.push_back(ipair);
    }

    // Build a bitmask of jumped to instructions
    is_jumped_to.resize(code.size(), false);

    for (size_t i = 0; i < code.size(); i++)
    {
        FlowInstruction::Pair *ipair = code[i];

        if (jump_targets.count(ipair->first))
            is_jumped_to[i] = true;
    }

    // Mark locations for stack top in rax
    bool can_prev_rax = false;

    keep_rax_top.resize(code.size(), false);

    for (size_t i = 1; i < code.size(); i++)
    {
        bool can_cur_in, can_cur_out;
        can_use_rax(code[i], &can_cur_in, &can_cur_out);

        if (can_prev_rax && can_cur_in && !is_jumped_to[i])
            keep_rax_top[i-1] = true;

        can_prev_rax = can_cur_out;
    }
}

/*
 * Move data from stack to rax, unless it is already there due to peepholing.
 */
void FlowJitProgram::FunctionAssembler::asm_stack_to_rax(CurPos *cpos)
{
    if (cpos->in_rax_top && !cpos->used_in_rax)
    {
        cpos->used_in_rax = true;
    }
    else
    {
        asm_pop_rax();
    }
}

/*
 * Move data from rax to stack unless it can be kept in the register.
 *
 * If the push is performed, also peepholes following simple push operations
 * to reduce the number of updates to rDStack.
 */
void FlowJitProgram::FunctionAssembler::asm_rax_to_stack(CurPos *cpos, int bias)
{
    if (cpos->rq_rax_top)
    {
        cpos->out_rax_top = true;
        if (bias != 0)
            as.add(rDStack, bias);
    }
    else
    {
        as.mov(ptr(rDStack, bias), rax);
        asm_push_to_stack(cpos, bias + QWORD, NULL, 0, false);
    }
}

/*
 * Moves TVoid to stack if it cannot be optimized out.
 *
 * Optimizes a little more aggressively than asm_rax_to_stack.
 */
void FlowJitProgram::FunctionAssembler::asm_void_to_stack(CurPos *cpos, int bias)
{
    if (can_peephole_next_op(cpos->iidx, CPop))
    {
        next_insn(cpos, true);
        if (bias != 0)
            as.add(rDStack, bias);
    }
    else
    {
        as.mov(rax, -1);

        if (cpos->rq_rax_top)
        {
            cpos->out_rax_top = true;
            if (bias != 0)
                as.add(rDStack, bias);
        }
        else
        {
            as.mov(ptr(rDStack, bias), rax);
            asm_push_to_stack(cpos, bias + QWORD, NULL, uint64_t(int64_t(-1)), true);
        }
    }
}

/*
 * Generates code for pushing simple constants and values of locals/globals/upvalues to stack.
 * Optimizes to avoid repeating updates to rDStack.
 *
 * ARGS:
 *   bias: already accumulated change to rDStack
 *   pinsn: instruction to start with, or NULL
 *   rax_fixed, rax_value: current value of rax if constant
 */
void FlowJitProgram::FunctionAssembler::asm_push_to_stack(CurPos *cpos, int bias, FlowInstruction::Pair *pinsn, uint64_t rax_value, bool rax_fixed)
{
    // rsi is set to the table of globals
    bool global_ptr_ready = false;

    do
    {
        if (pinsn)
        {
            uint64_t tmp;

            // Eliminate push before pop
            if (can_peephole_next_op(cpos->iidx, CPop))
            {
                next_insn(cpos, true);
                break;
            }

            switch (pinsn->second.op)
            {
            case CVoid:
                if (!rax_fixed || rax_value != uint64_t(int64_t(-1)))
                {
                    as.mov(rax, rax_value = uint64_t(int64_t(-1)));
                    rax_fixed = true;
                }
                break;

            case CInt:
                tmp = StackSlot::MakeInt(pinsn->second.IntValue).slot_private.QWordVal;
                if (!rax_fixed || rax_value != tmp)
                {
                    as.mov(rax, rax_value = tmp);
                    rax_fixed = true;
                }
                break;

            case CBool:
                tmp = StackSlot::MakeBool(pinsn->second.IntValue).slot_private.QWordVal;
                if (!rax_fixed || rax_value != tmp)
                {
                    as.mov(rax, rax_value = tmp);
                    rax_fixed = true;
                }
                break;

            case CDouble:
                tmp = StackSlot::MakeDouble(pinsn->second.DoubleVal).slot_private.QWordVal;
                if (!rax_fixed || rax_value != tmp)
                {
                    as.mov(rax, rax_value = tmp);
                    rax_fixed = true;
                }
                break;

            case CStruct:
            {
                StructInfo::Ptr info = owner->struct_by_id[pinsn->second.IntValue];

                if (info->num_fields != 0)
                    abort();

                tmp = info->empty_addr | info->type_tag;
                if (!rax_fixed || rax_value != tmp)
                {
                    as.mov(rax, rax_value = tmp);
                    rax_fixed = true;
                }
                break;
            }

            case CString:
            case CWString:
            {
                unicode_string us = parseUtf8(pinsn->second.StrValue);
                StackSlot str = owner->alloc_string_constant(us);
                tmp = str.slot_private.QWordVal;
                if (!rax_fixed || rax_value != tmp)
                {
                    as.mov(rax, rax_value = tmp);
                    rax_fixed = true;
                }
                break;
            }

            case CGetLocal:
                as.mov(rax, ptr(rDFrame, pinsn->second.IntValue*QWORD));
                rax_fixed = false;
                break;

            case CGetGlobal:
            {
                GlobalInfo::Ptr global = owner->globals[pinsn->second.IntValue];

                // Check for call to global
                if (asm_call_global_fn(cpos, global->global_fn, bias))
                    return;

                if (!global_ptr_ready)
                {
                    as.mov(rsi, STATE(DataStack.buf));
                    global_ptr_ready = true;
                }

                as.mov(rax, ptr(rsi, pinsn->second.IntValue*QWORD));
                rax_fixed = false;
                break;
            }

            case CGetFreeVar:
                as.mov(rax, ptr(rMemBase, rClosure, 0, 4+pinsn->second.IntValue*QWORD));
                rax_fixed = false;
                break;

            default:
                abort();
            }

            if (cpos->rq_rax_top)
            {
                cpos->out_rax_top = true;
            }
            else
            {
                as.mov(ptr(rDStack, bias), rax);
                bias += QWORD;
            }
        }

        pinsn = NULL;

        if (can_peephole_to(cpos->iidx))
        {
            switch (code[cpos->iidx]->second.op)
            {
            case CVoid:
            case CInt:
            case CBool:
            case CDouble:
            case CString:
            case CWString:
            case CGetLocal:
            case CGetGlobal:
            case CGetFreeVar:
                pinsn = next_insn(cpos);
                break;

            case CStruct:
                if (owner->struct_by_id[code[cpos->iidx]->second.IntValue]->num_fields == 0)
                    pinsn = next_insn(cpos);
                break;

            default:;
            }
        }
    }
    while (pinsn);

    if (bias != 0)
        as.add(rDStack, bias);
}

void FlowJitProgram::FunctionAssembler::asm_push_rax()
{
    as.mov(ptr(rDStack), rax);
    as.add(rDStack, QWORD);
}

void FlowJitProgram::FunctionAssembler::asm_pop_rax()
{
    as.sub(rDStack, QWORD);
    as.mov(rax, ptr(rDStack));
}

/*
 * Check that instruction i isn't jumped to, and thus can be optimized.
 */
bool FlowJitProgram::FunctionAssembler::can_peephole_to(size_t i)
{
    return i < code.size() && !is_jumped_to[i];
}

/*
 * Check that instruction i isn't jumped to, and is of the given type.
 */
bool FlowJitProgram::FunctionAssembler::can_peephole_next_op(size_t i, OpCode op)
{
    return can_peephole_to(i) && code[i]->second.op == op;
}

/*
 * Copy tail call arguments to the appropriate place of the stack.
 */
void FlowJitProgram::FunctionAssembler::copy_tailcall_args(int nargs)
{
    if (nargs >= 5)
    {
        as.lea(rsi, ptr(rDStack, -nargs*QWORD));
        as.mov(rdi, rDFrame);
        as.mov(ecx, nargs);
        as.rep().movsq();
        as.mov(rDStack, rdi);
    }
    else
    {
        for (int i = 0; i < nargs; i++)
        {
            as.mov(rcx, ptr(rDStack, -(nargs-i)*QWORD));
            as.mov(ptr(rDFrame, i*QWORD), rcx);
        }

        as.lea(rDStack, ptr(rDFrame, nargs*QWORD));
    }
}

/*
 * Generate comparison, appropriately peepholing CNot and CIfFalse.
 */
void FlowJitProgram::FunctionAssembler::asm_compare(
        CurPos *cpos, asmjit::X86Inst::Id testid, const asmjit::Operand &op_a, const asmjit::Operand &op_b,
        asmjit::X86Inst::Id setid, asmjit::X86Inst::Id jmpid, asmjit::X86Inst::Id isetid, asmjit::X86Inst::Id ijmpid
) {
    while (can_peephole_next_op(cpos->iidx, CNot))
    {
        next_insn(cpos, true);
        std::swap(setid, isetid);
        std::swap(jmpid, ijmpid);
    }

    if (can_peephole_next_op(cpos->iidx, CIfFalse))
    {
        // Can simply use a conditional jump
        FlowInstruction::Pair *ipair = next_insn(cpos, true);
        as.emit(testid, op_a, op_b);
        as.emit(ijmpid, jump_targets[ipair->second.PtrValue]);
    }
    else
    {
        // Generate a boolean slot value
        as.xor_(ecx,ecx);
        as.emit(testid, op_a, op_b);
        as.emit(setid, cl);
        as.mov(rax, StackSlot::MakeBool(0).slot_private.QWordVal);
        as.or_(rax, rcx);
        asm_rax_to_stack(cpos);
    }
}

/*
 * After a CGetGlobal, check if it is a direct call to a global function and generate it.
 */
bool FlowJitProgram::FunctionAssembler::asm_call_global_fn(CurPos *cpos, FunctionInfo::Ptr global_fn, int stack_bias)
{
    if (!global_fn)
        return false;

    if (can_peephole_next_op(cpos->iidx, CCall))
    {
        next_insn(cpos, true);

        if (stack_bias != 0)
            as.add(rDStack, stack_bias);

        if (global_fn->native_fallback)
        {
            // Optional natives require an indirection to work
            as.mov(rdx, STATE(JitFuncs.buf));
            as.call(ptr(rdx, global_fn->index * QWORD));
        }
        else
        {
            global_fn->addr.call(as);
        }

        asm_rax_to_stack(cpos);
        return true;
    }
    else if (can_peephole_next_op(cpos->iidx, CTailCall))
    {
        FlowInstruction::Pair *ipair2 = next_insn(cpos, true);

        if (stack_bias != 0)
            as.add(rDStack, stack_bias);

        copy_tailcall_args(ipair2->second.IntValue);
        owner->asm_leave_frame(false);

        if (global_fn->native_fallback)
        {
            // Optional natives require an indirection to work
            as.mov(rdx, STATE(JitFuncs.buf));
            as.jmp(ptr(rdx, global_fn->index * QWORD));
        }
        else
        {
            global_fn->addr.jmp(as);
        }

        if (can_peephole_next_op(cpos->iidx, CReturn))
            next_insn(cpos, true);

        return true;
    }

    return false;
}

/*
 * Recursively split a switch table that has too much empty space.
 */
void FlowJitProgram::FunctionAssembler::partition_swtable(std::map<int,T_swtable> &out, const T_swtable &swtable)
{
    int first = swtable.begin()->first;
    int last = swtable.rbegin()->first;

    // allow 50% junk
    if (swtable.size() * 2 >= unsigned(last-first+1))
    {
        out[first] = swtable;
    }
    else
    {
        // find largest hole closest to the center
        int mid = swtable.size() / 2;
        int hole_size = 0, hole_pos = -1, prev = first, i = 0, hole_i = 0;
        T_swtable::const_iterator it = swtable.begin();

        for (; it != swtable.end(); ++it, ++i)
        {
            int cur_hole = it->first - prev - 1;

            if (cur_hole > hole_size || (cur_hole == hole_size && abs(mid - hole_i) > abs(mid - i)))
            {
                hole_size = cur_hole;
                hole_pos = it->first;
                hole_i = i;
            }
        }

        // split table
        T_swtable table1, table2;
        table1.insert(swtable.begin(), swtable.lower_bound(hole_pos));
        table2.insert(swtable.lower_bound(hole_pos), swtable.end());

        partition_swtable(out, table1);
        partition_swtable(out, table2);
    }
}

/*
 * Generate switch as a binary search between jump tables.
 *
 * ARGS:
 *   l,r - binary search boundaries
 *   last_cmp - last comparison value (to avoid redundancy)
 *   def - default case
 *   reg - switch value
 */
void FlowJitProgram::FunctionAssembler::generate_switch(const std::map<int,T_swtable> &bintree, const std::vector<int> &binlist, size_t l, size_t r, int last_cmp, Label def, asmjit::X86Gp reg)
{
    if (l+1 == r)
    {
        int boundary = binlist[l];
        const T_swtable &table = bintree.find(boundary)->second;

        if (table.size() == 1)
        {
            if (last_cmp != boundary)
                as.cmp(reg, boundary);

            as.jne(def);
            as.jmp(table.find(boundary)->second);
        }
        else
        {
            int jumptable_size = table.rbegin()->first - boundary + 1;

            as.sub(reg, boundary);
            as.cmp(reg, jumptable_size);
            as.jae(def);

            std::vector<Label> jumptable(jumptable_size, def);
            for (T_swtable::const_iterator it = table.begin(); it != table.end(); ++it)
                jumptable[it->first - boundary] = it->second;

            as.lea(rdx, owner->alloc_jumptable(jumptable));
            as.jmp(ptr(rdx, reg, 3));
        }
    }
    else
    {
        size_t m = (l+r)/2;
        int boundary = binlist[m];

        Label skip = as.newLabel();
        as.cmp(reg, boundary);
        as.jb(skip);

        generate_switch(bintree, binlist, m, r, boundary, def, reg);

        as.bind(skip);

        generate_switch(bintree, binlist, l, m, boundary, def, reg);
    }
}

/*
 * Generate the switch operation using comparisons and jump tables.
 */
void FlowJitProgram::FunctionAssembler::asm_switch(const std::map<int,Label> &swtable, asmjit::X86Gp reg, Label def)
{
    std::map<int,T_swtable> bintree;
    partition_swtable(bintree, swtable);

    std::vector<int> binlist;
    for (std::map<int,T_swtable>::iterator it = bintree.begin(); it != bintree.end(); ++it)
        binlist.push_back(it->first);

    generate_switch(bintree, binlist, 0, binlist.size(), -1, def, reg);
}

static void log_instruction(Assembler &as, const FlowInstruction &insn, const char *prefix = "//")
{
    if (Logger *log = as.getCode()->getLogger())
    {
        std::stringstream ss;
        ss << insn;
        log->logf("%s%s\n", prefix, ss.str().c_str());
    }
}

/*
 * Advance instruction counter and return the next instruction.
 */
FlowInstruction::Pair *FlowJitProgram::FunctionAssembler::next_insn(CurPos *cpos, bool peephole)
{
    if (cpos->in_rax_top && !cpos->used_in_rax)
    {
        owner->err << "RAX top input mismatch at transition to idx " << cpos->iidx << std::endl;
        throw JitError();
    }

    if (cpos->rq_rax_top != cpos->out_rax_top && !peephole)
    {
        owner->err << "RAX top output mismatch at transition to idx " << cpos->iidx << std::endl;
        throw JitError();
    }

    FlowInstruction::Pair *ipair = code[cpos->iidx];

    cpos->in_rax_top = cpos->out_rax_top;
    cpos->rq_rax_top = keep_rax_top[cpos->iidx];
    cpos->out_rax_top = false;
    cpos->used_in_rax = peephole && cpos->in_rax_top;
    cpos->iidx++;

    log_instruction(as, ipair->second);

    return ipair;
}

/*
 * Determines if the given instruction can receive or output the stack top in rax.
 */
void FlowJitProgram::FunctionAssembler::can_use_rax(FlowInstruction::Pair *pinsn, bool *can_input_rax, bool *can_output_rax)
{
    switch (pinsn->second.op)
    {
#define SIMPLE(id,in,out) case id: *can_input_rax = in; *can_output_rax = out; break;

    SIMPLE(CVoid, false, true);
    SIMPLE(CInt, false, true);
    SIMPLE(CBool, false, true);
    SIMPLE(CDouble, false, true);
    SIMPLE(CString, false, true);
    SIMPLE(CWString, false, true);

    SIMPLE(CPlus, false, false);
    SIMPLE(CMinus, true, true);
    SIMPLE(CMultiply, true, true);
    SIMPLE(CDivide, true, true);
    SIMPLE(CModulo, true, true);
    SIMPLE(CNegate, true, true);
    SIMPLE(CPlusString, false, false);
    SIMPLE(CPlusInt, true, true);
    SIMPLE(CMinusInt, true, true);
    SIMPLE(CMultiplyInt, true, true);
    SIMPLE(CDivideInt, true, true);
    SIMPLE(CModuloInt, true, true);
    SIMPLE(CNegateInt, true, true);
    SIMPLE(CInt2Double, true, true);
    SIMPLE(CDouble2Int, true, true);
    SIMPLE(CDouble2String, false, true);
    SIMPLE(CInt2String, false, true);

    SIMPLE(CPop, true, false);
    SIMPLE(CGoto, false, false);
    SIMPLE(CIfFalse, true, false);

    SIMPLE(CLessThan, false, true);
    SIMPLE(CLessEqual, false, true);
    SIMPLE(CEqual, false, true);

    SIMPLE(CNot, true, true);

    SIMPLE(CGetGlobal, false, true);
    SIMPLE(CGetLocal, false, true);
    SIMPLE(CGetFreeVar, false, true);
    SIMPLE(CSetLocal, true, false);

    SIMPLE(CCall, true, true);
    SIMPLE(CTailCall, true, false);

    SIMPLE(CClosureReturn, true, false);
    SIMPLE(CReturn, true, false);

    SIMPLE(CCodePointer, false, true);
    SIMPLE(CClosurePointer, false, closure_args.count(pinsn->first));

    SIMPLE(COptionalNativeFn, true, true);
    SIMPLE(CNativeFn, false, true);

    SIMPLE(CArray, false, pinsn->second.IntValue == 0);
    SIMPLE(CArrayGet, true, true);

    SIMPLE(CRefTo, false, true);
    SIMPLE(CDeref, true, true);
    SIMPLE(CSetRef, false, true);

    SIMPLE(CStruct, false, true);
    SIMPLE(CField, true, true);
    SIMPLE(CFieldName, true, true);
    SIMPLE(CSetMutable, true, true);
    SIMPLE(CSetMutableName, true, true);

    SIMPLE(CSimpleSwitch, true, false);
    SIMPLE(CSwitch, true, false);

#undef SIMPLE
    default:
        *can_input_rax = *can_output_rax = false;
    }
}

/*
 * Main code generation loop.
 */
void FlowJitProgram::FunctionAssembler::generate()
{
    CurPos cpos;
    cpos.in_rax_top = cpos.out_rax_top = cpos.rq_rax_top = false;

    for (cpos.iidx = 0; cpos.iidx < code.size();)
    {
        bool has_jump = is_jumped_to[cpos.iidx];
        FlowInstruction::Pair *ipair = next_insn(&cpos);
        FlowInstruction &insn = ipair->second;

        if (has_jump)
        {
            // Bind the label
            std::map<FlowPtr,Label>::iterator lbl_it = jump_targets.find(ipair->first);
            if (lbl_it != jump_targets.end())
                as.bind(lbl_it->second);
        }

        switch (insn.op)
        {
        case CVoid:
        case CInt:
        case CBool:
        case CDouble:
        case CString:
        case CWString:
        case CGetGlobal:
        case CGetLocal:
        case CGetFreeVar:
            asm_push_to_stack(&cpos, 0, ipair, 0, false);
            break;

        case CPlus:
            // args on stack because of plus_string
            owner->util_add.call(as);
            break;

        case CMinus:
            asm_stack_to_rax(&cpos);
            owner->util_sub.call(as);
            asm_rax_to_stack(&cpos);
            break;

        case CMultiply:
            asm_stack_to_rax(&cpos);
            owner->util_mul.call(as);
            asm_rax_to_stack(&cpos);
            break;

        case CDivide:
            asm_stack_to_rax(&cpos);
            owner->util_div.call(as);
            asm_rax_to_stack(&cpos);
            break;

        case CModulo:
            asm_stack_to_rax(&cpos);
            owner->util_mod.call(as);
            asm_rax_to_stack(&cpos);
            break;

        case CNegate:
            asm_stack_to_rax(&cpos);
            owner->util_neg.call(as);
            asm_rax_to_stack(&cpos);
            break;

        case CPlusString:
            owner->thunk_plus_string.call(as);
            break;

        case CPlusInt:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.mov(rtmp0d, eax);
            asm_pop_rax();
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.add(eax, rtmp0d);
            as.or_(rax, owner->qword_tag_int);
            asm_rax_to_stack(&cpos);
            break;

        case CMinusInt:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.mov(rtmp0d, eax);
            asm_pop_rax();
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.sub(eax, rtmp0d);
            as.or_(rax, owner->qword_tag_int);
            asm_rax_to_stack(&cpos);
            break;

        case CMultiplyInt:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.mov(rtmp0d, eax);
            asm_pop_rax();
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.imul(rtmp0d);
            as.or_(rax, owner->qword_tag_int);
            asm_rax_to_stack(&cpos);
            break;

        case CDivideInt:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.mov(rtmp0d, eax);
            asm_pop_rax();
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.cdq();
            as.idiv(rtmp0d);
            as.or_(rax, owner->qword_tag_int);
            asm_rax_to_stack(&cpos);
            break;

        case CModuloInt:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.mov(rtmp0d, eax);
            asm_pop_rax();
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.cdq();
            as.idiv(rtmp0d);
            as.mov(eax, edx);
            as.or_(rax, owner->qword_tag_int);
            asm_rax_to_stack(&cpos);
            break;

        case CNegateInt:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.neg(eax);
            as.or_(rax, owner->qword_tag_int);
            asm_rax_to_stack(&cpos);
            break;

        case CInt2Double:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.xorps(xmm0,xmm0);
            as.cvtsi2sd(xmm0, eax);
            as.movq(rax, xmm0);
            asm_rax_to_stack(&cpos);
            break;

        case CDouble2Int:
            asm_stack_to_rax(&cpos);
            checker.asm_check_double(rax, rcx);
            as.movq(xmm0, rax);
            as.cvttsd2si(eax, xmm0);
            as.or_(rax, owner->qword_tag_int);
            asm_rax_to_stack(&cpos);
            break;

        case CDouble2String:
            owner->util_double2string.call(as);
            asm_rax_to_stack(&cpos);
            break;

        case CInt2String:
            owner->util_int2string.call(as);
            asm_rax_to_stack(&cpos);
            break;

        case CPop:
            // If top is already in rax, pretend it was used
            if (cpos.in_rax_top)
                cpos.used_in_rax = true;
            else
                as.sub(rDStack, QWORD);
            break;

        case CGoto:
            // Omit goto to next instruction
            if (!(cpos.iidx < code.size() && insn.PtrValue == code[cpos.iidx]->first))
                as.jmp(jump_targets[insn.PtrValue]);
            break;

        case CIfFalse:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_BOOL, TBool, rcx);
            as.test(eax, eax);
            as.jz(jump_targets[ipair->second.PtrValue]);
            break;

        case CLessThan:
            owner->thunk_compare.call(as);
            asm_compare(&cpos, X86Inst::kIdTest, eax, eax, X86Inst::kIdSetl, X86Inst::kIdJl, X86Inst::kIdSetnl, X86Inst::kIdJnl);
            break;
        case CLessEqual:
            owner->thunk_compare.call(as);
            asm_compare(&cpos, X86Inst::kIdTest, eax, eax, X86Inst::kIdSetle, X86Inst::kIdJle, X86Inst::kIdSetnle, X86Inst::kIdJnle);
            break;
        case CEqual:
            owner->thunk_compare.call(as);
            asm_compare(&cpos, X86Inst::kIdTest, eax, eax, X86Inst::kIdSete, X86Inst::kIdJe, X86Inst::kIdSetne, X86Inst::kIdJne);
            break;

        case CNot:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_BOOL, TBool, rcx);
            asm_compare(&cpos, X86Inst::kIdTest, eax, eax, X86Inst::kIdSetz, X86Inst::kIdJz, X86Inst::kIdSetnz, X86Inst::kIdJnz);
            break;

        case CSetLocal:
        {
            if (cpos.in_rax_top || !can_peephole_next_op(cpos.iidx, CSetLocal))
            {
                asm_stack_to_rax(&cpos);
                as.mov(ptr(rDFrame, insn.IntValue*QWORD), rax);
            }
            else
            {
                // Combine multiple sequential CSetLocal instructions to reduce rDStack updates.
                int offset = 0;

                while (offset > -128+QWORD)
                {
                    offset -= QWORD;
                    as.mov(rax, ptr(rDStack, offset));
                    as.mov(ptr(rDFrame, ipair->second.IntValue*QWORD), rax);

                    if (can_peephole_next_op(cpos.iidx, CSetLocal))
                        ipair = next_insn(&cpos, true);
                    else
                        break;
                }

                as.sub(rDStack, -offset);
            }
            break;
        }

        case CCall:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_NATIVEFN, TNativeFn, rcx);
            owner->asm_decode_funcidx(rcx, rax, checker);
            as.mov(rdx, STATE(JitFuncs.buf));
            as.call(ptr(rdx,rcx,3));
            asm_rax_to_stack(&cpos);
            break;

        case CTailCall:
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_NATIVEFN, TNativeFn, rcx);
			copy_tailcall_args(insn.IntValue);
			owner->asm_decode_funcidx(rcx, rax, checker);
            owner->asm_leave_frame(false);
            as.mov(rdx, STATE(JitFuncs.buf));
			as.jmp(ptr(rdx,rcx,3));

            if (can_peephole_next_op(cpos.iidx, CReturn))
                next_insn(&cpos, true);
            break;

        case CClosureReturn:
        case CReturn:
            asm_stack_to_rax(&cpos);
            as.mov(rDStack, rDFrame);
            owner->asm_leave_frame();
            break;

        case CCodePointer:
        {
            FunctionInfo::Ptr func = owner->function_map[insn.PtrValue];

            // Check if it's a direct call
            if (asm_call_global_fn(&cpos, func))
                break;

            as.mov(rax, StackSlot::MakeNativeFn(func->index).slot_private.QWordVal);
            asm_rax_to_stack(&cpos);
            break;
        }

        case CClosurePointer:
        {
            std::map<FlowPtr, T_bytecode_list>::iterator it = closure_args.find(ipair->first);

            // Closure pointer in the slot is offset 4 bytes from the real start of the object
            StackSlot tag = StackSlot::InternalMakeNativeClosure(MakeFlowPtr(4), insn.IntValue);

            as.mov(ecx, insn.IntValue*QWORD + 8);
            owner->util_allocate.call(as);

            // Optimize the normal case where arguments are simple var reads
            // by copying data directly to closure without using the stack.
            if (it != closure_args.end())
            {
                T_bytecode_list &args = it->second;
                assert(args.size() == unsigned(insn.IntValue));

                as.lea(rdi, ptr(rMemBase, rax, 0, 8));
                as.add(rax, owner->const_qword(tag.slot_private.QWordVal));

                // Set function id and gc header
                as.mov(rdx, owner->function_map[insn.PtrValue]->index | (uint64_t(insn.IntValue) << 32));
                as.mov(ptr(rdi, -8), rdx);

                for (size_t i = 0; i < args.size(); i++)
                {
                    FlowInstruction &arg = args[i]->second;
                    log_instruction(as, arg, "// arg ");

                    switch (args[i]->second.op) {
                    case CGetLocal:
                        as.mov(rdx, ptr(rDFrame, arg.IntValue*QWORD));
                        break;

                    case CGetFreeVar:
                        as.mov(rdx, ptr(rMemBase, rClosure, 0, 4+arg.IntValue*QWORD));
                        break;

                    default:
                        abort();
                    }

                    as.mov(ptr(rdi, 8*i), rdx);
                }

                asm_rax_to_stack(&cpos);
            }
            else
            {
                as.add(rax, owner->const_qword(tag.slot_private.QWordVal));

                as.mov(ecx, insn.IntValue);
                as.mov(edx, owner->function_map[insn.PtrValue]->index);
                owner->util_init_closure.call(as);
            }

            break;
        }

        case COptionalNativeFn:
        {
            FunctionInfo::Ptr func = owner->native_function_map[ipair->first];

            if (!func->native_fallback)
            {
                owner->err << "Could not link fallback for OptionalNativeFn at " << std::hex << FlowPtrToInt(ipair->first) << " - recompile bytecode." << std::endl;
#ifdef DEBUG_FLOW
                throw JitError();
#endif
            }

            asm_stack_to_rax(&cpos);
            as.mov(rax, StackSlot::MakeNativeFn(func->index).slot_private.QWordVal);
            asm_rax_to_stack(&cpos);
            break;
        }

        case CNativeFn:
            as.mov(rax, StackSlot::MakeNativeFn(owner->native_function_map[ipair->first]->index).slot_private.QWordVal);
            asm_rax_to_stack(&cpos);
            break;

        case CArray:
        {
            if (insn.IntValue == 0)
            {
                // Empty array is a constant
                as.mov(rax, StackSlot::MakeEmptyArray().slot_private.QWordVal);
                asm_rax_to_stack(&cpos);
            }
            else
            {
                as.mov(ecx, insn.IntValue*QWORD + 4);
                owner->util_allocate.call(as);

                bool big = (insn.IntValue & 0xffff0000) != 0;
                StackSlot tag =  StackSlot::InternalMakeArray(MakeFlowPtr(0), big ? (insn.IntValue>>16) : insn.IntValue, big);
                as.or_(rax, owner->const_qword(tag.slot_private.QWordVal));

                as.mov(ecx, insn.IntValue);
                owner->util_init_array.call(as);
            }
            break;
        }

        case CArrayGet:
        {
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, 0xffff, StackSlot::TAG_INT, TInt, rcx);
            as.mov(edx, eax);

            asm_pop_rax();
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_ARRAY, TArray, rcx);

            owner->asm_decode_arrdim(rsi, rcx, rax);
            checker.asm_check_arridx(edx, ecx);

            as.mov(rax, ptr(rsi, rdx, 3, 4));
            asm_rax_to_stack(&cpos);
            break;
        }

        case CRefTo:
        {
            as.mov(ecx, (uint64_t)sizeof(FlowHeapRef));
            owner->util_allocate.call(as);
            owner->util_init_ref.call(as);

            as.mov(rdx, ptr(rDStack, -QWORD));
            as.mov(ptr(rdi,4), rdx);

            asm_rax_to_stack(&cpos, -QWORD);
            break;
        }

        case CDeref:
        {
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_REFTO, TRefTo, rcx);

            as.mov(esi, eax);
            as.mov(rax, ptr(rMemBase, rsi, 0, 4));
            asm_rax_to_stack(&cpos);
            break;
        }

        case CSetRef:
        {
            as.mov(rax, ptr(rDStack, -2*QWORD));
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_REFTO, TRefTo, rcx);

            /*
             * TODO: more efficient common case fast path in assembly.
             *
             * Specifically, it should be feasible to update RefWriteMask
             * like ByteCodeRunner::RegisterWrite(FlowPtr) does from asm
             * (possibly after changing it to use a manually implemented bitmask),
             * and also maybe use gc tag to detect already registered updates
             * like struct code does.
             *
             * Currently this simply calls C++ ByteCodeRunner::RegisterWrite.
             */
            owner->thunk_register_ref_write.call(as);

            as.mov(edi, ptr(rDStack, -2*QWORD));
            as.mov(rax, ptr(rDStack, -QWORD));
            as.mov(ptr(rMemBase, rdi, 0, 4), rax);

            asm_void_to_stack(&cpos, -2*QWORD);
            break;
        }

        case CStruct:
        {
            StructInfo::Ptr info = owner->struct_by_id[insn.IntValue];
            as.mov(rax, info->empty_addr | info->type_tag);

            if (info->num_fields == 0)
            {
                asm_push_to_stack(&cpos, 0, ipair, 0, false);
            }
            else
            {
                as.mov(ecx, info->byte_size);
                owner->util_allocate.call(as);

                as.lea(rdi, ptr(rMemBase, rax));
                as.mov(rtmp0, info->type_tag);
                as.mov(ptr(rdi, 0, 4), info->index);
                as.or_(rtmp0, rax);

                as.lea(rsi, ptr(rDStack, -info->num_fields*QWORD));

                // Copy fields from slots on stack at rsi to struct at rdi
                info->cb_pack.call(as);

                as.sub(rDStack, info->num_fields*QWORD);
                as.mov(rax, rtmp0);
                asm_rax_to_stack(&cpos);
            }
            break;
        }

        case CField:
        {
            // Table of accessors for reading Nth field of any struct
            StructAccessorTable::Ptr table = owner->struct_field_readers_idx[insn.IntValue];

            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_STRUCT, TStruct, rcx);
            checker.asm_check_structidx(rcx, rax, table);
            as.mov(rtmp0, rax);
            as.mov(esi, eax);
            as.add(rsi, rMemBase);

            // Call reader: [rsi+field_offset] -> rax
            as.lea(rdi, ptr(uintptr_t(table->table_data)));
            as.call(ptr(rdi, rcx, 3));

            asm_rax_to_stack(&cpos);
            break;
        }

        case CFieldName:
        {
            // Table of accessors for reading a specifically named field of any struct
            StructAccessorTable::Ptr table = owner->struct_field_readers_name[insn.StrValue];

            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_STRUCT, TStruct, rcx);
            checker.asm_check_structidx(rcx, rax, table);

            if (insn.StrValue == "structname")
            {
                as.lea(rdi, ptr(uintptr_t(owner->struct_name_table)));
                as.mov(rax, ptr(rdi, rcx, 3));
            }
            else
            {
                as.mov(rtmp0, rax);
                as.mov(esi, eax);
                as.add(rsi, rMemBase);

                // Call reader: [rsi+field_offset] -> rax
                as.lea(rdi, ptr(uintptr_t(table->table_data)));
                as.call(ptr(rdi, rcx, 3));
            }

            asm_rax_to_stack(&cpos);
            break;
        }

        case CSetMutable:
        {
            // Table of accessors for writing Nth field of any struct
            StructAccessorTable::Ptr table = owner->struct_field_writers_idx[insn.IntValue];

            asm_stack_to_rax(&cpos);
            owner->util_pre_struct_write.call(as);
            checker.asm_check_structidx(rcx, rtmp0, table);

            // Call writer: rax -> [rdi+field_offset]
            as.lea(rsi, ptr(uintptr_t(table->table_data)));
            as.call(ptr(rsi, rcx, 3));

            asm_void_to_stack(&cpos, -QWORD);
            break;
        }

        case CSetMutableName:
        {
            // Table of accessors for writing named field of any struct
            StructAccessorTable::Ptr table = owner->struct_field_writers_name[insn.StrValue];

            asm_stack_to_rax(&cpos);
            owner->util_pre_struct_write.call(as);
            checker.asm_check_structidx(rcx, rtmp0, table);

            // Call writer: rax -> [rdi+field_offset]
            as.lea(rsi, ptr(uintptr_t(table->table_data)));
            as.call(ptr(rsi, rcx, 3));

            asm_void_to_stack(&cpos, -QWORD);
            break;
        }

        case CSimpleSwitch:
        {
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_STRUCT, TStruct, rcx);

            as.mov(rcx, rax);
            as.shr(rcx, 32);
            as.movzx(ecx, cx);

            std::map<int, Label> switch_table;
            for (int k = 0; k < insn.IntValue; ++k)
            {
                int id = insn.cases[k].id;
                StructInfo::Ptr sinfo = owner->struct_by_id[id];

                switch_table[sinfo->index] = jump_targets[insn.cases[k].target];
            }

            Label def = as.newLabel();
            asm_switch(switch_table, ecx, def);
            as.bind(def);
            break;
        }

        case CSwitch:
        {
            asm_stack_to_rax(&cpos);
            checker.asm_check_tag(rax, StackSlot::TAG_NOSIGN, StackSlot::TAG_STRUCT, TStruct, rcx);

            as.mov(rcx, rax);
            as.shr(rcx, 32);
            as.movzx(ecx, cx);

            as.mov(esi, eax);
            as.add(rsi, rMemBase);
            as.mov(rdi, rDStack);

            std::map<int, Label> switch_table;
            for (int k = 0; k < insn.IntValue; ++k)
            {
                int id = insn.cases[k].id;
                StructInfo::Ptr sinfo = owner->struct_by_id[id];

                switch_table[sinfo->index] = (sinfo->num_fields > 0) ? as.newLabel() : jump_targets[insn.cases[k].target];
            }

            Label def = as.newLabel();
            asm_switch(switch_table, ecx, def);

            // Generate code snippets for unpacking the struct
            for (int k = 0; k < insn.IntValue; ++k)
            {
                int id = insn.cases[k].id;
                StructInfo::Ptr sinfo = owner->struct_by_id[id];
                if (sinfo->num_fields == 0)
                    continue;

                as.bind(switch_table[sinfo->index]);
                as.add(rDStack, sinfo->num_fields*QWORD);

                // Unpacks struct at rsi to slots at rdi
                sinfo->cb_unpack.call(as);

                as.jmp(jump_targets[insn.cases[k].target]);
            }

            as.bind(def);
            break;
        }

        case CUncaughtSwitch:
            owner->thunk_uncaught_switch.call(as);
            break;

        case CLast:
        case CReserveLocals:
        case CDebugInfo:
        case CStructDef:
            break;

        /* Invalid codes */
        case CTypedArray:
        case CTypedStruct:
        case CTypedRefTo:
        case CBreakpoint:
        case CCodeCoverageTrap:
        case CNotImplemented:
            as.int3();
            break;

        /*default:
            as.int3();
            break;*/
        }
    }

    // Bind label for jump to the end of code
    {
        std::map<FlowPtr,Label>::iterator lbl_it = jump_targets.find(end_addr);
        if (lbl_it != jump_targets.end())
            as.bind(lbl_it->second);
    }
}
