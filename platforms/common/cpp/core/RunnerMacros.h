#ifndef RUNNERMACROS_H
#define RUNNERMACROS_H

/* This file defines macros that help in writing GC-safe native code.
   In order to do it, follow these rules:

   1. Don't directly use FlowPtr variables, or Memory->GetRawPointer.
      These are intended for low-level or optimized code, which obviously
      requires safety analysis on a case-by-case basis.

   2. All StackSlot local variables must be defined using either
      RUNNER_PopArgs#(...), or RUNNER_DefSlots#(...). These macros
      incur a small runtime overhead to register the variables with
      the garbage collector, in return making them safe.

      If you absolutely need to pass StackSlot values as parameters
      to C++ functions, you can use RUNNER_RegisterSlots#(...) as the
      first statement of the function to make these parameter variables
      safe post-factum.

   3. Only the outermost function call of a C++ statement may
      be potentially allocating, or invoking GC. This means for
      instance that you cannot pass the return value of AllocateString
      to EvalFunction without storing it in a variable first,
      or pass the result of EvalFunction to Memory->SetStackSlot.

      Exceptions:
        RUNNER->Push(AllocatingCall(...));
        RUNNER->SetArraySlot(variable, ..., AllocatingCall(...));
        var = RUNNER->GetString(AllocatingCall(...));
        var = RUNNER->GetNativePtr(AllocatingCall(...));

    Rationale:
      The problem of GC safety arises because when GC happens it
      moves Flow objects around, thus invalidating all old FlowPtr
      values. This means that all memory locations holding such
      pointers must be known and understandable to the GC engine
      at the moment it is called, so that it can patch them up.
        Plain FlowPtr values, as well as flow pointers disguised
      as native ones by GetRawPointer cannot be understood by GC,
      and are completely invalidated.
        StackSlot objects can be patched, but for this to happen
      their addresses must be pushed onto a special list in the
      runner. The macros take care of that.
        Finally, the C++ compiler decomposes nested calls anyway
      by introducing temporary variables itself, which are naturally
      in violation of rule 2. It can be proven that this is OK
      if the allocating call is the last thing that happens, so
      consequently it must be the outermost one. The exceptions
      can also be proven safe due to the properties of the listed
      functions.
      (SetStackSlot is unsafe because it almost certainly takes
       a FlowPtr temporary. SetArraySlot on the other hand receives
       only StackSlot references, thus ensuring correct ordering,
       provided that the array variable is valid under rule 2.)
 */

#ifdef _MSC_VER
    #define _INLINE_WRAP(content) __forceinline content
#else
    #define _INLINE_WRAP(content) inline content __attribute__((always_inline))
#endif

#define RUNNER pRunner__
#define RUNNER_VAR ByteCodeRunner *RUNNER
#define RUNNER_ARGS ByteCodeRunner *const RUNNER, StackSlot *const pRunnerArgs__
#define RUNNER_ARG(idx) (pRunnerArgs__[idx])
#define RUNNER_CLOSURE (pRunnerArgs__[-1])
#define MEMORY (RUNNER->GetMemory())

// Squash unused argument warnings
#define IGNORE_LOCAL(name) (void)&name;
#define IGNORE_RUNNER_ARGS \
    IGNORE_LOCAL(RUNNER); IGNORE_LOCAL(pRunnerArgs__);

#define FLOWVOID StackSlot::MakeVoid()
#define RETVOID return FLOWVOID

#define WITH_RUNNER_LOCK_DEFERRED(runner) \
    ByteCodeRunner::LockDeferred _lock_dfr##__LINE__(runner); \
    (void)(&_lock_dfr##__LINE__);

#define RUNNER_DefSlotAlias(newvar,oldvar) StackSlot &newvar = oldvar;

// Local root registration

#define RUNNER_RegisterSlots1(slot0) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 1, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots2(slot0, slot1) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 2, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots3(slot0, slot1, slot2) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1, &slot2 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 3, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots4(slot0, slot1, slot2, slot3) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1, &slot2, &slot3 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 4, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots5(slot0, slot1, slot2, slot3, slot4) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1, &slot2, &slot3, &slot4 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 5, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots6(slot0, slot1, slot2, slot3, slot4, slot5) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1, &slot2, &slot3, &slot4, &slot5 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 6, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots7(slot0, slot1, slot2, slot3, slot4, slot5, slot6) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1, &slot2, &slot3, &slot4, &slot5, &slot6 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 7, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots8(slot0, slot1, slot2, slot3, slot4, slot5, slot6, slot7) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1, &slot2, &slot3, &slot4, &slot5, &slot6, &slot7 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 8, _flow_root_lst_##slot0);
#define RUNNER_RegisterSlots9(slot0, slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8) \
    StackSlot *_flow_root_lst_##slot0[] = { &slot0, &slot1, &slot2, &slot3, &slot4, &slot5, &slot6, &slot7, &slot8 }; \
    LocalRootDefinition _flow_root_def_##slot0(RUNNER, 9, _flow_root_lst_##slot0);

#define RUNNER_RegisterNativeRoot(type, name) \
    LocalNativeRootDefinition<type> _flow_nroot_def_##name(RUNNER, const_cast<type&>(name));

// Argument retrieval for natives:

#define RUNNER_PopArgs1(arg0) \
    IGNORE_LOCAL(RUNNER); \
    StackSlot &arg0 = RUNNER_ARG(0);

#define RUNNER_PopArgs2(arg0, arg1) \
    RUNNER_PopArgs1(arg0); \
    StackSlot &arg1 = RUNNER_ARG(1);

#define RUNNER_PopArgs3(arg0, arg1, arg2) \
    RUNNER_PopArgs2(arg0, arg1); \
    StackSlot &arg2 = RUNNER_ARG(2);

#define RUNNER_PopArgs4(arg0, arg1, arg2, arg3) \
    RUNNER_PopArgs3(arg0, arg1, arg2); \
    StackSlot &arg3 = RUNNER_ARG(3);

#define RUNNER_PopArgs5(arg0, arg1, arg2, arg3, arg4) \
    RUNNER_PopArgs4(arg0, arg1, arg2, arg3); \
    StackSlot &arg4 = RUNNER_ARG(4);

#define RUNNER_PopArgs6(arg0, arg1, arg2, arg3, arg4, arg5) \
    RUNNER_PopArgs5(arg0, arg1, arg2, arg3, arg4); \
    StackSlot &arg5 = RUNNER_ARG(5);

#define RUNNER_PopArgs7(arg0, arg1, arg2, arg3, arg4, arg5, arg6) \
    RUNNER_PopArgs6(arg0, arg1, arg2, arg3, arg4, arg5); \
    StackSlot &arg6 = RUNNER_ARG(6);

#define RUNNER_PopArgs8(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7) \
    RUNNER_PopArgs7(arg0, arg1, arg2, arg3, arg4, arg5, arg6); \
    StackSlot &arg7 = RUNNER_ARG(7);

#define RUNNER_PopArgs9(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) \
    RUNNER_PopArgs8(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7); \
    StackSlot &arg8 = RUNNER_ARG(8);

#define RUNNER_PopArgs10(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) \
    RUNNER_PopArgs9(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8); \
    StackSlot &arg9 = RUNNER_ARG(9);

#define RUNNER_PopArgs11(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10) \
    RUNNER_PopArgs10(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9); \
    StackSlot &arg10 = RUNNER_ARG(10);

#define RUNNER_PopArgs12(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11) \
    RUNNER_PopArgs11(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10); \
    StackSlot &arg11 = RUNNER_ARG(11);

// Slot local variable definition

#define RUNNER_DefSlots1(slot0) \
    RUNNER_DefSlotArray(slot0##_arr_, 1); \
    StackSlot &slot0 = slot0##_arr_[0];

#define RUNNER_DefSlots2(slot0, slot1) \
    RUNNER_DefSlotArray(slot0##_arr_, 2); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1];

#define RUNNER_DefSlots3(slot0, slot1, slot2) \
    RUNNER_DefSlotArray(slot0##_arr_, 3); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1]; \
    StackSlot &slot2 = slot0##_arr_[2];

#define RUNNER_DefSlots4(slot0, slot1, slot2, slot3) \
    RUNNER_DefSlotArray(slot0##_arr_, 4); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1]; \
    StackSlot &slot2 = slot0##_arr_[2]; \
    StackSlot &slot3 = slot0##_arr_[3];

#define RUNNER_DefSlots5(slot0, slot1, slot2, slot3, slot4) \
    RUNNER_DefSlotArray(slot0##_arr_, 5); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1]; \
    StackSlot &slot2 = slot0##_arr_[2]; \
    StackSlot &slot3 = slot0##_arr_[3]; \
    StackSlot &slot4 = slot0##_arr_[4];

#define RUNNER_DefSlots6(slot0, slot1, slot2, slot3, slot4, slot5) \
    RUNNER_DefSlotArray(slot0##_arr_, 6); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1]; \
    StackSlot &slot2 = slot0##_arr_[2]; \
    StackSlot &slot3 = slot0##_arr_[3]; \
    StackSlot &slot4 = slot0##_arr_[4]; \
    StackSlot &slot5 = slot0##_arr_[5];

#define RUNNER_DefSlots7(slot0, slot1, slot2, slot3, slot4, slot5, slot6) \
    RUNNER_DefSlotArray(slot0##_arr_, 7); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1]; \
    StackSlot &slot2 = slot0##_arr_[2]; \
    StackSlot &slot3 = slot0##_arr_[3]; \
    StackSlot &slot4 = slot0##_arr_[4]; \
    StackSlot &slot5 = slot0##_arr_[5]; \
    StackSlot &slot6 = slot0##_arr_[6];

#define RUNNER_DefSlots8(slot0, slot1, slot2, slot3, slot4, slot5, slot6, slot7) \
    RUNNER_DefSlotArray(slot0##_arr_, 8); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1]; \
    StackSlot &slot2 = slot0##_arr_[2]; \
    StackSlot &slot3 = slot0##_arr_[3]; \
    StackSlot &slot4 = slot0##_arr_[4]; \
    StackSlot &slot5 = slot0##_arr_[5]; \
    StackSlot &slot6 = slot0##_arr_[6]; \
    StackSlot &slot7 = slot0##_arr_[7];

#define RUNNER_DefSlots9(slot0, slot1, slot2, slot3, slot4, slot5, slot6, slot7, slot8) \
    RUNNER_DefSlotArray(slot0##_arr_, 9); \
    StackSlot &slot0 = slot0##_arr_[0]; \
    StackSlot &slot1 = slot0##_arr_[1]; \
    StackSlot &slot2 = slot0##_arr_[2]; \
    StackSlot &slot3 = slot0##_arr_[3]; \
    StackSlot &slot4 = slot0##_arr_[4]; \
    StackSlot &slot5 = slot0##_arr_[5]; \
    StackSlot &slot6 = slot0##_arr_[6]; \
    StackSlot &slot7 = slot0##_arr_[7]; \
    StackSlot &slot8 = slot0##_arr_[8];

// Slot array definition

template<unsigned size, bool is_big = (size>32)>
struct SlotArrayInit {};

template<> struct SlotArrayInit<0,false> {
    static void init(StackSlot*) {}
};
template<> struct SlotArrayInit<1,false> {
    static _INLINE_WRAP(void init(StackSlot *array)) {
#ifdef __x86_64__
        array[0].slot_private.QWordVal = uint64_t(-1);
#else
        array[0].slot_private.Ints[1] = -1;
#endif
    }
};
template<> struct SlotArrayInit<2,false> {
    static _INLINE_WRAP(void init(StackSlot *array)) {
#ifdef __x86_64__
        array[0].slot_private.QWordVal = array[1].slot_private.QWordVal = uint64_t(-1);
#else
        array[0].slot_private.Ints[1] = array[1].slot_private.Ints[1] = -1;
#endif
    }
};
template<> struct SlotArrayInit<3,false> {
    static _INLINE_WRAP(void init(StackSlot *array)) {
#ifdef __x86_64__
        array[0].slot_private.QWordVal = array[1].slot_private.QWordVal = array[2].slot_private.QWordVal = uint64_t(-1);
#else
        array[0].slot_private.Ints[1] = array[1].slot_private.Ints[1] = array[2].slot_private.Ints[1] = -1;
#endif
    }
};
template<> struct SlotArrayInit<4,false> {
    static _INLINE_WRAP(void init(StackSlot *array)) {
#ifdef __x86_64__
        array[0].slot_private.QWordVal = array[1].slot_private.QWordVal = array[2].slot_private.QWordVal = array[3].slot_private.QWordVal = uint64_t(-1);
#else
        array[0].slot_private.Ints[1] = array[1].slot_private.Ints[1] = array[2].slot_private.Ints[1] = array[3].slot_private.Ints[1] = -1;
#endif
    }
};

template<unsigned size>
struct SlotArrayInit<size,false> {
    static _INLINE_WRAP(void init(StackSlot *array)) {
        SlotArrayInit<((size-1)&~3)>::init(array);
        SlotArrayInit<size - ((size-1)&~3)>::init(array + ((size-1)&~3));
    }
};
template<unsigned size>
struct SlotArrayInit<size,true> {
    static _INLINE_WRAP(void init(StackSlot *array)) {
        memset(array, -1, size*STACK_SLOT_SIZE);
    }
};

#define RUNNER_DefSlotArray(name, size) \
    StackSlot name[size]; \
    SlotArrayInit<size>::init(name); \
    LocalRootDefinition _flow_root_def_##name(RUNNER, size, name);

#define RUNNER_CopyArgArray(name, size, to_add) \
    StackSlot name[size+to_add]; \
    memcpy(name, pRunnerArgs__, sizeof(StackSlot)*size); \
    memset(name+size, -1, sizeof(StackSlot)*to_add); \
    LocalRootDefinition _flow_root_def_##name(RUNNER, size+to_add, name);

#define RUNNER_CopyClosureArgArray(name, size, to_add) \
    StackSlot name##_full_[1+size+to_add]; StackSlot *const name = name##_full_+1; \
    memcpy(name##_full_, pRunnerArgs__-1, sizeof(StackSlot)*(size+1)); \
    memset(name+size, -1, sizeof(StackSlot)*to_add); \
    LocalRootDefinition _flow_root_def_##name(RUNNER, size+to_add+1, name##_full_);

// Tag checking

#define RUNNER_CheckError() \
    if (unlikely(RUNNER->IsErrorReported())) RETVOID;

#define RUNNER_CheckTagVoid(tag, slot) \
    if (unlikely(!slot.Is##tag())) { \
        RUNNER->ReportTagError(slot, tag, #slot, NULL); \
        return; \
    }

#define RUNNER_CheckTag(tag, slot) \
    if (unlikely(!slot.Is##tag())) { \
        RUNNER->ReportTagError(slot, tag, #slot, NULL); \
        RETVOID; \
    }
#define RUNNER_CheckTag1(tag, slot1) \
    RUNNER_CheckTag(tag, slot1);
#define RUNNER_CheckTag2(tag, slot1, slot2) \
    RUNNER_CheckTag(tag, slot1); \
    RUNNER_CheckTag(tag, slot2);
#define RUNNER_CheckTag3(tag, slot1, slot2, slot3) \
    RUNNER_CheckTag(tag, slot1); \
    RUNNER_CheckTag(tag, slot2); \
    RUNNER_CheckTag(tag, slot3);
#define RUNNER_CheckTag4(tag, slot1, slot2, slot3, slot4) \
    RUNNER_CheckTag(tag, slot1); \
    RUNNER_CheckTag(tag, slot2); \
    RUNNER_CheckTag(tag, slot3); \
    RUNNER_CheckTag(tag, slot4);
#define RUNNER_CheckTag5(tag, slot1, slot2, slot3, slot4, slot5) \
    RUNNER_CheckTag(tag, slot1); \
    RUNNER_CheckTag(tag, slot2); \
    RUNNER_CheckTag(tag, slot3); \
    RUNNER_CheckTag(tag, slot4); \
    RUNNER_CheckTag(tag, slot5);
#define RUNNER_CheckTag6(tag, slot1, slot2, slot3, slot4, slot5, slot6) \
    RUNNER_CheckTag(tag, slot1); \
    RUNNER_CheckTag(tag, slot2); \
    RUNNER_CheckTag(tag, slot3); \
    RUNNER_CheckTag(tag, slot4); \
    RUNNER_CheckTag(tag, slot5); \
    RUNNER_CheckTag(tag, slot6);

// Lists

#define RUNNER_ForEachCons(cur, list) \
    for (cur = list; RUNNER->IsConsStruct(cur); cur = RUNNER->GetStructSlot(cur,1))

#define RUNNER_CheckEmptyList(cur, func_name) \
    if (unlikely(!RUNNER->VerifyEmptyList(cur, func_name))) RETVOID;

#define RUNNER_CheckStructType(cur, structname, func_name) \
    if (unlikely(!RUNNER->Verify##structname(cur, func_name))) RETVOID;

#endif // RUNNERMACROS_H
