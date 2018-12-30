#ifndef _HEAP_WALKER_H_
#define _HEAP_WALKER_H_

#include "ByteCodeRunner.h"

struct FlowVarReference {
    enum {
        R_SLOT = 0
#ifdef FLOW_COMPACT_STRUCTS
        ,R_FIELD = 1
#endif
    } type;

    union {
        StackSlot *slot;
#ifdef FLOW_COMPACT_STRUCTS
        struct {
            FlowStructHeader *obj;
            const FlowStructFieldDef *def;
            ByteCodeRunner *runner;
        } field;
#endif
    };

    FlowVarReference(const StackSlot *p = NULL) : type(R_SLOT) { slot = const_cast<StackSlot*>(p); }

#ifdef FLOW_COMPACT_STRUCTS
    FlowVarReference(ByteCodeRunner *runner, FlowStructHeader *obj, const FlowStructFieldDef *fd)
        : type(R_FIELD)
    {
        field.obj = obj; field.def = fd; field.runner = runner;
    }
#endif

    operator void* () { return slot; }

    StackSlot get() {
        switch (type) {
#ifdef FLOW_COMPACT_STRUCTS
        case R_FIELD: return field.def->fn_get(field.obj->Bytes + field.def->offset, field.runner);
#endif
        default: return *slot;
        }
    }
    bool set(const StackSlot &val) {
        switch (type) {
#ifdef FLOW_COMPACT_STRUCTS
        case R_FIELD:
            if (field.def->fn_set(field.obj->Bytes + field.def->offset, val))
                field.runner->RegisterWrite(field.obj);
            else
                return false;
#endif
        default: *slot = val;
        }
        return true;
    }
};

class HeapWalker : private GarbageCollectorFnCallback
{
    ByteCodeRunner *Runner;
    ByteMemory *Memory;
    char *MemoryBuffer;

    FlowPtr HeapStart, HeapEnd;
    void *pHeapStart, *pHeapEnd;

    StructDef *StructDefs;
    unsigned NumStructDefs;

public:
    HeapWalker(ByteCodeRunner *Runner);
    virtual ~HeapWalker();

    ByteCodeRunner *getFlowRunner() const { return Runner; }

    bool IsHeapPtr(FlowPtr i) {
        return i >= HeapStart && i < HeapEnd;
    }
    bool IsHeapPtr(void *ptr) {
        return ptr >= pHeapStart && ptr < pHeapEnd;
    }

    virtual void Process(FlowPtr ptr);
    virtual void Process(StackSlot &slot);
    virtual void Process(FlowNativeObject *obj);

    void ProcessRoots() {
        ProcessGlobalRoots();
        ProcessStackRoots();
        ProcessNativeRoots();
    }

    void ProcessGlobalRoots();
    void ProcessStackRoots();
    void ProcessNativeRoots();

    void ProcessRefs(FlowNativeObject *obj);

    void ProcessArray(FlowPtr ptr, int count);
    void ProcessArray(StackSlot *slot, int count);

    virtual void VisitError(StackSlot &) {}

    virtual void VisitSlot(StackSlot &) {}

    virtual void VisitScalar(StackSlot &val) { VisitSlot(val); }
    virtual void VisitString(StackSlot &val, unicode_char *, int /*size*/) { VisitSlot(val); }

    virtual void VisitSlotVector(StackSlot &val, StackSlot *, int /*size*/) {
        if (!val.IsNativeFn()) VisitSlot(val); // ugh, but seems necessary
    }

    virtual void VisitRef(StackSlot &ref, StackSlot *data) {
        VisitSlotVector(ref, data, 1);
    }
    virtual void VisitArray(StackSlot &ref, StackSlot *data, int size) {
        VisitSlotVector(ref, data, size);
    }
    virtual void VisitClosure(StackSlot &ref, StackSlot *data, int size) {
        VisitSlotVector(ref, data, size);
    }

#ifdef FLOW_COMPACT_STRUCTS
    bool ProcessFields(FlowStructHeader *obj, StructDef *type, bool write_back = false);

    virtual void VisitStruct(StackSlot &ref, FlowStructHeader* /*data*/, int /*size*/, StructDef* /*type*/) {
        VisitSlot(ref);
    }
#else
    virtual void VisitStruct(StackSlot &ref, StackSlot *data, int size, StructDef */*type*/) {
        VisitSlotVector(ref, data, size);
    }
#endif

    virtual void VisitNative(StackSlot &val, void *) { VisitSlot(val); }
    virtual void VisitNativeValue(StackSlot &val, AbstractNativeValue *obj) { VisitNative(val, obj); }
    virtual void VisitNativeObj(StackSlot &val, FlowNativeObject *obj) { VisitNative(val, obj); }

    virtual void VisitNativeFun(StackSlot &val, NativeFunction *obj, StackSlot *data, int size) {
        VisitNative(val, obj);
        VisitSlotVector(val, data, size);
    }
};

class RecursiveHeapWalker : public HeapWalker {
protected:
    typedef STL_HASH_SET<void*> T_SeenMap;
    T_SeenMap SeenMap;

public:
    RecursiveHeapWalker(ByteCodeRunner *Runner) : HeapWalker(Runner) {}

    const T_SeenMap &GetSeen() { return SeenMap; }

    bool IsSeen(void *obj) { return SeenMap.count(obj) != 0; }
    bool MarkSeen(void *obj) { return obj && SeenMap.insert(obj).second; }

    void VisitSlotVector(StackSlot &val, StackSlot *data, int size) {
        HeapWalker::VisitSlotVector(val, data, size);

        if (IsHeapPtr(data) && MarkSeen(data))
            ProcessArray(data, size);
    }

#ifdef FLOW_COMPACT_STRUCTS
    void VisitStruct(StackSlot &ref, FlowStructHeader *data, int size, StructDef *def)
    {
        HeapWalker::VisitStruct(ref, data, size, def);

        if (IsHeapPtr(data) && MarkSeen(data))
            ProcessFields(data, def);
    }
#endif

    void VisitNativeObj(StackSlot &val, FlowNativeObject *obj) {
        HeapWalker::VisitNativeObj(val, obj);

        if (MarkSeen(obj))
            ProcessRefs(obj);
    }
};

class StatisticsHeapWalker : public RecursiveHeapWalker {
protected:
    AddrIntervalSet StringRanges;
    std::vector<int> StructBytes;
    std::map<int,int> ClosureBytes;

    void CountArr(int &counter, void *key, int numslots) {
        if (IsHeapPtr(key) && !IsSeen(key))
            counter += numslots;
    }

public:
    int NumRefs, NumArraySlots, NumClosureSlots, NumStructSlots, NumNatives;

    int GetStringBytes() { return StringRanges.getTotalSize(); }
#ifdef FLOW_COMPACT_STRUCTS
    int GetSlotBytes() { return (NumRefs + NumArraySlots + NumClosureSlots + NumNatives) * STACK_SLOT_SIZE + NumStructSlots; }
#else
    int GetSlotBytes() { return (NumRefs + NumArraySlots + NumClosureSlots + NumStructSlots + NumNatives) * STACK_SLOT_SIZE; }
#endif
    const std::vector<int> &GetStructBytes() { return StructBytes; }
    const std::map<int,int> &GetClosureBytes() { return ClosureBytes; }

    StatisticsHeapWalker(ByteCodeRunner *Runner) : RecursiveHeapWalker(Runner) {
        NumRefs = NumArraySlots = NumClosureSlots = NumStructSlots = NumNatives = 0;
        StructBytes.resize(Runner->GetStructDefs().size());
    }

    virtual void VisitString(StackSlot &ref, unicode_char *data, int size) {
        if (data) {
            FlowPtr ptr = getFlowRunner()->GetStringAddr(ref);
            StringRanges.addInterval(ptr, ptr + size*FLOW_CHAR_SIZE);
        }
        RecursiveHeapWalker::VisitString(ref, data, size);
    }

    virtual void VisitRef(StackSlot &ref, StackSlot *data) {
        CountArr(NumRefs, data, 1);
        RecursiveHeapWalker::VisitRef(ref, data);
    }
    virtual void VisitArray(StackSlot &ref, StackSlot *data, int size) {
        CountArr(NumArraySlots, data, size);
        RecursiveHeapWalker::VisitArray(ref, data, size);
    }
    virtual void VisitClosure(StackSlot &ref, StackSlot *data, int size) {
        if (IsHeapPtr(data) && !IsSeen(data))
        {
            NumClosureSlots += size;
            ClosureBytes[FlowPtrToInt(getFlowRunner()->GetCodePointer(ref))] += size*STACK_SLOT_SIZE;
        }
        RecursiveHeapWalker::VisitClosure(ref, data, size);
    }
#ifdef FLOW_COMPACT_STRUCTS
    virtual void VisitStruct(StackSlot &ref, FlowStructHeader *data, int size, StructDef *type) {
#else
    virtual void VisitStruct(StackSlot &ref, StackSlot *data, int size, StructDef *type) {
#endif
        if (IsHeapPtr(data) && !IsSeen(data))
        {
#ifdef FLOW_COMPACT_STRUCTS
            NumStructSlots += type->ByteSize;
            StructBytes[ref.GetStructId()] += type->ByteSize;
#else
            NumStructSlots += size;
            StructBytes[ref.GetStructId()] += size * STACK_SLOT_SIZE;
#endif
        }
        RecursiveHeapWalker::VisitStruct(ref, data, size, type);
    }

    virtual void VisitNative(StackSlot &ref, void *obj) {
        CountArr(NumNatives, obj, 1);
        RecursiveHeapWalker::VisitNative(ref, obj);
    }
};

#endif
