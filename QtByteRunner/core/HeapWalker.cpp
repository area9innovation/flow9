#include "ByteCodeRunner.h"
#include "HeapWalker.h"
#include "NativeProgram.h"

#include <string.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef DEBUG_FLOW
#define MEMORY_PTR(base,size,write) Memory->GetRawPointer(base,size,write)
#else
#define MEMORY_PTR(base,size,write) (MemoryBuffer + FlowPtrToInt(base))
#endif

#define SLOT_PTR(base,count) ((StackSlot*)MEMORY_PTR(base,STACK_SLOT_SIZE*count,true))

HeapWalker::HeapWalker(ByteCodeRunner *Runner)
    : Runner(Runner), Memory(&Runner->Memory)
{
    HeapLimits Limits = Runner->GetHeapLimits(Runner->highHeap);

    HeapStart = Limits.Bound;
    HeapEnd = Limits.Start;

    MemoryBuffer = (char*)Memory->GetRawPointer(MakeFlowPtr(0), FlowPtrToInt(Runner->HeapEnd), true);

    pHeapStart = Memory->GetRawPointer(HeapStart, 0, true);
    pHeapEnd = Memory->GetRawPointer(HeapEnd, 0, true);

    StructDefs = Runner->StructDefs.data();
    NumStructDefs = Runner->StructDefs.size();
}

HeapWalker::~HeapWalker()
{
    //
}

void HeapWalker::ProcessGlobalRoots()
{
    if (Runner->Program)
    {
        GarbageCollectorFn fn(this);

        Runner->Program->flowGCObject(fn);
    }

    ProcessArray(&Runner->DataStack[0], Runner->DebugFnList.size());
}

void HeapWalker::ProcessStackRoots()
{
    int size = Runner->DataStack.size() - Runner->DebugFnList.size();
    ProcessArray(&Runner->DataStack[Runner->DebugFnList.size()], size);

    // Closure pointer
    if (Runner->closurepointer != 0)
    {
        FlowPtr ptr = Runner->closurepointer;
        StackSlot tmp = StackSlot::InternalMakeClosurePointer(ptr, Runner->Memory.GetUInt32(ptr-4));

        Process(tmp);
    }

    // Collect closures on the closure stack
    for (unsigned i = 0; i < Runner->CallStack.size(); i++)
    {
        FlowPtr ptr = Runner->CallStack[i].last_closure;
        StackSlot tmp = StackSlot::InternalMakeClosurePointer(ptr, Runner->Memory.GetUInt32(ptr-4));

        Process(tmp);
    }

    GarbageCollectorFn fn(this);

    // Deferred actions
    fn << Runner->DeferredActionQueue;

    // Local root stack
    ProcessLocalRoots(Runner->LocalRootStack);
}

void HeapWalker::ProcessNativeRoots()
{
    // Global roots
    ByteCodeRunner::T_NativeRoots::iterator rit;
    for (rit = Runner->NativeRoots.begin(); rit != Runner->NativeRoots.end(); ++rit)
    {
        Process(rit->second);
    }

    GarbageCollectorFn fn(this);

    // Hosts
    ByteCodeRunner::T_NativeHosts::iterator hit;
    for (hit = Runner->NativeHosts.begin(); hit != Runner->NativeHosts.end(); ++hit) {
        (*hit)->flowGCObject(fn);
    }
}

void HeapWalker::Process(FlowPtr ptr)
{
    Process(*SLOT_PTR(ptr,1));
}

void HeapWalker::ProcessArray(FlowPtr ptr, int count)
{
    ProcessArray(SLOT_PTR(ptr,count), count);
}

void HeapWalker::ProcessArray(StackSlot *ptr, int count)
{
    for (int i = 0; i < count; i++)
        Process(ptr[i]);
}

void HeapWalker::Process(FlowNativeObject *obj)
{
    if (obj)
        VisitNativeObj(const_cast<StackSlot&>(obj->getFlowValue()), obj);
}

void HeapWalker::ProcessRefs(FlowNativeObject *obj)
{
    if (!obj) return;

    GarbageCollectorFn fn(this);
    obj->flowGCObject(fn);
}

void HeapWalker::Process(StackSlot &value)
{
    switch (value.GetType()) {
    case TVoid:
    case TBool:
    case TInt:
    case TDouble:
    case TCodePointer:
    case TCapturedFrame:
        VisitScalar(value);
        break;

    case TString:
        {
            unsigned size;
            const unicode_char *ptr = getFlowRunner()->GetStringPtrSize(value, &size);
            VisitString(value, const_cast<unicode_char*>(ptr), size);
        }
        break;

    case TArray:
        {
            unsigned size = getFlowRunner()->GetArraySize(value);
            VisitArray(value, const_cast<StackSlot*>(getFlowRunner()->GetArraySlotPtr(value, size)), size);
        }
        break;


    case TStruct:
        {
            StructDef *def = StructDefs + value.GetStructId();
            if (unlikely(unsigned(value.GetStructId()) >= NumStructDefs ||
                         def->FieldsCount < 0))
                abort();
#ifdef FLOW_COMPACT_STRUCTS
            VisitStruct(value, (FlowStructHeader*)MEMORY_PTR(value.GetRawStructPtr(),4,true), def->FieldsCount, def);
#else
            VisitStruct(value, SLOT_PTR(value.GetRawStructPtr(),def->FieldsCount), def->FieldsCount, def);
#endif
        }
        break;

    case TClosurePointer:
        {
            FlowPtr ptr = value.GetClosureDataPtr();
            int size = FlowPtrToInt(ptr) ? *(int*)MEMORY_PTR(ptr-4,4,false) : 0;
            VisitClosure(value, size ? SLOT_PTR(ptr, size) : 0, size);
        }
        break;

    case TRefTo:
        VisitRef(value, SLOT_PTR(value.GetRawRefPtr(), 1));
        break;

    case TNative:
        {
            AbstractNativeValue *val = safeMapAt(Runner->NativeValues, value.GetNativeValId(), NULL);

            if (!val)
                VisitError(value);
            else
            {
                // Check if this object known how to GC itself
                FlowNativeObject *obj = val->nativeObject();
                if (obj)
                    VisitNativeObj(value, obj);
                else
                    VisitNativeValue(value, val);
            }
        }
        break;

    case TNativeFn:
        {
            NativeFunction *fun = Runner->lookupNativeFn(Runner->GetNativeFnId(value));

            if (fun)
            {
                FlowPtr ptr = value.GetNativeFnDataPtr();
                int size = FlowPtrToInt(ptr) ? *(int*)MEMORY_PTR(ptr-4,4,false) : 0;
                VisitNativeFun(value, fun, size ? SLOT_PTR(ptr, size) : 0, size);
            }
            else
                VisitError(value);
        }
        break;

    default:
        VisitError(value);
    }
}

#ifdef FLOW_COMPACT_STRUCTS
bool HeapWalker::ProcessFields(FlowStructHeader *obj, StructDef *def, bool write_back)
{
    for (int i = 0; i < def->FieldsCount; i++)
    {
        const FlowStructFieldDef &fd = def->FieldDefs[i];
        StackSlot tmp = fd.fn_get(obj->Bytes + fd.offset, Runner);

        Process(tmp);

        if (write_back && !fd.fn_set(obj->Bytes + fd.offset, tmp))
            return false;
    }

    return true;
}
#endif
