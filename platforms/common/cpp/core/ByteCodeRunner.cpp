#include "ByteCodeRunner.h"
#include <string.h>
#include "GarbageCollector.h"
#include "NativeProgram.h"

#ifdef FLOW_JIT
#include "JitProgram.h"
#endif

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#ifndef _MSC_VER
#include <alloca.h>
#endif

#include <iomanip>
#include <sstream>

#ifdef FLOW_MMAP_HEAP
#ifdef _MSC_VER
#include "win_mman.h"
#else
#include <sys/mman.h>
#endif
#endif

#ifdef FLOW_QT_BACKEND
#include <QDir>
#include <QTemporaryFile>
#include <QUrlQuery>
#endif

// in case 'usleep' is undefined during compile
// #include <unistd.h>

using std::stringstream;

StackSlot flowgen_common::error_stub_slot = StackSlot::MakeVoid();

/* !!OBSOLETE!! Memory representation:
    *
    *              0    ----------------------------------------------------------------------
    *                   bytecode
    * callStackStart    ----------------------------------------------------------------------
    *                   CallStack : [return address and framepointers: int]
    *                       ....
    *
    *
    *                       ....
    *                   Closure stack : [address to free variables on the heap: int]
    * dataStackStart    ----------------------------------------------------------------------
    *                   Data stack : [ tagged value ]
    *                       .....
    *
    *
    * heapStart         ----------------------------------------------------------------------
    *                   Heap 1 : length, data (except for references which are always stackslot)
    *                       .....
    *
    *
    *                   --- half heap
    *
    *
    *                       .....
    *                   Heap 2 : length, data
    * heapEnd           ----------------------------------------------------------------------
*/

#if defined(ANDROID) || defined(IOS)
    unsigned int EPHEMERAL_HEAP_SIZE = 2*1024*1024;
    unsigned int MAX_EPHEMERAL_ALLOC = 32*1024;
#else
    unsigned int EPHEMERAL_HEAP_SIZE = 128*1024*1024;
    unsigned int MAX_EPHEMERAL_ALLOC = 1*1024*1024;
#endif


#ifndef MIN
    #define MIN(X,Y) ((X) < (Y) ? (X) : (Y))
#endif

ByteCodeRunner::ByteCodeRunner() :
     flow_out(std::cout.rdbuf()), flow_err(std::cerr.rdbuf())
{
    initStructures();
}

ByteCodeRunner::ByteCodeRunner(const char *bytecode_buffer, int bytecode_length) :
     flow_out(std::cout.rdbuf()), flow_err(std::cerr.rdbuf())
{
    initStructures();
    Init(bytecode_buffer, bytecode_length);
}

ByteCodeRunner::ByteCodeRunner(std::string bytecode_file) :
     flow_out(std::cout.rdbuf()), flow_err(std::cerr.rdbuf())
{
    initStructures();
    Init(bytecode_file);
}

#ifndef _MSC_VER
struct tm ByteCodeRunner::tzOffsetInfo;
#endif

/*
 * Initialization of fields upon object construction.
 */
void ByteCodeRunner::initStructures() {
    ProfileStream = NULL;
#ifdef FLOW_TIME_PROFILING
#ifdef FLOW_PTHREAD
    ProfileClock = 0;
    pthread_mutex_init(&ProfileClockMutex, NULL);
#else
    ProfileClock = NULL;
    ProfileClockMutex = NULL;
#endif
#endif

#ifdef DEBUG_FLOW
    NotifyStubs = true;
#else
    NotifyStubs = false;
#endif

#ifdef FLOW_DEBUGGER
    DebuggerPtr = NULL;
#endif

#if defined(FLOW_TIME_PROFILING) || defined(FLOW_DEBUGGER)
    ProfileTimeCount = 0;
#endif

#ifdef FLOW_MMAP_HEAP
    MapStringPtr = MakeFlowPtr(align_down(MAX_MEMORY_SIZE, MemoryArea::page_size()));
    MapAreaBase = MakeFlowPtr(MAX_HEAP_SIZE);
#endif

#ifndef _MSC_VER
    time_t now = time(NULL);
    localtime_r(&now, &ByteCodeRunner::tzOffsetInfo);
#endif

    ExtDbgInfo = NULL;

    NativeReturnInsn = MakeFlowPtr(0);
    Memory.SetSize(0);
    Code.SetBuffer(NULL, 0, 0);

    DataStack.allocate(MAX_DATA_STACK + MemoryArea::page_size()/sizeof(StackSlot));
    NumFrozenDataStack = 0;

    DeferredQueueLockCount = 0;
    DeferredQueueTimeout = -1.0;

    NumFullGCs = 0;
    FramePointer = 0;
    closurepointer = MakeFlowPtr(0);
    NativeCallDepth = 0;

#ifdef FLOW_JIT
    JitCallFrame = NULL;
#endif

#ifdef FLOW_GARBAGE_PROFILING
    LastDumpID = 0;
#endif

    LastError = NoError;
    Program = NULL;
#ifdef FLOW_JIT
    JitProgram = NULL;
#endif
    is_raw_bytecode = false;

#define STRUCT(name,size) KnownStructTable[#name] = T_KnownStructTableItem(& name ## StructId, size);
    FLOW_KNOWN_STRUCTS
#undef STRUCT

#ifdef FLOW_NATIVE_OVERRIDES
#define OVERRIDE(name,args) NativeOverrides[#name] = T_NativeOverridesItem(override_##name,args);
    FLOW_NATIVE_OVERRIDES
#undef OVERRIDE
#endif
}

void ByteCodeRunner::Init(std::string bytecode_file) {
    initializationComplete = false;
    if (!bytecode_file.empty())
        DoInit(bytecode_file.c_str(), 0, true);
    else
        DoInit(NULL, FlowPtrToInt(getLastCodeAddress()), false);

    BytecodeFilename = bytecode_file;
    initializationComplete = true;
}

void ByteCodeRunner::Init(const char *bytecode_buffer, int bytecode_length)
{
    initializationComplete = false;
    DoInit(bytecode_buffer, bytecode_length, false);
    is_raw_bytecode = true;
    initializationComplete = true;
}

void ByteCodeRunner::Init(NativeProgram *program)
{
    initializationComplete = false;
    assert(program->owner == NULL || program->owner == this);

    int length = 0;
    const char *bytecode = program->getByteCode(&length);

    DoInit(bytecode, length, false);

    program->owner = this;
    Program = program;
    Program->onRunnerAttach();
    initializationComplete = true;
}

#ifdef FLOW_JIT
void ByteCodeRunner::Init(FlowJitProgram *program)
{
    initializationComplete = false;
    program->InitRunner(this);

    JitProgram = program;
    initializationComplete = true;
}
#endif

void ByteCodeRunner::ReloadBytecode()
{
    bool is_raw = is_raw_bytecode;
    std::string filename = BytecodeFilename;

    if (Program)
    {
        Init(Program);
    }
#ifdef FLOW_JIT
    else if (JitProgram)
    {
        Init(JitProgram);
    }
#endif
    else if (is_raw)
    {
        std::vector<std::string> SaveFieldRefNames = FieldRefNames;
        std::map<std::string,int> SaveFieldRefIds = FieldRefIds;

#ifdef FLOW_DEBUGGER
        for (std::map<FlowPtr, OpCode>::iterator it = BreakpointOpcodeBackup.begin();
             it != BreakpointOpcodeBackup.end(); ++it)
            Memory.SetByte(it->first, it->second);

        BreakpointOpcodeBackup.clear();
#endif

        unsigned size = Code.GetSize() - 1;
        std::string buffer(size, '\0');
        memcpy(&buffer[0], Memory.GetRawPointer(MakeFlowPtr(0), size, false), size);

        Init(buffer.data(), buffer.size());

        FieldRefNames = SaveFieldRefNames;
        FieldRefIds = SaveFieldRefIds;
    }
    else
    {
        Init(filename);
    }
}

/*
 * Initializes runner for executing given bytecode.
 *
 * Compiled C++ and JIT also provide a dummy 'bytecode' buffer
 * in order to load string constants into the flow memory area.
 */
void ByteCodeRunner::DoInit(const char *bytecode_buffer_or_fn, int bytecode_length, bool from_file)
{
    static StackSlot dummy_ss[2];
    static FlowPtr dummy_fp[2];

    if (sizeof(int) != 4 || sizeof(FlowPtr) != 4 || sizeof(StackSlot) != STACK_SLOT_SIZE ||
        sizeof(dummy_fp) != 8 || sizeof(dummy_ss) != 2*STACK_SLOT_SIZE)
    {
        flow_err << "Platform violates data type size assumptions.\n";
        abort();
    }

    Reset(false);

    // Set up the different memory segments
    int CodePosition = 0;
    FlowPtr CodeStart = MakeFlowPtr(CodePosition);

    bool code_mapped = false;
    if (from_file)
    {
        if (FILE *file = fopen(bytecode_buffer_or_fn, "rb"))
        {
            if(fseek(file, 0, SEEK_END) < 0)  // May be bad filename
            {
                cerr << "Bad/no bytecode file: <<" << bytecode_buffer_or_fn << ">>, error " << errno << ": " << strerror(errno) << endl;
            }

            bytecode_length = ftell(file);
            rewind(file);

            Memory.SetSize(bytecode_length + 1);

            if (!Memory.MapFile(CodeStart, bytecode_length, bytecode_buffer_or_fn, 0, true))
            {
                char *p = Memory.GetRawPointer(CodeStart, bytecode_length, true);
                int have_read = int(fread(p, 1, bytecode_length, file));
                if (have_read < bytecode_length) {
                	// We have read less elements, then required.
                	cerr << "Error loading bytecode file: <<" << bytecode_buffer_or_fn << ">>, have read " << have_read << " bytes while acquired " << bytecode_length << " bytes" << endl;
                }
            }
            else
                code_mapped = true;

            fclose(file);
        }
        else
        {
            cerr << "Can't open bytecode file: <<" << bytecode_buffer_or_fn << ">>, error " << errno << ": " << strerror(errno) << endl;
        }

        bytecode_buffer_or_fn = NULL;
    }

    // space for CLast artificial instruction
    bytecode_length++;

    // Call stack: starts right after the code, aligned up to 4 bytes
    HeapStart = MakeFlowPtr(bytecode_length);
    if (code_mapped)
        HeapStart = FlowPtrAlignUp(HeapStart, Memory.PageSize());
    else
        HeapStart = FlowPtrAlignUp(HeapStart, 4);

    HeapEnd = HeapStart + MIN_HEAP_SIZE; // The highest address

#ifdef FLOW_MMAP_HEAP
    MapStringPtr = MakeFlowPtr(align_down(MAX_MEMORY_SIZE, MemoryArea::page_size()));
    MapAreaBase = HeapStart + MAX_HEAP_SIZE;
#endif

    Memory.SetSize(FlowPtrToInt(HeapEnd));
    if (bytecode_buffer_or_fn != NULL)
        Memory.SetBytes(CodeStart, bytecode_buffer_or_fn, bytecode_length-1);

    // putting an artificial instruction in place
    Memory.SetByte(CodeStart + bytecode_length - 1, char(CLast));

    // initializing code memory
    Code.SetBuffer(Memory.GetRawPointer(MakeFlowPtr(0), bytecode_length, false), CodePosition, bytecode_length);

    NativeReturnInsn = getLastCodeAddress() - 1;

    UpdateHeapLimits(true);
    RefWriteMask.clear();
    SlotWriteSet.clear();
#ifdef FLOW_COMPACT_STRUCTS
    StructWriteSet.clear();
#endif

    NextRefId = 0;
    NextGCTag = GarbageCollector::MAX_SPECIAL_TAG+1;

    FramePointer = 0;
    closurepointer = MakeFlowPtr(0);

#ifdef FLOW_INSTRUCTION_PROFILING
    InstructionCount = 0;
    ProfileICBarrier = 0;
    ProfileICStep = 0;
    ProfileCodeCoverage = false;
    CoverageCodeBackup.clear();
    ProfileMemBarrier = MakeFlowPtr(0);
    ProfileMemStep = 0;
#ifdef FLOW_GARBAGE_PROFILING
    DoProfileGarbage = false;
    ProfileHeapObjects.clear();
#endif
#endif

#ifdef FLOW_TIME_PROFILING
    ProfileTimeStep = 0;
#endif

#if defined(FLOW_TIME_PROFILING) || defined(FLOW_DEBUGGER)
    ProfileTimeCount = 0;
#endif

    LastInstructionPtr = MakeFlowPtr(0);
    LastError = NoError;
    LastErrorDescr = LastErrorInfo = std::string();

#ifdef FLOW_DEBUGGER
    ImpersonateInsn = MakeFlowPtr(0);
    if (DebuggerPtr)
        DebuggerPtr->onRunnerInit();
#endif
}

void ByteCodeRunner::StopProfiling()
{
#ifdef FLOW_TIME_PROFILING
    // Stop time profiling
    if (ProfileClock) {
        ProfileTimeStep = 0;
#ifndef FLOW_PTHREAD
        if (ProfileClock->wait(500)) {
            delete ProfileClock;
            delete ProfileClockMutex;
        }
        ProfileClock = NULL;
        ProfileClockMutex = NULL;
#endif
    }
#endif

    // Close profile output
    if (ProfileStream) {
        fclose(ProfileStream);
        ProfileStream = NULL;
    }

#ifdef FLOW_GARBAGE_PROFILING
    LastDumpID = 0;
    DoProfileGarbage = false;
    ProfileHeapObjects.clear();
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
    InstructionCount = 0;
    ProfileICBarrier = 0;
    ProfileICStep = 0;
    ProfileCodeCoverage = false;
    CoverageCodeBackup.clear();
    ProfileMemBarrier = MakeFlowPtr(0);
    ProfileMemStep = 0;
#endif

#ifdef FLOW_TIME_PROFILING
    ProfileTimeStep = 0;
#endif

#if defined(FLOW_TIME_PROFILING) || defined(FLOW_DEBUGGER)
    ProfileTimeCount = 0;
#endif
}

/*
 * Reset runner state before its deallocation, or to prepare for executing new code.
 */
void ByteCodeRunner::Reset(bool inDestructor)
{
    StopProfiling();

#ifdef FLOW_DEBUGGER
    BreakpointOpcodeBackup.clear();
    DbgInsnTrap = DbgCallTrap = DbgReturnTrap = false;
    if (DebuggerPtr)
        DebuggerPtr->onRunnerReset();
    ImpersonateInsn = MakeFlowPtr(0);
#endif

    is_raw_bytecode = false;
    BytecodeFilename.clear();

    if (Program)
    {
        Program->onRunnerDetach();
        Program->owner = NULL;
        Program = NULL;
    }

#ifdef FLOW_JIT
    if (JitProgram)
    {
        JitProgram->ResetRunner(this);
        JitProgram = NULL;
    }
#endif

    // Free native values
    NumFrozenNativeFNs = 0;
#ifdef FLOW_COMPACT_STRUCTS
    NumCompactNativeFNs = 0;
#endif
    DeleteDeadNativeVals(T_LiveTable(), 0);
    DeleteDeadNativeFuns(T_LiveTable());
    NativeValues.clear();
    Natives.clear();
    ConstClosureCache.clear();
    NextNativeIdx = NativeGCGenBarrier = 0;
    NativeValueBudget = 1000;

    DataStack.readonly(NumFrozenDataStack, false);
    NumFrozenDataStack = 0;

#ifdef FLOW_JIT
    JitFuncs.clear();
    JitCallFrame = NULL;
#endif

    LastInstructionPtr = MakeFlowPtr(0);

    // Free structure definition records
    StructDefs.clear();
    StructSizes.clear();
    StructNameIds.clear();
    FieldRefIds.clear();
    FieldRefNames.clear();
    FieldRefIds["structname"] = -1;

#ifdef FLOW_COMPACT_STRUCTS
    for (size_t i = 0; i < AutoStructFields.size(); i++)
        delete[] AutoStructFields[i];
    AutoStructFields.clear();
    for (size_t i = 0; i < AutoStructGCFields.size(); i++)
        delete[] AutoStructGCFields[i];
    AutoStructGCFields.clear();
#endif

    // Clear cached ids
    for (T_KnownStructTable::iterator it = KnownStructTable.begin(); it != KnownStructTable.end(); ++it)
        *it->second.first = -1;

    // Free debug data
    DebugFnInfo.clear();
    DebugFnList.clear();

    // Empty other tables
    NativeRoots.clear();
    nNativeRoots = 0;

    Toplevel.clear();
    DataStack.clear();
    CallStack.clear();
    NativeCallDepth = 0;

    DeferredActionQueue.clear();

    NumFullGCs = 0;
    FramePointer = 0;
    closurepointer = MakeFlowPtr(0);

#ifdef FLOW_MMAP_HEAP
    MappedAreas.clear();
    MappedFiles.clear();
#endif

    // Reset hosts. This is done last, so that stuff
    // like native value tables & roots is ready for use.
    T_NativeHosts::iterator it;;
    for (it = NativeHosts.begin(); it != NativeHosts.end(); ++it)
        (*it)->OnRunnerReset(inDestructor);

    Memory.SetSize(0);
    Memory.DecommitRange(MakeFlowPtr(0), MakeFlowPtr(MAX_MEMORY_SIZE));
    Code.SetPosition(MakeFlowPtr(0));
    Code.SetBuffer(NULL,0,0);
}

ByteCodeRunner::~ByteCodeRunner()
{
    Reset(true);
#ifdef FLOW_TIME_PROFILING
#ifdef FLOW_PTHREAD
    pthread_mutex_destroy(&ProfileClockMutex);
#endif
#endif
}

#ifdef FLOW_QT_BACKEND
void ByteCodeRunner::setUrl(QUrl url)
{
    UrlString = qt2unicode(url.toString());
    UrlParameters.clear();

    typedef QPair<QString, QString> IX;
    foreach(IX item, QUrlQuery(url.query()).queryItems())
        UrlParameters[qt2unicode(item.first)] = qt2unicode(QUrl::fromPercentEncoding(item.second.toUtf8()));
}

void ByteCodeRunner::setUrlParameter(QString key, QString value) {
    UrlParameters[qt2unicode(key)] = qt2unicode(value);
}

#endif

void ByteCodeRunner::SetExtendedDebugInfo(ExtendedDebugInfo *dinfo)
{
    ExtDbgInfo = dinfo;
}

HeapLimits ByteCodeRunner::GetHeapLimits(bool high)
{
    unsigned size = HeapEnd - HeapStart;
    FlowPtr m = HeapStart + size / 2;
    HeapLimits ret;
    ret.Start = high ? HeapEnd : m;
    ret.Bound = high ? m : HeapStart;
    ret.Ephemeral = ret.Bound + EPHEMERAL_HEAP_SIZE;
    return ret;
}

void ByteCodeRunner::UpdateHeapLimits(bool high)
{
    highHeap = high;
    HeapLimits hl = GetHeapLimits(highHeap);
    hp = hl.Ephemeral;
    hpbound = hl.Bound;
    hp_ref_base = hp_ref_end = hl.Ephemeral;
    hp_big_end = hp_big_pos = hl.Start;
}

/*
 * Clear tables used for tracking writes to objects in the old generation.
 */
void ByteCodeRunner::ResetRefMask(FlowPtr ref_end, FlowPtr big_pos)
{
    hp_ref_end = ref_end;
    hp_big_pos = big_pos;
    RefWriteMask.clear();
    SlotWriteSet.clear();
#ifdef FLOW_COMPACT_STRUCTS
    StructWriteSet.clear();
#endif
    int rcount = (hp_ref_end-hp_ref_base)/sizeof(FlowHeapRef);
    RefWriteMask.resize((rcount+REF_MASK_STEP-1)/REF_MASK_STEP);
}

const char *FlowInstruction::OpCode2String(OpCode opcode)
{
    switch (opcode)
    {
    case CVoid: return "Void";
    case CBool: return "Bool";
    case CInt: return "Int";
    case CDouble: return "Double";
    case CString: return "String";
    case CArray: return "Array";
    case CStruct: return "Struct";
    case CSetLocal: return "SetLocal";
    case CGetLocal: return "GetLocal";
    case CGetGlobal: return "GetGlobal";
    case CReturn: return "Return";
    case CPop: return "Pop";
    case CGoto: return "Goto";
    case CCodePointer: return "CodePointer";
    case CCall: return "Call";
    case CNotImplemented: return "NotImplemented";
    case CIfFalse: return "IfFalse";
    case CNot: return "Not";
    case CNegate: return "Negate";
    case CMultiply:  return "Multiply";
    case CDivide: return "Divide";
    case CModulo: return "Modulo";
    case CPlus: return "Plus";
    case CMinus: return "Minus";
    case CEqual: return "Equal";
    case CLessThan: return "LessThan";
    case CLessEqual: return "LessEqual";
    case CNativeFn: return "NativeFn";
    case COptionalNativeFn: return "OptionalNativeFn";
    case CArrayGet: return "ArrayGet";
    case CReserveLocals: return "ReserveLocals";
    case CRefTo: return "RefTo";
    case CDeref: return "Deref";
    case CSetRef: return "SetRef";
    case CInt2Double: return "Int2Double";
    case CInt2String: return "Int2String";
    case CDouble2Int: return "Double2Int";
    case CDouble2String: return "Double2String";
    case CField: return "Field";
    case CFieldName: return "FieldName";
    case CStructDef: return "StructDef";
    case CGetFreeVar:return "GetFreeVar";
    case CDebugInfo: return "DebugInfo";
    case CClosureReturn: return "ClosureReturn";
    case CClosurePointer: return "ClosurePointer";
    case CSwitch: return "Switch";
    case CUncaughtSwitch: return "UncaughtSwitch";
    case CTailCall: return "TailCall";
    case CPlusString: return "PlusString";
    case CPlusInt: return "PlusInt";
    case CMinusInt: return "MinusInt";
    case CNegateInt: return "NegateInt";
    case CMultiplyInt: return "MultiplyInt";
    case CDivideInt: return "DivideInt";
    case CModuloInt: return "ModuloInt";
    case CSimpleSwitch: return "SimpleSwitch";
    case CWString: return "WString";
    case CLast: return "Last";
    case CBreakpoint: return "<BREAKPOINT>";
    case CTypedArray: return "TypedArray";
    case CTypedStruct: return "TypedStruct";
    case CTypedRefTo: return "TypedRefTo";
    case CSetMutable: return "SetMutable";
    case CSetMutableName: return "SetMutableName";
    case CCodeCoverageTrap: return "<COVERAGE-TRAP>";
    }

    return "Unknown";
}

/*
 * Import structure definitions from a flow to C++ compiled program.
 */
bool NativeProgram::InitStructTable(const StructSpec *in, unsigned count)
{
    assert(owner->StructDefs.empty());

    owner->StructDefs.reserve(count);
    owner->StructSizes.reserve(count);

    for (unsigned i = 0; i < count; i++)
    {
        StructDef sd;
        sd.Name = in[i].name;
        sd.NameU = parseUtf8(in[i].name);

        unsigned n = in[i].num_fields;
        const int *ptype = in[i].field_type_info;

        sd.FieldsCount = n;
        sd.CompareIdx = in[i].compare_idx;
        sd.IsMutable.resize(n);

        for (unsigned j = 0; j < n; ++j)
        {
            sd.FieldNames.push_back(in[i].field_names[j]);
            sd.FieldTypes.push_back(std::vector<FieldType>());

            for(;;) {
                int tv = *ptype++;
                if (tv == FTMutable) {
                    sd.IsMutable[j] = true;
                    continue;
                }
                if (tv == -1) break;
                sd.FieldTypes.back().push_back((FieldType)tv);
            }
        }

#ifdef FLOW_COMPACT_STRUCTS
        sd.ByteSize = in[i].byte_size;
        sd.EmptyPtr = MakeFlowPtr(in[i].empty_addr);
        sd.FieldDefs = in[i].field_defs;
        sd.GCFieldCount = in[i].num_gcdefs;
        sd.FieldGCDefs = in[i].field_gcdefs;
#endif

        owner->RegisterStructDef(i, sd);
    }

    return true;
}

/*
 * Import a struct definition from the relevant opcode.
 */
void ByteCodeRunner::RegisterStructDef(unsigned id, const StructDef &sd)
{
    if (unsigned(id) >= StructDefs.size()) {
        unsigned csz = StructDefs.size();

        StructDefs.resize(id+1);
        StructSizes.resize(id+1);

        memset(&StructSizes[csz], 0, sizeof(unsigned)*(StructSizes.size()-csz));
    }

    StructDefs[id] = sd;
    StructDefs[id].StructId = id;
    StructSizes[id] = sd.FieldsCount;
    StructNameIds[sd.Name] = id;

#ifdef FLOW_COMPACT_STRUCTS
    StructDef &def = StructDefs[id];

    if (!def.FieldDefs && def.FieldsCount > 0)
    {
        FlowStructFieldDef *fdefs =  new FlowStructFieldDef[def.FieldsCount];
        AutoStructFields.push_back(fdefs);

        std::vector<FlowStructFieldGCDef> gcdefs;
        int offset = 4;

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

        for (int i = 0; i < def.FieldsCount; i++)
        {
            fdefs[i].offset = offset;

            bool has_gc = true;
            FlowStructFieldGCDef gcdef;
            unsigned size = 4;

            switch (def.FieldTypes[i][0]) {
            case FTBool:
                fdefs[i] = def_bool;
                has_gc = false;
                break;
            case FTInt:
                fdefs[i] = def_int;
                has_gc = false;
                break;
            case FTDouble:
                size = sizeof(double);
                fdefs[i] = def_double;
                has_gc = false;
                break;
            case FTString:
                size = sizeof(FlowStructString);
                fdefs[i] = def_string;
                gcdef = gcdef_string;
                break;
            case FTArray:
            case FTTypedArray:
                size = sizeof(FlowStructArray);
                fdefs[i] = def_array;
                gcdef = gcdef_array;
                break;
            case FTRefTo:
            case FTTypedRefTo:
                size = sizeof(FlowStructRef);
                fdefs[i] = def_ref;
                gcdef = gcdef_ref;
                break;
            case FTStruct:
            case FTTypedStruct:
                size = sizeof(FlowPtr);
                fdefs[i] = def_struct;
                gcdef = gcdef_struct;
                break;
            default:
                size = STACK_SLOT_SIZE;
                fdefs[i] = def_slot;
                gcdef = gcdef_slot;
            }

            fdefs[i].offset = offset;
            gcdef.offset = offset;
            offset += size;

            if (has_gc)
                gcdefs.push_back(gcdef);
        }

        def.FieldDefs = fdefs;
        def.GCFieldCount = gcdefs.size();
        def.ByteSize = offset;

        if (!gcdefs.empty())
        {
            FlowStructFieldGCDef *pgcdefs = new FlowStructFieldGCDef[gcdefs.size()];
            memcpy(pgcdefs, gcdefs.data(), sizeof(FlowStructFieldGCDef)*gcdefs.size());
            def.FieldGCDefs = pgcdefs;
            AutoStructGCFields.push_back(pgcdefs);
        }
    }
#endif

    // Save some notable structures directly
    T_KnownStructTable::iterator it = KnownStructTable.find(sd.Name);
    if (it != KnownStructTable.end())
        *it->second.first = id;
}

// Global root handling

int ByteCodeRunner::RegisterRoot(StackSlot root)
{
    int n = nNativeRoots++;
    NativeRoots[n] = root;
    return n;
}

StackSlot ByteCodeRunner::LookupRoot(int i)
{
    T_NativeRoots::iterator it = NativeRoots.find(i);
    if (it != NativeRoots.end())
        return it->second;
    else
        return StackSlot::MakeVoid();
}

void ByteCodeRunner::ReleaseRoot(int i)
{
     NativeRoots.erase(i);
}

// Stack and memory functions

void ByteCodeRunner::StackError(RuntimeError error, bool overflow)
{
    const char *name = "unknown";
    switch (error) {
    case DatastackFull: name = "data"; break;
    case CallstackFull: name = "call"; break;
    case ClosurestackFull: name = "closure"; break;
    default:;
    }

    ReportError(error, "Stack %s in the %s stack.", (overflow ? "overflow" : "underflow"), name);
}

int ByteCodeRunner::PopStackInt() {
    StackSlot top = PopStackSlot();
    if (unlikely(!top.IsInt())) {
        ReportTagError(top, TInt, "PopStackInt()", NULL);
        return -1;
    }
    return top.GetInt();
}

FlowDouble ByteCodeRunner::PopStackDouble() {
    StackSlot top = PopStackSlot();
    if (unlikely(!top.IsDouble())) {
        ReportTagError(top, TDouble, "PopStackDouble()", NULL);
        return -1;
    }
    return top.GetDouble();
}

StackSlot ByteCodeRunner::AllocNativeObj(AbstractNativeValue *value)
{
    NativeValueBudget--;
    NativeValues[NextNativeIdx] = value;
    StackSlot name = StackSlot::MakeNative(NextNativeIdx++);
    value->registerSelf(name);
    return name;
}

AbstractNativeValue *ByteCodeRunner::GetNativeObj(NativeValueTypeBase *tag, const StackSlot &slot, bool fno)
{
    if (unlikely(!slot.IsNative())) {
        ReportTagError(slot, TNative, "GetNative()", NULL);
        return NULL;
    }

    T_NativeValues::iterator it = NativeValues.find(slot.GetNativeValId());

    if (unlikely(it == NativeValues.end() || it->second == NULL)) {
        ReportError(InvalidArgument, "Unknown native value index: %d", slot.GetNativeValId());
        return NULL;
    }

    AbstractNativeValue *value = it->second;

    for(NativeValueTypeBase *type = value->type(); type != tag; type = type->parent()) {
        if (unlikely(!type || !fno)) {
            ReportError(InvalidArgument, "Trying to use native value of type %s as type %s",
                        value->type()->name(), tag->name());
            return NULL;
        }
    }

    return value;
}

/*
 * Implements the DeleteNative native, which can be used to immediately free and invalidate native value.
 */
bool ByteCodeRunner::DeleteNative(const StackSlot &slot)
{
    if (unlikely(!slot.IsNative())) {
        ReportTagError(slot, TNative, "DeleteNative()", NULL);
        return false;
    }

    T_NativeValues::iterator it = NativeValues.find(slot.GetNativeValId());

    if (it != NativeValues.end())
    {
        FlowNativeObject *obj = it->second->nativeObject();

        if (obj != NULL)
        {
            // FlowNativeObject instances can refuse to be deleted
            if (!obj->flowDestroyObject())
                return false;

            obj->flowFinalizeObject();
        }

        delete it->second;
        NativeValues.erase(it);
        NativeValueBudget++;
    }

    return true;
}

StackSlot ByteCodeRunner::AllocNativeFn(NativeFunction *fn, FlowPtr cp)
{
    if (fn->num_args() > MAX_NATIVE_ARGS)
    {
        // Trying to call this native will overrun a stack buffer.
        // Increase the constant and recompile if this becomes a problem.
        ReportError(UnknownNativeName, "Too many args for native \"%s\": %d", fn->name(), fn->num_args());
        return StackSlot::MakeVoid();
    }

    int id = Natives.size();
    Natives.push_back(fn);
    fn->debug_token_ = cp;

#ifdef FLOW_JIT
    if (JitProgram)
        JitProgram->RegisterNative(this, id, fn);
#endif

    return StackSlot::MakeNativeFn(id);
}

/*
 * Import native definitions from a flow-to-C++ compiled program.
 */
bool NativeProgram::InitFunctionTable(StackSlot *out, const FunctionSpec *in, unsigned count)
{
    for (unsigned i = 0; i < count; i++)
    {
        const FunctionSpec &spec = in[i];

        NativeFunction *native_fn = NULL;

        if (spec.native_name)
        {
            native_fn = owner->MakeNativeFunction(spec.native_name, spec.num_args, spec.code != NULL);

            if (unlikely(native_fn == NULL && spec.code == NULL)) {
                owner->ReportError(UnknownNativeName, "Unknown native: \"%s\"", spec.native_name);
                return false;
            }
        }

        if (native_fn == NULL)
            native_fn = new SimpleNative(spec.name, spec.num_args, spec.code);

        out[i] = owner->AllocNativeFn(native_fn, owner->LastInstructionPtr);
    }

    return true;
}

StackSlot ByteCodeRunner::AllocateNativeClosure(NativeClosurePtr ptr, const char *name, int num_args, void *data, int num_slots, ...)
{
    StackSlot *buf = new StackSlot[num_slots+1];
    StackSlot &base = buf[0];

    va_list vl;
    va_start(vl, num_slots);
    for (int i = 0; i < num_slots; ++i)
        buf[i+1] = va_arg(vl, StackSlot);
    va_end(vl);

    base = AllocNativeFn(new NativeClosure(name, num_args, ptr, data), NativeReturnInsn);
    assert(base.IsNativeFn() && !base.GetSign());

    LocalRootDefinition frame(this, num_slots+1, buf); (void)&frame;
    FlowPtr arr = AllocateClosureBuffer(base.slot_private.IntValue, num_slots, buf+1); // ALLOC

    delete[] buf;
    return StackSlot::InternalMakeNativeClosure(arr, num_slots);
}

StackSlot ByteCodeRunner::AllocateConstClosure(int num_args, StackSlot value) {
    if (unsigned(num_args) >= ConstClosureCache.size())
        ConstClosureCache.resize(num_args+1, StackSlot::MakeVoid());

    if (!ConstClosureCache[num_args].IsNativeFn())
        ConstClosureCache[num_args] = AllocNativeFn(new SimpleNative("$const$", num_args, const_closure), NativeReturnInsn);

    LocalRootDefinition frame(this, 1, &value); (void)&frame;

    return AllocateClosure(ConstClosureCache[num_args], 1, &value); // ALLOC
}

/*
 * Perform allocation of a big object, or when the fast heap runs out.
 */
FlowPtr ByteCodeRunner::AllocateInner(unsigned size) {
    if (unlikely(unsigned(size) >= MIN_HEAP_SIZE / 2)) {
        ReportError(InvalidArgument, "Allocation size too large: %d bytes.", size);
        return HeapEnd;
    }

    if (unsigned(size) > MAX_EPHEMERAL_ALLOC)
    {
        if (unsigned(size) > unsigned(hp_big_pos - hp_ref_end))
            ForceGC(size, true);

        FlowPtr nhp = FlowPtrAlignDown(hp_big_pos - size, 4);

        if (unlikely(nhp < hp_ref_end || nhp > hp_big_pos))
        {
            ReportError(HeapFull, "Cannot allocate big memory object: %d bytes.", size);
            return HeapEnd;
        }
        else {
            hp_big_pos = nhp;
    #ifdef FLOW_INSTRUCTION_PROFILING
            if (unlikely(ProfileMemStep))
            {
                ProfileMemBarrier += size;
                if (hp <= ProfileMemBarrier)
                    ProfileMemEvent(size, true);
            }
    #endif
            return hp_big_pos;
        }
    }

    if (gcStressTestEnabled)
        ForceGC(size, rand()%3==0);
    else
        ForceGC(size);

    FlowPtr nhp = FlowPtrAlignDown(hp - size, 4);
    if (unlikely(nhp < hpbound || nhp > hp)) {
        ReportError(HeapFull, "Cannot allocate memory: %d bytes.", size);
        return HeapEnd;
    }
    else {
        hp = nhp;
#ifdef FLOW_INSTRUCTION_PROFILING
        if (unlikely(hp <= ProfileMemBarrier))
            ProfileMemEvent(size);
#endif
        return hp;
    }
}

#ifdef FLOW_QT_BACKEND
StackSlot ByteCodeRunner::AllocateString(const QString &str) {
	return AllocateString(str.utf16(), str.length());
}
#endif

/*
 * Allocate an uninitialized string of the specified length, returning a pointer to the buffer.
 */
unicode_char *ByteCodeRunner::AllocateStringBuffer(StackSlot *out, unsigned length)
{
    assert(length > 0);

    FlowPtr buf;
    unsigned bytes = length*FLOW_CHAR_SIZE;

    if (length & 0xffff0000u)
    {
        FlowPtr str = Allocate(4 + 4 + bytes); //ALLOC
        buf = str + 8;
        Memory.SetInt32(str, length & 0xffff);
        Memory.SetFlowPtr(str+4, buf);

        StackSlot::InternalSetString(*out, str, length>>16, true);
    }
    else
    {
        buf = Allocate(bytes); // ALLOC

        StackSlot::InternalSetString(*out, buf, length, false);
    }

    return (unicode_char*)Memory.GetRawPointer(buf, bytes, true);
}

/*
 * Allocate a reference to a string of the given length.
 *
 * Returns a pointer to the location where the address of the string buffer must be stored.
 */
FlowPtr *ByteCodeRunner::AllocateStringRef(StackSlot *out, unsigned length)
{
    static FlowPtr dummy = MakeFlowPtr(0);

    if (length == 0)
    {
        *out = StackSlot::MakeEmptyString();
        return &dummy;
    }

    if (length & 0xffff0000u)
    {
        FlowPtr str = Allocate(4 + 4);

        Memory.SetInt32(str, length & 0xffff);
        StackSlot::InternalSetString(*out, str, length>>16, true);

        return (FlowPtr*)Memory.GetRawPointer(str+4, 4, true);
    }
    else
    {
        StackSlot::InternalSetString(*out, MakeFlowPtr(0), length, false);

        return &out->slot_private.PtrValue;
    }
}

StackSlot ByteCodeRunner::AllocateString(const unicode_char *str, int len) {
    if (len == 0)
        return StackSlot::MakeEmptyString();

    StackSlot out;
    unicode_char *tmp = AllocateStringBuffer(&out, len); // ALLOC

    if (str)
        memcpy(tmp, str, len * FLOW_CHAR_SIZE);

    return out;
}

StackSlot ByteCodeRunner::LoadFileAsString(std::string filename, bool temporary)
{
    StackSlot rv = StackSlot::MakeVoid();

#ifdef FLOW_MMAP_HEAP
    if (!temporary && MappedFiles.count(filename))
        return MappedFiles[filename];
#endif

    FILE *file = fopen(filename.c_str(), "rb");
    if (!file)
        return StackSlot::MakeVoid();

    fseek(file, 0, SEEK_END);
    size_t size = ftell(file);
    rewind(file);

    if (size == 0)
    {
        rv = StackSlot::MakeEmptyString();
    }
    else
    {
        size_t length = size/FLOW_CHAR_SIZE+size%FLOW_CHAR_SIZE;
        size_t bytes = length * FLOW_CHAR_SIZE;

#ifdef FLOW_MMAP_HEAP
        if (bytes >= MIN_MMAP_SIZE && MapStringPtr - bytes >= MapAreaBase)
        {
            FlowPtr map_ptr = FlowPtrAlignDown(MapStringPtr - bytes, Memory.PageSize());

            if (Memory.MapFile(map_ptr, bytes, filename))
            {
                MappedAreaInfo::Ptr area(new MappedAreaInfo(map_ptr, bytes));
                MappedAreas[map_ptr] = area;
                MapStringPtr = map_ptr;

                *AllocateStringRef(&rv, length) = map_ptr;

                if (!temporary)
                {
                    MappedFiles[filename] = rv;
                    area->filename = filename;
                }
            }
        }
#endif

        if (rv.IsVoid())
        {
            StackSlot out;
            unicode_char *p = AllocateStringBuffer(&out, length);

            if (fread(p, FLOW_CHAR_SIZE, length, file) == length)
                rv = out;
        }
    }

    fclose(file);
    if (temporary)
        remove(filename.c_str());
    return rv;
}

void ByteCodeRunner::InvalidateFileCache(std::string filename)
{
#ifdef FLOW_MMAP_HEAP
    MappedFiles.erase(filename);
#endif
}

StackSlot ByteCodeRunner::AllocateUninitializedArray(unsigned len)
{
    assert(len > 0);

    unsigned bytes = len * STACK_SLOT_SIZE;

    FlowPtr buf = Allocate(bytes + 4); // ALLOC

    if (unlikely(IsErrorReported()))
        return StackSlot::MakeEmptyArray();

    Memory.SetInt32(buf, len & 0xffffu);

    if (len & 0xffff0000u) {
        return StackSlot::InternalMakeArray(buf, len>>16, true);
    } else {
        return StackSlot::InternalMakeArray(buf, len, false);
    }
}

StackSlot ByteCodeRunner::AllocateRef(const StackSlot &value) {
    unsigned id = NextRefId++;

    FlowPtr buf = Allocate(STACK_SLOT_SIZE + 4); // ALLOC
    Memory.SetInt32(buf, id & 0xffffu);

    SetMemorySlot(buf+4, 0, value);

    StackSlot rv;
    if (id & 0xffff0000u) {
        rv = StackSlot::InternalMakeRefTo(buf, id>>16, true);
    } else {
        rv = StackSlot::InternalMakeRefTo(buf, id, false);
    }

    return rv;
}

StackSlot ByteCodeRunner::AllocateArray(int length, StackSlot *data) { // data must be immovable
    if (length <= 0)
        return StackSlot::MakeEmptyArray();

    StackSlot rv = AllocateUninitializedArray(length);
    StackSlot *buf = GetArrayWritePtr(rv, length);

    if (data)
        memcpy(buf, data, length * STACK_SLOT_SIZE);
    else
        memset(buf, -1, length * STACK_SLOT_SIZE);

    return rv;
}

StackSlot ByteCodeRunner::AllocateUninitializedClosure(unsigned short len, FlowPtr code)
{
    int bytes = len * STACK_SLOT_SIZE;
    FlowPtr buf = Allocate(bytes + 4 + 4) + 4; // ALLOC

    Memory.SetFlowPtr(buf-4, code);
    Memory.SetInt32(buf, len);

    return StackSlot::InternalMakeClosurePointer(buf, len);
}

FlowPtr ByteCodeRunner::AllocateClosureBuffer(int code, unsigned short len, StackSlot *data) {
    int bytes = len * STACK_SLOT_SIZE;
    FlowPtr buf = Allocate(bytes + 4 + 4) + 4; // ALLOC

    Memory.SetInt32(buf-4, code);
    Memory.SetInt32(buf, len);

    if (data)
        CopySlots(buf+4, data, len);
    else
        Memory.FillBytes(buf+4, -1, bytes);

    return buf;
}

StackSlot ByteCodeRunner::AllocateRawStruct(StructDef &def, bool clear)
{
#ifdef FLOW_COMPACT_STRUCTS
    if (def.FieldsCount == 0)
        return StackSlot::MakeStruct(def.EmptyPtr, def.StructId);

    assert(def.ByteSize >= 8);
    FlowPtr buf = Allocate(def.ByteSize);

    FlowStructHeader *ph = Memory.GetStructPointer(buf, true);
    ph->StructId = def.StructId;
    ph->GC_Tag = unlikely(buf >= hp_ref_base) ? NextGCTag : 0;

    if (clear)
        memset(ph->Bytes+4, 0, def.ByteSize-4);
#else
    if (def.FieldsCount == 0)
        return StackSlot::Make(TStruct, MakeFlowPtr(0), def.StructId);

    int bytes = def.FieldsCount * STACK_SLOT_SIZE;
    FlowPtr buf = Allocate(bytes);
    if (clear)
        Memory.FillBytes(buf, 0, bytes);
#endif

    return StackSlot::MakeStruct(buf, def.StructId);
}

#ifdef FLOW_COMPACT_STRUCTS
void ByteCodeRunner::StructSlotPack(const StackSlot &str, const StackSlot *src, int start, unsigned count)
{
    StructDef &def = StructDefs[str.GetStructId()];
    FlowStructHeader *ph = Memory.GetStructPointer(str.GetRawStructPtr(), true);

    for (unsigned int i = 0; i < count; i++)
    {
        const FlowStructFieldDef &fd = def.FieldDefs[start + i];

        if (unlikely(!fd.fn_set(ph->Bytes + fd.offset, src[i])))
        {
            ReportTagError(src[i], fd.tag, def.FieldNames[start+i].c_str(), "StructSlotPack");
            return;
        }
    }

    if (unlikely(ph->GC_Tag))
        RegisterWrite(ph, str.GetRawStructPtr());
}

void ByteCodeRunner::StructSlotUnpack(const StackSlot &str, StackSlot *tgt, int start, unsigned count)
{
    StructDef &def = StructDefs[str.GetStructId()];
    FlowStructHeader *ph = Memory.GetStructPointer(str.GetRawStructPtr(), false);

    for (unsigned int i = 0; i < count; i++)
    {
        const FlowStructFieldDef &fd = def.FieldDefs[start + i];
        tgt[i] = fd.fn_get(ph->Bytes + fd.offset, this);
    }
}
#endif

StackSlot ByteCodeRunner::AllocateStruct(const char *name, unsigned size)
{
    T_StructNameIds::iterator it = StructNameIds.find(std::string(name));

    if (unlikely(it == StructNameIds.end())) {
        ReportError(InvalidArgument, "Unknown structure name: '%s'", name);
        return StackSlot::MakeVoid();
    }

    int id = it->second;

    StructDef *def = &StructDefs.at(id);
    if (unlikely(unsigned(def->FieldsCount) != size)) {
        ReportError(InvalidArgument, "Structure '%s' actually has size %d, not %d", name, def->FieldsCount, size);
        return StackSlot::MakeVoid();
    }

    return AllocateRawStruct(*def);
}

StackSlot ByteCodeRunner::AllocateKnownStruct(const char *name, unsigned size, int id, StackSlot *data)
{
    if (unlikely(id < 0))
    {
        ReportError(InvalidArgument, "Undefined structure: '%s'", name);
        return StackSlot::MakeVoid();
    }

    StackSlot rv = AllocateRawStruct(StructDefs[id], data==NULL);
    if (data)
        StructSlotPack(rv, data, 0, size);
    return rv;
}

unicode_string ByteCodeRunner::GetString(const StackSlot &str)
{
    if (unlikely(!str.IsString())) {
        ReportTagError(str, TString, "GetString()", NULL);
        return unicode_string();
    }

    unsigned len;
    const void *data = GetStringPtrSize(str, &len);
    return unicode_string((unicode_char*)data, len);
}

#ifdef FLOW_QT_BACKEND
QString ByteCodeRunner::GetQString(const StackSlot &str)
{
    if (unlikely(!str.IsString())) {
        ReportTagError(str, TString, "GetQString()", NULL);
        return NULL;
    }

    unsigned len;
    const void *data = GetStringPtrSize(str, &len);
    return QString::fromUtf16((unicode_char*)data, len);
}
#endif

FlowPtr ByteCodeRunner::MoveStackToHeap(int num_slots, bool with_size)
{
    if (num_slots == 0)
        return MakeFlowPtr(0);

    if (unlikely(DataStack.size() < unsigned(num_slots))) {
        StackError(DatastackFull, false);
        return MakeFlowPtr(0);
    }

    int bytes = num_slots * STACK_SLOT_SIZE;

    FlowPtr ptr;
    if (with_size) {
        ptr = Allocate(bytes + 4) + 4; // ALLOC
        Memory.SetInt32(ptr-4, num_slots);
    } else {
        ptr = Allocate(bytes); // ALLOC
    }

    Memory.SetBytes(ptr, DataStack.pop_ptr(num_slots), bytes);
    if (ptr >= hp_big_pos)
        SlotWriteSet.addInterval(ptr, ptr + num_slots*STACK_SLOT_SIZE);
    return ptr;
}

void ByteCodeRunner::MoveStructToStack(StackSlot str, unsigned count)
{
    if (unlikely(MAX_DATA_STACK - DataStack.size() < unsigned(count))) {
        ReportError(DatastackFull, "Cannot push %d items to the data stack.", count);
        return;
    }

    StructSlotUnpack(str, DataStack.push_ptr(count), 0, count);
}

// Disassembly

bool ByteCodeRunner::Disassemble(std::map<FlowPtr,FlowInstruction> *pmap, FlowPtr start_position, unsigned size)
{
    FlowPtr old_pos = Code.GetPosition();
    Code.SetPosition(start_position);

    std::map<FlowPtr,FlowInstruction>::iterator it = pmap->begin();
#ifdef DEBUG_FLOW
    while (Code.GetPosition() - start_position < int(size) && !Code.Eof())
#else
    while (int(Code.GetPosition()) - int(start_position) < int(size) && !Code.Eof())
#endif
    {
        FlowPtr pos = Code.GetPosition();

        it = pmap->insert(it, std::make_pair(pos, FlowInstruction()));

        FlowInstruction &insn = it->second;

        bool ok = Code.ParseOpcode(&insn);

        if (!ok)
        {
            switch (insn.op)
            {
            case CBreakpoint:
                {
        #ifdef FLOW_DEBUGGER
                    std::map<FlowPtr,OpCode>::iterator it = BreakpointOpcodeBackup.find(pos);
                    if (it != BreakpointOpcodeBackup.end())
                    {
                        insn.op = it->second;
                        ok = Code.ParseOpcode(&insn, true);
                    }
        #endif
                    break;
                }

            case CCodeCoverageTrap:
                {
        #ifdef FLOW_INSTRUCTION_PROFILING
                    size_t offset = pos - CodeStartPtr();
                    if (ProfileCodeCoverage && offset < CoverageCodeBackup.size())
                    {
                        insn.op = (OpCode)CoverageCodeBackup[offset];
                        ok = Code.ParseOpcode(&insn, true);
                    }
        #endif
                    break;
                }

            default:
                break;
            }

            if (!ok)
            {
                pmap->erase(it);

                Code.SetPosition(old_pos);
                return false;
            }
        }
    }

    Code.SetPosition(old_pos);
    return true;
}

void ByteCodeRunner::Disassemble(ostream &flow_out, FlowPtr start_position, unsigned size)
{
    FlowInstruction::Map table;

    Disassemble(&table, start_position, size);

    for (FlowInstruction::Map::iterator it = table.begin(); it != table.end(); ++it)
        flow_out << stl_sprintf("   0x%08x:\t",FlowPtrToInt(it->first)) << it->second << endl;
}

void ByteCodeRunner::enableGCStressTest()
{
    gcStressTestEnabled = true;
}

// Error reporting
void ByteCodeRunner::DoReportError(RuntimeError code) {
    if (IsErrorReported()) return;

    stringstream info_str;
    info_str << "Error during last opcode [0x" << hex << FlowPtrToInt(LastInstructionPtr)
             << "]: " << dec << code << endl;

#ifdef FLOW_JIT
    if (!JitProgram)
#endif
        info_str << "Location: " << AddressToFunction(LastInstructionPtr) << endl;

    info_str << "DataStack.size() = " << DataStack.size()
             << ", CallStack.size() = " << CallStack.size()
             << "hp = " << hex << FlowPtrToInt(hp)
             << ", HeapStart = 0x" << FlowPtrToInt(HeapStart)
             << ", HeapEnd = 0x" << FlowPtrToInt(HeapEnd)
             << dec << endl;

#ifdef FLOW_JIT
    if (!JitProgram)
#endif
        Disassemble(info_str, LastInstructionPtr, 1);

#ifdef FLOW_DEBUGGER
    if (!DebuggerPtr)
#endif
    PrintCallStack(info_str, true);

    LastErrorInfo = info_str.str();
    flow_err << LastErrorDescr << endl << LastErrorInfo << endl;

#ifdef FLOW_DEBUGGER
    if (DebuggerPtr)
        DebuggerPtr->onError(code, LastInstructionPtr);
#endif

    if (code == DivideByZerro || code == InvalidArgument || code == InvalidFieldName)
        callFlowCrashHandlers(LastErrorDescr + "\n" + LastErrorInfo);

    LastError = code;

    NotifyHostEvent(NativeMethodHost::HostEventError);
}

void ByteCodeRunner::PrintDataStack() {
    flow_err << "Stack:\n";
	int n = DataStack.size()-10;
	for (int i = DataStack.size()-1; i >= n && i >= 0; i--) {
        PrintData(flow_err, DataStack[i]);
        flow_err << endl;
    }
}

void ByteCodeRunner::ReportError(RuntimeError code, const char *msg, ...) {
    if (IsErrorReported()) return;
    va_list vl;
    va_start(vl, msg);
    LastErrorDescr = stl_vsprintf(msg, vl);
    va_end(vl);
    DoReportError(code);
}

const char * tag2string(int tag) {
	switch (tag) {
	case TVoid: return "void";
	case TBool: return "bool";
	case TInt: return "int";
	case TDouble: return "double";
	case TString: return "string";
	case TArray: return "array";
	case TStruct: return "struct";
	case TCodePointer: return "codepointer";
	case TNativeFn: return "nativefn";
	case TRefTo: return "ref";
	case TNative: return "native";
	case TClosurePointer: return "closure";
    case TCapturedFrame: return "native/frame";
	}
	return "Unknown Tag";
}

void ByteCodeRunner::ReportTagError(const StackSlot &slot, DataTag expected, const char *varname, const char *msg, ...) {
    if (IsErrorReported()) return;
    LastErrorDescr = stl_sprintf("Invalid Tag: %s (%s expected, %s found)", varname, tag2string(expected), tag2string(slot.GetType()));
    if (msg != NULL) {
        va_list vl;
        va_start(vl, msg);
        LastErrorDescr += "\n" + stl_vsprintf(msg, vl);
        va_end(vl);
    }
    DoReportError(InvalidArgument);
}

void ByteCodeRunner::ReportStructError(const StackSlot &slot, int expected_id, const char *varname, const char *msg, ...) {
    if (IsErrorReported()) return;
    if (!slot.IsStruct())
        LastErrorDescr = stl_sprintf("Invalid Tag: %s (struct expected, %s found)", varname, tag2string(slot.GetType()));
    else
    {
        StructDef *edef = safeVectorPtrAt(StructDefs, expected_id);
        StructDef *rdef = safeVectorPtrAt(StructDefs, slot.GetStructId());

        LastErrorDescr = stl_sprintf(
            "Invalid struct: %s (%s expected, %s (%d) found)",
            varname,
            edef?edef->Name.c_str():"?",
            rdef?rdef->Name.c_str():"?",
            slot.GetStructId()
        );
    }
    if (msg != NULL) {
        va_list vl;
        va_start(vl, msg);
        LastErrorDescr += "\n" + stl_vsprintf(msg, vl);
        va_end(vl);
    }
    DoReportError(InvalidArgument);
}

// Instruction interpreter

// Define on-stack arg references; only valid if the
// memory buffer is guaranteed not to be reallocated.
#define RUNNER_RefArgs1(arg0) \
    const StackSlot &arg0 = GetStackSlotRef(0);
#define RUNNER_RefArgs2(arg1, arg0) \
    const StackSlot &arg1 = GetStackSlotRef(1); \
    const StackSlot &arg0 = GetStackSlotRef(0);

// Like above, but the first argument is made writable
#define RUNNER_RefArgsRet1(rv_arg0) \
    StackSlot &rv_arg0 = *GetStackSlotPtr(0);
#define RUNNER_RefArgsRet2(rv_arg1, arg0) \
    StackSlot &rv_arg1 = *GetStackSlotPtr(1); \
    const StackSlot &arg0 = GetStackSlotRef(0);

#define RUNNER_CheckTag(tag, slot) \
    if (unlikely(!slot.Is##tag())) { \
        ReportTagError(slot, tag, #slot, NULL); \
        return; \
    }

#define RUNNER_CheckTag2(tag, slot1, slot2) \
    RUNNER_CheckTag(tag, slot1) \
    RUNNER_CheckTag(tag, slot2)


inline void ByteCodeRunner::DoReturn(bool closure)
{
    CallFrame *frame = CallStackPop();
    if (unlikely(!frame))
        return;

#ifdef FLOW_DEBUGGER
    if (unlikely(frame->is_closure != closure))
    {
        ReportError(StackCorruption, "Wrong return type for the frame: %d", closure);
        return;
    }
#endif

    // Copy the result to the right place
    DataStack[FramePointer] = DataStack.top();
    DataStack.resize(FramePointer+1);

    Code.SetPosition(LastInstructionPtr = frame->last_pc);
    FramePointer = frame->last_frame;
    closurepointer = frame->last_closure;

#ifdef FLOW_DEBUGGER
    ImpersonateInsn = frame->impersonate_pc;

    if (unlikely(DbgReturnTrap))
    {
        if (DebuggerPtr)
            DebuggerPtr->onReturnTrap(Code.GetPosition());
    }
#endif
}

void ByteCodeRunner::DoPlus(StackSlot &val1, const StackSlot &val2)
{
    if (val1.IsInt() && val2.IsInt())
        val1.SetIntValue(val1.GetInt() + val2.GetInt());
    else if (val1.IsDouble() && val2.IsDouble())
        val1.SetDoubleValue(val1.GetDouble() + val2.GetDouble());
    else if (val1.IsString() && val2.IsString())
        DoPlusString(val1, val2);
    else
        ReportError(InvalidArgument, "Error in arguments types in CPlus: %s + %s",
                    tag2string(val1.GetType()), tag2string(val2.GetType()));
}

void ByteCodeRunner::DoPlusString(ByteCodeRunner *self, StackSlot &val1, const StackSlot &val2)
{
    if (val2.IsEmpty())
        return;

    if (val1.IsEmpty())
    {
        val1 = val2;
        return;
    }

    int l1 = self->GetStringSize(val1);
    int l2 = self->GetStringSize(val2);

    if (self->GetStringAddr(val1) + l1 * FLOW_CHAR_SIZE == self->GetStringAddr(val2))
    {
        // Merge the strings in-place
        StackSlot rv;
        FlowPtr *rp = self->AllocateStringRef(&rv, l1 + l2); // ALLOC

        *rp = self->GetStringAddr(val1);
        val1 = rv;
    }
    else
    {
        StackSlot rv;
        unicode_char *ptr = self->AllocateStringBuffer(&rv, l1 + l2); // ALLOC

        {
            // Assume val1 & val2 don't move, since gc
            // doesn't reallocate the stack anymore
            memcpy(ptr,    self->GetStringPtr(val1), l1 * FLOW_CHAR_SIZE);
            memcpy(ptr+l1, self->GetStringPtr(val2), l2 * FLOW_CHAR_SIZE);
            val1 = rv;
        }
    }
}

void ByteCodeRunner::DoMinus(StackSlot &val1, const StackSlot &val2) {
    if (val1.IsInt() && val2.IsInt())
        val1.SetIntValue(val1.GetInt() - val2.GetInt());
    else if (val1.IsDouble() && val2.IsDouble())
        val1.SetDoubleValue(val1.GetDouble() - val2.GetDouble());
    else
        ReportError(InvalidArgument, "Error in arguments types in CMinus: %s - %s",
                    tag2string(val1.GetType()), tag2string(val2.GetType()));
}

void ByteCodeRunner::DoMultiply(StackSlot &val1, const StackSlot &val2) {
    if (val1.IsInt() && val2.IsInt())
        val1.SetIntValue(val1.GetInt() * val2.GetInt());
    else if (val1.IsDouble() && val2.IsDouble())
        val1.SetDoubleValue(val1.GetDouble() * val2.GetDouble());
    else
        ReportError(InvalidArgument, "Error in arguments types in CMultiply: %s + %s",
                    tag2string(val1.GetType()), tag2string(val2.GetType()));
}

void ByteCodeRunner::DoDivide(StackSlot &val1, const StackSlot &val2) {
    // TODO: division by zero
    if (val1.IsInt() && val2.IsInt())
        val1.SetIntValue(val1.GetInt() / val2.GetInt());
    else if (val1.IsDouble() && val2.IsDouble())
        val1.SetDoubleValue(val1.GetDouble() / val2.GetDouble());
    else
        ReportError(InvalidArgument, "Error in arguments types in CDivide: %s + %s",
                    tag2string(val1.GetType()), tag2string(val2.GetType()));
}

void ByteCodeRunner::DoModulo(StackSlot &val1, const StackSlot &val2) {
    // TODO: division by zero
    if (val1.IsInt() && val2.IsInt())
        val1.SetIntValue(val1.GetInt() % val2.GetInt());
    else if (val1.IsDouble() && val2.IsDouble())
        val1.SetDoubleValue(fmod(val1.GetDouble(), val2.GetDouble()));
    else
        ReportError(InvalidArgument, "Error in arguments types in CModulo");
}

inline void ByteCodeRunner::DoNegate(StackSlot &val) {
    if (val.IsInt())
        val.SetIntValue(-val.GetInt());
    else if (val.IsDouble())
        val.SetDoubleValue(-val.GetDouble());
    else
        ReportError(InvalidArgument, "Error in arguments types in CNegative");
}

inline void ByteCodeRunner::DoEqual() {
    RUNNER_RefArgsRet2(val1, val2);
    int c = Compare(val1, val2);
    StackSlot::SetBool(val1, (c == 0) ? 1 : 0);
    DiscardStackSlots(1);
}

inline void ByteCodeRunner::DoLessThan() {
    RUNNER_RefArgsRet2(val1, val2);
    int c = Compare(val1, val2);
    StackSlot::SetBool(val1, (c < 0) ? 1 : 0);
    DiscardStackSlots(1);
}

inline void ByteCodeRunner::DoLessEqual() {
    RUNNER_RefArgsRet2(val1, val2);
    int c = Compare(val1, val2);
    StackSlot::SetBool(val1, (c <= 0) ? 1 : 0);
    DiscardStackSlots(1);
}

inline void ByteCodeRunner::DoNot() {
    RUNNER_RefArgsRet1(flag);
    RUNNER_CheckTag(TBool, flag);
    flag.SetBoolValue(!flag.GetBool());
}

inline void ByteCodeRunner::DoArrayGet() {
    RUNNER_RefArgsRet2(array, index);
    RUNNER_CheckTag(TArray, array);
    RUNNER_CheckTag(TInt, index);
    int len = GetArraySize(array);
    if (unlikely(index.GetInt() < 0 || index.GetInt() >= len)) {
        PrintDataStack();
        ReportError(InvalidArgument, "Array index out of bounds: %d", index.GetInt());
    }
    array = GetArraySlot(array, index.GetInt());
    DiscardStackSlots(1);
}

inline void ByteCodeRunner::DoRefTo() {
    RUNNER_RefArgsRet1(ref);
    ref = AllocateRef(ref); // ALLOC
}

inline void ByteCodeRunner::DoDeref() {
    RUNNER_RefArgsRet1(ref);
    RUNNER_CheckTag(TRefTo, ref);
    ref = Memory.GetStackSlot(ref.GetRawRefPtr());
}

/*
 * Register updates to old generation objects for fast GC.
 */
void ByteCodeRunner::RegisterWrite(FlowPtr slot, unsigned count) {
    if (slot >= hp_big_pos)
        SlotWriteSet.addInterval(slot, slot + count*STACK_SLOT_SIZE);
}

void ByteCodeRunner::RegisterWrite(FlowPtr slot) {
    if (slot >= hp_ref_base && slot < hp_ref_end)
        RefWriteMask[(slot-hp_ref_base)/(sizeof(FlowHeapRef)*REF_MASK_STEP)] = true;
    else if (slot >= hp_big_pos)
        SlotWriteSet.addInterval(slot, slot+STACK_SLOT_SIZE);
}

#ifdef FLOW_COMPACT_STRUCTS
void ByteCodeRunner::RegisterWrite(FlowStructHeader *ptr, FlowPtr base) {
    if (ptr->GC_Tag != 0)
    {
        ptr->GC_Tag = 0;
        if (base >= hp_ref_base && StructDefs[ptr->StructId].GCFieldCount > 0)
            StructWriteSet.push_back(base);
    }
}
#endif

inline void ByteCodeRunner::DoSetRef() {
    RUNNER_RefArgsRet2(ref, value);
    RUNNER_CheckTag(TRefTo, ref);
    RegisterWrite(ref.GetRawRefPtr());
    Memory.SetStackSlot(ref.GetRawRefPtr(), value);
    DiscardStackSlots(1);
    StackSlot::SetVoid(ref);
}

inline void ByteCodeRunner::DoInt2Double() {
    RUNNER_RefArgsRet1(value);
    RUNNER_CheckTag(TInt, value);
    StackSlot::SetDouble(value, FlowDouble(value.GetInt()));
}

StackSlot ByteCodeRunner::DoInt2String(ByteCodeRunner *self, const StackSlot &value) {
    if (unlikely(!value.IsInt())) {
        self->ReportTagError(value, TInt, "value", NULL);
        return StackSlot::MakeVoid();
    }

    char buf[40] = {0};
    snprintf(buf, sizeof(buf), "%d", value.GetInt());
    return self->AllocateString(buf); // ALLOC
}

inline void ByteCodeRunner::DoDouble2Int() {
    RUNNER_RefArgsRet1(value);
    RUNNER_CheckTag(TDouble, value);
    StackSlot::SetInt(value, int(value.GetDouble()));
}

static std::string double2string(double val, bool force_pt) {
    stringstream ss;
    ss.precision(15);
    ss << val;

    std::string rv = ss.str();
    if (force_pt && rv.find('.') == std::string::npos && rv.find('e') == std::string::npos)
        rv += ".0";
    return rv;
}

StackSlot ByteCodeRunner::DoDouble2String(ByteCodeRunner *self, const StackSlot &value) {
    double aval;

    if (likely(value.IsDouble())) {
        aval = value.GetDouble();
    } else if (value.IsInt()) {
        // Hack: be more robust
        aval = value.GetInt();
    } else {
        aval = 0.0;
        self->ReportTagError(value, TDouble, "value", NULL);
    }

    return self->AllocateString(parseUtf8(double2string(aval, false))); // ALLOC
}

inline void ByteCodeRunner::DoField(int i) {
    RUNNER_RefArgsRet1(struct_ref);
    RUNNER_CheckTag(TStruct, struct_ref);

    int size = GetStructSize(struct_ref);
    if (likely(i >= 0 && i < size))
        struct_ref = GetStructSlot(struct_ref, i);
    else
        ReportError(InvalidArgument, "Field index out of bounds: %d (size %d)", i, size);
}

inline void ByteCodeRunner::DoSetMutable(int i) {
    RUNNER_RefArgsRet2(struct_ref, val_ref);
    RUNNER_CheckTag(TStruct, struct_ref);

    int size = GetStructSize(struct_ref);
    if (likely(i >= 0 && i < size))
    {
        StructDef &def = StructDefs[struct_ref.GetStructId()];

        if (likely(def.IsMutable[i]))
            SetStructSlot(struct_ref, i, val_ref);
        else
            ReportError(InvalidArgument, "Field %d is not mutable in %s", i, def.Name.c_str());
    }
    else
        ReportError(InvalidArgument, "Field index out of bounds: %d (size %d)", i, size);

    DiscardStackSlots(1);
    StackSlot::SetVoid(struct_ref);
}

/*
 * Optimization of struct field access by field name by generating lookup tables
 * for each used name. The lookup table index is stored in unnecessary bytes
 * within the instruction.
 */

int StructDef::findField(const char *name, int length)
{
    for (int i = 0; i < FieldsCount; ++i)
    {
        if (strncmp(FieldNames[i].c_str(), name, length) == 0)
            return i;
    }

    return -1;
}

int ByteCodeRunner::LookupFieldName(const StackSlot &struct_ref, char const * n, int length, short *idx, StructDef **pdef)
{
    StructDef *def = safeVectorPtrAt(StructDefs, struct_ref.GetStructId());

    if (unlikely(def == NULL || def->Name.empty())) {
        ReportError(UnknownStructDefId, "Unknown struct kind: %d", struct_ref.GetStructId());
        return -1;
    }

    *pdef = def;

    int field_id;

    if (idx)
    {
        int id = *idx;

        // Initially the bytes are zero, so look up or allocate an id for this field name
        if (id == 0)
        {
            std::string name(n, length);
            id = safeMapAt(FieldRefIds, name, 0);

            if (id == 0)
            {
                FieldRefNames.push_back(name);
                FieldRefIds[name] = id = FieldRefNames.size();
            }

            *idx = (short)id;
        }

        if (id < 0)
            return -2;
        else if (def->FieldsCount == 0)
            field_id = -1;
        else
        {
            // Initialize lookup table for this struct definition if necessary
            if (def->FieldIds.size() < unsigned(id))
            {
                def->FieldIds.resize(FieldRefNames.size(), -1);

                for (size_t i = 0; i < def->FieldNames.size(); i++)
                {
                    int idx = safeMapAt(FieldRefIds, def->FieldNames[i], 0);
                    if (idx > 0)
                        def->FieldIds[idx-1] = i;
                }
            }

            field_id = def->FieldIds[id-1];
        }
    }
    else
    {
        if (strncmp(n, "structname", length) == 0)
            return -2;
        else
            field_id = def->findField(n, length);
    }

    if (field_id < 0)
        ReportFieldNameError(struct_ref, std::string(n, length).c_str(), "CFieldName");

    return field_id;
}

void ByteCodeRunner::DoFieldName(char const *n, int length, short *idx) {
    RUNNER_RefArgsRet1(struct_ref);
    RUNNER_CheckTag(TStruct, struct_ref);

    StructDef *def = NULL;
    int field_id = LookupFieldName(struct_ref, n, length, idx, &def);

    if (field_id == -2) {
        // structname
        DiscardStackSlots(1);
        Push(def->NameU); // ALLOC
    } else if (likely(field_id >= 0)) {
        struct_ref = GetStructSlot(struct_ref, field_id);
    }
}

void ByteCodeRunner::DoSetMutableName(char const *n, int length, short *idx) {
    RUNNER_RefArgsRet2(struct_ref, val_ref);
    RUNNER_CheckTag(TStruct, struct_ref);

    StructDef *def = NULL;
    int field_id = LookupFieldName(struct_ref, n, length, idx, &def);

    if (field_id == -2)
        ReportError(InvalidArgument, "Cannot set structname");
    else if (likely(field_id >= 0))
    {
        if (likely(def->IsMutable[field_id]))
            SetStructSlot(struct_ref, field_id, val_ref);
        else
            ReportError(InvalidArgument, "Field %s is not mutable in %s", n, def->Name.c_str());
    }

    DiscardStackSlots(1);
    StackSlot::SetVoid(struct_ref);
}

void ByteCodeRunner::ReportFieldNameError(const StackSlot &struct_ref, const char *fname, const char *where)
{
    StructDef *def = safeVectorPtrAt(StructDefs, struct_ref.GetStructId());

    if (unlikely(def == NULL || def->Name.empty())) {
        ReportError(UnknownStructDefId, "Unknown struct kind: %d", struct_ref.GetStructId());
        return;
    }

    ReportError(InvalidFieldName, "Invalid field name \"%s\" for struct '%s' at [%08Xh] in %s",
                fname, def->Name.c_str(), FlowPtrToInt(struct_ref.GetRawStructPtr()), where);
}

ByteCodeRunner::CallFrame *ByteCodeRunner::CallStackPush(FlowPtr addr)
{
    if (likely(CallStack.size() < MAX_CALL_STACK))
    {
        CallFrame *pf = CallStack.push_ptr();
        pf->last_pc = addr;
        pf->last_frame = FramePointer;
        pf->last_closure = closurepointer;
#ifdef FLOW_DEBUGGER
        pf->impersonate_pc = ImpersonateInsn;
        pf->is_closure = false;
#endif
        return pf;
    }
    else
    {
        StackError(CallstackFull);
        return NULL;
    }
}

ByteCodeRunner::CallFrame *ByteCodeRunner::CallStackPop()
{
    if (likely(!CallStack.empty())) {
        return CallStack.pop_ptr();
    } else {
        StackError(CallstackFull, false);
        return NULL;
    }
}

void ByteCodeRunner::DoNativeCall(const StackSlot &arg_in)
{
    // Array for the native arguments. A static buffer
    // used to avoid malloc overhead on every call.
    StackSlot arg_buffer[1 + MAX_NATIVE_ARGS];

    // Stash the function reference
    StackSlot &arg = arg_buffer[0];
    arg = arg_in;

    // Lookup the native function
    NativeFunction *fn = lookupNativeFn(GetNativeFnId(arg));
    if (unlikely(fn == NULL)) {
        ReportError(InvalidNativeId, "Invalid native %d", GetNativeFnId(arg));
        return;
    }

    int num_args = fn->num_args();
#ifdef DEBUG_FLOW
    const char *name = fn->name();
#endif

    // Move the arguments to the buffer above
    if (unlikely((unsigned)num_args > DataStack.size()))
    {
        StackError(DatastackFull, false);
        return;
    }

    if (NativeCallDepth >= MAX_NATIVE_CALLS)
    {
        StackError(CallstackFull, true);
        return;
    }

    FramePointer -= num_args;
    memcpy(arg_buffer+1, DataStack.pop_ptr(num_args), sizeof(StackSlot)*num_args);

    // Register a local root for the arg buffer (and the function reference)
    LocalRootDefinition arg_buffer_root(this, num_args+1, arg_buffer);
    (void)&arg_buffer_root;

    // Tag for debugging:
    CallFrame *tag_frame = CallStackPush(fn->debug_token_);
    if (unlikely(!tag_frame))
        return;

    LastInstructionPtr = NativeReturnInsn;

#ifdef DEBUG_FLOW
    // Save stack positions for control
    unsigned sp_save = DataStack.size();
    unsigned cp_save = CallStack.size();
#endif

    NativeCallDepth++;

    // Invoke the function
    StackSlot retval = (CurNativeFn = fn)->func_(this, arg_buffer+1); // ALLOC

    NativeCallDepth--;

    if (unlikely(IsErrorReported()))
        return;

#ifdef FLOW_TIME_PROFILING
    if (unlikely(ProfileTimeCount))
        ProfileTimeEvent();
#endif

#ifdef DEBUG_FLOW
    // Verify stack discipline
    if (unlikely(cp_save != CallStack.size())) {
        int delta = (CallStack.size() - cp_save);
        ReportError(StackCorruption, "Call stack position changed in call to %s: added %d slots.",
                    name, delta);
        CallStack.resize(cp_save);
    }

    if (unlikely(sp_save != DataStack.size())) {
        int delta = (DataStack.size() - sp_save);
        // Note: forgetting to return a value is reported as using 1 additional argument.
        ReportError(StackCorruption, "Native function %s expected to use %d args; actually used %d.",
                    name, num_args, num_args-delta);
        DataStack.resize(sp_save);
    }
#endif

    // Push the return value
    DataStack.push_back(retval);

    // Return immediately
    CallFrame *frame = CallStack.pop_ptr(2);
    Code.SetPosition(frame->last_pc);
    FramePointer = frame->last_frame;

#ifdef FLOW_DEBUGGER
    ImpersonateInsn = frame->impersonate_pc;

    if (unlikely(DbgReturnTrap))
    {
        if (DebuggerPtr)
            DebuggerPtr->onReturnTrap(Code.GetPosition());
    }
#endif
}

inline void ByteCodeRunner::DoCall()
{
#ifdef FLOW_DEBUGGER
    if (unlikely(DbgCallTrap))
    {
        if (DebuggerPtr)
            DebuggerPtr->onCallTrap(LastInstructionPtr, false);
    }
#endif

    RUNNER_RefArgs1(arg);

    CallFrame *frame = CallStackPush(Code.GetPosition());
    if (unlikely(!frame))
        return;

    DiscardStackSlots(1);
    FramePointer = DataStack.size();
#ifdef FLOW_DEBUGGER
    ImpersonateInsn = MakeFlowPtr(0);
#endif

    // None of these allocate except native:
    switch (arg.slot_private.Tag)
    {
    case (StackSlot::TAG_FLOWCODE):
        Code.SetPosition(LastInstructionPtr = arg.GetCodePtr());
        break;
    case (StackSlot::TAG_FLOWCODE|StackSlot::TAG_SIGN):
#ifdef FLOW_DEBUGGER
        frame->is_closure = true;
#endif
        closurepointer = arg.GetClosureDataPtr();
        Code.SetPosition(LastInstructionPtr = Memory.GetFlowPtr(closurepointer-8));
        break;
    case (StackSlot::TAG_NATIVEFN):
    case (StackSlot::TAG_NATIVEFN|StackSlot::TAG_SIGN):
        DoNativeCall(arg);
        break;
    default:
        // Undo stack changes:
        CallStackPop();
        DataStack.push_ptr(1);
        ReportError(InvalidCall, "Not callable tag: %02x", arg.GetType());
    }
}

inline bool ByteCodeRunner::DoTailCall(int locals)
{
    // Peek without popping the closure type
    StackSlot &arg = DataStack.top();

    if (arg.IsCodePointer())
    {
        // This is our guy! We can do tail calls of this stuff
#ifdef FLOW_DEBUGGER
        if (unlikely(DbgCallTrap))
        {
            if (DebuggerPtr)
                DebuggerPtr->onCallTrap(LastInstructionPtr, true);
        }

        if (unlikely(CallStack.top().is_closure))
        {
            ReportError(StackCorruption, "Tail call inside closure.");
            return true;
        }

        ImpersonateInsn = MakeFlowPtr(0);
#endif

        // Get rid of the code address
        FlowPtr code_addr = arg.GetCodePtr();
        DiscardStackSlots(1);

        // OK, move the arguments down to the previous frame, which we are going to reuse
        memmove(&DataStack[FramePointer], &DataStack[DataStack.size()-locals], locals * STACK_SLOT_SIZE);

        // Fix the frame up so that Treservelocals in the function itself will make this the reuse
        FramePointer += locals;
        DataStack.resize(FramePointer);

        // And then go!
        Code.SetPosition(code_addr);

        return true;
    } else {
        return false;
    }
}

void ByteCodeRunner::PushDataStackSlot(int offset)
{
    unsigned size = DataStack.size();

    if (likely(size < MAX_DATA_STACK && unsigned(offset) < size))
    {
        // Must do in two phases in case the stack buffer is reallocated
        StackSlot *dest = DataStack.push_ptr();
        *dest = DataStack[offset];
    }
    else
    {
        if (unsigned(offset) >= size)
            ReportError(InvalidArgument, "Trying to push an invalid data stack index: %d", offset);
        else
            StackError(DatastackFull);
    }
}

#if !COMPILED

FlowPtr ByteCodeRunner::getLastCodeAddress() {
    return Code.GetLastAddr();
}

void ByteCodeRunner::run()
{
    /* NOTE: Instruction implementations in this function
             use some low-level optimizations that may be
             invalidated by Allocate. Therefore, all lines
             that may result in it being called must be
             commented as // ALLOC

             Namely, the code assumes that between potential
             allocation (and therefore gc) sites, it can do
             whatever it pleases with pointers to flow memory.
             This obviously requires precise understanding
             of the location of said sites. For example, see
             the implementation of CPlus for strings.
    */

    while (likely(LastError == NoError))
    {
        FlowPtr cur_insn = Code.GetPosition();

        if (likely(cur_insn < Code.GetLastAddr()))
            LastInstructionPtr = cur_insn;
        else
        {
            ReportError(InvalidCall, "Invalid instruction address: %08x", FlowPtrToInt(cur_insn));
            return;
        }

#if defined(FLOW_INSTRUCTION_PROFILING) || defined(FLOW_DEBUGGER)
#ifdef FLOW_INSTRUCTION_PROFILING
        if (unlikely(++InstructionCount == ProfileICBarrier))
#else
        if (unlikely(DbgInsnTrap))
#endif
            ProfileICEvent(false);
#endif

        OpCode opcode = (OpCode) Code.ReadByte();

#else
void ByteCodeRunner::runOpcode(OpCode opcode) {
#endif
    reparse_breakpoint:
        switch (opcode)
        {
        case CTailCall:
            if (!DoTailCall(Code.ReadInt31_16())) {
            	DoCall();
            }
            break;
        case CCall:
            DoCall(); // CALL->ALLOC
            break;
        case CLast:
            return;
        case CUncaughtSwitch:
            ReportError(UncaughtSwitch, "Unexpected case in switch.");
            break;
        case CVoid:
            PushVoid();
            break;
        case CBool:
            Push(StackSlot::MakeBool(Code.ReadByte()));
            break;
        case CInt:
            Push(StackSlot::MakeInt(Code.ReadInt32()));
            break;
        case CDouble:
            PushDouble(Code.ReadDouble());
            break;
        case CString:
            {
                /*int len = Code.ReadInt31();
                FlowPtr ptr = len ? Code.GetPosition() : MakeFlowPtr(0);
                Push(StackSlot::Make(TString, ptr, len));
                // Skip string
                Code.SetPosition(Code.GetPosition() + len);*/
                /*unicode_string sv = ReadWideString();
                if (sv.empty())
                    Push(StackSlot::Make(TString, MakeFlowPtr(0), 0));
                else
                    Push(sv);*/
                int len = Code.ReadInt31();
                if (len)
                {
                    Push( parseUtf8( Code.ReadString(len) ) );
                }
                else
                {
                    Push(StackSlot::MakeEmptyString());
                }
                break;
            }
        case CWString:
            {
                int len = Code.ReadByte();
                if (len)
                {
                    StackSlot str;
                    *AllocateStringRef(&str, len) = Code.GetPosition();
                    Push(str);
                    Code.SetPosition(Code.GetPosition() + len * 2); // Skip string
                }
                else
                {
                    Push(StackSlot::MakeEmptyString());
                }
                break;
            }
        case CArray:
            {
                int len = Code.ReadInt31_16();
                if (len)
                {
                    if (unlikely(DataStack.size() < unsigned(len))) {
                        StackError(DatastackFull, false);
                        break;
                    }

                    StackSlot arr = AllocateUninitializedArray(len); // ALLOC
                    memcpy(GetArrayWritePtr(arr, len), DataStack.pop_ptr(len), len * STACK_SLOT_SIZE);
                    Push(arr);
                }
                else
                {
                    Push(StackSlot::MakeEmptyArray());
                }
                break;
            }
        case CStruct:
            {
                int id = Code.ReadInt31_16();
                StructDef *def = safeVectorPtrAt(StructDefs, id);
                if (unlikely(def == NULL || def->Name.empty())) {
                    ReportError(UnknownStructDefId, "Unknown struct kind: %d", id);
                    break;
                }
                // Now make an array out of all of this
                StackSlot rv = AllocateRawStruct(*def, false);
                StructSlotPack(rv, DataStack.pop_ptr(def->FieldsCount), 0, def->FieldsCount);
                Push(rv);
                break;
            }
        case CArrayGet:
            {
                DoArrayGet();
                break;
            }
        case CGoto:
            {
                int offset = Code.ReadInt31(); // TO DO error
                Code.SetPosition(Code.GetPosition() + offset);
                break;
            }
        case CCodePointer:
            {
                int offset = Code.ReadInt31();
                Push(StackSlot::MakeCodePointer(Code.GetPosition() + offset));
                break;
            }
        case CReturn:
            {
                DoReturn(false); // RETURN
                break;
            }
        case CClosureReturn:
            {
                DoReturn(true); // RETURN
                break;
            }
        case CNativeFn:
            {
                // Push a native pointer to code here on the stack
                int args = Code.ReadInt31();
                std::string fn = Code.ReadString();

                NativeFunction *native_fn = MakeNativeFunction(fn.c_str(), args, false);

                if (unlikely(native_fn == NULL)) {
                    ReportError(UnknownNativeName, "Unknown native: \"%s\"", fn.c_str());
                    break;
                }

                Push(AllocNativeFn(native_fn, LastInstructionPtr));
                break;
            }
        case COptionalNativeFn:
            {
                RUNNER_RefArgsRet1(curval);
                int args = Code.ReadInt31();
                std::string fn = Code.ReadString();

                NativeFunction *native_fn = MakeNativeFunction(fn.c_str(), args, true);
                if (native_fn)
                    curval = AllocNativeFn(native_fn, LastInstructionPtr);
                break;
            }
        case CSetLocal:
            {
                int slot = Code.ReadInt31_16();
                DataStack[FramePointer + slot] = DataStack.top();
                DiscardStackSlots(1);
                break;
            }
        case CPlus:
            {
                RUNNER_RefArgsRet2(val1, val2);
                DoPlus(val1, val2);
                DiscardStackSlots(1);
                break;
            }
        case CPlusInt:
            {
                RUNNER_RefArgsRet2(val1, val2);
                RUNNER_CheckTag2(TInt, val1, val2);
                val1.SetIntValue(val1.GetInt() + val2.GetInt());
                DiscardStackSlots(1);
                break;
            }
        case CPlusString:
            {
                RUNNER_RefArgsRet2(val1, val2);
                RUNNER_CheckTag2(TString, val1, val2);
                DoPlusString(val1, val2);
                DiscardStackSlots(1);
                break;
            }
        case CMinus:
            {
                RUNNER_RefArgsRet2(val1, val2);
                DoMinus(val1, val2);
                DiscardStackSlots(1);
                break;
            }
        case CMinusInt:
            {
                RUNNER_RefArgsRet2(val1, val2);
                RUNNER_CheckTag2(TInt, val1, val2);
                val1.SetIntValue(val1.GetInt() - val2.GetInt());
                DiscardStackSlots(1);
                break;
            }
        case CMultiply:
            {
                RUNNER_RefArgsRet2(val1, val2);
                DoMultiply(val1, val2);
                DiscardStackSlots(1);
                break;
            }
        case CMultiplyInt:
            {
                RUNNER_RefArgsRet2(val1, val2);
                RUNNER_CheckTag2(TInt, val1, val2);
                val1.SetIntValue(val1.GetInt() * val2.GetInt());
                DiscardStackSlots(1);
                break;
            }
        case CDivide:
            {
                RUNNER_RefArgsRet2(val1, val2);
                DoDivide(val1, val2);
                DiscardStackSlots(1);
                break;
            }
        case CDivideInt:
            {
                RUNNER_RefArgsRet2(val1, val2);
                RUNNER_CheckTag2(TInt, val1, val2);
                if (unlikely(val2.GetInt() == 0)) {
                    ReportError(InvalidArgument, "Integer division by zero.");
                    return;
                }
                val1.SetIntValue(val1.GetInt() / val2.GetInt());
                DiscardStackSlots(1);
                break;
            }
        case CModulo:
            {
                RUNNER_RefArgsRet2(val1, val2);
                DoModulo(val1, val2);
                DiscardStackSlots(1);
                break;
            }
        case CModuloInt:
            {
                RUNNER_RefArgsRet2(val1, val2);
                RUNNER_CheckTag2(TInt, val1, val2);
                if (unlikely(val2.GetInt() == 0)) {
                    ReportError(InvalidArgument, "Integer division by zero in CModuloInt.");
                    return;
                }
                val1.SetIntValue(val1.GetInt() % val2.GetInt());
                DiscardStackSlots(1);
                break;
            }
        case CNegate:
            {
                RUNNER_RefArgsRet1(val);
                DoNegate(val);
                break;
            }
        case CNegateInt:
            {
                RUNNER_RefArgsRet1(val1);
                RUNNER_CheckTag(TInt, val1);
                val1.SetIntValue(-val1.GetInt());
                break;
            }
        case CEqual:
            {
                DoEqual();
                break;
            }
        case CLessThan:
            {
                DoLessThan();
                break;
            }
        case CLessEqual:
            {
                DoLessEqual();
                break;
            }
        case CNot:
            {
                DoNot();
                break;
            }
        case CIfFalse:
            {
                RUNNER_RefArgs1(flag);
                RUNNER_CheckTag(TBool, flag);
                if (!flag.GetBool()) {
                    int offset = Code.ReadInt31();
                    Code.SetPosition(Code.GetPosition() + offset);
                }
                else
                    Code.SkipInt();
                DiscardStackSlots(1);
                break;
            }
        case CGetGlobal:
            {
                PushDataStackSlot(Code.ReadInt31_16());
                break;
            }
        case CGetLocal:
            {
                PushDataStackSlot(FramePointer + Code.ReadInt31_16());
                break;
            }
        case CReserveLocals:
            {
                char *data = Code.GetBytes(8);
                int ncnt = ((PackedVals*)data)->usv;
                int v = *(unsigned char*)(data+4);
                // Allocate locals
                if (ncnt > 0) {
                    if (unlikely(MAX_DATA_STACK - DataStack.size() < unsigned(ncnt))) {
                        ReportError(DatastackFull, "Cannot reserve %d locals: stack overflow.", ncnt);
                        return;
                    }
                    memset(DataStack.push_ptr(ncnt), -1, STACK_SLOT_SIZE*ncnt);
                }
                // Eat parameters
                FramePointer -= v;
                break;
            }
        case CPop:
            {
                DiscardStackSlots(1);
                break;
            }
        case CRefTo:
            {
                DoRefTo();
                break;
            }
        case CDeref:
            {
                RUNNER_RefArgsRet1(ref);
                RUNNER_CheckTag(TRefTo, ref);
                ref = Memory.GetStackSlot(ref.GetRawRefPtr());
                break;
            }
        case CSetRef:
            {
                DoSetRef();
                break;
            }
        case CInt2Double:
            {
                DoInt2Double();
                break;
            }
        case CInt2String:
            {
                RUNNER_RefArgsRet1(value);
                value = DoInt2String(this, value);
                break;
            }
        case CDouble2Int:
            {
                DoDouble2Int();
                break;
            }
        case CDouble2String:
            {
                RUNNER_RefArgsRet1(value);
                value = DoDouble2String(this, value);
                break;
            }
        case CField:
            {
                int i = Code.ReadInt31_8();
                DoField(i);
                break;
            }
        case CFieldName:
            {
                char *plen = Code.GetBytes(4);
                int len = (unsigned char)plen[0];
                DoFieldName(Code.GetBytes(len), len, (short*)(plen+2));
                break;
            }
        case CSetMutable:
            {
                int i = Code.ReadInt31_8();
                DoSetMutable(i);
                break;
            }
        case CSetMutableName:
            {
                char *plen = Code.GetBytes(4);
                int len = (unsigned char)plen[0];
                DoSetMutableName(Code.GetBytes(len), len, (short*)(plen+2));
                break;
            }
        case CStructDef:
            {
                int id = Code.ReadInt31();
                std::string name = Code.ReadString();
                StructDef sd;
                sd.Name = name;
                sd.NameU = parseUtf8(name);
                int n = Code.ReadInt31();
                sd.FieldsCount = n;
                sd.CompareIdx = id;
                sd.IsMutable.resize(n);
                for (int i = 0; i < n; ++i)
                {
                    sd.FieldNames.push_back(Code.ReadString());
                    sd.FieldTypes.push_back(Code.ReadFieldType(&sd.IsMutable[i], NULL));
                }
#ifdef FLOW_COMPACT_STRUCTS
                sd.EmptyPtr = LastInstructionPtr+1;
#endif

                if (unlikely(Program != NULL))
                    ReportError(InvalidCall, "The StructDef instruction is disabled in native mode.");
                else
                    RegisterStructDef(id, sd);

                break;
            }
        case CGetFreeVar:
            {
                int n = Code.ReadInt31_8();
                PushFromMemory(closurepointer + n * STACK_SLOT_SIZE);
                break;
            }
        case CDebugInfo:
            {
#ifdef FLOW_NATIVE_OVERRIDES
                // Replace certain top-level functions
                if (!DebugFnList.empty() && !DataStack.empty() &&
                    DataStack.top().Type == TCodePointer)
                {
                    T_NativeOverrides::iterator it = NativeOverrides.find(DebugFnList.back());
                    if (it != NativeOverrides.end())
                    {
                         SimpleNative *fn = new SimpleNative(it->first.c_str(), it->second.second, it->second.first);
                         DataStack.top() = AllocNativeFn(fn, LastInstructionPtr-5);
                    }
                }
#endif

                std::string name = Code.ReadString();
                DebugFnInfo[Code.GetPosition()] = name;
                DebugFnList.push_back(name);
                break;
            }
        case CClosurePointer:
            {
                int n = Code.ReadInt31_8();
                int offset = Code.ReadInt31();

                if (unlikely(DataStack.size() < unsigned(n))) {
                    StackError(DatastackFull, false);
                    break;
                }

                StackSlot clos = AllocateUninitializedClosure(n, Code.GetPosition() + offset); // ALLOC
                memcpy(GetClosureWritePtr(clos, n), DataStack.pop_ptr(n), n * STACK_SLOT_SIZE);
                Push(clos);
                break;
            }
        case CSimpleSwitch:
        case CSwitch:
            {
                RUNNER_RefArgsRet1(struct_ref);
                RUNNER_CheckTag(TStruct, struct_ref);

                int cases = *(unsigned char*)Code.GetBytes(8);
                char *data = Code.GetBytes(cases * 8);

                int structId = struct_ref.GetStructId();

                // In the default case, we just eat the struct value
                DiscardStackSlots(1);

                for (int i = 0; i < cases; ++i)
                {
                    int cn = *(short*)(data + i*8);
                    if (cn == structId)
                    {
                        // We have a hit. Let's unpack the struct on the stack.
                        int offset = *(int*)(data + i*8 + 4);

                        if (opcode != CSimpleSwitch) {
                            int len = GetStructSize(struct_ref);
                            if (unlikely(len < 0)) {
                                ReportError(InvalidArgument, "Malformed struct object; unknown type %d", struct_ref.GetStructId());
                                return;
                            }
                            MoveStructToStack(struct_ref, len); // struct_ref overwritten
                        }
                        Code.SetPosition(Code.GetPosition() + offset);
                        break;
                    }
                }
                break;
            }

        case CBreakpoint:
            {
#ifdef FLOW_DEBUGGER
                std::map<FlowPtr,OpCode>::iterator it = BreakpointOpcodeBackup.find(cur_insn);
                if (it != BreakpointOpcodeBackup.end())
                {
                    opcode = it->second;

                    if (DebuggerPtr)
                        DebuggerPtr->onBreakpointTrap(cur_insn);

                    goto reparse_breakpoint;
                }
#endif
                ReportError(InvalidOpCode, "Invalid breakpoint");
                break;
            }

        case CCodeCoverageTrap:
            {
#ifdef FLOW_INSTRUCTION_PROFILING
                size_t offset = cur_insn - CodeStartPtr();

                if (ProfileCodeCoverage && offset < CoverageCodeBackup.size())
                {
                    opcode = (OpCode)CoverageCodeBackup[offset];
                    Memory.SetByte(cur_insn, opcode);

                    ProfileDumpStack(1, CallStack, LastInstructionPtr);

                    goto reparse_breakpoint;
                }
#endif
                ReportError(InvalidOpCode, "Invalid coverage trap");
                break;
            }

        default:
            ReportError(InvalidOpCode, "Invalid OpCode %d (%02Xh)", opcode, opcode);
            break;
        } // switch

#if COMPILED
}
#else

#ifdef FLOW_TIME_PROFILING
        if (unlikely(ProfileTimeCount))
            ProfileTimeEvent();
#endif
    }// while
}
#endif

int ByteCodeRunner::Compare(FlowPtr a1, FlowPtr a2)
{
    if (a1 == a2)
        return 0;
    else
        return Compare(Memory.GetStackSlot(a1), Memory.GetStackSlot(a2));
}

inline int CompareInt(int a, int b) {
    if (a == b)
        return 0;
    else
        return (a < b) ? -1 : 1;
}

int ByteCodeRunner::CompareFlowString(FlowPtr p1, int l1, FlowPtr p2, int l2) {
    if (p1 != p2) {
        // String comparison in UCS-2 format
        unsigned m = (unsigned)MIN(l1, l2);
        unicode_char *pchar1 = (unicode_char*)Memory.GetRawPointer(p1,m*FLOW_CHAR_SIZE,false);
        unicode_char *pchar2 = (unicode_char*)Memory.GetRawPointer(p2,m*FLOW_CHAR_SIZE,false);

        for (unsigned i = 0; likely(i < m); ) {
            unicode_char a = pchar1[i];
            unicode_char b = pchar2[i];
            i++;
            if (a != b)
                return (a > b) ? 1 : -1;
        }
    }

    return CompareInt(l1, l2);
}

/*
 * Deep comparison.
 */
int ByteCodeRunner::Compare(ByteCodeRunner *self, const StackSlot &slot1, const StackSlot &slot2) {
    DataTag t1 = slot1.GetType();
    DataTag t2 = slot2.GetType();

    if (unlikely(t1 != t2))
    {
        /*if ((t1 == TClosurePointer || t1 == TCodePointer || t1 == TNativeFn) &&
            (t2 == TClosurePointer || t2 == TCodePointer || t2 == TNativeFn))*/

        // It is legal to equality compare different types, but they are never identical!
        return CompareInt(t1, t2);
    }

#ifdef FLOW_INSTRUCTION_PROFILING
    // This is a complicated recursive function, so
    // expose its cost in the profile counter
    if (unlikely(++self->InstructionCount == self->ProfileICBarrier))
        self->ProfileICEvent(true);
#endif

    switch (t1) {
    case TInt:  {
        int i1 = slot1.GetInt();
        int i2 = slot2.GetInt();
        return CompareInt(i1, i2);
    }
    case TDouble: {
        FlowDouble d1 = slot1.GetDouble();
        FlowDouble d2 = slot2.GetDouble();
        if (d1 == d2) return 0;
        else if (d1 < d2) return -1;
        else return 1;
    }
    case TBool: {
        char c1 = (slot1.GetBool() ? 1 : 0);
        char c2 = (slot2.GetBool() ? 1 : 0);
        return CompareInt(c1, c2);
    }
    case TString:
        return self->CompareFlowString(
                    self->GetStringAddr(slot1), self->GetStringSize(slot1),
                    self->GetStringAddr(slot2), self->GetStringSize(slot2)
                    );

    case TArray: {
        if (slot1.GetInternalArrayPtr() == slot2.GetInternalArrayPtr())
            return 0;

        int l1 = self->GetArraySize(slot1);
        int l2 = self->GetArraySize(slot2);
        unsigned m = (unsigned)MIN(l1, l2);

        if (m != 0) {
            const StackSlot *arr1 = self->GetArraySlotPtr(slot1, m);
            const StackSlot *arr2 = self->GetArraySlotPtr(slot2, m);

            while (likely(m-- != 0))
            {
                int c = Compare(self, *arr1++, *arr2++);
                if (c != 0)
                    return c;
            }
        }

        return CompareInt(l1, l2);
    }
    case TStruct: {
        // Test types of structs
        if (slot1.GetStructId() != slot2.GetStructId())
        {
#if 1
            if (unlikely(unsigned(slot1.GetStructId()) >= self->StructSizes.size()) ||
                unlikely(unsigned(slot2.GetStructId()) >= self->StructSizes.size()))
            {
                self->ReportError(InvalidArgument, "Invalid struct id in Compare");
                return 0;
            }

            return (self->StructDefs[slot1.GetStructId()].CompareIdx <
                    self->StructDefs[slot2.GetStructId()].CompareIdx) ? -1 : 1;
#else
            return (slot1.IntValue2 < slot2.IntValue2) ? -1 : 1;
#endif
        }

        if (slot1.GetRawStructPtr() == slot2.GetRawStructPtr())
            return 0;

        int m = self->GetStructSize(slot1);
        if (unlikely(m < 0))
            self->ReportError(InvalidArgument, "Invalid struct type in compare: %d", slot1.GetStructId());

        if (m == 0) return 0;

#ifdef FLOW_COMPACT_STRUCTS
        StructDef &def = self->StructDefs[slot1.GetStructId()];
        uint8_t *p1 = (uint8_t*)self->Memory.GetRawPointer(slot1.GetRawStructPtr(),def.ByteSize,false);
        uint8_t *p2 = (uint8_t*)self->Memory.GetRawPointer(slot2.GetRawStructPtr(),def.ByteSize,false);

        for (int i = 0; likely(i < m); i++)
        {
            const FlowStructFieldDef &fd = def.FieldDefs[i];
            int c = Compare(self, fd.fn_get(p1+fd.offset,self), fd.fn_get(p2+fd.offset,self));
            if (c != 0)
                return c;
        }
#else
        StackSlot *arr1 = (StackSlot*)Memory.GetRawPointer(slot1.GetRawStructPtr(),m*STACK_SLOT_SIZE,false);
        StackSlot *arr2 = (StackSlot*)Memory.GetRawPointer(slot2.GetRawStructPtr(),m*STACK_SLOT_SIZE,false);

        while (likely(m-- > 0))
        {
            int c = Compare(self, *arr1++, *arr2++);
            if (c != 0)
                return c;
        }
#endif

        return 0;
    }
    case TRefTo: {
        return CompareInt(self->GetRefId(slot1), self->GetRefId(slot2));
    }
    case TClosurePointer: {
        return CompareInt(FlowPtrToInt(slot1.GetClosureDataPtr()), FlowPtrToInt(slot2.GetClosureDataPtr()));
    }
    case TCodePointer: {
        return CompareInt(FlowPtrToInt(slot1.GetCodePtr()), FlowPtrToInt(slot2.GetCodePtr()));
    }
    case TNative: {
        return CompareInt(slot1.GetNativeValId(), slot2.GetNativeValId());
    }
    case TCapturedFrame: {
        int c = CompareInt(FlowPtrToInt(slot1.GetCapturedFramePtr()), FlowPtrToInt(slot2.GetCapturedFramePtr()));
        if (c != 0) return c;
        return CompareInt(slot1.slot_private.AuxValue, slot2.slot_private.AuxValue);
    }
    case TNativeFn: {
        int c = CompareInt(self->GetNativeFnId(slot1), self->GetNativeFnId(slot2));
        if (c != 0) return c;
        c = CompareInt(slot1.GetSign(), slot2.GetSign());
        if (c != 0 || !slot1.GetSign()) return c;
        return CompareInt(FlowPtrToInt(slot1.GetNativeFnDataPtr()), FlowPtrToInt(slot2.GetNativeFnDataPtr()));
    }
    case TVoid: {
        return 0;
    }
    default: {
        // TODO: Implement for union
        self->ReportError(InvalidArgument, "Cannot compare tag 0x%02x", t1);
        return 0;
    }
    }
}

/*
 * Shallow comparison - only compares non-slot memory data for strings.
 */
bool ByteCodeRunner::CompareByRef(const StackSlot &slot1, const StackSlot &slot2)
{
    if (slot1.GetType() != slot2.GetType())
        return false;

    switch (slot1.GetType()) {
    case TInt:
        return slot1.GetInt() == slot2.GetInt();
    case TNative:
        return slot1.GetNativeValId() == slot2.GetNativeValId();
    case TDouble:
        return slot1.GetDouble() == slot2.GetDouble();
    case TBool:
        return slot1.GetBool() == slot2.GetBool();
    case TString:
        return CompareFlowString(GetStringAddr(slot1), GetStringSize(slot1), GetStringAddr(slot2), GetStringSize(slot2)) == 0;

    case TCodePointer:
        return slot1.GetCodePtr() == slot2.GetCodePtr();

    case TArray:
    case TRefTo:
    case TStruct:
    case TNativeFn:
    case TClosurePointer:
    case TCapturedFrame:
        return slot1.slot_private.PtrValue == slot2.slot_private.PtrValue && slot1.slot_private.AuxValue == slot2.slot_private.AuxValue;

    case TVoid:
        return true;

    default:
        // TODO: Implement for union
        ReportError(InvalidArgument, "Cannot compare tag 0x%02x", slot1.GetType());
        return false;
    }
}

/*
 * Recursively prints data. As a hack, negative max_depth is used to mean no explicit limit.
 */
bool ByteCodeRunner::PrintData(ostream &out, const StackSlot &slot, int max_depth, int max_count)
{
    DataTag tag = slot.GetType();

    if (unlikely(max_depth < -8000))
    {
        out << "... <TOO DEEP>";
        return false;
    }

    bool ok = true;

    switch (tag)
    {
    case TVoid:
        out << "{}";
        break;
    case TBool:
        out << (slot.GetBool() ? "true" : "false");
        break;
    case TInt:
        out << slot.GetInt();
        break;
    case TDouble:
        out << double2string(slot.GetDouble(), true);
        break;

    case TString:
    {
        unicode_string tmp = GetString(slot);
        if (max_count > 0 && tmp.size() > unsigned(5*max_count))
            tmp = tmp.substr(0,max_count*5) + parseUtf8("...");
        printQuotedString(out, encodeUtf8(tmp), true);
        break;
    }
    case TArray:
        {
            int len = GetArraySize(slot);

            if (max_depth == 0 && len > 0)
            {
                out << "[...]";
                return ok;
            }

            out << "[";

            for (int i = 0; i < len && ok; ++i)
            {
                if (i > 0)
                    out << ", ";

                if (max_count >= 0 && i == max_count)
                {
                    out << "...";
                    break;
                }

                ok = PrintData(out, GetArraySlot(slot, i), max_depth-1, max_count);
            }

            out << "]";
            break;
        }
    case TStruct:
        {
            int id = slot.GetStructId();
            StructDef *def = safeVectorPtrAt(StructDefs, id);
            int len = GetStructSize(slot);

            out << def->Name << "(";

            if (def->Name == "DLink")
            {
                // Avoid infinite recursion from cyclical links
                max_depth = 0;
            }

            if (max_depth == 0 && len > 0)
            {
                out << "...)";
                return ok;
            }

            for (int i = 0; i < len && ok; ++i)
            {
                if (i > 0)
                    out << ", ";

                const StackSlot &value = GetStructSlot(slot, i);
                ok = PrintData(out, value, max_depth-1, max_count);

                if (def->FieldTypes[i][0] == FTDouble && value.IsInt()) {
                        // We need a double, but get an int!
                        out << ".0";
                }
            }

            out << ")";
            break;
        }
    case TCapturedFrame:
        out << "<frame: " << AddressToFunction(slot.GetCapturedFramePtr()) << ">";
        break;
    case TCodePointer:
        out << "<fn: " << AddressToFunction(slot.GetCodePtr()) << ">";
        break;
    case TRefTo:
        if (max_depth >= 0)
        {
            out << "<ref #" << GetRefId(slot) << ": ";
            if (max_depth > 0)
                ok = PrintData(out, GetRefTarget(slot), max_depth-1, max_count);
            else
                out << "...";
            out << ">";
        }
        else
        {
            out << "ref ";
            ok = PrintData(out, GetRefTarget(slot), max_depth-1, max_count);
        }
        break;
    case TNative:
    {
        AbstractNativeValue *val = safeMapAt(NativeValues, slot.GetNativeValId(), NULL);
        out << "<native " << slot.GetNativeValId() << ": " << (val ? val->type()->name() : "?invalid?") << ">";
        break;
    }
    case TNativeFn:
    {
        NativeFunction *fn = lookupNativeFn(GetNativeFnId(slot));
        const char *name = fn ? fn->name() : "?";
        out << "<native fn " << GetNativeFnId(slot) << ": " << name << ">";
        break;
    }
    case TClosurePointer:
        out << "<closure 0x" << std::hex << FlowPtrToInt(slot.GetClosureDataPtr()) << std::dec
                    << ": " << AddressToFunction(GetCodePointer(slot)) << ">";
        break;
    default:
        out << "Unknown data-type tag 0x" << std::hex << tag << std::dec;
    }

    return ok;
}

void ByteCodeRunner::FreezeNativeFunctions(bool compact)
{
    NumFrozenNativeFNs = Natives.size();
#ifdef FLOW_COMPACT_STRUCTS
    if (compact)
        NumCompactNativeFNs = Natives.size();
#else
    assert(!compact);
#endif
}

void ByteCodeRunner::ForceGC(unsigned ensure_space, bool full)
{
    if (NativeValueBudget < 0) {
#ifdef DEBUG_FLOW
        flow_err << "Full GC forced by native budget." << endl;
#endif
        full = true;
    }

    // Do a garbage collection pass
#ifdef FLOW_INSTRUCTION_PROFILING
    unsigned pdelta = hp - ProfileMemBarrier;
#endif

#ifdef DEBUG_FLOW
    double start_time = GetCurrentTime();
#endif

    ByteCodeRunnerNativeContext ctx(this, 0); (void)&ctx;

    bool fast_ok = false;
    GarbageCollector gc(this);

    if (!full)
        fast_ok = gc.CollectFast();

    if (!fast_ok)
    {
        if (!gc.Collect(ensure_space))
            return;

        // Heuristically force full gc when too many new natives are allocated
        NativeValueBudget = gc.ComputeNativeBudget();
    }

#ifdef DEBUG_FLOW
    if (!fast_ok)
        flow_err << "FULL ";
    flow_err << "GC performed: " << (GetCurrentTime() - start_time) << " (generation " << NumFullGCs << ")" << endl;
#endif

    NumFullGCs += (fast_ok ? 1 : 1000);

#ifdef FLOW_GARBAGE_PROFILING
    if (DoProfileGarbage) {
        gc.UpdateProfileInfo();
        if (fast_ok)
            gc.PrintStats(flow_err, "", 0);
        else
        {
            gc.PrintStats(flow_err, stl_sprintf("flowprof.fullgc-%d", (NumFullGCs/1000)), LastDumpID);
            LastDumpID = NumFullGCs;
        }
    }
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
    if (ProfileMemStep > 0) {
        if (pdelta > ProfileMemStep)
            pdelta = ProfileMemStep;
        ProfileMemBarrier = hp - pdelta;
    }
#endif

    if (fast_ok)
    {
        NativeValueBudget += DeleteDeadNativeVals(gc.GetLiveValues(), NativeGCGenBarrier);
    }
    else
    {
        // Delete obsolete native objects
        DeleteDeadNativeVals(gc.GetLiveValues(), 0);
        DeleteDeadNativeFuns(gc.GetLiveFunctions());
    }

    NativeGCGenBarrier = NextNativeIdx;
}

int ByteCodeRunner::DeleteDeadNativeVals(const T_LiveTable &live_vals, int valbarrier)
{
    // Remove expired native values
    T_NativeValues::iterator itv = NativeValues.begin(), itv2;

    std::vector<AbstractNativeValue*> to_delete;
    int cnt = 0;

    while (itv != NativeValues.end()) {
        if (itv->first < valbarrier || live_vals.find(itv->first) != live_vals.end())
            ++itv;
        else {
            // Flow natives are first finalized, then deleted
            FlowNativeObject *obj = itv->second->nativeObject();
            if (obj) {
                to_delete.push_back(itv->second);
                obj->flowFinalizeObject();
            }
            else
                delete itv->second;

            itv2 = itv; ++itv;
            NativeValues.erase(itv2);
            cnt++;
        }
    }

    // Delete all finalized FNOs
    for (std::vector<AbstractNativeValue*>::iterator it = to_delete.begin();
         it != to_delete.end(); ++it)
        delete *it;

    return cnt;
}

void ByteCodeRunner::DeleteDeadNativeFuns(const T_LiveTable &live_funcs)
{
    // Remove expired native functions
    for (unsigned i = NumFrozenNativeFNs; i < Natives.size(); i++) {
        if (live_funcs.find(i) != live_funcs.end())
            continue;

        // TODO: also reuse the index somehow
        delete Natives[i];
        Natives[i] = NULL;

#ifdef FLOW_JIT
        if (JitProgram)
            JitProgram->FreeNative(this, i);
#endif
    }
}

void ByteCodeRunner::NotifyHostEvent(NativeMethodHost::HostEvent type)
{
    T_NativeHosts::reverse_iterator it;;
    for (it = NativeHosts.rbegin(); it != NativeHosts.rend(); ++it)
        (*it)->OnHostEvent(type);

    if (type != NativeMethodHost::HostEventDeferredActionTimeout)
        RunDeferredActions();
}

void ByteCodeRunner::RunDeferredActions()
{
    if (DeferredQueueLockCount > 0) return;

    class LockDeferredNoRun {
        ByteCodeRunner *runner;
    public:
        LockDeferredNoRun(ByteCodeRunner *runner) : runner(runner) { runner->DeferredQueueLockCount++; }
        ~LockDeferredNoRun() { runner->DeferredQueueLockCount--; }
    } dlock(this);

    (void)(&dlock);

    double start = GetCurrentTime();

    do {
        while (!DeferredActionQueue.empty()) {
            if (DeferredQueueTimeout > 0 && (GetCurrentTime()-start) >= DeferredQueueTimeout) {
                NotifyHostEvent(NativeMethodHost::HostEventDeferredActionTimeout);
                return;
            }

            StackSlot slot = DeferredActionQueue.front();
            DeferredActionQueue.pop_front();

            EvalFunction(slot, 0);
        }

        NotifyHostEvent(NativeMethodHost::HostEventRunDeferredActions);
    } while (!DeferredActionQueue.empty());
}

NativeFunction *ByteCodeRunner::MakeNativeFunction(const char *name, int num_args, bool optional)
{
    // Try external hosts from latest to oldest
    T_NativeHosts::reverse_iterator it;;
    for (it = NativeHosts.rbegin(); it != NativeHosts.rend(); ++it) {
        NativeFunction *nf = (*it)->MakeNativeFunction(name, num_args);
        if (nf != NULL)
            return nf;
    }

#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, println, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, failWithError, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, deleteNative, 1);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, mapi, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, map, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, iter, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, iteri, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, fold, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, foldi, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, filter, 2);

    // optional
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, elemIndex, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, exists, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, find, 2);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, gc, 0);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, subrange, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, length, 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeStrlen, "strlen", 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, strIndexOf, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, strContainsAt, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, strRangeIndexOf, 4);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, substring, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, concat, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, replace, 3);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, s2a, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, string2utf8, 1);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitXor, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitAnd, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitOr, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitUshr, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitShl, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, bitNot, 1);

    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeTimestamp, "timestamp", 0);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, random, 0);

    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeSrand, "srand", 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeSin, "sin", 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeAsin, "asin", 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeAcos, "acos", 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeAtan, "atan", 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeAtan2, "atan2", 2);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeExp, "exp", 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeLog, "log", 1);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, setKeyValue, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getKeyValue, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, removeKeyValue, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, removeAllKeyValues, 0);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getKeysList, 0);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, enumFromTo, 2);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, captureCallstack, 0);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, captureCallstackItem, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, impersonateCallstackItem, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, impersonateCallstackFn, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, impersonateCallstackNone, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, callstack2string, 1);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativePrintCallStack, "printCallstack", 0);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, NativeGetTargetName, "getTargetName", 0);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, toLowerCase, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, toUpperCase, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, toString, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, makeStructValue, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, extractStructArguments, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getDataTagForValue, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getFileContent, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getFileContentBinary, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, setFileContent, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, setFileContentUTF16, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, setFileContentBinary, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, setFileContentBytes, 2);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getBytecodeFilename, 0);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, loaderUrl, 0);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getUrlParameter, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getAllUrlParameters, 0);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, fromCharCode, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, string2time, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, time2string, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, utc2local, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, local2utc, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, dayOfWeek, 3);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, number2double, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getCharCodeAt, 2);

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, list2array, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, list2string, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, isArray, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, isSameStructType, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, isSameObj, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, iteriUntil, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, toBinary, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, fromBinary, 3);
    TRY_USE_NATIVE_STATIC_NAME(ByteCodeRunner, fromBinary2, "fromBinary", 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, stringbytes2double, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, stringbytes2int, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getCurrentDate, 0);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, getTotalMemoryUsed, 0);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, addCrashHandler, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, addPlatformEventListener, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, addCustomFileTypeHandler, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, addCameraPhotoEventListener, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, addCameraVideoEventListener, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, addTakeAudioEventListener, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, md5, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, fileChecksum, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, readBytes, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, readUntil, 1);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, print, 1);

    // optional
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, fast_lookupTree, 2);
    TRY_USE_NATIVE_STATIC(ByteCodeRunner, fast_setTree, 3);

#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "HttpSupport."

    TRY_USE_NATIVE_STATIC(ByteCodeRunner, preloadMediaUrl, 3);

    if (optional)
        return NULL;

    // TODO: restrict
#ifdef DEBUG_FLOW
    flow_err << "Substituting a stub for: " << name << " (" << num_args << " args)" << endl;
#endif
    return new StubNative(strdup(name), num_args);
}

void ByteCodeRunner::RunMain()
{
    if (!CallStack.empty() ||
        !DataStack.empty() ||
        Code.GetPosition() != MakeFlowPtr(0) ||
        IsErrorReported())
    {
        ReportError(InvalidCall, "Cannot RunMain: ByteCodeRunner has already been executing code.");
        return;
    }

#ifdef FLOW_TIME_PROFILING
    ProfileTimeCount = 0;
#endif
#ifdef FLOW_DEBUGGER
    ImpersonateInsn = MakeFlowPtr(0);
#endif

    if (Program)
    {
        Program->onRunMain();
    }
#ifdef FLOW_JIT
    else if (JitProgram)
    {
        StackSlot fn = JitProgram->GetMainFunction();
        FastEvalFunction(&fn, 0);
    }
#endif
    else
    {
        run();
    }

    Code.SetPosition(NativeReturnInsn);
    LastInstructionPtr = NativeReturnInsn;
#ifdef FLOW_DEBUGGER
    ImpersonateInsn = MakeFlowPtr(0);
#endif

    RunDeferredActions();
}

StackSlot ByteCodeRunner::EvalFunction(const StackSlot &func, int args_num, ...)
{
    va_list vl;

    if (unlikely(IsErrorReported()))
        return StackSlot::MakeVoid();

    switch (func.slot_private.Tag & StackSlot::TAG_NOSIGN)
    {
    case StackSlot::TAG_NATIVEFN:
    {
        NativeFunction *p = lookupNativeFn(GetNativeFnId(func));

        if (unlikely(p == NULL)) {
            ReportError(InvalidNativeId, "Invalid native %d", GetNativeFnId(func));
            return StackSlot::MakeVoid();
        }

        if (unlikely(p->num_args_ != args_num)) {
            ReportError(InvalidNativeId, "Invalid native argument count: %d vs %d for %s", args_num, p->num_args_, p->name());
            return StackSlot::MakeVoid();
        }

        StackSlot *func_and_args = (StackSlot*)alloca((args_num+1) * sizeof(StackSlot));

        func_and_args[0] = func;

        va_start(vl, args_num);
        for (int i = 0; i < args_num; ++i)
            func_and_args[i+1] = va_arg(vl, StackSlot);
        va_end(vl);

        LocalRootDefinition arg_buffer_root(this, args_num+1, func_and_args);
        (void)&arg_buffer_root;

        return (CurNativeFn = p)->func_(this, func_and_args+1);
    }

    case StackSlot::TAG_FLOWCODE:
    {
        va_start(vl, args_num);
        for (int i = 0; i < args_num; ++i)
            Push(va_arg(vl, StackSlot));
        va_end(vl);

        if (likely(EvalFunctionStack(func, args_num)))
            return PopStackSlot();

        return StackSlot::MakeVoid();
    }

    default:
        ReportError(InvalidCall, "Not callable tag: %02x", func.GetType());
        return StackSlot::MakeVoid();
    }
}

StackSlot ByteCodeRunner::EvalFunctionArr(const StackSlot &func, int args_num, StackSlot *args)
{
    if (unlikely(IsErrorReported()))
        return StackSlot::MakeVoid();

    switch (func.slot_private.Tag & StackSlot::TAG_NOSIGN)
    {
    case StackSlot::TAG_NATIVEFN:
    {
        NativeFunction *p = lookupNativeFn(GetNativeFnId(func));

        if (unlikely(p == NULL)) {
            ReportError(InvalidNativeId, "Invalid native %d", GetNativeFnId(func));
            return StackSlot::MakeVoid();
        }

        if (unlikely(p->num_args_ != args_num)) {
            ReportError(InvalidNativeId, "Invalid native argument count: %d vs %d for %s", args_num, p->num_args_, p->name());
            return StackSlot::MakeVoid();
        }

        StackSlot *func_and_args = (StackSlot*)alloca((args_num+1) * sizeof(StackSlot));

        func_and_args[0] = func;
        memcpy(func_and_args+1, args, sizeof(StackSlot)*args_num);

        LocalRootDefinition arg_buffer_root(this, args_num+1, func_and_args);
        (void)&arg_buffer_root;

        return (CurNativeFn = p)->func_(this, func_and_args+1);
    }

    case StackSlot::TAG_FLOWCODE:
    {
        for (int i = 0; i < args_num; ++i)
            Push(args[i]);

        if (likely(EvalFunctionStack(func, args_num)))
            return PopStackSlot();

        return StackSlot::MakeVoid();
    }

    default:
        ReportError(InvalidCall, "Not callable tag: %02x", func.GetType());
        return StackSlot::MakeVoid();
    }
}

bool ByteCodeRunner::EvalFunctionStack(const StackSlot &func, int args_num)
{
#ifdef FLOW_JIT
    assert(!JitProgram);
#endif

#ifdef FLOW_TIME_PROFILING
    if (unlikely(ProfileTimeCount))
        ProfileTimeEvent();
#endif

    // At this point the flow return address must be already
    // on the stack, if any is needed.
    Code.SetPosition(NativeReturnInsn);

    // Remember the stack position for control and push args
    unsigned cur_stack_pos = DataStack.size()-args_num+1;
    unsigned cur_cstack_pos = CallStack.size();

    // Call the function
    Push(func);
    DoCall(); // NATIVE: ALLOC
    run();    // FLOW: ALLOC

    if (unlikely(IsErrorReported()))
        return false;

    // Verify stack integrity
    if (unlikely(cur_stack_pos != DataStack.size())) {
        int delta = (DataStack.size() - cur_stack_pos);
        // Note: forgetting to return a value is reported as using 1 additional argument.
        ReportError(StackCorruption, "Stack position changed in EvalFunction: added %d slots.", delta);
        DataStack.resize(cur_stack_pos);
        return false;
    }

    if (unlikely(cur_cstack_pos != CallStack.size())) {
        int delta = (CallStack.size() - cur_cstack_pos);
        ReportError(StackCorruption, "Call stack position changed in EvalFunction: added %d entries.", delta);
        CallStack.resize(cur_cstack_pos);
        return false;
    }

    return true;
}

int ByteCodeRunner::FindStructId(const std::string &name, int fields_num)
{
    int index = safeMapAt(StructNameIds, name, -1);
    if (unlikely(index < 0))
        return -1;

    unsigned dcnt = StructSizes[index];
    if (unlikely(dcnt != (unsigned)fields_num))
        return -2;

    return index;
}

StackSlot ByteCodeRunner::MakeStruct(const std::string& name, int fields_num, const StackSlot * fields)
{
    int index = safeMapAt(StructNameIds, name, -1);

    if (unlikely(index < 0)) {
        ReportError(InvalidArgument, "Unknown struct: '%s'", name.c_str());
        return StackSlot::MakeVoid();
    }

    StructDef *def = &StructDefs[index];
    if (unlikely(def->FieldsCount != fields_num)) {
        ReportError(InvalidArgument, "Struct %s has %d fields; %d found",
                            name.c_str(), def->FieldsCount, fields_num);
        return StackSlot::MakeVoid();
    }

    StackSlot arr = AllocateRawStruct(*def, false);

    for (int i = 0; i < fields_num; ++i) {
        SetStructSlot(arr, i, fields[i]);
    }

    return arr;
}

void addStackFrame(std::vector<FlowStackFrame> *vec, FlowPtr insn, unsigned stack_place,
                   unsigned frame, FlowPtr closure, FlowPtr impersonate, ExtendedDebugInfo *dbg)
{
    int idx = vec->size();

    vec->push_back(FlowStackFrame());
    FlowStackFrame &rframe = vec->back();

    rframe.index = idx;
    rframe.stack_place = stack_place;
    rframe.insn = insn;
    rframe.frame = frame;
    rframe.closure = closure;
    rframe.special_id = -1-FlowPtrToInt(insn);

    if (!dbg)
    {
        rframe.function = NULL;
        rframe.chunk = NULL;
    }
    else if (rframe.special_id < 0)
    {
        rframe.function = dbg->find_function(insn);
        rframe.chunk = dbg->find_chunk(insn);
    }

    rframe.impersonate_insn = MakeFlowPtr(0);
    rframe.impersonate_function = NULL;
    rframe.impersonate_chunk = NULL;

    if (FlowPtrToInt(impersonate) > 0)
    {
        rframe.impersonate_insn = impersonate;

        if (dbg)
        {
            rframe.impersonate_function = dbg->find_function(impersonate);
            rframe.impersonate_chunk = dbg->find_chunk(impersonate);
        }
    }
}

/*
 * Return addresses in the call stack naturally point after the call instruction.
 * This updates the address to refer to the call instruction itself when appropriate.
 */
FlowPtr ByteCodeRunner::BacktrackCall(FlowPtr val)
{
    if (val == 0 || val >= getLastCodeAddress())
        return val;

    // Backtrack calls
    char op = Memory.GetByte(val-1);
    if (op == CCall || op == CTailCall)
        return val-1;
    else
        return val;
}

void ByteCodeRunner::ParseCallStack(std::vector<FlowStackFrame> *vec, const TCallStack &CallStack, FlowPtr cur_insn, ExtendedDebugInfo *dbg)
{
    int depth = CallStack.size();

    if (!dbg) dbg = ExtDbgInfo;

    vec->clear();

#ifdef FLOW_JIT
    if (JitProgram && &CallStack == &this->CallStack)
    {
        JitProgram->ParseCallstack(vec, this);
        return;
    }
#endif

    vec->reserve(depth);

    addStackFrame(vec, cur_insn, CallStack.size(), FramePointer, closurepointer, MakeFlowPtr(0), dbg);

    for (int i = depth-1; i >= 0; i--)
    {
        const CallFrame &cframe = CallStack[i];

#ifdef FLOW_DEBUGGER
        FlowPtr impersonate = cframe.impersonate_pc;
#else
        FlowPtr impersonate = MakeFlowPtr(0);
#endif
        addStackFrame(vec, BacktrackCall(cframe.last_pc), i, cframe.last_frame, cframe.last_closure, impersonate, dbg);
    }
}

void ByteCodeRunner::PrintCallStack(ostream &out, bool with_args)
{
    std::vector<FlowStackFrame> frames;
    ParseCallStack(&frames, CallStack, LastInstructionPtr);
    for (size_t i = 0; i < frames.size(); i++)
        PrintCallStackLine(out, frames[i], with_args);
#ifdef FLOW_JIT
    if (JitProgram) {
        out << "Run with --no-jit to get line numbers in this callstack" << endl;
    }
#endif
}

void ByteCodeRunner::PrintCallStackLine(ostream &out, const FlowStackFrame &frame, bool with_args)
{
    out << stl_sprintf("#%-2d 0x%08x in ", frame.index, FlowPtrToInt(frame.insn));

    if (frame.impersonate_insn != MakeFlowPtr(0))
    {
        out << "~";

        if (frame.impersonate_function)
            out << frame.impersonate_function->name;
        else
            out << AddressToFunction(frame.impersonate_insn);

        ExtendedDebugInfo::ChunkEntry *chunk = frame.impersonate_chunk;
        if (chunk)
            out << " at " << chunk->line->file->name << ":" << chunk->line->line_idx;

        out << " VIA ";
    }

    if (!frame.function || frame.insn >= NativeReturnInsn)
    {
        out << AddressToFunction(frame.insn);
    }
    else
    {
        ExtendedDebugInfo::FunctionEntry *function = frame.function;

        if (!function)
            out << "?";
        else
        {
            out << function->name;

            if (with_args && !function->locals.empty() &&
                frame.frame + function->num_args <= DataStack.size())
            {
                out << " (";
                for (int i = 0; i < function->num_args; i++)
                {
                    ExtendedDebugInfo::LocalEntry *local = function->find_local(ExtendedDebugInfo::LOCAL_ARG, i);

                    if (i > 0) out << ", ";
                    if (local) out << local->name << "=";

                    PrintData(out, DataStack[frame.frame+i], 1, 3);
                }
                out << ")";
            }
        }

        if (frame.chunk)
            out << " at " << frame.chunk->line->file->name << ":" << frame.chunk->line->line_idx;
    }

    out << endl;
}

FlowPtr ByteCodeRunner::FunctionToAddress(const char * name)
{
    std::map<FlowPtr,std::string>::iterator it = DebugFnInfo.begin();

    for (; it != DebugFnInfo.end(); ++it)
    {
        if (it->second == name)
            return it->first;
    }

    return MakeFlowPtr(-1); // means not found
}

std::string ByteCodeRunner::AddressToFunction(FlowPtr pc)
{
    static std::string q("?");
    static std::string invalid("<invalid>");
    static std::string native("<native>");

    if (int(FlowPtrToInt(pc)) < 0)
        return stl_sprintf("<special %d>", -1-int(FlowPtrToInt(pc)));

#ifdef FLOW_JIT
    if (JitProgram)
        return JitProgram->AddressToFunction(pc);
#endif

    if (pc >= getLastCodeAddress())
        return invalid;
    else if (pc == NativeReturnInsn)
        return native;

    if (ExtDbgInfo)
    {
        ExtendedDebugInfo::FunctionEntry *func = ExtDbgInfo->find_function(pc);
        if (func)
            return func->name;
    }

    std::map<FlowPtr,std::string>::iterator it = mapFindLE(DebugFnInfo, pc);
    if (it != DebugFnInfo.end())
        return it->second;
    else
        return q;
}

void ByteCodeRunner::ProfileDumpStack(int samples, TCallStack &stack, FlowPtr cur_pos)
{
    if (!ProfileStream || samples <= 0) return;

    int depth = stack.size();
    unsigned *buffer = new unsigned[depth*2 + 3];
    unsigned *sbuffer = buffer+2;
    unsigned &cnt = buffer[1];

    buffer[0] = samples;
    cnt = 0;

    if (cur_pos != NativeReturnInsn)
        sbuffer[cnt++] = FlowPtrToInt(cur_pos);

    for (int i = depth-1; i >= 0; i--)
    {
#ifdef FLOW_DEBUGGER
        if (stack[i].impersonate_pc != MakeFlowPtr(0))
            sbuffer[cnt++] = FlowPtrToInt(stack[i].impersonate_pc) | 0x80000000;
#endif
        sbuffer[cnt++] = FlowPtrToInt(BacktrackCall(stack[i].last_pc));
    }

    if (cnt > 0)
    {
        if (fwrite(buffer, sizeof(unsigned), 2+cnt, ProfileStream) > 0)
            fflush(ProfileStream);
    }

    delete[] buffer;
}

#ifdef FLOW_DEBUGGER
FlowDebuggerBase::FlowDebuggerBase(ByteCodeRunner *runner) : runner(runner)
{
    assert(runner->DebuggerPtr == NULL);
    runner->DebuggerPtr = this;
    onRunnerInit();
}

FlowDebuggerBase::~FlowDebuggerBase()
{

}

void FlowDebuggerBase::onRunnerInit()
{
    insn_table.clear();
    globals.clear();
    global_vars.clear();
    structs.clear();

    runner->Disassemble(&insn_table, runner->CodeStartPtr(), runner->CodeSize());

    FlowInstruction::Map::iterator it = insn_table.begin();
    for (; it != insn_table.end(); ++it)
    {
        switch (it->second.op)
        {
        case CStructDef:
            structs[it->second.IntValue] = &it->second;
            break;
        case CDebugInfo:
            globals[it->second.StrValue] = global_vars.size();
            global_vars.push_back(it->second.StrValue);
            break;
        default:
            break;
        }
    }

    active_dbg_info = runner->ExtDbgInfo;
    if (!active_dbg_info)
    {
        active_dbg_info = &our_dbg_info;
        our_dbg_info.load_code(insn_table);
    }
}

int FlowDebuggerBase::findGlobalByName(const std::string &name)
{
    return safeMapAt(globals, name, -1);
}

FlowInstruction *FlowDebuggerBase::findStructDef(int id)
{
    return safeMapAt(structs, id, NULL);
}

void FlowDebuggerBase::onRunnerReset()
{
    insn_table.clear();
    globals.clear();
    global_vars.clear();
    structs.clear();
}

FlowPtr FlowDebuggerBase::SetBreakpoint(FlowPtr addr, bool enable)
{
    FlowInstruction::Map::iterator it = mapFindLE(insn_table, addr);
    if (it != insn_table.end())
        addr = it->first;

    if (enable)
    {
        if (!breakpoints().count(addr))
        {
            OpCode op = (OpCode)runner->Memory.GetByte(addr);
            assert(op != CBreakpoint);
            runner->BreakpointOpcodeBackup[addr] = op;
            runner->Memory.SetByte(addr, (char)CBreakpoint);
        }
    }
    else
    {
        if (breakpoints().count(addr))
        {
            OpCode op = runner->BreakpointOpcodeBackup[addr];
            runner->Memory.SetByte(addr, (char)op);
            runner->BreakpointOpcodeBackup.erase(addr);
        }
    }

    return addr;
}
#endif


#if defined(FLOW_INSTRUCTION_PROFILING) || defined(FLOW_DEBUGGER)
void ByteCodeRunner::ProfileICEvent(bool in_compare)
{
#ifdef FLOW_DEBUGGER
    if (DbgInsnTrap) {
        if (!in_compare) {
            if (DebuggerPtr)
                DebuggerPtr->onInsnTrap(LastInstructionPtr);
            else
                DbgInsnTrap = false;
        }

#ifdef FLOW_INSTRUCTION_PROFILING
        if (DbgInsnTrap)
            ProfileICBarrier = InstructionCount+1;
        else
            ProfileICBarrier = InstructionCount + ProfileICStep;
        return;
#endif
    }
#endif
#ifdef FLOW_INSTRUCTION_PROFILING
    if (ProfileICStep > 0) {
        ProfileDumpStack(ProfileICStep, CallStack, LastInstructionPtr);
        ProfileICBarrier += ProfileICStep;
    }
#endif
}
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
void ByteCodeRunner::DoClaimInstructionsSpent(int amount, int special)
{
    if (special >= 0)
    {
        ByteCodeRunnerNativeContext ctx(this, special); (void)&ctx;
        DoClaimInstructionsSpent(amount, -1);
    }
    else
    {
        InstructionCount += amount;
        while (InstructionCount >= ProfileICBarrier)
            ProfileICEvent(false);
    }
}

void ByteCodeRunner::ProfileMemEvent(unsigned size, bool big)
{
    if (ProfileMemStep > 0) {
#ifdef FLOW_GARBAGE_PROFILING
        if (DoProfileGarbage)
        {
            FlowPtr obj = big ? hp_big_pos : hp;
            ProfileHeapObjects.push_back(AllocationInfo(obj, size, NumFullGCs));

            // Compute the stack size
            int ssize = CallStack.size();
            if (LastInstructionPtr != NativeReturnInsn || ssize == 0)
                ssize++;
            if (ssize > MaxGarbageStack)
                ssize = MaxGarbageStack;

            // Extract top of the stack
            AllocationInfo &newrec = ProfileHeapObjects.back();
            newrec.stack_buf.resize(ssize*sizeof(unsigned));
            unsigned *buf = (unsigned*)&newrec.stack_buf[0];
            int sidx = 0;

            if (LastInstructionPtr != NativeReturnInsn)
                buf[sidx++] = FlowPtrToInt(LastInstructionPtr);

            for (int i = CallStack.size()-1; i >= 0 && sidx < ssize; i--)
            {
                FlowPtr ptr = BacktrackCall(CallStack[i].last_pc);
#ifdef FLOW_DEBUGGER
                if (CallStack[i].impersonate_pc != MakeFlowPtr(0))
                    ptr = CallStack[i].impersonate_pc;
#endif
                buf[sidx++] = FlowPtrToInt(ptr);
            }

            if (sidx == 0)
                buf[sidx++] = FlowPtrToInt(LastInstructionPtr);

            assert(sidx == ssize);
        }
        else
#endif
        {
            unsigned delta = ProfileMemStep + (ProfileMemBarrier - hp);
            ProfileDumpStack(delta, CallStack, LastInstructionPtr);
        }

        ProfileMemBarrier = hp - ProfileMemStep;
    }
}
#endif

void ByteCodeRunner::ProfileOpenFile(const char *name)
{
    if (ProfileStream)
        fclose(ProfileStream);

    ProfileStream = fopen(name, "wb");
    if (fwrite("FLOWPROF", 8, 1, ProfileStream) > 0)
        fflush(ProfileStream);
}

#ifdef FLOW_INSTRUCTION_PROFILING
void ByteCodeRunner::BeginInstructionProfile(const char *file, unsigned step)
{
    ProfileOpenFile(file);
    ProfileICStep = step;
    ProfileICBarrier = InstructionCount + step;
}

void ByteCodeRunner::BeginMemoryProfile(const char *file, unsigned step)
{
    ProfileOpenFile(file);
    ProfileMemStep = step;
    ProfileMemBarrier = hp - step;
}

void ByteCodeRunner::BeginCoverageProfile(const char *file)
{
    ProfileOpenFile(file);

    if (!ProfileCodeCoverage)
    {
        ProfileCodeCoverage = true;
        size_t code_size = CodeSize();

        CoverageCodeBackup.resize(code_size);
        memcpy(CoverageCodeBackup.data(), Memory.GetRawPointer(CodeStartPtr(), code_size, false), code_size);

        // Tag all instructions for a trap
        FlowInstruction::Map table;
        Disassemble(&table, CodeStartPtr(), CodeSize());

        for (FlowInstruction::Map::iterator it = table.begin(); it != table.end(); ++it)
            Memory.SetByte(it->first, CCodeCoverageTrap);
    }
}

#ifdef FLOW_GARBAGE_PROFILING
void ByteCodeRunner::BeginGarbageProfile(int stack)
{
    DoProfileGarbage = true;
    MaxGarbageStack = std::max(1,stack);
    ProfileMemStep = 1;
    ProfileMemBarrier = hp - 1;
}
#endif
#endif

#if defined(FLOW_TIME_PROFILING) || defined(FLOW_DEBUGGER)
void ByteCodeRunner::ProfileTimeEvent()
{
#ifdef FLOW_DEBUGGER
    if (DebuggerPtr) {
        ProfileTimeCount = 0;
        DebuggerPtr->onAsyncInterrupt(LastInstructionPtr);
        return;
    }
#endif
#ifdef FLOW_TIME_PROFILING
    ProfileDumpStack(ProfileGetTimeSamples(), CallStack, LastInstructionPtr);
#endif
}
#endif

#ifdef FLOW_TIME_PROFILING

#ifndef FLOW_PTHREAD
ByteCodeProfileClock::ByteCodeProfileClock(ByteCodeRunner *owner) :
    runner(owner), mutex(owner->ProfileClockMutex)
{
    // nothing
}

void ByteCodeProfileClock::run()
{
#else
void* ByteCodeRunner::ProfileClockThread(void *bcr)
{
    ByteCodeRunner *const runner = (ByteCodeRunner*)bcr;
#endif
    unsigned step;

#ifdef FLOW_PTHREAD
    {
        pthread_mutex_lock(&runner->ProfileClockMutex);
        step = runner->ProfileTimeStep;
        if (step <= 0)
            runner->ProfileClock = 0;
        pthread_mutex_unlock(&runner->ProfileClockMutex);
    }
#else
    {
        QMutexLocker lock(mutex);
        Q_UNUSED(lock);
        step = runner->ProfileTimeStep;
    }
#endif

    while (step > 0) {
        // Wait out the tick:
        usleep(step);

        // Notify the runner:
        {
#ifdef FLOW_PTHREAD
            pthread_mutex_lock(&runner->ProfileClockMutex);
#else
            QMutexLocker lock(mutex);
            Q_UNUSED(lock);
#endif
            step = runner->ProfileTimeStep;
            if (step > 0)
                runner->ProfileTimeCount++;
#ifdef FLOW_PTHREAD
            if (step <= 0)
                runner->ProfileClock = 0;
            pthread_mutex_unlock(&runner->ProfileClockMutex);
#endif
        }
    }

#ifdef FLOW_PTHREAD
	return NULL;
#endif
}

int ByteCodeRunner::ProfileGetTimeSamples()
{
    if (ProfileTimeStep > 0) {
        unsigned delta;

#ifdef FLOW_PTHREAD
        {
            pthread_mutex_lock(&ProfileClockMutex);
            delta = ProfileTimeCount;
            ProfileTimeCount = 0;
            pthread_mutex_unlock(&ProfileClockMutex);
        }
#else
        {
            QMutexLocker lock(ProfileClockMutex);
            Q_UNUSED(lock);
            delta = ProfileTimeCount;
            ProfileTimeCount = 0;
        }
#endif

        if (delta > 0)
            return delta * ProfileTimeStep;
    } else {
        ProfileTimeCount = 0;
    }

    return 0;
}

void ByteCodeRunner::BeginTimeProfile(const char *file, unsigned step)
{
#ifdef FLOW_DEBUGGER
    if (DebuggerPtr)
        return;
#endif

    ProfileOpenFile(file);
    ProfileTimeStep = step;
    ProfileTimeCount = 0;

    if (step > 0) {
#ifdef FLOW_PTHREAD
        pthread_mutex_lock(&ProfileClockMutex);
        if (!ProfileClock)
            pthread_create(&ProfileClock, NULL, ProfileClockThread, this);
        pthread_mutex_unlock(&ProfileClockMutex);
#else
        ProfileClockMutex = new QMutex();
        ProfileClock = new ByteCodeProfileClock(this);
        ProfileClock->start();
#endif
    }
}

void FlowStackSnapshot::doClaimTime(int code)
{
    ByteCodeRunner *runner = getFlowRunner();
    runner->ProfileDumpStack(runner->ProfileGetTimeSamples(), CallStack, ByteCodeRunnerNativeContext::MakeTag(code));
}
#endif
