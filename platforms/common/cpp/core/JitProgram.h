#ifndef _JIT_PROGRAM_H_
#define _JIT_PROGRAM_H_

#include "CodeMemory.h"

// Stupid Qt define
#undef emit

#include <asmjit/asmjit.h>

/* Simplified data structure describing memory layout for GDB python script */
struct FlowGdbMemorySymbol {
    uint64_t addr;
    const char *name;
};

struct FlowGdbMemoryLayout {
    FlowGdbMemoryLayout *next;
    uint64_t start, end;
    FlowGdbMemorySymbol *symbols;
    uint64_t num_symbols;
};

class FlowJitProgram : protected asmjit::ErrorHandler {
	ostream &err;

    // Memory space for generating code
    MemoryArea code_buffer;
    unsigned next_code_off;
	uint64_t memoryLimit;


    // Memory layout data for the gdb script
    FlowGdbMemoryLayout layout_info;
    std::vector<FlowGdbMemorySymbol> layout_symbols;

    // Allocation of const data in the code buffer
    unsigned next_data_off, committed_data_off;
    uint8_t *alloc_const_data(unsigned size);

    std::map<uint64_t, uint64_t> const_qword_map;
    asmjit::X86Mem const_qword(uint64_t value);

    asmjit::X86Mem qword_tag_int, qword_tag_bool;

    // Buffer with the original bytecode
    StaticBuffer flow_code;

    // Buffer with flow constants to be copied into flow heap
    std::vector<uint8_t> flow_constant_buffer;
    unsigned alloc_flow_const_data(unsigned size);

    StackSlot alloc_string_constant(const unicode_string &us);

    // Bytecode instructions
    typedef std::vector<FlowInstruction::Pair*> T_bytecode_list;

    FlowInstruction::Map bytecodes;
    T_bytecode_list bytecode_list, structdef_list;

    // Tracking of function labels
    struct LabelAddr {
        std::string name;
        asmjit::Label label;
        uint64_t addr;

        LabelAddr() : addr(0) {}

        template<class T> T *as_pointer() const { return (T*)addr; }

        asmjit::X86Mem ptr() const;

        asmjit::Error bind(asmjit::Assembler &as);

        asmjit::Error call(asmjit::X86Assembler &as) const;
        asmjit::Error jump(asmjit::X86Assembler &as, asmjit::X86Inst::Id insn) const;

        asmjit::Error jmp(asmjit::X86Assembler &as) const { return jump(as, asmjit::X86Inst::kIdJmp); }
        asmjit::Error je(asmjit::X86Assembler &as) const { return jump(as, asmjit::X86Inst::kIdJe); }
        asmjit::Error jnz(asmjit::X86Assembler &as) const { return jump(as, asmjit::X86Inst::kIdJnz); }
        asmjit::Error jae(asmjit::X86Assembler &as) const { return jump(as, asmjit::X86Inst::kIdJae); }
    };

    std::vector<LabelAddr*> active_addrs;
    std::map<uint64_t, LabelAddr*> address_map;

    void new_label_addr(LabelAddr *paddr, const std::string &name);
    void finalize_label_addrs(uint8_t *base);

    // Tracking of jump tables for switches
    typedef std::map<uint64_t*, std::vector<asmjit::Label>> T_pending_jumptables;
    T_pending_jumptables pending_jumptables;

    asmjit::X86Mem alloc_jumptable(const std::vector<asmjit::Label> &table);
    void finalize_jumptables(uint8_t *base);

    // Tracking of helper functions for accessing fields, keyed by field type and byte offset
    struct StructFieldAccessor {
        typedef shared_ptr<StructFieldAccessor> Ptr;
        typedef std::pair<DataTag, int> Key;
        typedef std::map<Key, Ptr> Map;

        const Key key;
        LabelAddr fn_read, fn_write;

        StructFieldAccessor(Key k) : key(k) {}
    };

    StructFieldAccessor::Map struct_field_accessors;
    StructFieldAccessor::Ptr get_field_accessor(DataTag type, int offset);

    // Tracking of lookup tables from struct id to the appropriate field accessor
    struct StructAccessorTable {
        typedef shared_ptr<StructAccessorTable> Ptr;

        const bool is_reader;
        const std::string name;

        uint64_t *table_data;
        LabelAddr fn_fail;
        std::vector<StructFieldAccessor::Ptr> table;

        StructAccessorTable(bool r, std::string n) : is_reader(r), name(n) {}
    };

    std::map<std::string, StructAccessorTable::Ptr> struct_field_readers_name, struct_field_writers_name;
    std::map<int, StructAccessorTable::Ptr> struct_field_readers_idx, struct_field_writers_idx;

    // Struct information
    struct StructInfo {
        typedef shared_ptr<StructInfo> Ptr;

        // true index and comparison key
        int index, compare_idx;

        unsigned num_fields;
        unsigned byte_size;

        std::string name;
        StackSlot name_string;

        // address of the unique instance for fieldless structs
        uint32_t empty_addr;

        uint64_t type_tag;

        // helpers to convert between array of slots and packed struct
        LabelAddr cb_pack, cb_unpack;

        // field information
        std::vector<std::string> field_names;
        std::vector<std::vector<FieldType> > field_types;
        std::vector<char> is_mutable;

        std::vector<FlowStructFieldDef> field_defs;
        std::vector<FlowStructFieldGCDef> field_gcdefs;

        std::vector<StructFieldAccessor::Ptr> field_accessors;

        StructInfo(int compare_idx) : index(-1), compare_idx(compare_idx) {}

        static bool compare_fieldcnt(const StructInfo::Ptr &a, const StructInfo::Ptr &b) { return a->num_fields > b->num_fields; }
    };

    std::vector<StructInfo::Ptr> structs;
    std::map<int, StructInfo::Ptr> struct_by_id;
    std::vector<int> struct_fcnt_limits;

    StackSlot *struct_name_table;

    // Functions
    struct FunctionInfo {
        typedef shared_ptr<FunctionInfo> Ptr;

        int index;
        FlowPtr start, end;
        FlowInstruction *definer;
        std::string name;
        int num_args;

        std::string native_name;
        FunctionInfo::Ptr native_fallback;

        LabelAddr addr;

        FunctionInfo(int i, FlowPtr s, FlowPtr e, FlowInstruction *def, std::string n) : index(i), start(s), end(e), definer(def), name(n), num_args(0) {}
    };

    std::vector<FunctionInfo::Ptr> functions;
    std::map<FlowPtr, FunctionInfo::Ptr> function_map;
    std::map<FlowPtr, FunctionInfo::Ptr> native_function_map;
    std::set<FlowPtr> function_skip_map;

    void init_runner_funcs(ByteCodeRunner *runner);
    void init_runner_structs(ByteCodeRunner *runner);

    // Global initializers
    struct GlobalInfo {
        typedef shared_ptr<GlobalInfo> Ptr;

        int index;
        std::string name;
        FlowPtr start, end;

        LabelAddr init_addr;
        T_bytecode_list init_code;

        FunctionInfo::Ptr global_fn;

        GlobalInfo(int i, FlowPtr s, std::string n) : index(i), name(n), start(s) {}
    };

    std::vector<GlobalInfo::Ptr> globals;

    // Asmjit objects
    std::string log_filename;
    asmjit::FileLogger asm_logger;
    asmjit::CodeInfo asm_codeinfo;
    asmjit::CodeHolder asm_holder;
    asmjit::X86Assembler as;

    // Global entry points
    NativeFunctionPtr entry_thunk_ptr;
    void *invalid_native_ptr, *generic_native_ptr;
    LabelAddr entry_thunk, unwind_flow, invalid_native_fn, generic_native_fn;

    // Helper for generating safety checks, with the failure handlers deferred to the end of function
    class CheckAssembler {
        FlowJitProgram *owner;

        typedef std::map<std::pair<uint32_t,DataTag>, asmjit::Label> T_type_trampolines;
        T_type_trampolines type_trampolines;

        typedef std::map<uint32_t, asmjit::Label> T_funcidx_trampolines;
        T_funcidx_trampolines funcidx_trampolines;

        typedef std::map<std::pair<uint32_t,uint32_t>, asmjit::Label> T_arridx_trampolines;
        T_arridx_trampolines arridx_trampolines;

        typedef std::map<std::pair<uint32_t,StructAccessorTable::Ptr>, asmjit::Label> T_structidx_trampolines;
        T_structidx_trampolines structidx_trampolines;
    public:
        CheckAssembler(FlowJitProgram *o) : owner(o) {}

        void asm_check_tag(asmjit::X86Gp input, unsigned mask, unsigned check, DataTag tag, asmjit::X86Gp tmp);
        void asm_check_double(asmjit::X86Gp input, asmjit::X86Gp tmp);
        void asm_check_funcidx(asmjit::X86Gp idx, asmjit::X86Gp value);
        void asm_check_arridx(asmjit::X86Gp idx, asmjit::X86Gp limit);
        void asm_check_structidx(asmjit::X86Gp idx, asmjit::X86Gp value, StructAccessorTable::Ptr table);

        void flush(bool use_jmp = false);
        bool needs_flush();
    };

	std::tuple<bool, uint64_t> compile();
    bool disassemble();

    bool find_functions();
    bool find_global_inits();
    bool find_structs();

    void extract_function_code(T_bytecode_list *plist, FlowPtr start, FlowPtr end);

    void asm_enter_frame();
    void asm_leave_frame(bool ret = true);

    void asm_leave_flow();
    void asm_enter_flow(bool check_error = true);

    void asm_decode_funcidx(asmjit::X86Gp idx, asmjit::X86Gp value, CheckAssembler &checker);
    void asm_decode_arrdim(asmjit::X86Gp ptr, asmjit::X86Gp size, asmjit::X86Gp src);

    void assemble_fail_func(StructAccessorTable::Ptr table);
    void assemble_field_read(DataTag tag, int offset);
    void assemble_field_write(DataTag tag, int offset, CheckAssembler &checker);

    void assemble_utilities();
    void assemble_struct_fields();
    void assemble_entry_thunk();

    void link_struct_tables();
    void link_accessor_table(StructAccessorTable::Ptr table);

    LabelAddr thunk_type_error, thunk_func_error, thunk_field_error, thunk_arridx_error;
    LabelAddr thunk_register_slot_write, thunk_register_ref_write;
    LabelAddr thunk_compare, thunk_plus_string, thunk_uncaught_switch, thunk_freeze_globals;

    static void callback_type_error(ByteCodeRunner *runner, StackSlot value, DataTag tag);
    static void callback_func_error(ByteCodeRunner *runner, StackSlot value);
    static void callback_field_error(ByteCodeRunner *runner, StackSlot value, StructAccessorTable *table);
    static void callback_arridx_error(ByteCodeRunner *runner, int access, uint32_t size);
    static uint64_t callback_allocate(ByteCodeRunner *runner, uint32_t size);
    static void callback_register_slot_write(ByteCodeRunner *runner, uint32_t addr, int count);
    static void callback_register_ref_write(ByteCodeRunner *runner, uint32_t addr);
    static void callback_register_struct_write(ByteCodeRunner *runner, uint32_t addr);
    static void callback_uncaught_switch(ByteCodeRunner *runner);
    static void callback_freeze_globals(ByteCodeRunner *runner);

    LabelAddr util_allocate, util_init_array, util_init_closure, util_init_ref, util_pre_struct_write;
    LabelAddr util_add, util_sub, util_mul, util_div, util_mod, util_neg, util_double2string, util_int2string;

    void assemble_util_allocate();
    void assemble_util_init_array(bool closure);
    void assemble_util_init_ref();
    void assemble_util_pre_struct_write();
    void assemble_math_ops();

    void assemble_assign_args(asmjit::X86Gp arg1, asmjit::X86Gp arg2, asmjit::X86Gp arg3);
    void asm_cpp_call(void *callable);
    void assemble_cpp_call_thunk(void *callable, asmjit::X86Gp arg1, asmjit::X86Gp arg2, asmjit::X86Gp arg3, bool unwind = false);
    void assemble_compare_thunk();
    void assemble_plus_string_thunk();
    void assemble_native_call_thunk(int index, int nargs);
    void assemble_generic_native_thunk();
    bool assemble_native_substitute(const std::string &name);

    struct FunctionAssembler {
        FlowJitProgram *owner;

        asmjit::X86Assembler &as;
        CheckAssembler checker;

        const T_bytecode_list &code_in;
        T_bytecode_list code;
        FlowPtr end_addr;

        bool is_closure;
        int num_args, num_locals;

        std::map<FlowPtr, T_bytecode_list> closure_args;
        std::map<FlowPtr, asmjit::Label> jump_targets;
        std::vector<bool> is_jumped_to, keep_rax_top;

        FunctionAssembler(FlowJitProgram *owner, const T_bytecode_list &code, FlowPtr end_addr);

        void enter_func(bool is_closure, int num_args, int num_locals);

    private:
        struct CurPos {
            // Next instruction index
            size_t iidx;
            // Input stack top is in rax
            bool in_rax_top;
            // Input stack top in rax was consumed
            bool used_in_rax;
            // Output stack top should be in rax
            bool rq_rax_top;
            // Output stack top was placed in rax
            bool out_rax_top;
        };

        void can_use_rax(FlowInstruction::Pair *pinsn, bool *can_input_rax, bool *can_output_rax);

        void asm_stack_to_rax(CurPos *cpos);
        void asm_rax_to_stack(CurPos *cpos, int bias = 0);
        void asm_void_to_stack(CurPos *cpos, int bias = 0);
        void asm_push_to_stack(CurPos *cpos, int bias, FlowInstruction::Pair *pinsn, uint64_t rax_value, bool rax_fixed);

        void asm_pop_rax();
        void asm_push_rax();

        void asm_compare(
                CurPos *cpos, asmjit::X86Inst::Id testid, const asmjit::Operand &opa, const asmjit::Operand &opb,
                asmjit::X86Inst::Id setid, asmjit::X86Inst::Id jmpid, asmjit::X86Inst::Id isetid, asmjit::X86Inst::Id ijmpid);

        typedef std::map<int,asmjit::Label> T_swtable;
        void asm_switch(const T_swtable &swtable, asmjit::X86Gp reg, asmjit::Label def);
        bool asm_call_global_fn(CurPos *cpos, FunctionInfo::Ptr global_fn, int stack_bias = 0);

        void partition_swtable(std::map<int,T_swtable> &out, const T_swtable &swtable);
        void generate_switch(const std::map<int,T_swtable> &bintree, const std::vector<int> &binlist, size_t l, size_t r, int last_cmp, asmjit::Label def, asmjit::X86Gp reg);

    public:
        void preprocess();
        void generate();

    private:
        bool can_peephole_to(size_t i);
        bool can_peephole_next_op(size_t i, OpCode op);
        FlowInstruction::Pair *next_insn(CurPos *cpos, bool peephole = false);
        void copy_tailcall_args(int nargs);
    };

    void assemble_functions();
    void assemble_global_init();

    virtual bool handleError(asmjit::Error err, const char* message, asmjit::CodeEmitter* origin);

public:
	FlowJitProgram(ostream &err, const std::string &log_name = std::string(), uint64_t memoryLimit = MAX_CODE_MEMORY);
    ~FlowJitProgram();

	static const unsigned MAX_CODE_MEMORY = 256*1024*1024;

	std::tuple<bool, uint64_t> Load(const std::string &bytecode_file);

    void InitRunner(ByteCodeRunner *runner);
    void ResetRunner(ByteCodeRunner *runner);

    StackSlot GetMainFunction();
    std::string AddressToFunction(FlowPtr code);
    void ParseCallstack(std::vector<FlowStackFrame> *vec, ByteCodeRunner *runner);

    void RegisterNative(ByteCodeRunner *runner, unsigned id, NativeFunction *fn);
    void FreeNative(ByteCodeRunner *runner, unsigned id);
};

#endif
