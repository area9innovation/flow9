#include "ByteCodeRunner.h"
#include "GarbageCollector.h"
#include "NativeProgram.h"

#include <string.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

/*
 * Flow GC is at its core a copying garbage collector, which was extended to support
 * two generations of objects, and allow partially shared string buffers. The latter
 * feature requires doing two passes over objects.
 *
 * Flow memory layout:
 *
 * +-------------+------+--------------------------+------+--------------------------+--------------+----
 * | code        | new1 | old-gen 1                | new2 | old-gen 2                | reserved...  | mmap...
 * |             |   <- | refs>           <objects |    < | refs>           <objects |              |
 * +-------------+------+--------------------------+------+--------------------------+--------------+----
 *                   ^hp      ^hp_ref_end ^hp_big_pos
 *
 * GENERATIONS:
 *
 * There are two identically sized heaps, but outside of full GC only one of them contains
 * valid data and requires actually mapped pages of memory. Heap is expanded when necessary
 * by doubling it into the reserved area until it runs out; this behavior means that after
 * doubling the old pair of heaps becomes heap 1 of the doubled heap.
 *
 * New objects that don't exceed a certain size limit are allocated in the 'new' area
 * of the currently active half-heap. When it is full, a fast GC copies any live objects
 * to the old generation.
 *
 * To make fast GC fast it should work without walking all live objects in the old generation.
 * This doesn't require any additional work except in the case when old objects are actually
 * modified, e.g. via ref or mutable field assignment. This means that writes to the old
 * generation have to be tracked.
 *
 * To make this easier, refs are placed separately from regular objects in the old generation
 * so that write tracking can use a bit mask. For other objects more complicated tables have
 * to be used in the runner.
 *
 * Native objects implementing flowGCObject don't track changes to their fields, so all natives
 * that were alive during previous gc are assumed alive and checked for roots during fast GC.
 *
 * If the old generation doesn't have enough space to perform fast GC, a full GC is performed.
 * In order to do this, memory is committed in the other half-heap, and all objects are walked
 * and copied to the new area as required.
 *
 * Memory areas outside the heap (e.g. code and mmap) can contain flow objects, but they are not
 * walked by gc under assumption that they are immutable, persist for the duration of execution,
 * and don't reference any objects in the heap.
 *
 * STRINGS & TWO PASSES:
 *
 * Supporting O(1) non-copying substring operation in flow complicates the task for GC to the
 * point that it is necessary to perform two passes on the data. The first (enumeration) pass
 * collects a set of all contiguous intervals of memory that are filled with string data; it
 * also counts memory required for other objects, which allows making the decision to do a full
 * GC or double the heap before any objects are actually modified.
 *
 * During the second (collect) pass objects are copied to the new area, ensuring that all string
 * intervals detected by the first pass are copied only once and are not split even if there are
 * strings that refer only to a sub-interval. After copying, the address of the new location of
 * the object is stored by overwriting part of the previous copy of the object to facilitate
 * updating other references to the same source object.
 *
 * GC TAG:
 *
 * All heap objects except string buffers have a header with a GC tag field. This tag is used
 * to track which objects have already been walked during the current GC pass. There are following
 * tag values:
 *
 * 0: new object or possibly a modified regular object in the old generation
 * 1: object that has been walked by fast GC enum pass.
 * 2: object that has been walked by full GC enum pass
 * 3 to max: object that has been processed by collect pass
 *
 * The collect pass tags are changed in a cycle during every full gc as a way to detect heap corruption.
 */


/*
 * Container for efficiently holding a set of values that form continuous intervals.
 */

bool AddrIntervalSet::getInterval(FlowPtr point, range_type *output) const
{
    T_bounds::const_iterator iend = bounds.upper_bound(point);

    if (iend != bounds.end() && iend->second)
    {
        output->second = iend->first;
        --iend;
        output->first = iend->first;
        return true;
    }
    else
        return false;
}

bool AddrIntervalSet::listIntervals(FlowPtr start, FlowPtr end, std::vector<range_type> *output) const
{
    output->clear();

    T_bounds::const_iterator icur = bounds.lower_bound(start);

    if (icur != bounds.end() && icur->second)
    {
        // Started in the middle of a range?
        if (icur->first > start) {
            T_bounds::const_iterator iprev = icur;
            --iprev;
            output->push_back(range_type(iprev->first, icur->first));
        }
        ++icur;
    }

    while (icur != bounds.end() && icur->first < end)
    {
        FlowPtr begin = icur->first;
        ++icur;
        output->push_back(range_type(begin, icur->first));
        ++icur;
    }

    return !output->empty();
}

int AddrIntervalSet::getTotalSize(int align)
{
    int size = 0;

    T_bounds::const_iterator icur = bounds.begin();

    while (icur != bounds.end())
    {
        FlowPtr start = icur->first;
        ++icur;
        size += (icur->first - start + align - 1) & ~(align - 1);
        ++icur;
    }

    return size;
}

void AddrIntervalSet::addInterval(FlowPtr start, FlowPtr end)
{
    if (end <= start)
        return;

    assert(bounds.size()%2 == 0);

    // Find the boundary conditions
    bool start_inside = false;
    bool end_inside = false;

    T_bounds::iterator istart = bounds.lower_bound(start); // start <= x
    if (istart != bounds.end())
    {
        // Skip the start bound that we would have inserted anyway
        if (istart->first == start && !istart->second)
            ++istart;

        // If the start point is already inside, no need to insert
        if (istart->second)
            start_inside = true;
    }

    T_bounds::iterator iend = bounds.lower_bound(end); // end <= x
    if (iend != bounds.end())
    {
        // Eat the start bound exactly at the end of the interval
        if (iend->first == end && !iend->second)
            ++iend;

        if (iend->second)
            end_inside = true;
    }

    // Erase boundaries inside the range
    while (istart != iend)
    {
        T_bounds::iterator tmp = istart;
        ++istart;
        bounds.erase(tmp);
    }

    // Create new boundaries
    if (!start_inside)
        bounds[start] = false;
    if (!end_inside)
        bounds[end] = true;

    assert(bounds.size()%2 == 0);
}

#ifdef DEBUG_FLOW
#define MEMORY_PTR(base,size,write) Memory->GetRawPointer(base,size,write)
#else
#define MEMORY_PTR(base,size,write) (MemoryBuffer + FlowPtrToInt(base))
#endif

#define HEADER_PTR(type,base) ((type*)MEMORY_PTR(base,sizeof(type),false))

GarbageCollector::GarbageCollector(ByteCodeRunner *rnr)
{
    Runner = rnr;
    Memory = rnr->GetMemory();

    StructDefs = Runner->StructDefs.data();
    StructSizes = &Runner->StructSizes[0];
    NumStructDefs = Runner->StructDefs.size();
}

/*
 * Compute the amount of memory required to hold all live objects.
 */
int GarbageCollector::ComputeLiveBytes()
{
    int strbytes = StringRanges.getTotalSize(4);
    int live_bytes = NumRefs * sizeof(FlowHeapRef) + NumSlots * STACK_SLOT_SIZE + NumLongStrings * sizeof(FlowStringRef) + NumObjects * 4 + NumClosures * 4 + strbytes;

#ifdef FLOW_COMPACT_STRUCTS
    live_bytes += NumStructBytes;
#endif

#ifdef DEBUG_FLOW
    cerr << "Live bytes: " << live_bytes << "; "
         << NumRefs << " refs, " << NumSlots << " slots, "
         << NumLongStrings << " long strings, " << NumObjects << " objects, "
#ifdef FLOW_COMPACT_STRUCTS
         << NumStructBytes << " struct bytes, "
#endif
         << strbytes << " string bytes." << endl;
#endif

    return live_bytes;
}

/*
 * To handle the situation when the code allocates very little flow memory but a lot of native objects,
 * allocating a certain amount of natives can also trigger GC even if the heap isn't yet full.
 */
int GarbageCollector::ComputeNativeBudget()
{
    return 1000 + (NumRefs + NumSlots + NumLongStrings + NumObjects) * 100 /*per mb*/ / 88000 + NativeValuesAlive.size();
}

/*
 * Attempt to do a fast GC. Returns false if a full collection is needed.
 */
bool GarbageCollector::CollectFast()
{
    bool currentIsHigh = Runner->highHeap;

    // Init the heap ranges
    NewLimits = OldLimits = Runner->GetHeapLimits(currentIsHigh);
    HeapStart = OldLimits.Bound;
    HeapEnd = OldLimits.Ephemeral;

    hp_ref_end = Runner->hp_ref_end;
    hp_big_pos = Runner->hp_big_pos;

    inFastGC = true;
    NativeGCGenBarrier = Runner->NativeGCGenBarrier;

    MemoryBuffer = (char*)Memory->GetRawPointer(MakeFlowPtr(0), FlowPtrToInt(Runner->HeapEnd), true);

#ifdef DEBUG_FLOW
    MaxStackDepth = 0;
#endif

    // Collect info
    inEnumPhase = true;
    EnumPhaseTag(1);
    ProcessRoots();
    ProcessFastRoots();
    FlushArrays();

    // Check if enough size to do fast gc
    int live_bytes = ComputeLiveBytes();
    if (live_bytes >= int(hp_big_pos - hp_ref_end))
        return false;

    Runner->DataStack.readonly(Runner->NumFrozenDataStack, false);

    // Move live objects
    inEnumPhase = false;
    LastTag = CurTag;
    MaxOKTag = 0;
    CurTag = Runner->NextGCTag;
    ProcessRoots();
    ProcessFastRoots();
    FlushArrays();

    Runner->DataStack.readonly(Runner->NumFrozenDataStack, true);

#ifdef DEBUG_FLOW
    cerr << "Max GC stack depth: " << MaxStackDepth << endl;

    // Destroy old memory contents
    Memory->FillBytes(HeapStart, 0xFF, HeapEnd-HeapStart);
#endif

#if 0
    if (Runner->hp < HeapStart + ByteCodeRunner::EPHEMERAL_HEAP_SIZE/2)
#endif
    Runner->hp = OldLimits.Ephemeral;
    Runner->ResetRefMask(hp_ref_end, hp_big_pos);
    return true;
}

/*
 * Double the heap if there is still space to do it.
 */
bool GarbageCollector::DoubleHeap()
{
    unsigned size = Runner->HeapEnd - Runner->HeapStart;
    if (size >= MAX_HEAP_SIZE)
        return false;

#ifdef DEBUG_FLOW
    Runner->flow_err << "Doubling flow heap to " << size*2 << " bytes." << endl;
#endif

    // Double the heap area
    Runner->HeapEnd = Runner->HeapStart + size*2;
    Memory->SetSize(FlowPtrToInt(Runner->HeapEnd));
    //Runner->Code.Update();

    // Adjust the heap limits. The current heap
    // contents always end up in the low half.
    Runner->highHeap = false;

    // Reinitialize fields
    NewLimits = Runner->GetHeapLimits(true);

    hp_ref_end = NewLimits.Ephemeral;
    hp_big_pos = NewLimits.Start;

    MemoryBuffer = (char*)Memory->GetRawPointer(MakeFlowPtr(0), FlowPtrToInt(Runner->HeapEnd), true);

    return true;
}

/*
 * Do a full collection, possibly doubling the heap. The ensure_space parameter
 * can be used to force heap doubling if after collection there won't be enough
 * free space.
 */
bool GarbageCollector::Collect(unsigned ensure_space)
{
    bool currentIsHigh = Runner->highHeap;

    // Init the heap ranges
    OldLimits = Runner->GetHeapLimits(currentIsHigh);
    NewLimits = Runner->GetHeapLimits(!currentIsHigh);
    HeapStart = OldLimits.Bound;
    HeapEnd = OldLimits.Start;

    hp_ref_end = NewLimits.Ephemeral;
    hp_big_pos = NewLimits.Start;

    inFastGC = false;
    NativeGCGenBarrier = 0;

    MemoryBuffer = (char*)Memory->GetRawPointer(MakeFlowPtr(0), FlowPtrToInt(Runner->HeapEnd), true);

#ifdef DEBUG_FLOW
    MaxStackDepth = 0;
#endif

    // Enumerate live objects
    inEnumPhase = true;
    EnumPhaseTag(2);
    ProcessRoots();
    ProcessFullRoots();
    FlushArrays();

    // Check if need to double the heap
    int live_bytes = ComputeLiveBytes() + ensure_space;
    int heap_bytes = hp_big_pos - hp_ref_end;
    int ehlimit = heap_bytes - EPHEMERAL_HEAP_SIZE*3;

    if (live_bytes >= heap_bytes)
    {
        if (!DoubleHeap())
            return false;
    }
    else if (live_bytes >= std::max(heap_bytes*3/4, ehlimit))
        DoubleHeap();

    // Move objects to the new half-heap
    Memory->CommitRange(NewLimits.Bound, NewLimits.Start);
    Runner->DataStack.readonly(Runner->NumFrozenDataStack, false);

    inEnumPhase = false;
    NextTag();
    ProcessRoots();
    ProcessFullRoots();
    FlushArrays();

#ifdef DEBUG_FLOW
    cerr << "Max GC stack depth: " << MaxStackDepth << endl;

    // Destroy old memory contents
    Memory->FillBytes(HeapStart, 0xFF, HeapEnd-HeapStart);
#endif
	
    Memory->DecommitRange(OldLimits.Bound, OldLimits.Start);
    Runner->DataStack.readonly(Runner->NumFrozenDataStack, true);

    // Flip the runner state
    Runner->UpdateHeapLimits(!Runner->highHeap);
    Runner->ResetRefMask(hp_ref_end, hp_big_pos);
    return true;
}

#ifdef FLOW_GARBAGE_PROFILING
/*
 * GC profiling tracks allocation information for all live objects.
 * This has to be updated when objects are moved.
 */
void GarbageCollector::UpdateProfileInfo()
{
    std::vector<ByteCodeRunner::AllocationInfo> NewObjects;
    std::vector<ByteCodeRunner::AllocationInfo> &CurObjects = Runner->ProfileHeapObjects;

    CollectedObjects.clear();
    CollectedBytes.clear();
    NewObjects.reserve(CurObjects.size());

    for (size_t i = 0; i < CurObjects.size(); i++)
    {
        ByteCodeRunner::AllocationInfo info = CurObjects[i];

        // Objects not in the current arena assumed live
        if (!IsHeapPtr(info.alloc_addr))
        {
            NewObjects.push_back(info);
            continue;
        }

        ByteCodeRunner::AllocationInfo info2 = info;
        std::vector<AddrIntervalSet::range_type> string_ranges;
        FlowPtr start_addr = info.alloc_addr, end_addr = info.alloc_addr+info.size;

        if (StringRanges.listIntervals(start_addr, end_addr, &string_ranges))
        {
            int cur_size = info.size;

            for (size_t j = 0; j < string_ranges.size(); j++)
            {
                AddrIntervalSet::range_type range = string_ranges[j];
                T_AddressMap::const_iterator it = AddressMap.find(range.first);
                if (it == AddressMap.end())
                    continue;

                int gap = std::max(0, int(start_addr - range.first));
                info2.alloc_addr = it->second + gap;
                info2.size = std::min(end_addr, range.second) - range.first - gap;
                NewObjects.push_back(info2);

                cur_size -= info2.size;
            }

            if (cur_size > 0)
            {
                CollectedObjects[info.generation]++;
                CollectedBytes[info.generation] += cur_size;
            }
        }
        else
        {
            // Simple moved objects
            T_AddressMap::const_iterator it = AddressMap.find(start_addr);
            if (it != AddressMap.end())
            {
                info2.alloc_addr = it->second;
                NewObjects.push_back(info2);
            }
            else
            {
                CollectedObjects[info.generation]++;
                CollectedBytes[info.generation] += info.size;
            }
        }
    }

    CurObjects.swap(NewObjects);
}

static void WriteDump(std::string fname, std::map<std::string, int> &BytesByCode)
{
    FILE *out = fopen(fname.c_str(), "wb");

    if (out)
    {
        fwrite("FLOWPROF", 8, 1, out);

        for (std::map<std::string, int>::iterator it = BytesByCode.begin(); it != BytesByCode.end(); ++it)
        {
            unsigned buffer[2];
            buffer[0] = it->second;
            buffer[1] = it->first.size()/sizeof(unsigned);
            fwrite(buffer, sizeof(unsigned), 2, out);
            fwrite(it->first.data(), sizeof(unsigned), buffer[1], out);
        }

        fclose(out);
    }
}

void GarbageCollector::PrintStats(ostream &out, std::string fname, int FirstNewID)
{
    std::vector<ByteCodeRunner::AllocationInfo> &CurObjects = Runner->ProfileHeapObjects;
    std::map<int, int> CurCount, CurBytes;
    std::map<std::string, int> BytesByCode;
    std::map<std::string, int> NewBytesByCode;

    bool write_file = !fname.empty();

    for (size_t i = 0; i < CurObjects.size(); i++)
    {
        ByteCodeRunner::AllocationInfo &info = CurObjects[i];
        int bytes = (info.size + 3) & ~3;

        CurCount[info.generation]++;
        CurBytes[info.generation] += bytes;

        if (write_file)
        {
            BytesByCode[info.stack_buf] += bytes;
            if (info.generation >= unsigned(FirstNewID))
                NewBytesByCode[info.stack_buf] += bytes;
        }
    }

    if (write_file)
    {
        WriteDump(fname, BytesByCode);
        WriteDump(fname + "-new", NewBytesByCode);
    }

    out << "Live objects:" << endl;

    int counted_bytes = 0;
    for (std::map<int, int>::iterator it = CurCount.begin(); it != CurCount.end(); ++it)
    {
        counted_bytes += CurBytes[it->first];
        out << "  generation " << it->first << ": " << it->second << " objects, " << CurBytes[it->first] << " bytes." << endl;
    }

    int heap_bytes = NewLimits.Start - NewLimits.Ephemeral - (hp_big_pos - hp_ref_end);
    int strbytes = StringRanges.getTotalSize(4);
    int known_bytes = NumRefs * sizeof(FlowHeapRef) + NumSlots * STACK_SLOT_SIZE + NumLongStrings * sizeof(FlowStringRef) + NumClosures * 4 + NumObjects * 4 + strbytes;

#ifdef FLOW_COMPACT_STRUCTS
    known_bytes += NumStructBytes;
#endif

    out << "  total: " << NumRefs << " refs, " << NumSlots << " slots, " << NumClosures << " closures, "<< NumLongStrings << " long strings, " << NumObjects << " objects, "
#ifdef FLOW_COMPACT_STRUCTS
        << NumStructBytes << " struct bytes, "
#endif
        << strbytes << " string bytes." << endl;
    out << "  live bytes: " << heap_bytes << ", " << heap_bytes-counted_bytes << " unaccounted, " << heap_bytes-known_bytes << " padding." << endl;

    out << "Collected:" << endl;

    for (std::map<int, int>::iterator it = CollectedObjects.begin(); it != CollectedObjects.end(); ++it)
    {
        out << "  generation " << it->first << ": " << it->second << " objects, " << CollectedBytes[it->first] << " bytes." << endl;
    }
}
#endif

void GarbageCollector::EnumPhaseTag(T_GC_Tag tag)
{
    LastTag = Runner->NextGCTag;
    MaxOKTag = tag;
    CurTag = tag;
}

void GarbageCollector::NextTag()
{
    LastTag = CurTag;
    MaxOKTag = 0;
    if (!++Runner->NextGCTag)
        Runner->NextGCTag = MAX_SPECIAL_TAG+1;
    CurTag = Runner->NextGCTag;
}

/*
 * Walk all supported root references.
 */
void GarbageCollector::ProcessRoots()
{
    if (inEnumPhase)
    {
        NumRefs = NumSlots = NumClosures = NumLongStrings = NumObjects = 0;
#ifdef FLOW_COMPACT_STRUCTS
        NumStructBytes = 0;
#endif
        StringRanges.clear();
    }

    AddressMap.clear();
    NativeFunctionsAlive.clear();
    NativeValuesAlive.clear();

    GarbageCollectorFn fn(this);

    // Program
    if (Runner->Program)
        Runner->Program->flowGCObject(fn);

    // Data stack
    ProcessVector(&Runner->DataStack[0], Runner->DataStack.size());

    // Global roots
    ByteCodeRunner::T_NativeRoots::iterator rit;
    for (rit = Runner->NativeRoots.begin(); rit != Runner->NativeRoots.end(); ++rit)
    {
        Process(rit->second);
    }

    FlushArrays();

    // Hosts
    ByteCodeRunner::T_NativeHosts::iterator hit;
    for (hit = Runner->NativeHosts.begin(); hit != Runner->NativeHosts.end(); ++hit) {
        (*hit)->flowGCObject(fn);
    }

    FlushArrays();

    // Closure pointer
    if (Runner->closurepointer != 0)
    {
        FlowPtr ptr = Runner->closurepointer - 4;
        StackSlot closure = StackSlot::InternalMakeClosurePointer(ptr, *HEADER_PTR(unsigned short, ptr));

        if (inEnumPhase)
            Enumerate(closure);
        else
        {
            Collect(closure);
            Runner->closurepointer = closure.GetClosureDataPtr();
        }
    }

    // Collect closures on the closure stack
    for (unsigned i = 0; i < Runner->CallStack.size(); i++)
    {
        FlowPtr &a = Runner->CallStack[i].last_closure;
        if (a == 0)
            continue;

        StackSlot closure = StackSlot::InternalMakeClosurePointer(a-4, *HEADER_PTR(unsigned short, a-4));

        if (inEnumPhase)
            Enumerate(closure);
        else
        {
            Collect(closure);
            a = closure.GetClosureDataPtr();
        }
    }

#ifdef FLOW_JIT
    if (Runner->JitProgram)
    {
        void **pframe = (void**)Runner->JitCallFrame;

        // See comments on rCFrame in JitProgram.cpp for memory layout info
        while (pframe)
        {
            FlowPtr &a = *(FlowPtr*)&pframe[-2];
            StackSlot closure = StackSlot::InternalMakeClosurePointer(a, *HEADER_PTR(unsigned short, a));

            if (inEnumPhase)
                Enumerate(closure);
            else
            {
                Collect(closure);
                a = closure.slot_private.PtrValue;
            }

            pframe = (void**)pframe[0];
        }
    }
#endif

    // Deferred actions
    fn << Runner->DeferredActionQueue;

    // Const closure natives
    fn << Runner->ConstClosureCache;

#ifdef FLOW_MMAP_HEAP
    // Memory mapped files
    fn << Runner->MappedFiles;
#endif

    // Local root stack
    ProcessLocalRoots(Runner->LocalRootStack);
}

/*
 * Walk the list of roots that are located in local variables within native methods.
 */
void GarbageCollectorFnCallback::ProcessLocalRoots(LocalRootRecord *rrec)
{
    GarbageCollectorFn fn(this);

    while (rrec != NULL) {
        switch (rrec->type) {
        case 0:
            for (int i = 0; i < rrec->count; i++)
                Process(*rrec->roots[i]);
            break;
        case 1:
            ProcessVector(rrec->root_arr, rrec->count);
            break;
        case 2:
        {
            rrec->cb->flowGCObject(fn);
            break;
        }
        default:
            cerr << "Root stack corrupted." << endl;
            abort();
        }

        rrec = rrec->next;
    }
}

/*
 * Process roots that only pertain to the full GC.
 */
void GarbageCollector::ProcessFullRoots()
{
#ifdef FLOW_MMAP_HEAP
    for (ByteCodeRunner::T_MappedAreas::iterator it = Runner->MappedAreas.begin();
         it != Runner->MappedAreas.end(); ++it)
    {
        ByteCodeRunner::MappedAreaInfo &info = *it->second;

        for (size_t i = 0; i < info.ref_roots.size(); i++)
        {
            FlowPtr start = info.ref_roots[i].first;
            int size = info.ref_roots[i].second;

            FlowHeapRef *refs = (FlowHeapRef*)MEMORY_PTR(start, size*sizeof(FlowHeapRef), true);
            for (int j = 0; j < size; j++)
            {
                refs[j].header.GC_Tag = CurTag;
                Process(refs[j].data);
            }

            FlushArrays();
        }
    }
#endif
}

/*
 * Process roots that only pertain to fast GC. Specifically, any modified objects and refs.
 */
void GarbageCollector::ProcessFastRoots()
{
    // Process stable generation refs
    int TouchedRefs = 0;

    for (size_t i = 0; i < Runner->RefWriteMask.size(); i++)
    {
        if (!Runner->RefWriteMask[i])
            continue;

        int count = ByteCodeRunner::REF_MASK_STEP;
        FlowPtr base = Runner->hp_ref_base + i*count*sizeof(FlowHeapRef);
        count = std::min(count, int((Runner->hp_ref_end - base)/sizeof(FlowHeapRef)));
        TouchedRefs += count;

        FlowHeapRef *refs = (FlowHeapRef*)Memory->GetRawPointer(base, count*sizeof(FlowHeapRef), true);

        for (int j = 0; j < count; j++)
        {
            Process(refs[j].data);
            FlushArrays();
        }
    }

#ifdef DEBUG_FLOW
    if (TouchedRefs > 0)
    {
        cerr << "Scanned " << TouchedRefs << " of "
             << (Runner->hp_ref_end-Runner->hp_ref_base)/STACK_SLOT_SIZE
             << " refs in the old generation." << endl;
    }
#endif

    // Process random writes to the heap from native code
    for (std::map<FlowPtr,bool>::const_iterator it = Runner->SlotWriteSet.raw_bounds().begin();
         it != Runner->SlotWriteSet.raw_bounds().end(); ++it)
    {
        FlowPtr start = it->first;
        ++it;
        int size = (it->first - start);
        ProcessVector((StackSlot*)Memory->GetRawPointer(start, size, true), size/STACK_SLOT_SIZE);
    }

#ifdef DEBUG_FLOW
    if (!Runner->SlotWriteSet.empty())
        cerr << "Scanned " << Runner->SlotWriteSet.getTotalSize()/STACK_SLOT_SIZE << " slots modified by natives." << endl;
#endif

#ifdef FLOW_COMPACT_STRUCTS
    for (size_t i = 0; i < Runner->StructWriteSet.size(); i++)
    {
        FlowPtr ptr = Runner->StructWriteSet[i];
        FlowHeapStruct *obj = HEADER_PTR(FlowHeapStruct, ptr);

        if (unlikely(!(obj->header.GC_Tag < MaxOKTag || obj->header.GC_Tag == LastTag)))
            ReportTagError(obj->header.GC_Tag);

        obj->header.GC_Tag = CurTag;

        ArrayStack.push_back(TArrayDim(ptr, -1));
    }

    FlushArrays();

#ifdef DEBUG_FLOW
    if (!Runner->StructWriteSet.empty())
        cerr << "Scanned " << Runner->StructWriteSet.size() << " structs modified by natives." << endl;
#endif
#endif

    // Process native objects
    for (ByteCodeRunner::T_NativeValues::iterator it = Runner->NativeValues.begin();
         it != Runner->NativeValues.end(); ++it)
    {
        if (it->first >= NativeGCGenBarrier)
            continue;

        AbstractNativeValue *val = it->second;
        if (!val)
            continue;

        ProcessNativeValue(val);
    }

    FlushArrays();
}

void GarbageCollector::ProcessVector(StackSlot *start, unsigned size)
{
    for (unsigned i = 0; i < size; i++)
    {
        Process(start[i]);
        FlushArrays();
    }
}

FlowPtr GarbageCollector::AllocFailure(int bytes)
{
    cerr << "Alloc failure in GC: " << bytes << endl;
    abort();
    return hp_big_pos;
}

void GarbageCollector::ReportTagError(int tag)
{
    Runner->flow_err << stl_sprintf("Invalid GC tag: %d vs %d,%d", tag, MaxOKTag, LastTag) << std::endl;
    Runner->DoReportError(GCFailure);
    abort();
}

/*
 * Main function of the enumeration phase.
 */
void GarbageCollector::Enumerate(const StackSlot &value)
{
    assert(inEnumPhase);

    if (!value.CheckTag(StackSlot::TAG_NAN,StackSlot::TAG_NAN))
        return;

    switch (value.slot_private.Tag & StackSlot::TAG_TYPEMASK)
    {
    case StackSlot::TYPE_DOUBLENAN:
    case StackSlot::TYPE_DOUBLEINF:
    case StackSlot::TYPE_VOID:
    case StackSlot::TYPE_INTBOOL:
    case StackSlot::TYPE_CAPFRAME:
        break; // Nothing to do
    case StackSlot::TYPE_STRING:
        {
            EnumerateString(value);
            break;
        }
    case StackSlot::TYPE_ARRAY:
        {
            EnumerateArray(value);
            break;
        }
    case StackSlot::TYPE_STRUCT:
        {
            FlowPtr ptr = value.slot_private.PtrValue;

            if (unlikely(unsigned(value.GetStructId()) >= NumStructDefs))
                abort();

            if (IsHeapPtr(ptr))
            {
#ifdef FLOW_COMPACT_STRUCTS
                EnumerateStruct(ptr);
#else
                EnumerateArray(ptr, StructSizes[value.GetStructId()]);
#endif
            }
            break;
        }
    case StackSlot::TYPE_FLOWCODE:
        {
            if (value.GetSign())
                EnumerateArray(value.slot_private.PtrValue, value.slot_private.AuxValue, true);
            break;
        }
    case StackSlot::TYPE_NATIVEFN:
        {
            unsigned func_id;

            // Native function with a closure heap object?
            if (value.GetSign())
            {
                FlowPtr ptr = value.slot_private.PtrValue;

                func_id = *HEADER_PTR(unsigned, ptr-4);

                if (IsHeapPtr(ptr))
                {
#ifdef FLOW_COMPACT_STRUCTS
                    // Closures based on struct layouts are used by the generated C++ code target
                    if (func_id < Runner->NumCompactNativeFNs)
                        EnumerateStruct(ptr, true);
                    else
#endif
                        EnumerateArray(ptr, value.slot_private.AuxValue, true);
                }
            }
            else
                func_id = value.slot_private.IntValue;

            if (func_id >= Runner->NumFrozenNativeFNs)
                ProcessNativeFunction(func_id);
            break;
        }
    case StackSlot::TYPE_REFTO:
        {
            EnumerateRef(value.slot_private.PtrValue);
            break;
        }
    case StackSlot::TYPE_NATIVE:
        {
            ProcessNativeValue(value.GetNativeValId());
            break;
        }
    default:
         Runner->ReportError(GCFailure, "Unknown tag value in GC enumerate: %x", value.slot_private.Tag);
    }
}

void GarbageCollector::EnumerateString(const StackSlot &value)
{
    FlowPtr ptr = value.slot_private.PtrValue;
    unsigned size = value.slot_private.AuxValue;

    if (size != 0 && IsHeapPtr(ptr))
    {
        // Strings longer than 64K characters use an additional helper object to contain the full length
        if (value.GetSign())
        {
            FlowStringRef *ref = HEADER_PTR(FlowStringRef, ptr);

            // check header tag
            if (ref->header.GC_Tag == CurTag)
                return;

            if (unlikely(!(ref->header.GC_Tag < MaxOKTag || ref->header.GC_Tag == LastTag)))
                ReportTagError(ref->header.GC_Tag);

            ref->header.GC_Tag = CurTag;

            // update data
            size = (size<<16) | ref->header.DataValue;
            ptr = ref->dataptr;

            // register memory requirement
            NumLongStrings++;

            if (!IsHeapPtr(ptr))
                return;
        }

        // register the string range
        StringRanges.addInterval(ptr, ptr + size*FLOW_CHAR_SIZE);
    }
}

void GarbageCollector::EnumerateArray(const StackSlot &value)
{
    FlowPtr ptr = value.slot_private.PtrValue;
    unsigned size = value.slot_private.AuxValue;

    if (size != 0)
    {
        // Long array - part of the length is in the heap object header
        if (value.GetSign())
            size = (size<<16) | HEADER_PTR(FlowGCHeader, ptr)->DataValue;

        EnumerateArray(ptr, size);
    }
}

void GarbageCollector::EnumerateArray(FlowPtr ptr, unsigned len, bool closure)
{
    if (!IsHeapPtr(ptr))
        return;

    FlowHeapArray *obj = HEADER_PTR(FlowHeapArray, ptr);

    // Check tag
    if (obj->header.GC_Tag == CurTag)
        return;

    if (unlikely(!(obj->header.GC_Tag < MaxOKTag || obj->header.GC_Tag == LastTag)))
        ReportTagError(obj->header.GC_Tag);

    obj->header.GC_Tag = CurTag;

    // Add the array to the recursion stack
    ArrayStack.push_back(TArrayDim(ptr, len));

#ifdef DEBUG_FLOW
    MaxStackDepth = std::max(ArrayStack.size(), MaxStackDepth);
#endif

    // Register the memory requirements
    NumObjects++;
    NumSlots += len;
    if (closure)
        NumClosures++;
}

void GarbageCollector::EnumerateRef(FlowPtr ptr)
{
    if (!IsHeapPtr(ptr))
        return;

    FlowHeapRef *obj = HEADER_PTR(FlowHeapRef, ptr);

    // Check tag
    if (obj->header.GC_Tag == CurTag)
        return;

    if (unlikely(!(obj->header.GC_Tag < MaxOKTag || obj->header.GC_Tag == LastTag)))
        ReportTagError(obj->header.GC_Tag);

    obj->header.GC_Tag = CurTag;

    // register memory requirement and recurse
    NumRefs++;
    Enumerate(obj->data);
}

#ifdef FLOW_COMPACT_STRUCTS
void GarbageCollector::EnumerateStruct(FlowPtr ptr, bool closure)
{
    if (!IsHeapPtr(ptr))
        return;

    FlowHeapStruct *obj = HEADER_PTR(FlowHeapStruct, ptr);

    // Check tag
    if (obj->header.GC_Tag == CurTag)
        return;

    if (unlikely(!(obj->header.GC_Tag < MaxOKTag || obj->header.GC_Tag == LastTag)))
        ReportTagError(obj->header.GC_Tag);

    obj->header.GC_Tag = CurTag;

    // Register
    StructDef &def = StructDefs[obj->header.DataValue];

    if (def.GCFieldCount > 0)
    {
        ArrayStack.push_back(TArrayDim(ptr, -1));

#ifdef DEBUG_FLOW
        MaxStackDepth = std::max(ArrayStack.size(), MaxStackDepth);
#endif
    }

    NumStructBytes += def.ByteSize;
    if (closure)
        NumClosures++;
}
#endif

/*
 * Enumerate array and struct contents from the recursion stack until empty.
 */
void GarbageCollector::EnumerateArrays()
{
    while (!ArrayStack.empty())
    {
        TArrayDim item = ArrayStack.pop();

#ifdef FLOW_COMPACT_STRUCTS
        if (item.second < 0)
        {
            FlowHeapStruct *obj = HEADER_PTR(FlowHeapStruct, item.first);
            assert(obj->header.GC_Tag == CurTag);

            StructDef &def = StructDefs[obj->header.DataValue];

            for (int i = 0; i < def.GCFieldCount; i++)
            {
                const FlowStructFieldGCDef &gcd = def.FieldGCDefs[i];
                gcd.fn_enum(this, obj->header.Bytes + gcd.offset);
            }

            continue;
        }
#endif

#ifdef DEBUG_FLOW
        int bytes = item.second * STACK_SLOT_SIZE;
#endif
        StackSlot *old_slots = (StackSlot*)MEMORY_PTR(item.first+4, bytes, false);

        for (int i = 0; i < item.second; ++i)
            Enumerate(old_slots[i]);
    }
}

#ifdef FLOW_COMPACT_STRUCTS
void flow_fields::enum_slot(GarbageCollector *gc, const void *p)
{
    gc->Enumerate(*(StackSlot*)p);
}
void flow_fields::enum_array(GarbageCollector *gc, const void *p)
{
    gc->EnumerateArray(*(StackSlot*)p);
}
void flow_fields::enum_string(GarbageCollector *gc, const void *p)
{
    gc->EnumerateString(*(StackSlot*)p);
}
void flow_fields::enum_ref(GarbageCollector *gc, const void *p)
{
    FlowStructRef *pp = (FlowStructRef*)p;
    gc->EnumerateRef(pp->slot_private.PtrValue);
}
void flow_fields::enum_struct(GarbageCollector *gc, const void *p)
{
    gc->EnumerateStruct(*(FlowPtr*)p);
}
#endif

/*
 * Main collection pass function. Copies the heap object when necessary and updates the slot.
 */
void GarbageCollector::Collect(StackSlot &value)
{
    assert(!inEnumPhase);

    if (!value.CheckTag(StackSlot::TAG_NAN,StackSlot::TAG_NAN))
        return;

    switch (value.slot_private.Tag & StackSlot::TAG_TYPEMASK)
    {
    case StackSlot::TYPE_DOUBLENAN:
    case StackSlot::TYPE_DOUBLEINF:
    case StackSlot::TYPE_VOID:
    case StackSlot::TYPE_INTBOOL:
    case StackSlot::TYPE_CAPFRAME:
        break; // Nothing to do
    case StackSlot::TYPE_STRING:
        {
            CollectString(value);
            break;
        }
    case StackSlot::TYPE_ARRAY:
        {
            CollectArray(value);
            break;
        }
    case StackSlot::TYPE_STRUCT:
        {
            FlowPtr ptr = value.slot_private.PtrValue;

#ifdef DEBUG_FLOW
            if (unlikely(unsigned(value.GetStructId()) >= NumStructDefs))
                abort();
#endif

            if (IsHeapPtr(ptr))
            {
#ifdef FLOW_COMPACT_STRUCTS
                value.slot_private.PtrValue = CollectStruct(ptr);
#else
                value.slot_private.PtrValue = CollectArray(ptr, StructSizes[value.GetStructId()]);
#endif
            }
            break;
        }
    case StackSlot::TYPE_FLOWCODE:
        {
            if (value.GetSign())
                 value.slot_private.PtrValue = CollectArray(value.slot_private.PtrValue, value.slot_private.AuxValue, true);
            break;
        }
    case StackSlot::TYPE_NATIVEFN:
        {
            unsigned func_id;

            // Native function with a closure heap object?
            if (value.GetSign())
            {
                FlowPtr ptr = value.slot_private.PtrValue;

                func_id = *HEADER_PTR(unsigned, ptr-4);

                if (IsHeapPtr(ptr))
                {
#ifdef FLOW_COMPACT_STRUCTS
                    // Closures based on struct layouts are used by the generated C++ code target
                    if (func_id < Runner->NumCompactNativeFNs)
                        value.slot_private.PtrValue = CollectStruct(ptr, true);
                    else
#endif
                        value.slot_private.PtrValue = CollectArray(ptr, value.slot_private.AuxValue, true);
                }
            }
            else
                func_id = value.slot_private.IntValue;

            if (func_id >= Runner->NumFrozenNativeFNs)
                ProcessNativeFunction(func_id);
            break;
        }
    case StackSlot::TYPE_REFTO:
        {
            value.slot_private.PtrValue = CollectRef(value.slot_private.PtrValue);
            break;
        }
    case StackSlot::TYPE_NATIVE:
        {
            ProcessNativeValue(value.GetNativeValId());
            break;
        }
    default:
         Runner->ReportError(GCFailure, "Unknown tag value in GC collect: %x", value.slot_private.Tag);
    }
}

void GarbageCollector::CollectString(StackSlot &value)
{
    unsigned size = value.slot_private.AuxValue;

    if (size == 0)
    {
        value.slot_private.PtrValue = MakeFlowPtr(0);
        return;
    }

    FlowPtr *pptr = &value.slot_private.PtrValue;

    if (IsHeapPtr(*pptr))
    {
        // Strings longer than 64K have an additional object with full length
        if (value.GetSign())
        {
            FlowStringRef *ref = HEADER_PTR(FlowStringRef, *pptr);

            // check header tag
            if (ref->header.GC_Tag == CurTag)
            {
                // already copied and handled this ref object
                assert(ref->header.DataValue == StackSlot::MASK_GC_FORWARD_PTR16);
                *pptr = ref->dataptr;
                return;
            }

            if (unlikely(!(ref->header.GC_Tag < MaxOKTag || ref->header.GC_Tag == LastTag)))
                ReportTagError(ref->header.GC_Tag);

            ref->header.GC_Tag = CurTag;

            // copy the ref object
            FlowPtr newptr = Allocate(sizeof(FlowStringRef));
            FlowStringRef *newref = HEADER_PTR(FlowStringRef, newptr);

            *newref = *ref;

            // save address of the new object in the old one
            ref->header.DataValue = StackSlot::MASK_GC_FORWARD_PTR16;
            ref->dataptr = newptr;

            // update slot pointer
            *pptr = newptr;

            // process the actual string
            size = (size<<16) | newref->header.DataValue;
            pptr = &newref->dataptr;

            if (!IsHeapPtr(*pptr))
                return;
        }

        *pptr = CollectString(*pptr);
    }
}

void GarbageCollector::CollectArray(StackSlot &value)
{
    FlowPtr ptr = value.slot_private.PtrValue;
    unsigned size = value.slot_private.AuxValue;

    if (size != 0)
    {
        if (value.GetSign())
            size = (size<<16) | HEADER_PTR(FlowGCHeader, ptr)->DataValue;

        value.slot_private.PtrValue = CollectArray(ptr, size);
    }
}

#ifdef FLOW_COMPACT_STRUCTS
void flow_fields::gc_slot(GarbageCollector *gc, void *p)
{
    gc->Collect(*(StackSlot*)p);
}
void flow_fields::gc_array(GarbageCollector *gc, void *p)
{
    gc->CollectArray(*(StackSlot*)p);
}
void flow_fields::gc_string(GarbageCollector *gc, void *p)
{
    gc->CollectString(*(StackSlot*)p);
}
void flow_fields::gc_ref(GarbageCollector *gc, void *p)
{
    FlowStructRef *pp = (FlowStructRef*)p;
    pp->slot_private.PtrValue = gc->CollectRef(pp->slot_private.PtrValue);
}
void flow_fields::gc_struct(GarbageCollector *gc, void *p)
{
    *(FlowPtr*)p = gc->CollectStruct(*(FlowPtr*)p);
}
#endif

FlowPtr GarbageCollector::CollectString(FlowPtr addr)
{
    // Find interval this string refers to
    AddrIntervalSet::range_type range;
    if (!StringRanges.getInterval(addr, &range))
        abort();

    int offset = addr - range.first;

    // Check if it was already copied, and if not, copy
    T_AddressMap::const_iterator it = AddressMap.find(range.first);
    if (it != AddressMap.end()) {
        range.first = it->second;
    } else {
        int sz = range.second - range.first;
        FlowPtr new_ptr = Allocate(sz);
        Copy(range.first, new_ptr, sz);
        range.first = AddressMap[range.first] = new_ptr;
    }

    return range.first + offset;
}

void GarbageCollector::ProcessNativeFunction(int id)
{
    if (inFastGC)
        return;

    NativeFunctionsAlive.insert(id);
}

void GarbageCollector::ProcessNativeValue(int id)
{
    if (id < NativeGCGenBarrier || !NativeValuesAlive.insert(id).second)
        return;

    ProcessNativeValue(safeMapAt(Runner->NativeValues, id, NULL));
}

void GarbageCollector::ProcessNativeValue(AbstractNativeValue *val)
{
    if (!val) return;

    // Check if this object known how to GC itself
    FlowNativeObject *obj = val->nativeObject();
    if (obj) {
        // Update the tag of the object's own reference to itself
        if (obj->id_tag != CurTag) {
            if (unlikely(!(obj->id_tag < MaxOKTag || obj->id_tag == LastTag)))
                ReportTagError(obj->id_tag);

            obj->id_tag = CurTag;
        }

        GarbageCollectorFn fn(this);
        obj->flowGCObject(fn);
    }
}

/*
 * Collect array and struct contents from the recursion stack until empty.
 */
void GarbageCollector::CollectArrays()
{
    while (!ArrayStack.empty())
    {
        TArrayDim item = ArrayStack.pop();

#ifdef FLOW_COMPACT_STRUCTS
        if (item.second < 0)
        {
            FlowHeapStruct *obj = HEADER_PTR(FlowHeapStruct, item.first);
            assert(obj->header.GC_Tag == CurTag);

            StructDef &def = StructDefs[obj->header.DataValue];

            for (int i = 0; i < def.GCFieldCount; i++)
            {
                const FlowStructFieldGCDef &gcd = def.FieldGCDefs[i];
                gcd.fn_collect(this, obj->header.Bytes + gcd.offset);
            }

            continue;
        }
#endif

#ifdef DEBUG_FLOW
        int bytes = item.second * STACK_SLOT_SIZE;
#endif
        StackSlot *old_slots = (StackSlot*)MEMORY_PTR(item.first+4, bytes, false);

        for (int i = 0; i < item.second; ++i)
            Collect(old_slots[i]);
    }
}

FlowPtr GarbageCollector::CollectArray(FlowPtr ptr, unsigned len, bool closure)
{
    // Safety net: fix malformed empty arrays & structs
    if (len == 0)
        return MakeFlowPtr(0);

    // Check if it has already been processed
    if (!IsHeapPtr(ptr))
        return ptr;

    FlowHeapArray *obj = HEADER_PTR(FlowHeapArray, ptr);

    // Check tag
    if (obj->header.GC_Tag == CurTag)
    {
        assert(obj->data[0].slot_private.Ints[1] == StackSlot::MASK_GC_FORWARD_PTR);
        return obj->data[0].slot_private.PtrValue;
    }

    if (unlikely(!(obj->header.GC_Tag < MaxOKTag || obj->header.GC_Tag == LastTag)))
        ReportTagError(obj->header.GC_Tag);

    obj->header.GC_Tag = CurTag;

    // Allocate and copy
    unsigned prefix = closure ? 4 : 0;
    unsigned bytes = len * STACK_SLOT_SIZE + 4 + prefix;

    FlowPtr new_base = Allocate(bytes);
    FlowPtr old_base = ptr - prefix;

    memcpy(MEMORY_PTR(new_base, bytes, true), MEMORY_PTR(old_base, bytes, false), bytes);

    FlowPtr newptr = new_base + prefix;

    // Save address of the new copy in the old one
    obj->data[0].slot_private.PtrValue = newptr;
    obj->data[0].slot_private.Ints[1] = StackSlot::MASK_GC_FORWARD_PTR;

#ifdef FLOW_GARBAGE_PROFILING
    if (unlikely(Runner->DoProfileGarbage))
        AddressMap[old_base] = new_base;
#endif

    // Register for recursion
    ArrayStack.push_back(TArrayDim(newptr, len));

#ifdef DEBUG_FLOW
    MaxStackDepth = std::max(ArrayStack.size(), MaxStackDepth);
#endif

    return newptr;
}

FlowPtr GarbageCollector::CollectRef(FlowPtr ptr)
{
    // Check if it has already been processed
    if (!IsHeapPtr(ptr))
        return ptr;

    FlowHeapRef *obj = HEADER_PTR(FlowHeapRef, ptr);

    // Check tag
    if (obj->header.GC_Tag == CurTag)
    {
        assert(obj->data.slot_private.Ints[1] == StackSlot::MASK_GC_FORWARD_PTR);
        return obj->data.slot_private.PtrValue;
    }

    if (unlikely(!(obj->header.GC_Tag < MaxOKTag || obj->header.GC_Tag == LastTag)))
        ReportTagError(obj->header.GC_Tag);

    obj->header.GC_Tag = CurTag;

    // Allocate and copy
    FlowPtr newptr = AllocateRef();
    FlowHeapRef *newobj = HEADER_PTR(FlowHeapRef, newptr);

    *newobj = *obj;

    // Save address of the new copy in the old one
    obj->data.slot_private.PtrValue = newptr;
    obj->data.slot_private.Ints[1] = StackSlot::MASK_GC_FORWARD_PTR;

#ifdef FLOW_GARBAGE_PROFILING
    if (unlikely(Runner->DoProfileGarbage))
        AddressMap[ptr] = newptr;
#endif

    // Process
    Collect(newobj->data);

    return newptr;
}

#ifdef FLOW_COMPACT_STRUCTS
FlowPtr GarbageCollector::CollectStruct(FlowPtr ptr, bool closure)
{
    if (!IsHeapPtr(ptr))
        return ptr;

    FlowHeapStruct *obj = HEADER_PTR(FlowHeapStruct, ptr);

    // Check tag
    if (obj->header.GC_Tag == CurTag)
    {
        assert(obj->header.DataValue == StackSlot::MASK_GC_FORWARD_PTR16);
        return obj->fwd_ptr;
    }

    if (unlikely(!(obj->header.GC_Tag < MaxOKTag || obj->header.GC_Tag == LastTag)))
        ReportTagError(obj->header.GC_Tag);

    obj->header.GC_Tag = CurTag;

    // Copy
    StructDef &def = StructDefs[obj->header.DataValue];
    assert(unsigned(def.ByteSize) >= sizeof(FlowHeapStruct));

    unsigned prefix = closure ? 4 : 0;
    unsigned bytes = def.ByteSize + prefix;

    FlowPtr new_base = Allocate(bytes);
    FlowPtr old_base = ptr - prefix;

    memcpy(MEMORY_PTR(new_base, bytes, true), MEMORY_PTR(old_base, bytes, false), bytes);

    FlowPtr newptr = new_base + prefix;

    // Save address of the new copy in the old one
    obj->header.DataValue = StackSlot::MASK_GC_FORWARD_PTR16;
    obj->fwd_ptr = newptr;

#ifdef FLOW_GARBAGE_PROFILING
    if (unlikely(Runner->DoProfileGarbage))
        AddressMap[ptr] = newptr;
#endif

    // Register
    if (def.GCFieldCount > 0)
    {
        ArrayStack.push_back(TArrayDim(newptr, -1));

#ifdef DEBUG_FLOW
        MaxStackDepth = std::max(ArrayStack.size(), MaxStackDepth);
#endif
    }

    return newptr;
}
#endif
