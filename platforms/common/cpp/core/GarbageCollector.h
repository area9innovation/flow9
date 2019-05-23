#ifndef _GARBAGE_COLLECTOR_H_
#define _GARBAGE_COLLECTOR_H_

#include "ByteCodeRunner.h"

/*
 * Two generation copying garbage collector for the flow runner.
 *
 * Manages garbage collection of the flow heap and native objects
 * owned by flow. Supports and preserves partial sharing of string
 * data buffers between multiple strings (i.e. O(1) non-copying
 * substring operation).
 *
 * Allows the following kinds of root references:
 *
 * 1. Data and call stacks of the flow runner, which contain
 *    globals and currently active locals & closure references.
 *
 * 2. Slot values stored using ByteCodeRunner::RegisterRoot(),
 *    and some other internal tables like the deferred action queue.
 *
 * 3. Fields exposed to GC by native method hosts via implementing
 *    the NativeMethodHost::flowGCObject() virtual method.
 *
 * 4. Local variables of native methods, which are exposed to GC via
 *    a linked list mantained by macros defined in RunnerMacros.h
 *    (NOTE: see comments there for instructions on their proper use!).
 *
 * Native objects that inherit from FlowNativeObject can also implement
 * a flowGCObject virtual method. This allows native objects that are
 * found alive to retain references to other flow values in their fields.
 * It is not a kind of root, because without a reference from elsewhere
 * the native object and then its references will be collected.
 */

#ifdef FLOW_COMPACT_STRUCTS
namespace flow_fields {
    void enum_slot(GarbageCollector*, const void*);
    void gc_slot(GarbageCollector*, void*);
    void enum_array(GarbageCollector*, const void*);
    void gc_array(GarbageCollector*, void*);
    void enum_string(GarbageCollector*, const void*);
    void gc_string(GarbageCollector*, void*);
    void enum_ref(GarbageCollector*, const void*);
    void gc_ref(GarbageCollector*, void*);
    void enum_struct(GarbageCollector*, const void*);
    void gc_struct(GarbageCollector*, void*);
#define FLOW_FIELD_GC_DEF(type,offset) \
    { int(offset), flow_fields::enum_##type, flow_fields::gc_##type }
}
#endif

class GarbageCollector : private GarbageCollectorFnCallback
{
    char *MemoryBuffer;
    ByteMemory *Memory;
    ByteCodeRunner *Runner;

    // The heap pointer in the new heap half
    FlowPtr hp_big_pos, hp_ref_end;

    HeapLimits OldLimits;
    FlowPtr HeapStart, HeapEnd;

    // GC phase state
    bool inEnumPhase, inFastGC;

    // Statistics
    int NumRefs, NumSlots, NumClosures, NumLongStrings, NumObjects;
#ifdef FLOW_COMPACT_STRUCTS
    int NumStructBytes;
#endif

    // GC tag tracking
    T_GC_Tag CurTag, LastTag, MaxOKTag;

    // Struct info
    StructDef *StructDefs;
    unsigned *StructSizes;
    unsigned NumStructDefs;

    // Object movement map; used for strings, or for all objects if gc profiling is on
    typedef STL_HASH_MAP<FlowPtr, FlowPtr> T_AddressMap;
    T_AddressMap AddressMap;

    // Address ranges of live strings
    AddrIntervalSet StringRanges;

    // GC memory walk recursion stack
    typedef std::pair<FlowPtr, int> TArrayDim;
    FlowStack<TArrayDim, 16384> ArrayStack;

#ifdef DEBUG_FLOW
    unsigned MaxStackDepth;
#endif

    typedef STL_HASH_SET<int> T_LiveTable;

    // Which native values are alive?
    T_LiveTable NativeValuesAlive;
    int NativeGCGenBarrier;

    // Which native functions are alive?
    T_LiveTable NativeFunctionsAlive;

    void ReportTagError(int tag);

public:
    GarbageCollector(ByteCodeRunner *rnr);

    static const int MAX_SPECIAL_TAG = 2;

    bool CollectFast();
    bool Collect(unsigned ensure_space);

    int ComputeNativeBudget();

#ifdef FLOW_GARBAGE_PROFILING
    std::map<int,int> CollectedObjects, CollectedBytes;
    void UpdateProfileInfo();
    void PrintStats(ostream &out, std::string fname, int FirstNewID);
#endif

    // Heap limits
    HeapLimits NewLimits;

    const T_LiveTable &GetLiveValues() { return NativeValuesAlive; }
    const T_LiveTable &GetLiveFunctions() { return NativeFunctionsAlive; }

private:
    friend class GarbageCollectorFn;

    void EnumPhaseTag(T_GC_Tag tag);
    void NextTag();

    int ComputeLiveBytes();
    bool DoubleHeap();

    void UpdateRunnerHeap();

    void ProcessRoots();
    void ProcessFullRoots();
    void ProcessFastRoots();
    void ProcessVector(StackSlot *start, unsigned size);

    void Process(StackSlot &ptr) {
        if (inEnumPhase)
            Enumerate(ptr);
        else
            Collect(ptr);
    }

    void Process(FlowNativeObject *obj) {
        if (!obj) return;
        obj->getFlowValue();
        if (obj->id_tag == CurTag) return;
        Process(obj->id_slot);
    }

    void FlushArrays() {
        if (ArrayStack.empty()) return;
        if (inEnumPhase)
            EnumerateArrays();
        else
            CollectArrays();
    }

    // Enumeration phase
    void Enumerate(const StackSlot &slot);
    void EnumerateArrays();

    // Copy a value (always stackslot size)
    void Collect(StackSlot &value);
    void CollectArrays();

    void ProcessNativeFunction(int id);
    void ProcessNativeValue(int id);
    void ProcessNativeValue(AbstractNativeValue *obj);

    void EnumerateString(const StackSlot &value);
    void EnumerateArray(const StackSlot &value);
    void EnumerateRef(const StackSlot &value);

    void EnumerateArray(FlowPtr a, unsigned size, bool closure = false);
    void EnumerateRef(FlowPtr a);

    void CollectString(StackSlot &value);
    void CollectArray(StackSlot &value);
    void CollectRef(StackSlot &value);

    FlowPtr CollectString(FlowPtr a);
    FlowPtr CollectArray(FlowPtr a, unsigned size, bool closure = false);
    FlowPtr CollectRef(FlowPtr a);

#ifdef FLOW_COMPACT_STRUCTS
    void EnumerateStruct(FlowPtr a, bool closure = false);
    FlowPtr CollectStruct(FlowPtr a, bool closure = false);
#endif


    void Copy(FlowPtr from, FlowPtr to, int bytes) {
        Memory->Copy(from, to, bytes);
    }

    FlowPtr AllocFailure(int bytes);

    FlowPtr Allocate(int bytes) {
        if (unlikely(bytes < 0))
            return AllocFailure(bytes);
        hp_big_pos = FlowPtrAlignDown(hp_big_pos - bytes, 4);
        if (unlikely(hp_big_pos < hp_ref_end))
            return AllocFailure(bytes);
        return hp_big_pos;
    }

    FlowPtr AllocateRef() {
        FlowPtr rv = hp_ref_end;
        hp_ref_end = FlowPtrAlignUp(hp_ref_end + sizeof(FlowHeapRef), 4);
        if (unlikely(hp_big_pos < hp_ref_end))
            return AllocFailure(sizeof(FlowHeapRef));
        return rv;
    }

    bool IsHeapPtr(FlowPtr i) {
        return i >= HeapStart && i < HeapEnd;
    }

#ifdef FLOW_COMPACT_STRUCTS
    friend void flow_fields::enum_slot(GarbageCollector*, const void*);
    friend void flow_fields::gc_slot(GarbageCollector*, void*);
    friend void flow_fields::enum_array(GarbageCollector*, const void*);
    friend void flow_fields::gc_array(GarbageCollector*, void*);
    friend void flow_fields::enum_string(GarbageCollector*, const void*);
    friend void flow_fields::gc_string(GarbageCollector*, void*);
    friend void flow_fields::enum_ref(GarbageCollector*, const void*);
    friend void flow_fields::gc_ref(GarbageCollector*, void*);
    friend void flow_fields::enum_struct(GarbageCollector*, const void*);
    friend void flow_fields::gc_struct(GarbageCollector*, void*);
#endif
};

#endif
