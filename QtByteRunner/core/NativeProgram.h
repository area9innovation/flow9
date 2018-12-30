#ifndef NATIVEPROGRAM_H
#define NATIVEPROGRAM_H

#include "ByteCodeRunner.h"

#include <math.h>

/*
 * Infrastructure for flow-to-C++ compiled code.
 */

namespace flowgen_common {
    extern StackSlot error_stub_slot;
/*
    __attribute__((always_inline))
    inline StackSlot AllocStruct(ByteCodeRunner *runner, int id, int size, StackSlot *data) {
        FlowPtr arr = size ? runner->AllocateArrayBuffer(size, data) : MakeFlowPtr(0);
        return StackSlot::MakeStruct(arr, id);
    }
*/
    inline const StackSlot &DerefArray(ByteCodeRunner *runner, const StackSlot &arr, int index) {
        if (unlikely(unsigned(index) >= unsigned(runner->GetArraySize(arr)))) {
            runner->ReportError(InvalidArgument, "Array index out of bounds: %d", index);
            return error_stub_slot;
        }
        else return runner->GetArraySlot(arr, index);
    }
}

#ifdef FLOW_COMPACT_STRUCTS
namespace flow_struct {
    inline StackSlot get_slot(const StackSlot &val) { return val; }
    inline void set_slot(StackSlot &place, const StackSlot &val) { place = val; }
    inline StackSlot get_int(int val) { return StackSlot::MakeInt(val); }
    inline void set_int(int &place, const StackSlot &val) { place = val.GetInt(); }
    inline StackSlot get_bool(char val) { return StackSlot::MakeBool(val); }
    inline void set_bool(char &place, const StackSlot &val) { place = (char)val.GetBool(); }
    inline StackSlot get_double(double val) { return StackSlot::MakeDouble(val); }
    inline void set_double(double &place, const StackSlot &val) { place = val.GetDouble(); }
#if 0
    inline StackSlot get_array(const FlowStructArray &val) { return StackSlot::MakeArray(val.addr, val.size); }
    inline void set_array(FlowStructArray &place, const StackSlot &val) { place.addr = val.GetInternalArrayPtr(); place.size = val.GetInternalArraySize(); }
    inline StackSlot get_string(const FlowStructString &val) { return StackSlot::MakeString(val.addr, val.size); }
    inline void set_string(FlowStructString &place, const StackSlot &val) { place.addr = val.GetInternalStringPtr(); place.size = val.GetInternalStringSize(); }
    inline StackSlot get_ref(const FlowStructRef &val) { return StackSlot::MakeRefTo(val.addr, val.id); }
    inline void set_ref(FlowStructRef &place, const StackSlot &val) { place.addr = val.GetRawRefPtr(); place.id = val.GetInternalRefId(); }
#else
    inline StackSlot get_array(const StackSlot &val) { return val; }
    inline void set_array(StackSlot &place, const StackSlot &val) { place = val; }
    inline StackSlot get_string(const StackSlot &val) { return val; }
    inline void set_string(StackSlot &place, const StackSlot &val) { place = val; }
    inline StackSlot get_ref(const StackSlot &val) { return val; }
    inline void set_ref(StackSlot &place, const StackSlot &val) { place = val; }
#endif
    inline StackSlot get_struct(FlowPtr val, ByteCodeRunner *runner) {
        return StackSlot::MakeStruct(val, runner->GetMemory()->GetStructPointer(val,false)->StructId);
    }
    inline void set_struct(FlowPtr &place, const StackSlot &val) { place = val.GetRawStructPtr(); }
}
namespace flow_fields {
    const DataTag tag_int = TInt;
    StackSlot get_int(const void *p,ByteCodeRunner*);
    bool set_int(void *p, const StackSlot &v);
    const DataTag tag_bool = TBool;
    StackSlot get_bool(const void *p,ByteCodeRunner*);
    bool set_bool(void *p, const StackSlot &v);
    const DataTag tag_double = TDouble;
    StackSlot get_double(const void *p,ByteCodeRunner*);
    bool set_double(void *p, const StackSlot &v);
    const DataTag tag_slot = TVoid;
    StackSlot get_slot(const void *p,ByteCodeRunner*);
    bool set_slot(void *p, const StackSlot &v);
    const DataTag tag_array = TArray;
    StackSlot get_array(const void *p,ByteCodeRunner*);
    bool set_array(void *p, const StackSlot &v);
    const DataTag tag_string = TString;
    StackSlot get_string(const void *p,ByteCodeRunner*);
    bool set_string(void *p, const StackSlot &v);
    const DataTag tag_ref = TRefTo;
    StackSlot get_ref(const void *p,ByteCodeRunner*);
    bool set_ref(void *p, const StackSlot &v);
    const DataTag tag_struct = TStruct;
    StackSlot get_struct(const void *p,ByteCodeRunner*);
    bool set_struct(void *p, const StackSlot &v);
#define FLOW_FIELD_DEF(type,offset) \
    { int(offset), flow_fields::tag_##type, flow_fields::get_##type, flow_fields::set_##type }
}
#endif


#if 1
// Use in-place new to avoid creation of a temporary with subsequent use of operator=.
// The address of retslot will be passed into the function as the output object.
// Beware of possible lifetime conflicts if the retslot is also used to store an argument.
#define CALL_WITH_RETSLOT(retslot,call) (new (&retslot) StackSlot(call))
#else
#define CALL_WITH_RETSLOT(retslot,call) (retslot = call)
#endif

class NativeProgram {
    friend class ByteCodeRunner;
    ByteCodeRunner *owner;

protected:
    friend class GarbageCollector;
    friend class HeapWalker;
    virtual void flowGCObject(GarbageCollectorFn) {}

    NativeProgram() : owner(NULL) {}
    virtual ~NativeProgram() { if (owner) owner->Program = NULL; }

    virtual const char *getByteCode(int* /*length*/) = 0;

    virtual void onRunnerAttach() {}
    virtual void onRunnerDetach() {}

    virtual void onRunMain() = 0;

public:
    struct FunctionSpec {
        const char *name;
        const char *native_name;
        int num_args;
        NativeFunctionPtr code;
    };

    struct StructSpec {
        unsigned num_fields;
        int compare_idx;
        unsigned name_size;
        unsigned name_addr;
#ifdef FLOW_COMPACT_STRUCTS
        unsigned byte_size;
        unsigned empty_addr;
        unsigned num_gcdefs;
#endif
        const char *name;
        const char *const *field_names;
        const int *field_type_info;
#ifdef FLOW_COMPACT_STRUCTS
        const FlowStructFieldDef *field_defs;
        const FlowStructFieldGCDef *field_gcdefs;
#endif
    };

protected:
    bool InitFunctionTable(StackSlot *out, const FunctionSpec *in, unsigned count);
    bool InitStructTable(const StructSpec *in, unsigned count);

public:
    ByteCodeRunner *getFlowRunner() const { return owner; }
};

#endif // NATIVEPROGRAM_H
