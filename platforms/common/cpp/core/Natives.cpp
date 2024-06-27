#include "ByteCodeRunner.h"
#ifndef _MSC_VER
    #include <sys/time.h>
#else
    #include <Windows.h>
    #include <sys/timeb.h>
#endif

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <time.h>
#include <string.h>
#include <errno.h>

#include "RunnerMacros.h"

#include <algorithm>
#include <sstream>
#include <iomanip>

#include "utils/md5.h"

using std::endl;
using std::stringstream;
using std::max;
using std::min;

/* Native object support */

template<> NativeValueType<FlowNativeObject*,true>
NativeValueType<FlowNativeObject*,true>::Tag("FlowNativeObject*", NULL);

/*FlowNativeValueType *FlowNativeObject::getFlowValueType() const {
    return &NativeValueType<FlowNativeObject*>::Tag;
}*/

bool flow_instanceof(FlowNativeObject *obj, FlowNativeValueType *type)
{
    NativeValueTypeBase *otype = obj ? obj->getFlowValueType() : NULL;

    while (otype) {
        if (otype == type)
            return true;

        otype = otype->parent();
    }

    return false;
}

FlowNativeObject::~FlowNativeObject() {
    assert(id_slot.IsVoid());
}

void FlowNativeObject::autoRegisterValue() const {
    assert(id_slot.IsVoid());
    FlowNativeObject *obj = const_cast<FlowNativeObject*>(this);
    StackSlot nv = owner->AllocNativeObj(getFlowValueType()->WrapNativePointer(owner, obj));
    UNUSED(nv);
    assert(id_slot.IsNative() && id_slot.GetNativeValId() == nv.GetNativeValId() && !id_tag);
}

void FlowNativeValueType::ReferenceValue(ByteCodeRunner *, AbstractNativeValue *wrapper) {
    FlowNativeObject *obj = wrapper->nativeObject();
    assert(obj->id_slot.IsVoid());
    obj->id_slot = wrapper->id();
    obj->id_tag = 0;
    assert(obj->id_slot.IsNative());
}

void FlowNativeValueType::DereferenceValue(ByteCodeRunner *, AbstractNativeValue *wrapper) {
    FlowNativeObject *obj = wrapper->nativeObject();
    assert(obj->id_slot.IsNative());
    obj->id_slot = StackSlot::MakeVoid();
    delete obj;
}

/* Native hosts */

NativeMethodHost::NativeMethodHost(ByteCodeRunner *owner) : owner(owner) {
    owner->NativeHosts.push_back(this);
}

NativeMethodHost::~NativeMethodHost() {
    if (owner)
        eraseItem(owner->NativeHosts, this);
}

/* Utilities */

static void ClipLenToRange(int pidx, unsigned *plen, unsigned size) {
    // Range too long, or overflow even?
    int end = pidx + int(*plen);
    if (end > int(size) || end < 0)
        *plen = size - pidx;
}

static void checkProperSubstringArguments(int *idx, int *len, int strLen)
{
    // this function copies the current logic of JS target from NativeHx.substring
    // to unify targets
    if (unlikely(*len < 0)) {
        if (*idx != 0) *len = 0;
        else {
            int smartLen1 = *len + *idx;
            if (smartLen1 >= 0) *len = 0;
            else {
                int smartLen2 = smartLen1 + strLen;
                if (smartLen2 <= 0) *len = 0;
                else *len = smartLen2;
            }
        }
    }
    if (unlikely(*idx < 0)) {
        int smartIdx = *idx + strLen;
        if (smartIdx > 0) *idx = smartIdx;
        else *idx = 0;
    } else if (*idx >= strLen) {
        *len = 0;
    }
}

/* Native function wrappers */

StackSlot ByteCodeRunner::const_closure(RUNNER_ARGS)
{
    return RUNNER->GetClosureSlot(RUNNER_CLOSURE,0);
}

StackSlot StubNative::thunk(ByteCodeRunner *runner, StackSlot*)
{
    NativeFunction *self = get_self(runner);
    if (runner->NotifyStubs)
        runner->flow_err << "Stub native function called: " << self->name() << endl;
    RETVOID;
}

StackSlot NativeClosure::thunk(ByteCodeRunner *runner, StackSlot *args)
{
    NativeClosure *self = (NativeClosure*)get_self(runner);
    return (self->Clos)(runner, args, self->data);
}

#ifdef FLOW_COMPACT_STRUCTS
namespace flow_fields {
    StackSlot get_int(const void *p,ByteCodeRunner*) {
        return StackSlot::MakeInt(*(const int*)p);
    }
    bool set_int(void *p, const StackSlot &v) {
        if (!v.IsInt()) return false;
        *(int*)p = v.GetInt();
        return true;
    }
    StackSlot get_bool(const void *p,ByteCodeRunner*) {
        return StackSlot::MakeBool(*(const char*)p);
    }
    bool set_bool(void *p, const StackSlot &v) {
        if (!v.IsBool()) return false;
        *(char*)p = v.GetBool();
        return true;
    }
    StackSlot get_double(const void *p,ByteCodeRunner*) {
        return StackSlot::MakeDouble(*(const double*)p);
    }
    bool set_double(void *p, const StackSlot &v) {
        if (!v.IsDouble()) return false;
        *(double*)p = v.GetDouble();
        return true;
    }
    StackSlot get_slot(const void *p,ByteCodeRunner*) {
        return *(const StackSlot*)p;
    }
    bool set_slot(void *p, const StackSlot &v) {
        *(StackSlot*)p = v;
        return true;
    }
#if 0
    StackSlot get_array(const void *p,ByteCodeRunner*) {
        const FlowStructArray *pp = (const FlowStructArray*)p;
        return StackSlot::MakeArray(pp->addr, pp->size);
    }
    bool set_array(void *p, const StackSlot &v) {
        if (!v.IsArray()) return false;
        FlowStructArray *pp = (FlowStructArray*)p;
        pp->addr = v.GetInternalArrayPtr();
        pp->size = v.GetInternalArraySize();
        return true;
    }
    StackSlot get_string(const void *p,ByteCodeRunner*) {
        const FlowStructString *pp = (const FlowStructString*)p;
        return StackSlot::MakeString(pp->addr, pp->size);
    }
    bool set_string(void *p, const StackSlot &v)  {
        if (!v.IsString()) return false;
        FlowStructString *pp = (FlowStructString*)p;
        pp->addr = v.GetInternalStringPtr();
        pp->size = v.GetInternalStringSize();
        return true;
    }
    StackSlot get_ref(const void *p,ByteCodeRunner*) {
        const FlowStructRef *pp = (const FlowStructRef*)p;
        return StackSlot::MakeRefTo(pp->addr, pp->id);
    }
    bool set_ref(void *p, const StackSlot &v) {
        if (!v.IsRefTo()) return false;
        FlowStructRef *pp = (FlowStructRef*)p;
        pp->addr = v.GetRawRefPtr();
        pp->id = v.GetInternalRefId();
        return true;
    }
#else
    StackSlot get_array(const void *p,ByteCodeRunner*) {
        return *(const StackSlot*)p;
    }
    bool set_array(void *p, const StackSlot &v) {
        if (!v.IsArray()) return false;
        *(StackSlot*)p = v;
        return true;
    }
    StackSlot get_string(const void *p,ByteCodeRunner*) {
        return *(const StackSlot*)p;
    }
    bool set_string(void *p, const StackSlot &v) {
        if (!v.IsString()) return false;
        *(StackSlot*)p = v;
        return true;
    }
    StackSlot get_ref(const void *p,ByteCodeRunner*) {
        return *(const StackSlot*)p;
    }
    bool set_ref(void *p, const StackSlot &v) {
        if (!v.IsRefTo()) return false;
        *(StackSlot*)p = v;
        return true;
    }
#endif
    StackSlot get_struct(const void *p,ByteCodeRunner *runner) {
        FlowPtr pv = *(const FlowPtr*)p;
        FlowStructHeader *sh = runner->GetMemory()->GetStructPointer(pv, false);
        return StackSlot::MakeStruct(pv, sh->StructId);
    }
    bool set_struct(void *p, const StackSlot &v) {
        if (!v.IsStruct()) return false;
        assert(v.GetRawStructPtr() != MakeFlowPtr(0));
        *(FlowPtr*)p = v.GetRawStructPtr();
        return true;
    }
}
#endif

IMPLEMENT_FLOW_NATIVE_OBJECT(FlowStackSnapshot, FlowNativeObject);

// NATIVES

StackSlot ByteCodeRunner::println(RUNNER_ARGS)
{
    RUNNER_PopArgs1(object);

    if (object.IsString())
        RUNNER->flow_out << encodeUtf8(RUNNER->GetString(object));
    else
        RUNNER->PrintData(RUNNER->flow_out, object);

    RUNNER->flow_out << endl;

    RETVOID;
}

StackSlot ByteCodeRunner::failWithError(RUNNER_ARGS)
{
    RUNNER_PopArgs1(error);

    std::string msg = encodeUtf8(RUNNER->GetString(error));
    RUNNER->ReportError(InvalidCall, "Runtime failure: %s", msg.c_str());
    RETVOID;
}

StackSlot ByteCodeRunner::deleteNative(RUNNER_ARGS)
{
    RUNNER_PopArgs1(arg);

    if (arg.IsNative())
        RUNNER->DeleteNative(arg);
    RETVOID;
}

StackSlot ByteCodeRunner::removePlatformEventListener(RUNNER_ARGS, void *)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 2);
    PlatformEvent event = (PlatformEvent)slot[0].GetInt();
    int cb_root = slot[1].GetInt();
    std::vector<int> & listeners =  RUNNER->PlatformEventListeners[event];
    listeners.erase(std::find(listeners.begin(), listeners.end(), cb_root));
    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

static PlatformEvent last_network_event = PlatformEventUnknown;
StackSlot ByteCodeRunner::addPlatformEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs2(event, cb);
    RUNNER_CheckTag1(TString, event);

    std::string event_str = encodeUtf8(RUNNER->GetString(event));
    PlatformEvent e = PlatformEventUnknown;

    if (event_str == "idle") e = PlatformApplicationUserIdle; else
    if (event_str == "active") e = PlatformApplicationUserActive; else
    if (event_str == "resume") e = PlatformApplicationResumed; else
    if (event_str == "suspend") e = PlatformApplicationSuspended; else
    if (event_str == "online") e = PlatformNetworkOnline; else
    if (event_str == "offline") e = PlatformNetworkOffline; else
    if (event_str == "lowmemory") e = PlatformLowMemory; else
    if (event_str == "devicebackbutton") e = PlatformDeviceBackButton;

    int cb_root = RUNNER->RegisterRoot(cb);
    RUNNER->PlatformEventListeners[e].push_back(cb_root);

    // Send network state right now
    if (e == PlatformNetworkOffline && last_network_event == PlatformNetworkOffline) RUNNER->EvalFunction(cb, 0);
    else if (e == PlatformNetworkOnline && last_network_event == PlatformNetworkOnline) RUNNER->EvalFunction(cb, 0);

    return RUNNER->AllocateNativeClosure(removePlatformEventListener, "addPlatformEventListener$disposer", 0, NULL,
                                         2, StackSlot::MakeInt(e), StackSlot::MakeInt(cb_root));
}

bool ByteCodeRunner::NotifyPlatformEvent(PlatformEvent event) {
    if (event == PlatformNetworkOffline || event == PlatformNetworkOnline) last_network_event = event;

    std::vector<int> & listeners =  PlatformEventListeners[event];
    bool cancelled = false;
    for (std::vector<int>::iterator it = listeners.begin(); it != listeners.end(); ++ it) {
        StackSlot tmp = EvalFunction(LookupRoot(*it), 0);
        cancelled |= tmp.IsBool() && tmp.GetBool();
    }
    return cancelled;
}

StackSlot ByteCodeRunner::removeCustomFileTypeHandler(RUNNER_ARGS, void *)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 2);
    int cb_root = slot[0].GetInt();
    std::vector<int> & listeners =  RUNNER->CustomFileTypeHandlers;
    listeners.erase(std::find(listeners.begin(), listeners.end(), cb_root));
    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

StackSlot ByteCodeRunner::addCustomFileTypeHandler(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);
    RUNNER->CustomFileTypeHandlers.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removePlatformEventListener, "addCustomFileTypeHandler$disposer", 0, NULL,
                                         1, StackSlot::MakeInt(cb_root));
}

void ByteCodeRunner::NotifyCustomFileTypeOpened(unicode_string path) {
    std::vector<int> & listeners =  CustomFileTypeHandlers;
    for (std::vector<int>::iterator it = listeners.begin(); it != listeners.end(); ++ it) {
        EvalFunction(LookupRoot(*it), 1, AllocateString(path));
    }
}

// input & output via data stack ( array closure --> mapi(closure, array) )
StackSlot ByteCodeRunner::mapi(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, clos);
    RUNNER_CheckTag(TArray, arr);

    RUNNER_DefSlotArray(fn_args, 3);
    fn_args[0] = clos;
    fn_args[1] = StackSlot::MakeInt(0);

    int len = RUNNER->GetArraySize(arr);
    RUNNER_DefSlots1(retarr);
    retarr = RUNNER->AllocateArray(len);

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    for (int i = 0; i < len; ++i)
    {
        fn_args[1].SetIntValue(i);
        fn_args[2] = RUNNER->GetArraySlot(arr, i);
        fn_args[2] = RUNNER->FastEvalFunction(fn_args, 2);
        RUNNER->SetArraySlot(retarr, i, fn_args[2]);
    }

    return retarr;
}

StackSlot ByteCodeRunner::map(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, clos);
    RUNNER_CheckTag(TArray, arr);

    RUNNER_DefSlotArray(fn_args, 2);
    fn_args[0] = clos;

    int len = RUNNER->GetArraySize(arr);
    RUNNER_DefSlots1(retarr);
    retarr = RUNNER->AllocateArray(len);

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    for (int i = 0; i < len; ++i)
    {
        fn_args[1] = RUNNER->GetArraySlot(arr, i);
        fn_args[1] = RUNNER->FastEvalFunction(fn_args, 1);
        RUNNER->SetArraySlot(retarr, i, fn_args[1]);
    }

    return retarr;
}

StackSlot ByteCodeRunner::iter(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, clos);
    RUNNER_CheckTag(TArray, arr);

    RUNNER_DefSlotArray(fn_args, 2);
    fn_args[0] = clos;

    int len = RUNNER->GetArraySize(arr);

    for (int i = 0; i < len; ++i)
    {
        fn_args[1] = RUNNER->GetArraySlot(arr, i);
        RUNNER->FastEvalFunction(fn_args, 1);
    }

    RETVOID;
}

StackSlot ByteCodeRunner::iteri(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, clos);
    RUNNER_CheckTag(TArray, arr);

    RUNNER_DefSlotArray(fn_args, 3);
    fn_args[0] = clos;
    fn_args[1] = StackSlot::MakeInt(0);

    int len = RUNNER->GetArraySize(arr);

    for (int i = 0; i < len; ++i)
    {
        fn_args[1].SetIntValue(i);
        fn_args[2] = RUNNER->GetArraySlot(arr, i);
        RUNNER->FastEvalFunction(fn_args, 2);
    }

    RETVOID;
}

StackSlot ByteCodeRunner::fold(RUNNER_ARGS)
{
    RUNNER_PopArgs3(arr, init, clos);
    RUNNER_CheckTag(TArray, arr);
    RUNNER_DefSlotArray(fn_args, 3);

    int len = RUNNER->GetArraySize(arr);

    fn_args[0] = clos;
    fn_args[1] = init;

    for (int i = 0; i < len; ++i)
    {
        fn_args[2] = RUNNER->GetArraySlot(arr, i);

        // CALL
        fn_args[1] = RUNNER->FastEvalFunction(fn_args, 2);

        RUNNER_CheckError();
    }

    return fn_args[1];
}

StackSlot ByteCodeRunner::foldi(RUNNER_ARGS)
{
    RUNNER_PopArgs3(arr, init, clos);
    RUNNER_CheckTag(TArray, arr);
    RUNNER_DefSlotArray(fn_args, 4);

    int len = RUNNER->GetArraySize(arr);

    fn_args[0] = clos;
    fn_args[2] = init;

    for (int i = 0; i < len; ++i)
    {
        fn_args[1] = StackSlot::MakeInt(i);
        fn_args[3] = RUNNER->GetArraySlot(arr, i);

        // CALL
        fn_args[2] = RUNNER->FastEvalFunction(fn_args, 3);

        RUNNER_CheckError();
    }

    return fn_args[2];
}

StackSlot ByteCodeRunner::filter(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, clos);
    RUNNER_CheckTag(TArray, arr);
    RUNNER_DefSlots2(retarr, val);

    int len = RUNNER->GetArraySize(arr);
    if (len == 0) {
        return StackSlot::MakeEmptyArray();
    }

    // Compute the result length and an inclusion mask
    std::vector<char> inctab(len, 0);
    int rlen = 0;

    RUNNER_DefSlotArray(fn_args, 2);
    fn_args[0] = clos;

    for (int i = 0; i < len; ++i)
    {
        fn_args[1] = RUNNER->GetArraySlot(arr, i);
        val = RUNNER->FastEvalFunction(fn_args, 1);
        RUNNER_CheckTag(TBool, val);
        char inc = val.GetBool() ? 1 : 0;
        inctab[i] = inc;
        rlen += inc;
    }

    // Allocate output and copy data
    retarr = RUNNER->AllocateArray(rlen);

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    for (int i = 0, j = 0; i < len; ++i)
        if (inctab[i])
            RUNNER->SetArraySlot(retarr, j++, RUNNER->GetArraySlot(arr, i));

    return retarr;
}

StackSlot ByteCodeRunner::gc(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    RUNNER->ForceGC(0, true);
    RETVOID;
}

StackSlot ByteCodeRunner::subrange(RUNNER_ARGS)
{
    RUNNER_PopArgs3(arr, idx, len);
    RUNNER_CheckTag(TArray, arr);
    RUNNER_CheckTag2(TInt, idx, len);

    unsigned arr_len = RUNNER->GetArraySize(arr);
    unsigned len_int = len.GetInt();

    if (unlikely(idx.GetInt() < 0 || len_int < 1) || unsigned(idx.GetInt()) >= arr_len) {
        return StackSlot::MakeEmptyArray();
    }

    ClipLenToRange(idx.GetInt(), &len_int, arr_len);

    StackSlot rval = RUNNER->AllocateUninitializedArray(len_int); // ALLOC

    if (unlikely(RUNNER->IsErrorReported()))
        return StackSlot::MakeVoid();

    RUNNER->CopyArraySlots(rval, 0, arr, idx.GetInt(), len_int);

    return rval;
}

StackSlot ByteCodeRunner::length(RUNNER_ARGS)
{
    RUNNER_PopArgs1(arr);
    RUNNER_CheckTag(TArray, arr);
    return StackSlot::MakeInt(RUNNER->GetArraySize(arr));
}

StackSlot ByteCodeRunner::NativeStrlen(RUNNER_ARGS)
{
    RUNNER_PopArgs1(str);
    RUNNER_CheckTag(TString, str);
    return StackSlot::MakeInt(RUNNER->GetStringSize(str));
}

int ByteCodeRunner::strRangeIndexOf(const unicode_char *pstr, const unicode_char *psub, unsigned l1, unsigned l2, unsigned start, unsigned end)
{
    if (end > l1)
        end = l1;

    if (l2 == 0) {
        return 0;
	} else if (!pstr) {
		return -1;
    } else if (l2 > end - start) {
        return -1;
    } else if (l2 == 1) {
        unicode_char key = *psub;

        for (const unicode_char *p = pstr + start; p <= pstr + end - l2; ++p) {
            if (*p == key) {
                return p - pstr;
            }
        }
    } else {
        unsigned size = l2 * FLOW_CHAR_SIZE;

        for (const unicode_char *p = pstr + start; p <= pstr + end - l2; ++p) {
            if (memcmp(p, psub, size) == 0) {
                return p - pstr;
            }
        }
    }

    return -1;
}

StackSlot ByteCodeRunner::strIndexOf(RUNNER_ARGS)
{
    RUNNER_PopArgs2(str, sub);
    RUNNER_CheckTag2(TString, str, sub);

    unsigned l1, l2;
    const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &l1);
    const unicode_char *psub = RUNNER->GetStringPtrSize(sub, &l2);

    return StackSlot::MakeInt(strRangeIndexOf(pstr, psub, l1, l2, 0, l1));
}

StackSlot ByteCodeRunner::strContainsAt(RUNNER_ARGS)
{
    RUNNER_PopArgs3(str, pos, sub);
    RUNNER_CheckTag2(TString, str, sub);
    RUNNER_CheckTag1(TInt, pos);

    unsigned ppos = pos.GetInt();

    unsigned lstr, lsub;
    const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &lstr);
    const unicode_char *psub = RUNNER->GetStringPtrSize(sub, &lsub);

    if (ppos + lsub > lstr) {
        return StackSlot::MakeBool(false);
    }

    const unicode_char *pstrpos = pstr + ppos;
    unsigned size               = lsub * FLOW_CHAR_SIZE;

    return StackSlot::MakeBool(memcmp(pstrpos, psub, size) == 0);
}

StackSlot ByteCodeRunner::strRangeIndexOf(RUNNER_ARGS)
{
    RUNNER_PopArgs4(str, sub, start, end);
    RUNNER_CheckTag2(TString, str, sub);
    RUNNER_CheckTag2(TInt, start, end);

    unsigned l1, l2;
    const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &l1);
    const unicode_char *psub = RUNNER->GetStringPtrSize(sub, &l2);

    return StackSlot::MakeInt(strRangeIndexOf(pstr, psub, l1, l2, start.GetInt(), end.GetInt()));
}

StackSlot ByteCodeRunner::substring(RUNNER_ARGS)
{
    RUNNER_PopArgs3(str, idx, len);
    RUNNER_CheckTag(TString, str);
    RUNNER_CheckTag2(TInt, idx, len);

    int idx_int = idx.GetInt();
    int len_int = len.GetInt();

    checkProperSubstringArguments(&idx_int, &len_int, RUNNER->GetStringSize(str));
    if (len_int < 1)
        return StackSlot::MakeEmptyString();
    else
        RUNNER->DoSubstring(&str, idx_int, len_int);
    return str;
}

bool ByteCodeRunner::DoSubstring(StackSlot *pdata, int idx, unsigned len)
{
    ClipLenToRange(idx, &len, GetStringSize(*pdata));

    StackSlot tmp;
    FlowPtr *pp = AllocateStringRef(&tmp, len); // ALLOC

    *pp = GetStringAddr(*pdata) + idx * FLOW_CHAR_SIZE;
    *pdata = tmp;

    return true;
}

static STL_HASH_MAP<unicode_string, unicode_string> KeyValueMap;

StackSlot ByteCodeRunner::setKeyValue(RUNNER_ARGS)
{
    RUNNER_PopArgs2(akey, aval);

    unicode_string val = RUNNER->GetString(aval);
    unicode_string key = RUNNER->GetString(akey);

    KeyValueMap[key] = val;

    return StackSlot::MakeBool(1);
}

StackSlot ByteCodeRunner::getKeyValue(RUNNER_ARGS)
{
    RUNNER_PopArgs2(akey, adefval);

    unicode_string key = RUNNER->GetString(akey);

    STL_HASH_MAP<unicode_string, unicode_string>::iterator it = KeyValueMap.find(key);

    if (it != KeyValueMap.end())
        return RUNNER->AllocateString(it->second);
    else
        return adefval;
}

StackSlot ByteCodeRunner::removeKeyValue(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    RETVOID;
}

StackSlot ByteCodeRunner::removeAllKeyValues(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    RETVOID;
}

StackSlot ByteCodeRunner::getKeysList(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    RETVOID;
}

StackSlot ByteCodeRunner::generate(RUNNER_ARGS)
{
    RUNNER_PopArgs3(from_arg, to_arg, fn_arg);
    RUNNER_CheckTag2(TInt, from_arg, to_arg);

    int from = from_arg.GetInt();
    int to   = to_arg.GetInt();
    int len  = to - from;

    if (len <= 0) {
        return StackSlot::MakeEmptyArray();
    }

    RUNNER_DefSlotArray(fn_args, 2);
    fn_args[0] = fn_arg;

    RUNNER_DefSlots1(retarr);
    retarr = RUNNER->AllocateArray(len);

    for (int i = 0; i < len; ++i)
    {
        fn_args[1] = StackSlot::MakeInt(from + i);
        fn_args[1] = RUNNER->FastEvalFunction(fn_args, 1);
        RUNNER->SetArraySlot(retarr, i, fn_args[1]);
    }

    return retarr;
}

StackSlot ByteCodeRunner::enumFromTo(RUNNER_ARGS)
{
    RUNNER_PopArgs2(from_arg, to_arg);
    RUNNER_CheckTag2(TInt, from_arg, to_arg);

    int from = from_arg.GetInt();
    int to   = to_arg.GetInt();
    int len  = to - from + 1;

    if (len <= 0) {
        return StackSlot::MakeEmptyArray();
    }

    // Do not use safe wrappers for speed:
    StackSlot arrslot = RUNNER->AllocateUninitializedArray(len); // ALLOC

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    StackSlot *arr = (StackSlot*)MEMORY->GetRawPointer(arrslot.GetInternalArrayPtr(), len*STACK_SLOT_SIZE, true);
    for (int j = 0; j < len; j++)
        arr[j] = StackSlot::MakeInt(from + j);

    return arrslot;
}

StackSlot ByteCodeRunner::concat(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr1, arr2);
    RUNNER_CheckTag2(TArray, arr1, arr2);

    int arr1_len = RUNNER->GetArraySize(arr1);
    int arr2_len = RUNNER->GetArraySize(arr2);

    int len = arr1_len + arr2_len;

    if (len == 0) {
        return StackSlot::MakeEmptyArray();
    }

    // Do not use safe wrappers for speed:
    StackSlot rval = RUNNER->AllocateUninitializedArray(len); // ALLOC

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    RUNNER->CopyArraySlots(rval, 0, arr1, 0, arr1_len);
    RUNNER->CopyArraySlots(rval, arr1_len, arr2, 0, arr2_len);

    return rval;
}

StackSlot ByteCodeRunner::replace(RUNNER_ARGS)
{
    RUNNER_PopArgs3(arr, idx, new_val);
    RUNNER_CheckTag(TArray, arr);
    RUNNER_CheckTag(TInt, idx);

    int len = RUNNER->GetArraySize(arr);

    if (idx.GetInt() < 0 || idx.GetInt() > len) {
        RUNNER->ReportError(InvalidArgument, "Replace index %d out of bound %d",
                            idx.GetInt(), len);
        RETVOID;
    }

    // for arrayPush using !!!
    int new_len = (idx.GetInt() == len ? len + 1 : len);

    // Do not use safe wrappers for speed:
    StackSlot rval = RUNNER->AllocateUninitializedArray(new_len); // ALLOC

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    RUNNER->CopyArraySlots(rval, 0, arr, 0, len);
    RUNNER->SetArraySlot(rval, idx.GetInt(), new_val);

    return rval;
}

// Convert a string to an array of character codes
// native s2a : (string) -> [int] = Native.s2a;
StackSlot ByteCodeRunner::s2a(RUNNER_ARGS)
{
    RUNNER_PopArgs1(str);
    RUNNER_CheckTag(TString, str);

    int len = RUNNER->GetStringSize(str);

    if (len == 0) {
        return StackSlot::MakeEmptyArray();
    }

    // Do not use safe wrappers for speed:
    StackSlot aptr = RUNNER->AllocateUninitializedArray(len); // ALLOC

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    const unicode_char *str_data = RUNNER->GetStringPtr(str);
    StackSlot *arr_data = (StackSlot*)MEMORY->GetRawPointer(aptr.GetInternalArrayPtr(), len*STACK_SLOT_SIZE, true);

    for (int i = 0; i < len; ++i)
        arr_data[i] = StackSlot::MakeInt(str_data[i]);

    return aptr;
}

StackSlot ByteCodeRunner::string2utf8(RUNNER_ARGS)
{
    RUNNER_PopArgs1(str);
    RUNNER_CheckTag(TString, str);

    std::string utf8 = encodeUtf8(RUNNER->GetString(str));
    int len = utf8.size();

    if (len == 0) {
        return StackSlot::MakeEmptyArray();
    }

    // Do not use safe wrappers for speed:
    StackSlot aptr = RUNNER->AllocateUninitializedArray(len); // ALLOC
    StackSlot *arr_data = (StackSlot*)MEMORY->GetRawPointer(aptr.GetInternalArrayPtr(), len*STACK_SLOT_SIZE, true);

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    for (int i = 0; i < len; ++i)
        arr_data[i] = StackSlot::MakeInt(uint8_t(utf8[i]));

    return aptr;
}

// 32 bit xor
// native xor : (int, int) -> int = Native.bitXor;
StackSlot ByteCodeRunner::bitXor(RUNNER_ARGS)
{
    RUNNER_PopArgs2(a1, a2);
    RUNNER_CheckTag2(TInt, a1, a2);
    return StackSlot::MakeInt(a1.GetInt() ^ a2.GetInt());
}

StackSlot ByteCodeRunner::bitOr(RUNNER_ARGS)
{
    RUNNER_PopArgs2(a1, a2);
    RUNNER_CheckTag2(TInt, a1, a2);
    return StackSlot::MakeInt(a1.GetInt() | a2.GetInt());
}

StackSlot ByteCodeRunner::bitAnd(RUNNER_ARGS)
{
    RUNNER_PopArgs2(a1, a2);
    RUNNER_CheckTag2(TInt, a1, a2);
    return StackSlot::MakeInt(a1.GetInt() & a2.GetInt());
}

StackSlot ByteCodeRunner::bitUshr(RUNNER_ARGS)
{
    RUNNER_PopArgs2(a1, a2);
    RUNNER_CheckTag2(TInt, a1, a2);
    return StackSlot::MakeInt((unsigned int)(a1.GetInt()) >> a2.GetInt());
}

StackSlot ByteCodeRunner::bitShl(RUNNER_ARGS)
{
    RUNNER_PopArgs2(a1, a2);
    RUNNER_CheckTag2(TInt, a1, a2);
    return StackSlot::MakeInt(a1.GetInt() << a2.GetInt());
}


StackSlot ByteCodeRunner::bitNot(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TInt, a1);
    return StackSlot::MakeInt(~ a1.GetInt());
}
#undef GetCurrentTime
double GetCurrentTime()
{
#ifdef _MSC_VER
    struct timeb time;
    ftime(&time);

    return FlowDouble(time.time) + FlowDouble(time.millitm) * 1.0E-3;
#else
    timeval info;
    gettimeofday(&info, NULL);

    return FlowDouble(info.tv_sec) + FlowDouble(info.tv_usec) * 1.0E-6;
#endif
}

StackSlot ByteCodeRunner::NativeTimestamp(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeDouble(GetCurrentTime() * 1000.0);
}

StackSlot ByteCodeRunner::random(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeDouble(FlowDouble(random_dist(random_gen)));
}

StackSlot ByteCodeRunner::NativeSrand(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TInt, a1);
    random_gen = std::mt19937(a1.GetInt());
    RETVOID;
}

StackSlot ByteCodeRunner::NativeSin(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TDouble, a1);
    return StackSlot::MakeDouble(sin(a1.GetDouble()));
}

StackSlot ByteCodeRunner::NativeAsin(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TDouble, a1);
    return StackSlot::MakeDouble(asin(a1.GetDouble()));
}

StackSlot ByteCodeRunner::NativeAcos(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TDouble, a1);
    return StackSlot::MakeDouble(acos(a1.GetDouble()));
}

StackSlot ByteCodeRunner::NativeAtan(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TDouble, a1);
    return StackSlot::MakeDouble(atan(a1.GetDouble()));
}

StackSlot ByteCodeRunner::NativeAtan2(RUNNER_ARGS)
{
    RUNNER_PopArgs2(a1, a2);
    RUNNER_CheckTag2(TDouble, a1, a2);
    return StackSlot::MakeDouble(atan2(a1.GetDouble(), a2.GetDouble()));
}

StackSlot ByteCodeRunner::NativeExp(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TDouble, a1);
    return StackSlot::MakeDouble(exp(a1.GetDouble()));
}

StackSlot ByteCodeRunner::NativeLog(RUNNER_ARGS)
{
    RUNNER_PopArgs1(a1);
    RUNNER_CheckTag1(TDouble, a1);
    return StackSlot::MakeDouble(log(a1.GetDouble()));
}

StackSlot ByteCodeRunner::NativePrintCallStack(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    RUNNER->PrintCallStack(RUNNER->flow_out);
    RETVOID;
}

StackSlot ByteCodeRunner::captureCallstack(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    if (RUNNER->IsProfiling() || RUNNER->IsDebugging())
        return RUNNER->AllocNative(new FlowStackSnapshot(RUNNER, 1));
    else
        RETVOID;
}

StackSlot ByteCodeRunner::captureCallstackItem(RUNNER_ARGS)
{
    RUNNER_PopArgs1(index);
    RUNNER_CheckTag(TInt, index);

#ifdef FLOW_JIT
    if (RUNNER->JitProgram)
        RETVOID;
#endif

    if (unsigned(index.GetInt()+1) >= RUNNER->CallStack.size())
        RETVOID;

    CallFrame &frame = RUNNER->CallStack.top(index.GetInt()+1);

#ifdef FLOW_DEBUGGER
    FlowPtr impersonate = frame.impersonate_pc;
#else
    FlowPtr impersonate = MakeFlowPtr(0);
#endif

    // TODO
    return StackSlot::InternalMakeCapturedFrame(impersonate != 0 ? impersonate : frame.last_pc, impersonate != 0);
}

StackSlot ByteCodeRunner::impersonateCallstackItem(RUNNER_ARGS)
{
#ifndef FLOW_DEBUGGER
    IGNORE_RUNNER_ARGS;
    RETVOID;
#else
    RUNNER_PopArgs2(cstack, flags);
    RUNNER_CheckTag(TInt, flags);

#ifdef FLOW_JIT
    if (RUNNER->JitProgram)
        RETVOID;
#endif

    if (RUNNER->CallStack.size() < 2 || cstack.IsVoid())
        RETVOID;

    CallFrame &frame = RUNNER->CallStack.top(1);
    FlowPtr ipc;

    if (cstack.IsNative())
    {
        unsigned index = (flags.GetInt() & 0xFF);

        FlowStackSnapshot *pstack = RUNNER->GetNative<FlowStackSnapshot*>(cstack);
        if (!pstack)
            RETVOID;

        const TCallStack *stack = &pstack->getCallStack();

        if (index >= stack->size())
            RETVOID;

        const CallFrame &sframe = stack->top(index);

        ipc = sframe.impersonate_pc;
        if (ipc == MakeFlowPtr(0))
            ipc = RUNNER->BacktrackCall(sframe.last_pc);
    }
    else if (cstack.IsCapturedFrame())
    {
        /*ipc = cstack.GetCapturedImpersonate();
        if (ipc == MakeFlowPtr(0))
            ipc = RUNNER->BacktrackCall(cstack.GetCapturedFramePtr());*/
        ipc = cstack.GetCapturedFramePtr();
        if (!cstack.slot_private.AuxValue)
            ipc = RUNNER->BacktrackCall(ipc);
    }
    else
    {
        RUNNER->ReportError(InvalidArgument, "Invalid argument in impersonateCallstackItem");
        RETVOID;
    }

    if (ipc > MakeFlowPtr(0) && ipc < RUNNER->NativeReturnInsn)
        frame.impersonate_pc = ipc;

    RETVOID;
#endif
}

StackSlot ByteCodeRunner::impersonateCallstackFn(RUNNER_ARGS)
{
#ifndef FLOW_DEBUGGER
    IGNORE_RUNNER_ARGS;
    RETVOID;
#else
    RUNNER_PopArgs2(cstack, flags);
    RUNNER_CheckTag(TInt, flags);

#ifdef FLOW_JIT
    if (RUNNER->JitProgram)
        RETVOID;
#endif

    if (RUNNER->CallStack.size() < 2 || cstack.IsVoid())
        RETVOID;

    CallFrame &frame = RUNNER->CallStack.top(1);
    FlowPtr ipc;

    if (cstack.IsCodePointer())
        ipc = cstack.GetCodePtr();
    else if (cstack.IsClosurePointer())
        ipc = RUNNER->GetCodePointer(cstack);
    else if (cstack.IsNativeFn())
    {
        NativeFunction *fn = RUNNER->lookupNativeFn(RUNNER->GetNativeFnId(cstack));
        ipc = fn ? fn->debug_token() : MakeFlowPtr(0);
    }
    else
    {
        RUNNER->ReportError(InvalidArgument, "Invalid argument in impersonateCallstackFn");
        RETVOID;
    }

    if (ipc > MakeFlowPtr(0) && ipc < RUNNER->NativeReturnInsn)
        frame.impersonate_pc = ipc;

    RETVOID;
#endif
}

StackSlot ByteCodeRunner::impersonateCallstackNone(RUNNER_ARGS)
{
#ifndef FLOW_DEBUGGER
    IGNORE_RUNNER_ARGS;
    RETVOID;
#else
    RUNNER_PopArgs1(flags);
    RUNNER_CheckTag(TInt, flags);

#ifdef FLOW_JIT
    if (RUNNER->JitProgram)
        RETVOID;
#endif

    if (RUNNER->CallStack.size() < 2)
        RETVOID;

    CallFrame &frame = RUNNER->CallStack.top(1);
    const TCallStack *stack;
    unsigned index = (flags.GetInt() & 0xFF);

    if (index == 0) // (None, 0) -> clear impersonation
    {
        frame.impersonate_pc = MakeFlowPtr(0);
        RETVOID;
    }
    else
    {
        stack = &RUNNER->CallStack;
        index++;
    }

    if (index >= stack->size())
        RETVOID;

    const CallFrame &sframe = stack->top(index);

    FlowPtr ipc = sframe.impersonate_pc;
    if (ipc == MakeFlowPtr(0))
        ipc = RUNNER->BacktrackCall(sframe.last_pc);

    if (ipc > MakeFlowPtr(0) && ipc < RUNNER->NativeReturnInsn)
        frame.impersonate_pc = ipc;

    RETVOID;
#endif
}

StackSlot ByteCodeRunner::callstack2string(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cstack);

    if (cstack.IsVoid())
        return StackSlot::MakeEmptyString();

    std::vector<FlowStackFrame> frames;

    if (cstack.IsNative())
    {
        FlowStackSnapshot *stack = RUNNER->GetNative<FlowStackSnapshot*>(cstack);
        if (!stack)
            RETVOID;

        RUNNER->ParseCallStack(&frames, stack->getCallStack(), RUNNER->NativeReturnInsn);
    }
    else
    {
        TCallStack tmp_stack;
        CallFrame *frame = tmp_stack.push_ptr(1);
        memset(frame, 0, sizeof(CallFrame));

        if (cstack.IsCapturedFrame())
        {
            frame->last_pc = cstack.GetCapturedFramePtr();
#ifdef FLOW_DEBUGGER
            frame->impersonate_pc = cstack.slot_private.AuxValue ? frame->last_pc : MakeFlowPtr(0);
#endif
        }
        else if (cstack.IsCodePointer())
            frame->last_pc = cstack.GetCodePtr();
        else if (cstack.IsClosurePointer())
            frame->last_pc = RUNNER->GetCodePointer(cstack);
        else
        {
            RUNNER->ReportError(InvalidArgument, "Invalid argument in callstack2string");
            RETVOID;
        }

        RUNNER->ParseCallStack(&frames, tmp_stack, RUNNER->NativeReturnInsn);
    }

    stringstream ss;
    for (size_t i = 1; i < frames.size(); i++)
        RUNNER->PrintCallStackLine(ss, frames[i], false);

    return RUNNER->AllocateString(parseUtf8(ss.str()));
}

std::string FlowStackSnapshot::toString()
{
    RUNNER_VAR = getFlowRunner();
    std::vector<FlowStackFrame> frames;

    RUNNER->ParseCallStack(&frames, getCallStack(), RUNNER->NativeReturnInsn);

    stringstream ss;
    for (size_t i = 1; i < frames.size(); i++)
        RUNNER->PrintCallStackLine(ss, frames[i], false);

    return ss.str();
}

#if defined(__APPLE__)
#include "TargetConditionals.h"
#endif

StackSlot ByteCodeRunner::NativeGetTargetName(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    std::set<std::string> tokens(RUNNER->TargetTokens);

    T_NativeHosts::iterator it;;
    for (it = RUNNER->NativeHosts.begin(); it != RUNNER->NativeHosts.end(); ++it)
        (*it)->GetTargetTokens(tokens);

    stringstream ss;
    ss << "c++";
#if defined(WIN32)
    ss << ",windows";
#elif defined(__linux__)
    ss << ",linux";
#elif defined(__APPLE__)
    #if TARGET_OS_IPHONE
        ss << ",iOS";
    #elif TARGET_OS_MAC
        ss << ",macosx";
    #else
        ss << ",apple";
    #endif
#endif
#if defined(QT_VERSION)
    ss << ",qt";
#endif

    for (std::set<std::string>::iterator it = tokens.begin(); it != tokens.end(); ++it)
        ss << "," << *it;
    return RUNNER->AllocateString(parseUtf8(ss.str()));
}

StackSlot ByteCodeRunner::toLowerCase(RUNNER_ARGS)
{
    RUNNER_PopArgs1(str);
    RUNNER_CheckTag(TString, str);

    int str_len = RUNNER->GetStringSize(str);

    if (str_len == 0) {
        return str;
    }

    // Do not use safe wrappers for speed:
    StackSlot rval;
    unicode_char *nstr = RUNNER->AllocateStringBuffer(&rval, str_len); // ALLOC

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    const unicode_char *pstr = RUNNER->GetStringPtr(str);

    for (int i = 0; i < str_len; i++)
        nstr[i] = (pstr[i]<256) ? tolower(pstr[i]) : pstr[i];

    return rval;
}

StackSlot ByteCodeRunner::toUpperCase(RUNNER_ARGS)
{
    RUNNER_PopArgs1(str);
    RUNNER_CheckTag(TString, str);

    int str_len = RUNNER->GetStringSize(str);

    if (str_len == 0) {
        return str;
    }

    // Do not use safe wrappers for speed:
    StackSlot rval;
    unicode_char *nstr = RUNNER->AllocateStringBuffer(&rval, str_len); // ALLOC

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    const unicode_char *pstr = RUNNER->GetStringPtr(str);

    for (int i = 0; i < str_len; i++)
        nstr[i] = (pstr[i]<256) ? toupper(pstr[i]) : pstr[i];

    return rval;
}

StackSlot ByteCodeRunner::toString(RUNNER_ARGS)
{
    stringstream ss;

    if (!RUNNER->PrintData(ss, RUNNER_ARG(0)))
        RUNNER->ReportError(InvalidArgument, "Recursion too deep in toString");

    return RUNNER->AllocateString(parseUtf8(ss.str()));
}

bool ByteCodeRunner::isValueFitInType(RUNNER_VAR, const std::vector<FieldType> &type, const StackSlot &value, int ti) {
    switch (type[ti++]) {
        case FTVoid: return value.IsVoid();
        case FTBool: return value.IsBool();
        case FTInt: return value.IsInt();
        case FTDouble: return value.IsDouble();
        case FTString: return value.IsString();
        case FTArray: return value.IsArray();
        case FTStruct: return value.IsStruct();
        case FTRefTo:return value.IsRefTo();
        case FTTypedArray: {
            if (unlikely(!value.IsArray())) return false;
            FieldType arrtype = type[ti];
            if (arrtype != FTFlow) { // Type is not Flow
                for (unsigned int i = 0; i < RUNNER->GetArraySize(value); ++i)
                    if (unlikely(!isValueFitInType(RUNNER, type, RUNNER->GetArraySlot(value, i), ti))) return false;
            }
            return true;
        }
        case FTTypedRefTo: {
            if (unlikely(!value.IsRefTo())) return false;
            return isValueFitInType(RUNNER, type, RUNNER->Memory.GetStackSlot(value.GetRawRefPtr()), ti);
        }
        case FTTypedStruct: {
            if (unlikely(!value.IsStruct())) return false;
            return (value.GetStructId() == type[ti]);
        }
        default: return true;
    }
}

StackSlot ByteCodeRunner::makeStructValue(RUNNER_ARGS)
{
    RUNNER_PopArgs3(struct_name, arr, default_value);
    RUNNER_CheckTag(TString, struct_name);
    RUNNER_CheckTag(TArray, arr);

    int size = RUNNER->GetArraySize(arr);

    std::string name = encodeUtf8(RUNNER->GetString(struct_name));
    int index = RUNNER->FindStructId(name, size);

    if (!RUNNER->VerifyStruct(arr, index)) {
        return default_value;
    } else {
#ifdef FLOW_COMPACT_STRUCTS
        StackSlot tmp = RUNNER->AllocateRawStruct(RUNNER->StructDefs[index], false);
        RUNNER->StructSlotPack(tmp, RUNNER->GetArraySlotPtr(arr, size), 0, size);
        arr = tmp;
#else
        arr.Type = TStruct;
        arr.IntValue2 = index;
#endif
    }

    return arr;
}

StackSlot ByteCodeRunner::extractStructArguments(RUNNER_ARGS)
{
    StackSlot &flow_struct = RUNNER_ARG(0);
    if (!flow_struct.IsStruct()) {
        return StackSlot::MakeEmptyArray();
    }
    int size = RUNNER->GetStructSize(flow_struct);
    StackSlot arrslot = RUNNER->AllocateUninitializedArray(size); // ALLOC

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeEmptyArray();

    StackSlot *arr = (StackSlot*)MEMORY->GetRawPointer(arrslot.GetInternalArrayPtr(), size*STACK_SLOT_SIZE, true);
    for (int i = 0; i < size; i++)
        arr[i] = RUNNER->GetStructSlot(flow_struct, i);

    return arrslot;
}

StackSlot ByteCodeRunner::getDataTagForValue(RUNNER_ARGS)
{
	UNUSED(RUNNER);
    StackSlot &value = RUNNER_ARG(0);
    return StackSlot::MakeInt(value.GetType());
}

bool ByteCodeRunner::VerifyStruct(const StackSlot &arr, int struct_id)
{
    if (unsigned(struct_id) >= StructDefs.size())
        return false;

    StructDef *def = &StructDefs[struct_id];
    if (GetArraySize(arr) != unsigned(def->FieldsCount))
        return false;

    for (int i = 0; i < def->FieldsCount; ++i) {
        if (!isValueFitInType(this, def->FieldTypes[i], GetArraySlot(arr, i), 0))
            return false;
    }

    return true;
}

void ByteCodeRunner::StructTypeError(const StackSlot &slot, const char *fn, const char *tname, int struct_id)
{
    if (struct_id < 0)
    {
        ReportError(InvalidArgument, "Undefined struct type: %s", tname);
    }
    else
    {
        StructDef *def = safeVectorPtrAt(StructDefs, slot.GetStructId());
        ReportError(InvalidArgument,
                    "Not a %s argument in %s: '%s'",
                    tname, fn, (def ? def->Name.c_str() : "?"));
    }
}

StackSlot ByteCodeRunner::list2array(RUNNER_ARGS)
{
    RUNNER_PopArgs1(list);
    RUNNER_CheckTag(TStruct, list);
    RUNNER_DefSlots2(cur,arr);

    // 1st pass: measure size
    int count = 0;
    RUNNER_ForEachCons(cur, list) {
        count++;
    }

    RUNNER_CheckEmptyList(cur, "list2array");

    // 2nd pass: construct the array (in reverse)
    arr = RUNNER->AllocateArray(count);

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    RUNNER_ForEachCons(cur, list) {
        RUNNER->SetArraySlot(arr, --count, RUNNER->GetConsItem(cur));
    }

    return arr;
}

StackSlot ByteCodeRunner::list2string(RUNNER_ARGS)
{
    RUNNER_PopArgs1(list);
    RUNNER_CheckTag(TStruct, list);
    RUNNER_DefSlots3(cur,str_item,string);

    // 1st pass: measure size
    int size = 0;
    RUNNER_ForEachCons(cur, list) {
        str_item = RUNNER->GetConsItem(cur);
        RUNNER_CheckTag(TString, str_item);
        size += RUNNER->GetStringSize(str_item);
    }

    RUNNER_CheckEmptyList(cur, "list2string");

    // 2nd pass: construct the string (in reverse)
    string = RUNNER->AllocateString(NULL, size);

    if (RUNNER->IsErrorReported())
        return StackSlot::MakeVoid();

    FlowPtr dest_ptr = RUNNER->GetStringAddr(string);

    RUNNER_ForEachCons(cur, list) {
        str_item = RUNNER->GetConsItem(cur);
        int item_size = RUNNER->GetStringSize(str_item);
        size -= item_size;
        MEMORY->Copy(RUNNER->GetStringAddr(str_item), dest_ptr + size * FLOW_CHAR_SIZE, item_size * FLOW_CHAR_SIZE);
    }

    return string;
}

StackSlot ByteCodeRunner::isArray(RUNNER_ARGS)
{
    RUNNER_PopArgs1(value);
    return StackSlot::MakeBool(value.IsArray());
}

StackSlot ByteCodeRunner::isSameStructType(RUNNER_ARGS)
{
    RUNNER_PopArgs2(value1, value2);

    bool rv = value1.IsStruct() && value2.IsStruct() &&
              value1.GetStructId() == value2.GetStructId();

    return StackSlot::MakeBool(rv);
}

StackSlot ByteCodeRunner::isSameObj(RUNNER_ARGS)
{
    RUNNER_PopArgs2(slot1, slot2);

    return StackSlot::MakeBool(RUNNER->CompareByRef(slot1, slot2));
}

StackSlot ByteCodeRunner::getFileContent(RUNNER_ARGS)
{
    RUNNER_PopArgs1(rawpath);
    RUNNER_CheckTag(TString, rawpath);

    std::string name = encodeUtf8(RUNNER->GetString(rawpath));

    return RUNNER->AllocateString(readFileAsUnicodeString(name));
}

StackSlot ByteCodeRunner::getFileContentBinary(RUNNER_ARGS)
{
    RUNNER_PopArgs1(rawpath);
    RUNNER_CheckTag(TString, rawpath);

    std::string name = encodeUtf8(RUNNER->GetString(rawpath));

    return RUNNER->LoadFileAsString(name, false);
}


StackSlot ByteCodeRunner::setFileContent(RUNNER_ARGS)
{
    RUNNER_PopArgs2(key_str, value_str);
    RUNNER_CheckTag2(TString, key_str, value_str);

    std::string filename = encodeUtf8(RUNNER->GetString(key_str));
    std::string content = encodeUtf8(RUNNER->GetString(value_str));
    const char * pdata= content.c_str();
    size_t bytes = content.length();

    bool ok = false;
    std::string tmp_fn = filename + ".tmp";

    if (FILE *out = fopen(tmp_fn.c_str(), "wb")) {
        ok = (fwrite(pdata, 1, bytes, out) == bytes);
        fclose(out);

        if (ok) {
#ifdef WIN32
            unlink(filename.c_str());
#endif
            ok = !rename(tmp_fn.c_str(), filename.c_str());
            RUNNER->InvalidateFileCache(filename);
        }
    }

    return StackSlot::MakeBool(ok);
}

StackSlot ByteCodeRunner::setFileContentUTF16(RUNNER_ARGS)
{
    RUNNER_PopArgs2(key_str, value_str);
    RUNNER_CheckTag2(TString, key_str, value_str);

    std::string filename = encodeUtf8(RUNNER->GetString(key_str));
    unsigned bytes;
    const unicode_char *pdata = RUNNER->GetStringPtrSize(value_str, &bytes);
    bytes *= FLOW_CHAR_SIZE;

    static const uint8_t bom_bytes[] = { 0xFF, 0xFE };

    bool ok = false;
    std::string tmp_fn = filename + ".tmp";

    if (FILE *out = fopen(tmp_fn.c_str(), "wb")) {
        ok = (fwrite(bom_bytes, 1, 2, out) == 2) && (fwrite(pdata, 1, bytes, out) == bytes);
        fclose(out);

        if (ok) {
#ifdef WIN32
            unlink(filename.c_str());
#endif
            ok = !rename(tmp_fn.c_str(), filename.c_str());
            RUNNER->InvalidateFileCache(filename);
        }
    }

    return StackSlot::MakeBool(ok);
}

void bytesProcessor(int nbytes, const unicode_char * pdata, uint8_t * bytes) {
    for (unsigned i = 0; i < unsigned(nbytes); i++) {
        unicode_char data = pdata[i];
        bytes[i] = data % 256;
    }
}

StackSlot ByteCodeRunner::setFileContentHelper(RUNNER_ARGS, void (*processor)(int nbytes, const unicode_char * pdata, uint8_t * bytes))
{
    RUNNER_PopArgs2(key_str, value_str);
    RUNNER_CheckTag2(TString, key_str, value_str);

    std::string filename = encodeUtf8(RUNNER->GetString(key_str));
    unsigned nbytes;
    const unicode_char *pdata = RUNNER->GetStringPtrSize(value_str, &nbytes);

    uint8_t * bytes;
    if (processor != NULL) {
        bytes = new uint8_t[nbytes];
        processor(nbytes, pdata, bytes);
    } else {
        bytes = (uint8_t*)pdata;
        nbytes *= 2;
    }

    bool ok = false;
    std::string tmp_fn = filename + ".tmp";

    if (FILE *out = fopen(tmp_fn.c_str(), "wb")) {
        ok = (fwrite(bytes, 1, nbytes, out) == nbytes);
        fclose(out);

        if (ok) {
#ifdef WIN32
            unlink(filename.c_str());
#endif
            ok = !rename(tmp_fn.c_str(), filename.c_str());
            RUNNER->InvalidateFileCache(filename);
        }
    }

    if (processor != NULL)
        delete [] bytes;

    return StackSlot::MakeBool(ok);
}

StackSlot ByteCodeRunner::setFileContentBinary(RUNNER_ARGS) {
    return setFileContentHelper(RUNNER, pRunnerArgs__, NULL);
}

StackSlot ByteCodeRunner::setFileContentBytes(RUNNER_ARGS) {
    return setFileContentHelper(RUNNER, pRunnerArgs__, &bytesProcessor);
}

StackSlot ByteCodeRunner::getBytecodeFilename(RUNNER_ARGS)
{
	UNUSED(pRunnerArgs__);
    return RUNNER->AllocateString(parseUtf8(RUNNER->BytecodeFilename));
}

StackSlot ByteCodeRunner::loaderUrl(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return RUNNER->AllocateString(RUNNER->UrlString);
}

StackSlot ByteCodeRunner::getUrlParameter(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name);
    RUNNER_CheckTag(TString, name);

    return RUNNER->AllocateString(RUNNER->UrlParameters[RUNNER->GetString(name)]);
}

StackSlot ByteCodeRunner::getAllUrlParameters(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    int i = RUNNER->UrlParameters.size();

    RUNNER_DefSlots1(array);
    array = RUNNER->AllocateArray(RUNNER->UrlParameters.size());
    for (T_UrlParameters::iterator it = RUNNER->UrlParameters.begin(); it != RUNNER->UrlParameters.end(); ++it) {
        RUNNER_DefSlots1(keyvalue);
        keyvalue = RUNNER->AllocateArray(2);
        RUNNER->SetArraySlot(keyvalue, 0, RUNNER->AllocateString((*it).first));
        RUNNER->SetArraySlot(keyvalue, 1, RUNNER->AllocateString((*it).second));

        RUNNER->SetArraySlot(array, --i, keyvalue);
    }

    return array;
}

StackSlot ByteCodeRunner::preloadMediaUrl(RUNNER_ARGS)
{
    RUNNER_PopArgs3(url, successfn, errorfn);
    RUNNER_CheckTag(TString, url);
    IGNORE_LOCAL(errorfn);

    // Stub to be overridden in hosts
    RUNNER->EvalFunction(successfn, 0);
    RETVOID;
}

StackSlot ByteCodeRunner::fromCharCode(RUNNER_ARGS)
{
    RUNNER_PopArgs1(charcode);
    RUNNER_CheckTag(TInt, charcode);

    return RUNNER->AllocateString(unicode_string(1, unicode_char(charcode.GetInt())));
}

StackSlot ByteCodeRunner::getCharCodeAt(RUNNER_ARGS)
{
    RUNNER_PopArgs2(str, index);
    RUNNER_CheckTag(TString, str);
    RUNNER_CheckTag(TInt, index);

    unsigned size;
    const unicode_char *ptr = RUNNER->GetStringPtrSize(str, &size);

    if (unsigned(index.GetInt()) < size)
        return StackSlot::MakeInt(ptr[index.GetInt()]);
    else
        return StackSlot::MakeInt(0);
}

static bool eatNumber(int *res, const char **pptr, char end) {
    const char *cur = *pptr;
    while (isdigit(*cur))
        cur++;
    if (cur == *pptr || *cur != end)
        return false;

    *res = atoi(*pptr);
    *pptr = cur+1;
    return true;
}

StackSlot ByteCodeRunner::string2time(RUNNER_ARGS)
{
    RUNNER_PopArgs1(time_slot);
    RUNNER_CheckTag(TString, time_slot);

    std::string time_str = encodeUtf8(RUNNER->GetString(time_slot));

    if (time_str.size() == 10)
        time_str += " 00:00:00";

    struct tm parts;
    memset(&parts, 0, sizeof(parts));

    const char *p = time_str.c_str();
    if (eatNumber(&parts.tm_year, &p, '-') &&
        eatNumber(&parts.tm_mon, &p, '-') &&
        eatNumber(&parts.tm_mday, &p, ' ') &&
        eatNumber(&parts.tm_hour, &p, ':') &&
        eatNumber(&parts.tm_min, &p, ':') &&
        eatNumber(&parts.tm_sec, &p, '\0'))
    {
        // Handle 0000-00-00 ??:??:??
        if (parts.tm_year == 0 && parts.tm_mon == 0 && parts.tm_mday == 0)
            return StackSlot::MakeDouble(0);

#ifdef _MSC_VER
        SYSTEMTIME utcSystemTime, localSystemTime;
        FILETIME utcFileTime;

        localSystemTime.wYear = parts.tm_year;
        localSystemTime.wMonth = parts.tm_mon;
        localSystemTime.wDay = parts.tm_mday;
        localSystemTime.wHour = parts.tm_hour;
        localSystemTime.wMinute = parts.tm_min;
        localSystemTime.wSecond = parts.tm_sec;
        localSystemTime.wMilliseconds = 0;
        localSystemTime.wDayOfWeek = -1;

        long long ms;

        if (TzSpecificLocalTimeToSystemTime(NULL, &localSystemTime, &utcSystemTime) && SystemTimeToFileTime(&utcSystemTime, &utcFileTime)) {
            ms = *(long long*)&utcFileTime;
            ms /= 10000; // 100-nanoseconds to milliseconds since Jan 1st 1601
            ms -= 11644473600000; // 1601 to 1970
        } else {
            ms = 0;
        }

        return StackSlot::MakeDouble(ms);
#else

        parts.tm_year -= 1900;
        parts.tm_mon -= 1;
        parts.tm_isdst = -1;

        // Hack to let it work for 1970-01-01 even in UTC+X timezones
        // on systems that don't allow negative time_t result in mktime.
        bool first_day = (parts.tm_year == 70 && parts.tm_mon == 0 && parts.tm_mday == 1);
        if (first_day)
            parts.tm_mday++;

#ifdef ANDROID
        time_t tv = mktime(&parts);
#else
        time_t tv = timelocal(&parts);
#endif

        if (tv == (time_t)-1)
        {
            RUNNER->ReportError(InvalidArgument, "Invalid time value: %s", time_str.c_str());
            RETVOID;
        }

        // We added 1 day, so subtract 24 hours
        if (first_day)
            tv -= 24*60*60;

        return StackSlot::MakeDouble(tv * 1000.0);
#endif
    }
    else
    {
        RUNNER->ReportError(InvalidArgument, "Invalid time format: %s", time_str.c_str());
        RETVOID;
    }
}

StackSlot ByteCodeRunner::time2string(RUNNER_ARGS)
{
    RUNNER_PopArgs1(time);
    RUNNER_CheckTag(TDouble, time);

    double v = time.GetDouble() / 1000.0;

    time_t tv = time_t(v);
    struct tm parts, *tmp;
    char buf[20] = {0};
    int rv;

#ifdef _MSC_VER
    SYSTEMTIME utcSystemTime, localSystemTime;
    FILETIME utcFileTime;

    long long iTime = time.GetDouble();
    iTime += 11644473600000; // 1970 to 1601
    iTime *= 10000; // milliseconds to 100-nanoseconds since Jan 1st 1601

    memcpy(&utcFileTime, &iTime, sizeof(utcFileTime));

    if (FileTimeToSystemTime(&utcFileTime, &utcSystemTime) && SystemTimeToTzSpecificLocalTime(NULL, &utcSystemTime, &localSystemTime)) {

        parts.tm_year = localSystemTime.wYear - 1900;
        parts.tm_mon = localSystemTime.wMonth - 1;
        parts.tm_mday = localSystemTime.wDay;

        parts.tm_hour = localSystemTime.wHour;
        parts.tm_min = localSystemTime.wMinute;
        parts.tm_sec = localSystemTime.wSecond;

        tmp = &parts;
    }
#else
    tmp = localtime_r(&tv, &parts);
#endif

    if (!tmp)
    {
        RUNNER->ReportError(InvalidArgument, "Invalid time in time2string: %lf", (double)time.GetDouble());
        RETVOID;
    }

    rv = strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &parts);

    if (!rv)
    {
        RUNNER->ReportError(InvalidArgument, "Could not format time in time2string: %lf", (double)time.GetDouble());
        RETVOID;
    }

    return RUNNER->AllocateString(buf);
}

StackSlot ByteCodeRunner::utc2local(RUNNER_ARGS)
{
    RUNNER_PopArgs1(utc);
    RUNNER_CheckTag(TDouble, utc);

#ifdef _MSC_VER
    FILETIME utcFileTime, localFileTime;
    SYSTEMTIME utcSystemTime, localSystemTime;

    long long iTime = utc.GetDouble();
    iTime += 11644473600000; // 1970 to 1601
    iTime *= 10000; // milliseconds to 100-nanoseconds since Jan 1st 1601

    memcpy(&utcFileTime, &iTime, sizeof(utcFileTime));

    FileTimeToSystemTime(&utcFileTime, &utcSystemTime);
    SystemTimeToTzSpecificLocalTime(NULL, &utcSystemTime, &localSystemTime);
    SystemTimeToFileTime(&localSystemTime, &localFileTime);

    double offset = (*(long long*)&localFileTime - *(long long*)&utcFileTime) / 10000;

     return StackSlot::MakeDouble(utc.GetDouble() + offset);
#else
    tm tmp;
    time_t stamp = time_t(utc.GetDouble() / 1000.0);

    localtime_r(&stamp, &tmp);

    return StackSlot::MakeDouble(utc.GetDouble() + tmp.tm_gmtoff * 1000.0);
#endif
}

StackSlot ByteCodeRunner::local2utc(RUNNER_ARGS)
{
    RUNNER_PopArgs1(local);
    RUNNER_CheckTag(TDouble, local);

#ifdef _MSC_VER
    FILETIME utcFileTime, localFileTime;
    SYSTEMTIME utcSystemTime, localSystemTime;

    long long iTime = local.GetDouble();
    iTime += 11644473600000; // 1970 to 1601
    iTime *= 10000; // milliseconds to 100-nanoseconds since Jan 1st 1601

    memcpy(&localFileTime, &iTime, sizeof(utcFileTime));

    FileTimeToSystemTime(&localFileTime, &localSystemTime);
    TzSpecificLocalTimeToSystemTime(NULL, &localSystemTime, &utcSystemTime);
    SystemTimeToFileTime(&utcSystemTime, &utcFileTime);

    double offset = (*(long long*)&localFileTime - *(long long*)&utcFileTime) / 10000;

     return StackSlot::MakeDouble(local.GetDouble() - offset);
#else
    tm tmp;
    time_t stamp = time_t(local.GetDouble() / 1000.0);

    localtime_r(&stamp, &tmp);
    stamp -= tmp.tm_gmtoff;
    localtime_r(&stamp, &tmp);

    return StackSlot::MakeDouble(local.GetDouble() - tmp.tm_gmtoff * 1000.0);
#endif

}

StackSlot ByteCodeRunner::dayOfWeek(RUNNER_ARGS)
{
    RUNNER_PopArgs3(year,month,day);
    RUNNER_CheckTag3(TInt,year,month,day);

    struct tm parts;
    memset(&parts, 0, sizeof(parts));

    parts.tm_year = year.GetInt() - 1900;
    parts.tm_mon = month.GetInt() - 1;
    parts.tm_mday = day.GetInt();
    parts.tm_isdst = -1;

    mktime(&parts);

    return StackSlot::MakeInt((parts.tm_wday + 6) % 7);
}

StackSlot ByteCodeRunner::number2double(RUNNER_ARGS)
{
    RUNNER_PopArgs1(number);

    if (number.IsDouble())
    {
        return number;
    }
    else if (number.IsInt())
    {
        return StackSlot::MakeDouble(number.GetInt());
    }
    else
    {
        RUNNER->ReportTagError(number, TInt, "value", NULL);
        RETVOID;
    }
}

StackSlot ByteCodeRunner::iteriUntil(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, callback);
    RUNNER_CheckTag(TArray, arr);
    RUNNER_DefSlots1(tmp);

    RUNNER_DefSlotArray(fn_args, 3);
    fn_args[0] = callback;
    fn_args[1] = StackSlot::MakeInt(0);

    int arr_len = RUNNER->GetArraySize(arr);
    int i = 0;
    for (; i < arr_len; i++) {
        fn_args[1].SetIntValue(i);
        fn_args[2] = RUNNER->GetArraySlot(arr, i);
        tmp = RUNNER->FastEvalFunction(fn_args, 2);
        RUNNER_CheckTag(TBool, tmp);
        if (tmp.GetBool())
            break;
	}

    return StackSlot::MakeInt(i);
}

class BinarySerializer
{
    RUNNER_VAR;

    std::map<int, int> structIdxs;
    std::vector<int> structIds;

    unicode_string buf;

    inline void pushInt32(int val) {
        buf.push_back(val & 0xFFFF);
        buf.push_back(val >> 16);
    }

    void pushInteger(int value);

    void pushString(const unicode_char *data, unsigned len);
    void pushString(const unicode_string &obj) { pushString(obj.data(), obj.size()); }

    void pushArraySize(unsigned len);

    int registerStruct(int id);
    void writeStructDefs();

    void writeBinaryValue(const StackSlot & value);

public:
    BinarySerializer(RUNNER_VAR) : RUNNER(RUNNER) {
        //
    }

    void serialize(const StackSlot &object);

    const unicode_string &output() { return buf; }
};

void BinarySerializer::pushInteger(int int_value)
{
    if (int_value & 0xFFFF8000) {
        buf.push_back(0xFFF5);
        pushInt32(int_value);
    } else {
        buf.push_back(int_value);
    }
}

void BinarySerializer::pushString(const unicode_char *data, unsigned len)
{
    if (len & 0xFFFF0000) {
        buf.push_back(0xFFFB);
        pushInt32(len);
    } else {
        buf.push_back(0xFFFA);
        buf.push_back(len);
    }

    buf.append(data, len);
}

void BinarySerializer::pushArraySize(unsigned len)
{
    if (len == 0) {
        buf.push_back(0xFFF7);
    } else {
        if (len & 0xFFFF0000) {
            buf.push_back(0xFFF9);
            pushInt32(len);
        } else {
            buf.push_back(0xFFF8);
            buf.push_back(len);
        }
    }
}

void BinarySerializer::writeStructDefs() {
    pushArraySize(structIds.size());
    for (unsigned i = 0; i < structIds.size(); ++i) {
        pushArraySize(2);
        const StructDef & struct_def = RUNNER->GetStructDef(structIds[i]);
        pushInteger(struct_def.FieldsCount);
        pushString(struct_def.NameU);
    }
}

int BinarySerializer::registerStruct(int struct_id)
{
    int struct_idx = 0;
    std::map<int,int>::iterator it = structIdxs.find(struct_id);
    if (it == structIdxs.end()) {
        structIdxs[struct_id] = struct_idx = structIds.size();
        structIds.push_back(struct_id);
    } else {
        struct_idx = it->second;
    }
    return struct_idx;
}

void BinarySerializer::writeBinaryValue(const StackSlot & value)
{
    switch (value.GetType()) {
        case TVoid:
            buf.push_back(0xFFFF);
            break;
        case TBool:
            buf.push_back(value.GetBool() ? 0xFFFE : 0xFFFD);
            break;
        case TInt:
            pushInteger(value.GetInt());
            break;
        case TDouble:
        {
            const int *pdata = (const int*)&value.slot_private.DoubleVal;
            buf.push_back(0xFFFC);
            pushInt32(pdata[0]);
            pushInt32(pdata[1]);
            break;
        }
        case TString:
            pushString(RUNNER->GetStringPtr(value), RUNNER->GetStringSize(value));
            break;
        case TArray:
        {
            int len = RUNNER->GetArraySize(value);
            pushArraySize(len);
            for (int i = 0; i < len; ++i)
                writeBinaryValue(RUNNER->GetArraySlot(value, i));
            break;
        }
        case TStruct:
        {
            int size = RUNNER->GetStructSize(value);
            int struct_idx = registerStruct(value.GetStructId());

            buf.push_back(0xFFF4);
            buf.push_back(struct_idx);
            for (int i = 0; i < size; ++i)
                writeBinaryValue(RUNNER->GetStructSlot(value, i));
            break;
        }
        case TRefTo:
            buf.push_back(0xFFF6);
            writeBinaryValue(RUNNER->GetRefTarget(value));
            break;
        default:
            RUNNER->ReportError(InvalidArgument, "Cannot serialize flow value. Invalid DataTag: %d", value.GetType());
            break;
    }
}

void BinarySerializer::serialize(const StackSlot &value)
{
    buf.clear();
    structIds.clear();
    structIdxs.clear();

    buf.push_back(0); buf.push_back(0); // Stub for footer offset
    writeBinaryValue(value);

    int struct_defs_offset = buf.length();
    writeStructDefs();

    buf[0] = struct_defs_offset & 0xFFFF;
    buf[1] = struct_defs_offset >> 16;
}

// Converts flow value to a binary stream as UTF-16 flow string
StackSlot ByteCodeRunner::toBinary(RUNNER_ARGS)
{
    RUNNER_PopArgs1(value);

    BinarySerializer worker(RUNNER);
    worker.serialize(value);

    return RUNNER->AllocateString(worker.output());
}

class BinaryDeserializer
{
    RUNNER_VAR;

    std::vector<int> structIndex;
    std::vector<int> structSize;
    std::vector<StackSlot> structFixups;
    bool has_fixups;

    const StackSlot *pinput, *pdefault;
    unsigned char_idx, ssize;

    // A check for corrupted array sizes
    int slot_budget;

    bool error;

#ifdef FLOW_MMAP_HEAP
    typedef ByteCodeRunner::MappedAreaInfo MappedAreaInfo;

    bool mapped;
    FlowPtr hp, hplimit;
    FlowPtr rhp, rhplimit;
    MappedAreaInfo::Ptr area;
#endif

    StackSlot NewRef();
    FlowPtr NewBuffer(int size);
    StackSlot NewArray(int size, bool map = true);

    void SetSlot(const StackSlot &vec, int index, const StackSlot &val);
    void SetRefTarget(const StackSlot &vec, const StackSlot &val);

    const unicode_char *readChars(int count) {
        unsigned new_idx = char_idx + count;
        if (new_idx < char_idx || new_idx > ssize) {
            error = true;
            return NULL;
        }
        unsigned cur_idx = char_idx;
        char_idx = new_idx;
        return RUNNER->GetStringPtr(*pinput) + cur_idx;
    }

    unicode_char readChar() {
        const unicode_char *data = readChars(1);
        return data ? *data : 0;
    }
    int readInt32() {
        const unicode_char *data = readChars(2);
        return data ? *(int*)data : 0;
    }

    int readInteger();
    int readArraySize();
    StackSlot readString();

    void readStructIndex(const StackSlot &fixups);

    StackSlot readValue();

public:
    BinaryDeserializer(RUNNER_VAR) : RUNNER(RUNNER) {
        //
    }

    StackSlot deserialize(const StackSlot &input, const StackSlot &defval, const StackSlot &fixups);

    bool success() { return !error; }
};

StackSlot BinaryDeserializer::NewRef()
{
    if (error || --slot_budget < 0)
    {
        error = true;
        return StackSlot::MakeVoid();
    }

#ifdef FLOW_MMAP_HEAP
    if (mapped)
    {
        if (rhp >= rhplimit)
        {
            int count = 1000;
            int bytes = count * sizeof(FlowHeapRef);

            FlowPtr ptr = NewBuffer(bytes);
            if (error) return StackSlot::MakeVoid();

            FlowHeapRef *refs = (FlowHeapRef*)MEMORY->GetRawPointer(ptr, bytes, true);

            for (int i = 0; i < count; i++)
            {
                refs[i].header.IntVal = 0;
                StackSlot::SetVoid(refs[i].data);
            }

            rhp = ptr;
            rhplimit = rhp + bytes;
            area->ref_roots.push_back(std::pair<FlowPtr,int>(rhp, count));
        }

        FlowPtr ptr = rhp;
        rhp += sizeof(FlowHeapRef);

        unsigned id = RUNNER->NextRefId++;
        bool big = (id & 0xffff0000u) != 0;

        MEMORY->SetInt32(ptr, id & 0xffffu);
        return StackSlot::InternalMakeRefTo(ptr, big ? id>>16 : id, big);
    }
#endif

    return RUNNER->AllocateRef(StackSlot::MakeVoid());
}

FlowPtr BinaryDeserializer::NewBuffer(int bytes)
{
#ifdef FLOW_MMAP_HEAP
    if (mapped)
    {
        FlowPtr cur = hp, end = hp + bytes;

        if (end > hplimit)
        {
            hplimit = FlowPtrAlignUp(end, 1024*1024);
            MEMORY->CommitRange(hp, hplimit);
        }

        hp = end;
        return cur;
    }
    else
#endif
        return RUNNER->Allocate(bytes);
}

StackSlot BinaryDeserializer::NewArray(int size, bool do_map)
{
    if (error || size < 0 || (slot_budget -= size) < 0)
    {
        error = true;
        return StackSlot::MakeVoid();
    }

    if (size == 0)
        return StackSlot::MakeEmptyArray();

#ifdef FLOW_MMAP_HEAP
    if (mapped && do_map)
    {
        int bytes = size * STACK_SLOT_SIZE;
        FlowPtr cur = NewBuffer(4 + bytes);

        MEMORY->SetInt32(cur, size & 0xffffu);
        MEMORY->FillBytes(cur+4, -1, bytes);

        bool big = (size & 0xffff0000u) != 0;
        return StackSlot::InternalMakeArray(cur, big ? size>>16 : size, big);
    }
#endif

    return RUNNER->AllocateArray(size);
}

void BinaryDeserializer::SetSlot(const StackSlot &arr, int index, const StackSlot &val)
{
#ifdef FLOW_MMAP_HEAP
    if (mapped)
    {
        FlowPtr slot = arr.GetInternalArrayPtr() + index*STACK_SLOT_SIZE;
        MEMORY->SetStackSlot(slot, val);
        return;
    }
#endif

    RUNNER->SetArraySlot(arr, index, val);
}

void BinaryDeserializer::SetRefTarget(const StackSlot &ref, const StackSlot &val)
{
#ifdef FLOW_MMAP_HEAP
    if (mapped)
    {
        MEMORY->SetStackSlot(ref.GetRawRefPtr(), val);
        return;
    }
#endif

    RUNNER->SetRefTarget(ref, val);
}

int BinaryDeserializer::readInteger()
{
    const unicode_char *pdata = readChars(1);
    if (!pdata) return 0;

    if (*pdata == 0xFFF5)
        return readInt32();
    if (*pdata == 0xFFF3)
        return readInt32() | readInt32();
    else if (*pdata <= 0x7FFF)
        return *pdata;
    else
    {
        error = true;
        return 0;
    }
}

int BinaryDeserializer::readArraySize()
{
    const unicode_char *pdata = readChars(1);
    if (!pdata)
        return 0;

    switch (*pdata)
    {
    case 0xFFF7:
        return 0;
    case 0xFFF8:
        return readChar();
    case 0xFFF9:
        return readInt32();
    default:
        error = true;
        return 0;
    }
}

StackSlot BinaryDeserializer::readString()
{
    StackSlot fail = StackSlot::MakeEmptyString();

    const unicode_char *pdata = readChars(1);
    if (!pdata)
        return fail;

    int len = 0;
    switch (*pdata)
    {
    case 0xFFFA:
        len = readChar();
        break;
    case 0xFFFB:
        len = readInt32();
        break;
    default:
        error = true;
        return fail;
    }

    unsigned start_idx = char_idx;

    if (!readChars(len))
        return fail;

    StackSlot rv;
    FlowPtr *pp;

#ifdef FLOW_MMAP_HEAP
    if (mapped)
    {
        if (len & 0xffff0000u)
        {
            FlowPtr ptr = NewBuffer(sizeof(FlowStringRef));
            FlowStringRef *ref = (FlowStringRef*)MEMORY->GetRawPointer(ptr, sizeof(FlowStringRef), true);

            ref->header.IntVal = (len & 0xffff);

            pp = &ref->dataptr;
            StackSlot::InternalSetString(rv, ptr, len>>16, true);
        }
        else
        {
            pp = &rv.slot_private.PtrValue;
            StackSlot::InternalSetString(rv, MakeFlowPtr(0), len, false);
        }
    }
    else
#endif
    {
        pp = RUNNER->AllocateStringRef(&rv, len); // ALLOC
    }

    *pp = RUNNER->GetStringAddr(*pinput) + start_idx*FLOW_CHAR_SIZE;
    return rv;
}

void BinaryDeserializer::readStructIndex(const StackSlot &fixups)
{
    structIndex.clear();

    unsigned offset = readInt32();

    // See UTF-16 surrogate pair workaround in binary.flow, getFooterOffset(s)
    if(offset == 1)
        offset = readInt32() | readInt32();

    if (error || offset < char_idx || offset >= ssize)
    {
        error = true;
        return;
    }

    unsigned old_pos = char_idx;
    char_idx = offset;

    int isize = readArraySize();

    structIndex.resize(isize);
    structSize.resize(isize);
    structFixups.resize(isize, StackSlot::MakeVoid());

    RUNNER_DefSlots2(name_str, tmp);

    for (int i = 0; i < isize; i++)
    {
        if (readArraySize() != 2)
        {
            error = true;
            return;
        }

        int fcount = readInteger();

        name_str = readString();
        unicode_string name = RUNNER->GetString(name_str);

        structIndex[i] = RUNNER->FindStructId(encodeUtf8(name), fcount);
        structSize[i] = fcount;

        if (!fixups.IsVoid())
        {
            tmp = RUNNER->EvalFunction(fixups, 1, name_str);
            RUNNER_CheckTagVoid(TStruct, tmp);

            // Some(fixup_cb)
            if (RUNNER->GetStructSize(tmp) > 0)
            {
                structFixups[i] = RUNNER->GetStructSlot(tmp, 0);
                has_fixups = true;
            }
        }
    }

    char_idx = old_pos;
    ssize = offset;
}

StackSlot BinaryDeserializer::readValue()
{
    const unicode_char *pdata = readChars(1);
    if (error)
        return *pdefault;

    switch (*pdata)
    {
    case 0xFFFF:
        return StackSlot::MakeVoid();
    case 0xFFFC:
        pdata = readChars(4);
        if (!pdata)
            return *pdefault;
#ifdef FLOW_EMBEDDED
        // workaraund for ARMv7 alignment problem (both iOS and Android)
        FlowDouble d;
        memcpy(&d, pdata, sizeof(FlowDouble));
        return StackSlot::MakeDouble(d);
#else
        return StackSlot::MakeDouble(*(FlowDouble*)pdata);
#endif
    case 0xFFFD:
        return StackSlot::MakeBool(false);
    case 0xFFFE:
        return StackSlot::MakeBool(true);
    case 0xFFFA:
    case 0xFFFB:
        char_idx--;
        return readString();
    case 0xFFF6:
    {
        RUNNER_DefSlots1(ref);
        ref = NewRef();
        if (error) return *pdefault;
        SetRefTarget(ref, readValue());
        return ref;
    }
    case 0xFFF4:
    {
        unsigned idx = readChar();

        if (error || idx >= structIndex.size())
        {
            error = true;
            return *pdefault;
        }

        unsigned size = structSize[idx];

        RUNNER_DefSlots1(arr);
#ifdef FLOW_COMPACT_STRUCTS
        arr = NewArray(size, false);
        if (error) return *pdefault;
        for (unsigned i = 0; i < size; i++)
            RUNNER->SetArraySlot(arr, i, readValue());
#else
        arr = NewArray(size);
        if (error) return *pdefault;
        for (unsigned i = 0; i < size; i++)
            SetSlot(arr, i, readValue());
#endif

        // Apply fixup if any
        if (!structFixups[idx].IsVoid())
            return RUNNER->EvalFunction(structFixups[idx], 1, arr);

        if (!RUNNER->VerifyStruct(arr, structIndex[idx])) {
            const StructDef &def = RUNNER->GetStructDef(structIndex[idx]);
            cout << "struct name" << def.Name;
            RUNNER->PrintData(RUNNER->flow_out, arr);

            return RUNNER->MakeStruct("IllegalStruct", 0, NULL);
        }

#ifdef FLOW_COMPACT_STRUCTS
        const StructDef &def = RUNNER->GetStructDef(structIndex[idx]);
        if (size == 0)
            arr = StackSlot::MakeStruct(def.EmptyPtr, def.StructId);
        else
        {
            StackSlot tmp = StackSlot::MakeStruct(NewBuffer(def.ByteSize), def.StructId);
            RUNNER->Memory.SetInt32(tmp.GetRawStructPtr(), def.StructId);
            RUNNER->StructSlotPack(tmp, RUNNER->GetArraySlotPtr(arr, size), 0, size);
            arr = tmp;
        }
#else
        arr.Type = TStruct;
        arr.IntValue2 = structIndex[idx];
#endif

        return arr;
    }
    case 0xFFF7:
    case 0xFFF8:
    case 0xFFF9:
    {
        char_idx--;
        unsigned size = readArraySize();
        if (error)
            return *pdefault;

        RUNNER_DefSlots1(arr);
        arr = NewArray(size);
        if (error) return *pdefault;
        for (unsigned i = 0; i < size; i++)
            SetSlot(arr, i, readValue());
        return arr;
    }
    case 0xFFF5:
        return StackSlot::MakeInt(readInt32());
    case 0xFFF3:
        return StackSlot::MakeInt(readInt32() | readInt32());
    default:
        if (*pdata <= 0x7FFF)
            return StackSlot::MakeInt(*pdata);
        error = true;
        return *pdefault;
    }
}

StackSlot BinaryDeserializer::deserialize(const StackSlot &input, const StackSlot &defval, const StackSlot &fixups)
{
    pinput = &input;
    pdefault = &defval;
    char_idx = 0;
    ssize = RUNNER->GetStringSize(input);
    error = false;
    has_fixups = false;
#ifdef FLOW_MMAP_HEAP
    mapped = false;
#endif

    RUNNER_RegisterNativeRoot(std::vector<StackSlot>, structFixups);

    readStructIndex(fixups);
    if (error || RUNNER->IsErrorReported())
        return defval;

    slot_budget = ssize + 1000;

#ifdef FLOW_MMAP_HEAP
    bool input_mapped = RUNNER->IsMappedArea(RUNNER->GetStringAddr(input));
    bool enough_free = unsigned(RUNNER->MapStringPtr - RUNNER->MapAreaBase) >= STACK_SLOT_SIZE * unsigned(slot_budget);

    if (input_mapped && enough_free && !has_fixups)
    {
        MappedAreaInfo::Ptr ptr = RUNNER->FindMappedArea(RUNNER->GetStringAddr(input));

        if (ptr)
        {
            mapped = true;
            hp = hplimit = rhp = rhplimit = RUNNER->MapAreaBase;
            area = MappedAreaInfo::Ptr(new MappedAreaInfo(hp, 0));
            area->depends.push_back(ptr);
        }
    }
#endif

    StackSlot rv = readValue();

#ifdef FLOW_MMAP_HEAP
    if (mapped)
    {
        RUNNER->MapAreaBase = hp = FlowPtrAlignUp(hp, MEMORY->PageSize());
        area->length = hp - area->start;
        if (hp < hplimit)
            MEMORY->DecommitRange(hp, hplimit);
        RUNNER->MappedAreas[area->start] = area;
    }
#endif

    if (char_idx < ssize)
        RUNNER->flow_out << "Did not understand all!";
    return rv;
}

StackSlot ByteCodeRunner::fromBinary2(RUNNER_ARGS)
{
    RUNNER_CopyArgArray(new_args, 2, 1);
    new_args[2] = StackSlot::MakeVoid();
    return fromBinary(RUNNER, new_args);
}

StackSlot ByteCodeRunner::fromBinary(RUNNER_ARGS)
{
    RUNNER_PopArgs3(value, defval, fixups);

    BinaryDeserializer worker(RUNNER);

#ifdef DEBUG_FLOW
    double start_time = GetCurrentTime();
#endif

    StackSlot rv = worker.deserialize(value, defval, fixups);

#ifdef DEBUG_FLOW
    RUNNER->flow_err << "Deserialized in " << (GetCurrentTime() - start_time) << " seconds." << endl;
#endif

    return rv;
}

// Read 8 bytes of the string in UTF-16 and converts to a double
StackSlot ByteCodeRunner::stringbytes2double(RUNNER_ARGS)
{
    RUNNER_PopArgs1(str);
    RUNNER_CheckTag(TString, str);

    unsigned len;
    const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &len);

    if (len != sizeof(FlowDouble) / FLOW_CHAR_SIZE)
    {
        RUNNER->ReportError(InvalidArgument, "String length in stringbytes2double should be %d chars", sizeof(FlowDouble) / FLOW_CHAR_SIZE);
        RETVOID;
    }

    FlowDouble tmp;
    memcpy(&tmp, pstr,sizeof(FlowDouble) );

    return StackSlot::MakeDouble(tmp);
}

// Read 4 bytes of the string in UTF-16 and converts to an int
StackSlot ByteCodeRunner::stringbytes2int(RUNNER_ARGS)
{
    RUNNER_PopArgs1(str);
    RUNNER_CheckTag(TString, str);

    unsigned len;
    const unicode_char *pstr = RUNNER->GetStringPtrSize(str, &len);

    if (len != sizeof(int) / FLOW_CHAR_SIZE)
    {
        RUNNER->ReportError(InvalidArgument, "String length in stringbytes2int should be %d chars", sizeof(int) / FLOW_CHAR_SIZE);
        RETVOID;
    }

    int tmp;
    memcpy(&tmp, pstr, sizeof(int) );

    return StackSlot::MakeInt(tmp);
}

StackSlot ByteCodeRunner::getCurrentDate(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    time_t tv = time_t(GetCurrentTime());
    struct tm parts;
    memset(&parts, 0, sizeof(parts));

#ifdef WIN32
    tm *tmp = localtime(&tv);
    if (tmp) parts = *tmp;
#else
    localtime_r(&tv, &parts);
#endif

    StackSlot fields[] = { StackSlot::MakeInt(parts.tm_year + 1900), StackSlot::MakeInt(parts.tm_mon + 1),
        StackSlot::MakeInt(parts.tm_mday) };

    return RUNNER->MakeStruct("Date", 3, fields);
}

StackSlot ByteCodeRunner::AllocateSomeStruct(StackSlot data)
{
    // Pin the argument for gc
    LocalRootDefinition frame(this, 1, &data);
    IGNORE_LOCAL(frame);

    if (unlikely(SomeStructId < 0))
        return AllocateSomeStruct(); // will emit error

    StackSlot rv = AllocateRawStruct(StructDefs[SomeStructId], false);
    SetStructSlot(rv, 0, data);
    return rv;
}

StackSlot ByteCodeRunner::elemIndex(RUNNER_ARGS)
{
    RUNNER_PopArgs3(arr, key, defidx);
    RUNNER_CheckTag(TArray, arr);

    int len = RUNNER->GetArraySize(arr);
    const StackSlot *data = RUNNER->GetArraySlotPtr(arr, len);

    for (int i = 0; i < len; i++)
        if (RUNNER->Compare(data[i], key) == 0)
            return StackSlot::MakeInt(i);

    return defidx;
}

StackSlot ByteCodeRunner::exists(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, clos);
    RUNNER_CheckTag(TArray, arr);

    RUNNER_DefSlots1(rv);
    rv = StackSlot::MakeBool(false);

    RUNNER_DefSlotArray(fn_args, 2);
    fn_args[0] = clos;

    int len = RUNNER->GetArraySize(arr);

    for (int i = 0; i < len; i++)
    {
        fn_args[1] = RUNNER->GetArraySlot(arr, i);
        rv = RUNNER->FastEvalFunction(fn_args, 1);
        RUNNER_CheckTag(TBool, rv);
        if (rv.GetBool())
            break;
    }

    return rv;
}

StackSlot ByteCodeRunner::find(RUNNER_ARGS)
{
    RUNNER_PopArgs2(arr, clos);
    RUNNER_CheckTag(TArray, arr);
    RUNNER_DefSlots1(rv);

    RUNNER_DefSlotArray(fn_args, 2);
    fn_args[0] = clos;

    int len = RUNNER->GetArraySize(arr);

    for (int i = 0; i < len; i++)
    {
        fn_args[1] = RUNNER->GetArraySlot(arr, i);
        rv = RUNNER->FastEvalFunction(fn_args, 1);
        RUNNER_CheckTag(TBool, rv);
        if (rv.GetBool())
            return RUNNER->AllocateSomeStruct(fn_args[1]);
    }

    return RUNNER->AllocateNoneStruct();
}

StackSlot ByteCodeRunner::getTotalMemoryUsed(RUNNER_ARGS)
{
	UNUSED(RUNNER);
	UNUSED(pRunnerArgs__);
    return StackSlot::MakeDouble((FlowDouble)(RUNNER->GetMemory()->GetMemSize() + StaticBuffer::total_memory()));
}

StackSlot ByteCodeRunner::removeCrashHandler(RUNNER_ARGS, void* /*data*/)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_root = slot[0].GetInt();
    T_FlowCrashHandlers & handlers = RUNNER->FlowCrashHandlers;
    handlers.erase(std::find(handlers.begin(), handlers.end(), cb_root));
    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

StackSlot ByteCodeRunner::addCrashHandler(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);
    int cb_root = RUNNER->RegisterRoot(cb);
    RUNNER->FlowCrashHandlers.push_back(cb_root);
    return RUNNER->AllocateNativeClosure(removeCrashHandler, "addCrashHandler$disposer", 0, NULL,
                                         1, StackSlot::MakeInt(cb_root));
}

void ByteCodeRunner::callFlowCrashHandlers(std::string msg)
{
    const StackSlot & msg_str = AllocateString(parseUtf8(msg));
    T_FlowCrashHandlers handlers = FlowCrashHandlers;
    for (T_FlowCrashHandlers::iterator it = handlers.begin(); it != handlers.end(); ++it)
        EvalFunction(LookupRoot(*it), 1, msg_str);
}

StackSlot ByteCodeRunner::removeCameraEventListener(RUNNER_ARGS, void *)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_root = slot[0].GetInt();

    T_CameraEventListeners::iterator itListeners = std::find(RUNNER->CameraEventListeners.begin(), RUNNER->CameraEventListeners.end(), cb_root);
    if(itListeners !=  RUNNER->CameraEventListeners.end()) {
        RUNNER->CameraEventListeners.erase(itListeners);
    }

    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

StackSlot ByteCodeRunner::removeCameraVideoEventListener(RUNNER_ARGS, void *)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_root = slot[0].GetInt();

    T_CameraVideoEventListeners::iterator itListeners = std::find(RUNNER->CameraVideoEventListeners.begin(), RUNNER->CameraVideoEventListeners.end(), cb_root);
    if(itListeners !=  RUNNER->CameraVideoEventListeners.end()) {
        RUNNER->CameraVideoEventListeners.erase(itListeners);
    }

    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

StackSlot ByteCodeRunner::removeTakeAudioEventListener(RUNNER_ARGS, void *)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_root = slot[0].GetInt();

    T_TakeAudioEventListeners::iterator itListeners = std::find(RUNNER->TakeAudioEventListeners.begin(), RUNNER->TakeAudioEventListeners.end(), cb_root);
    if(itListeners !=  RUNNER->TakeAudioEventListeners.end()) {
        RUNNER->TakeAudioEventListeners.erase(itListeners);
    }

    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

StackSlot ByteCodeRunner::addCameraPhotoEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);
    RUNNER->CameraEventListeners.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeCameraEventListener, "addCameraPhotoEventListener$disposer", 0, NULL,
                                         1, StackSlot::MakeInt(cb_root));
}

StackSlot ByteCodeRunner::addCameraVideoEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);
    RUNNER->CameraVideoEventListeners.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeCameraVideoEventListener, "addCameraVideoEventListener$disposer", 0, NULL,
                                         1, StackSlot::MakeInt(cb_root));
}

StackSlot ByteCodeRunner::addTakeAudioEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);
    RUNNER->TakeAudioEventListeners.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeTakeAudioEventListener, "addTakeAudioEventListener$disposer", 0, NULL,
                                         1, StackSlot::MakeInt(cb_root));
}

StackSlot ByteCodeRunner::md5(RUNNER_ARGS) {
    RUNNER_PopArgs1(content_str);
    RUNNER_CheckTag1(TString, content_str);

    std::string res = encodeUtf8(RUNNER->GetString(content_str));
    //std::string res1 = ::md5(res);

    return RUNNER->AllocateString(parseUtf8(::md5(res)));

}

StackSlot ByteCodeRunner::fileChecksum(RUNNER_ARGS)
{
	RUNNER_PopArgs1(content_str);
    RUNNER_CheckTag1(TString, content_str);

	std::string fileName = encodeUtf8(RUNNER->GetString(content_str));
	std::string res("");

	#ifdef FLOW_QT_BACKEND

	QFile f(QString(fileName.c_str()));
	if (f.open(QFile::ReadOnly)) {
		QCryptographicHash hash(QCryptographicHash::Md5);
		if (hash.addData(&f)) {
			res = hash.result().toHex().data();
		}
	}

	return RUNNER->AllocateString(QString(res.c_str()));

	#endif

	return RUNNER->AllocateString(parseUtf8(res));
}

StackSlot ByteCodeRunner::readBytes(RUNNER_ARGS)
{
	RUNNER_PopArgs1(n);
	RUNNER_CheckTag(TInt, n);
	std::string str;
	getline(std::cin, str);

	unsigned int len = n.GetInt();
	if (str.size() != len) {
		cerr << "Expected " << len << " bytes, got " << str.size() << " bytes" << std::endl;
	}

	return RUNNER->AllocateString(parseUtf8(str));
}

StackSlot ByteCodeRunner::readUntil(RUNNER_ARGS)
{
	RUNNER_PopArgs1(p);
	RUNNER_CheckTag(TString, p);
	std::string pattern = encodeUtf8(RUNNER->GetString(p));
	std::ostringstream buffer;
	unsigned int pos = 0;
	char ch = '\0';
	while (std::cin.get(ch)) {
		buffer << ch;
		if (ch == pattern[pos]) {
			pos += 1;
			if (pos == pattern.size()) {
				break;
			}
		} else {
			pos = 0;
		}
	}
	return RUNNER->AllocateString(parseUtf8(buffer.str()));
}

StackSlot ByteCodeRunner::print(RUNNER_ARGS)
{
	RUNNER_PopArgs1(object);

    if (object.IsString())
        RUNNER->flow_out << encodeUtf8(RUNNER->GetString(object));
    else
        RUNNER->PrintData(RUNNER->flow_out, object);

    RUNNER->flow_out << std::flush;

    RETVOID;
}

void ByteCodeRunner::NotifyCameraEvent(int code, std::string message, std::string additionalInfo, int width, int height)
{
    const StackSlot &code_arg = StackSlot::MakeInt(code);
    const StackSlot &message_arg = AllocateString(parseUtf8(message));
    const StackSlot &additionalInfo_arg = AllocateString(parseUtf8(additionalInfo));
    const StackSlot &width_arg = StackSlot::MakeInt(width);
    const StackSlot &height_arg = StackSlot::MakeInt(height);

    for(unsigned int i = 0; i < CameraEventListeners.size(); i++)
    {
        EvalFunction(LookupRoot(CameraEventListeners[i]), 5, code_arg, message_arg, additionalInfo_arg, width_arg, height_arg);
    }
}

void ByteCodeRunner::NotifyCameraEventVideo(int code, std::string message, std::string additionalInfo, int width, int height, int duration, unsigned size)
{
    const StackSlot &code_arg = StackSlot::MakeInt(code);
    const StackSlot &message_arg = AllocateString(parseUtf8(message));
    const StackSlot &additionalInfo_arg = AllocateString(parseUtf8(additionalInfo));
    const StackSlot &width_arg = StackSlot::MakeInt(width);
    const StackSlot &height_arg = StackSlot::MakeInt(height);
    const StackSlot &duration_arg = StackSlot::MakeInt(duration);
    const StackSlot &size_arg = StackSlot::MakeInt(size);

    for(unsigned int i = 0; i < CameraVideoEventListeners.size(); i++)
    {
        EvalFunction(LookupRoot(CameraVideoEventListeners[i]), 7, code_arg, message_arg, additionalInfo_arg, width_arg, height_arg, duration_arg, size_arg);
    }
}

void ByteCodeRunner::NotifyCameraEventAudio(int code, std::string message, std::string additionalInfo, int duration, unsigned size)
{
    const StackSlot &code_arg = StackSlot::MakeInt(code);
    const StackSlot &message_arg = AllocateString(parseUtf8(message));
    const StackSlot &additionalInfo_arg = AllocateString(parseUtf8(additionalInfo));
    const StackSlot &duration_arg = StackSlot::MakeInt(duration);
    const StackSlot &size_arg = StackSlot::MakeInt(size);

    for(T_TakeAudioEventListeners::iterator itAudio = TakeAudioEventListeners.begin(); itAudio != TakeAudioEventListeners.end(); ++itAudio)
    {
        EvalFunction(LookupRoot(*itAudio), 5, code_arg, message_arg, additionalInfo_arg, duration_arg, size_arg);
    }
}

enum TreeFields {
    TreeKey = 0, TreeValue, TreeLeft, TreeRight, TreeDepth
};

StackSlot ByteCodeRunner::fast_lookupTree(RUNNER_ARGS)
{
    RUNNER_PopArgs2(tree, key);

    for (;;)
    {
        RUNNER_CheckTag(TStruct, tree);

        // TreeEmpty():
        if (RUNNER->IsTreeEmptyStruct(tree))
            return RUNNER->AllocateNoneStruct();

        // TreeNode(k, v, l, r, depth):
        RUNNER_CheckStructType(tree, TreeNode, "lookupTree");

        int cmpv = RUNNER->Compare(key, RUNNER->GetStructSlot(tree, TreeKey)); // k
        if (cmpv < 0)
            tree = RUNNER->GetStructSlot(tree, TreeLeft); // l
        else if (cmpv > 0)
            tree = RUNNER->GetStructSlot(tree, TreeRight); // r
        else
            return RUNNER->AllocateSomeStruct(RUNNER->GetStructSlot(tree, TreeValue)); // v
    }
}

static int treeDepth(RUNNER_VAR, const StackSlot &tree)
{
    if (RUNNER->IsTreeNodeStruct(tree))
    {
        const StackSlot depth = RUNNER->GetStructSlot(tree, TreeDepth);
        if (!depth.IsInt()) {
            RUNNER->ReportTagError(depth, TInt, "depth", "depth in binary tree");
            return -1;
        }
        return depth.GetInt();
    }

    return 0;
}

static StackSlot mkTreeNode(RUNNER_VAR, StackSlot *node, int depth = -1)
{
    // TreeNode(k, v, left, right, max(treeDepth(left), treeDepth(right)) + 1);
    if (depth < 0)
    {
        int depth1 = treeDepth(RUNNER, node[TreeLeft]);
        int depth2 = treeDepth(RUNNER, node[TreeRight]);
        depth = max(depth1,depth2) + 1;
    }

    StackSlot rv = RUNNER->AllocateTreeNodeStruct();
    RUNNER->StructSlotPack(rv, node, 0, TreeDepth);
    RUNNER->SetStructSlot(rv, TreeDepth, StackSlot::MakeInt(depth));
    return rv;
}

// on-stack rotation
static bool rotateRight(RUNNER_VAR, StackSlot *node)
{
    if (!RUNNER->IsTreeNodeStruct(node[TreeLeft]))
        return false;

    // TreeNode(ck, cv, cleft, cright, cdepth):
    //const StackSlot *lnode = RUNNER->GetArraySlotPtr(node[TreeLeft], 5);

    // tmp = mkTreeNode(k, v, cright, right);
    RUNNER_DefSlotArray(newnode, 4);
    newnode[TreeKey] = node[TreeKey];
    newnode[TreeValue] = node[TreeValue];
    newnode[TreeLeft] = RUNNER->GetStructSlot(node[TreeLeft], TreeRight);
    newnode[TreeRight] = node[TreeRight];

    // mkTreeNode(ck, cv, cleft, tmp);
    node[TreeKey] = RUNNER->GetStructSlot(node[TreeLeft], TreeKey);
    node[TreeValue] = RUNNER->GetStructSlot(node[TreeLeft], TreeValue);
    node[TreeLeft] = RUNNER->GetStructSlot(node[TreeLeft], TreeLeft);
    node[TreeRight] = mkTreeNode(RUNNER, newnode);
    return true;
}

StackSlot ByteCodeRunner::fast_treeRightRotation(RUNNER_ARGS)
{
    RUNNER_PopArgs1(tree);
    RUNNER_CheckTag(TStruct, tree);

    if (RUNNER->IsTreeNodeStruct(tree))
    {
        RUNNER_DefSlotArray(node, 4);
        RUNNER->StructSlotUnpack(tree, node, 0, 4);

        if (rotateRight(RUNNER, node))
            return mkTreeNode(RUNNER, node);
    }

    return tree;
}

// on-stack rotation
static bool rotateLeft(RUNNER_VAR, StackSlot *node)
{
    if (!RUNNER->IsTreeNodeStruct(node[TreeRight]))
        return false;

    // TreeNode(ck, cv, cleft, cright, cdepth):
    //const StackSlot *rnode = RUNNER->GetArraySlotPtr(node[TreeRight], 5);

    // tmp = mkTreeNode(k, v, left, cleft)
    RUNNER_DefSlotArray(newnode, 4);
    newnode[TreeKey] = node[TreeKey];
    newnode[TreeValue] = node[TreeValue];
    newnode[TreeLeft] = node[TreeLeft];
    newnode[TreeRight] = RUNNER->GetStructSlot(node[TreeRight], TreeLeft);

    // mkTreeNode(ck, cv, tmp, cright);
    node[TreeKey] = RUNNER->GetStructSlot(node[TreeRight], TreeKey);
    node[TreeValue] = RUNNER->GetStructSlot(node[TreeRight], TreeValue);
    node[TreeRight] = RUNNER->GetStructSlot(node[TreeRight], TreeRight);
    node[TreeLeft] = mkTreeNode(RUNNER, newnode);
    return true;
}

StackSlot ByteCodeRunner::fast_treeLeftRotation(RUNNER_ARGS)
{
    RUNNER_PopArgs1(tree);
    RUNNER_CheckTag(TStruct, tree);

    if (RUNNER->IsTreeNodeStruct(tree))
    {
        RUNNER_DefSlotArray(node, 4);
        RUNNER->StructSlotUnpack(tree, node, 0, 4);

        if (rotateLeft(RUNNER, node))
            return mkTreeNode(RUNNER, node);
    }

    return tree;
}

StackSlot ByteCodeRunner::fast_rebalancedTree(RUNNER_ARGS)
{
    StackSlot *newnode = &RUNNER_ARG(0);

    int leftDepth = treeDepth(RUNNER, newnode[TreeLeft]);
    int rightDepth = treeDepth(RUNNER, newnode[TreeRight]);
    int balance = leftDepth - rightDepth;

    if (balance <= -2)
    {
        RUNNER_CheckStructType(newnode[TreeRight], TreeNode, "lookupTree");

        //const StackSlot *rnode = RUNNER->GetArraySlotPtr(newnode[TreeRight], 5);
        int rld = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeRight], TreeLeft));
        int rrd = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeRight], TreeRight));
        if (rld >= rrd)
            newnode[TreeRight] = fast_treeRightRotation(RUNNER, &newnode[TreeRight]);

        rotateLeft(RUNNER, newnode);

        return mkTreeNode(RUNNER, newnode);
    }
    else if (balance >= 2)
    {
        RUNNER_CheckStructType(newnode[TreeLeft], TreeNode, "lookupTree");

        //const StackSlot *lnode = RUNNER->GetArraySlotPtr(newnode[TreeLeft], 5);
        int lld = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeLeft], TreeLeft));
        int lrd = treeDepth(RUNNER, RUNNER->GetStructSlot(newnode[TreeLeft], TreeRight));
        if (lld <= lrd)
            newnode[TreeLeft] = fast_treeLeftRotation(RUNNER, &newnode[TreeLeft]);

        rotateRight(RUNNER, newnode);

        return mkTreeNode(RUNNER, newnode);
    }
    else
        return mkTreeNode(RUNNER, newnode, max(leftDepth,rightDepth)+1);
}

StackSlot ByteCodeRunner::fast_setTree(RUNNER_ARGS)
{
    RUNNER_PopArgs3(tree, key, value);
    RUNNER_DefSlotArray(newnode, 4);

    RUNNER_CheckTag(TStruct, tree);

    if (RUNNER->IsTreeEmptyStruct(tree))
    {
        // TreeEmpty():
        newnode[TreeKey] = key;
        newnode[TreeValue] = value;
        newnode[TreeLeft] = newnode[TreeRight] = tree;

        return mkTreeNode(RUNNER, newnode, 1);
    }
    else
    {
        // TreeNode(k, v, l, r, depth):
        RUNNER_CheckStructType(tree, TreeNode, "lookupTree");
        RUNNER->StructSlotUnpack(tree, newnode, 0, 4);

        int cmpv = RUNNER->Compare(key, newnode[TreeKey]);
        if (cmpv < 0)
        {
            tree = newnode[TreeLeft]; // reuse initial argument memory
            newnode[TreeLeft] = fast_setTree(RUNNER, &RUNNER_ARG(0));

            return fast_rebalancedTree(RUNNER, newnode);
        }
        else if (cmpv > 0)
        {
            tree = newnode[TreeRight]; // reuse initial argument memory
            newnode[TreeRight] = fast_setTree(RUNNER, &RUNNER_ARG(0));

            return fast_rebalancedTree(RUNNER, newnode);
        }
        else
        {
            // Exact match => just replace
            StackSlot depth = RUNNER->GetStructSlot(tree, TreeDepth);
            RUNNER_CheckTag(TInt, depth);

            newnode[TreeValue] = value;

            return mkTreeNode(RUNNER, newnode, depth.GetInt());
        }
    }
}


void ExtendedDebugInfo::clear()
{
    functions.clear();
    function_ranges.clear();
    files.clear();
    chunk_ranges.clear();
}

void ExtendedDebugInfo::addFunctionRange(FlowPtr pc, const std::string &sname)
{
    FunctionEntry &fun = functions[sname];

    if (fun.name.empty())
    {
        fun.name = sname;
        fun.num_args = fun.num_upvars = 0;
    }

    fun.ranges.push_back(pc);
    function_ranges[pc] = &fun;
}

void ExtendedDebugInfo::addSourceRange(FlowPtr pc, const std::string &module, int line, int byte)
{
    FileEntry &file = files[module];
    if (file.name.empty())
        file.name = module;
    LineEntry &fline = file.lines[line];
    fline.file = &file;
    fline.line_idx = line;
    ChunkEntry &chunk = fline.chunks[byte];
    chunk.line = &fline;
    chunk.char_idx = byte;

    chunk.ranges.push_back(pc);
    chunk_ranges[pc] = &chunk;
}

bool ExtendedDebugInfo::load_file(const std::string &fname)
{
    clear();

    FILE *f = fopen(fname.c_str(), "r");
    if (!f)
    {
        cerr << "Failed to load debug info: <<" << fname << ">>, error " << errno << ": " << strerror(errno) << endl;
        return false;
    }

    char line[255];

    while (!feof(f))
    {
        if(!fgets(line, sizeof(line), f)) {
        	break;
        }
        if (feof(f) || line[0] == '\n' || line[0] == '\0')
            break;

        unsigned pc;
        char name[255];

        if (sscanf(line, "%u %s", &pc, name) != 2)
        {
            printf("Error in debug info file structure: bad toplevel.\n");
            fclose(f);
            return false;
        }

        addFunctionRange(MakeFlowPtr(pc), name);
    }

    while (!feof(f))
    {
        if (!fgets(line, sizeof(line), f)) {
        	break;
        }
        if (feof(f) || line[0] == '\n' || line[0] == '\0')
            break;

        unsigned pc;
        int ln, fpos;
        char module[255];
        if (sscanf(line, "%u %s %d %d", &pc, module, &ln, &fpos) != 4)
        {
            printf("Error in debug info file structure: bad source pos.\n");
            fclose(f);
            return false;
        }

        addSourceRange(MakeFlowPtr(pc), module, ln, fpos);
    }

    while (!feof(f))
    {
        if (!fgets(line, sizeof(line), f)) {
        	break;
        }
        if (feof(f) || line[0] == '\n' || line[0] == '\0')
            break;

        unsigned pc;
        int type, id;
        char ident[255];
        if (sscanf(line, "L %u %d %d %s", &pc, &type, &id, ident) != 4)
        {
            printf("Error in debug info file structure: bad local variable info.\n");
            fclose(f);
            return false;
        }

        ExtendedDebugInfo::FunctionEntry *function = safeMapAt(function_ranges, MakeFlowPtr(pc));
        if (!function)
            continue;

        int index = function->locals.size();

        function->locals.push_back(LocalEntry());
        LocalEntry &entry = function->locals.back();

        entry.type = (LocalType)type;
        entry.id = id;
        entry.name = ident;

        if (!function->local_name_idx.count(entry.name))
            function->local_name_idx[entry.name] = index;

        function->local_id_idx[std::make_pair(entry.type,entry.id)] = index;

        switch (entry.type)
        {
        case LOCAL_ARG:
            function->num_args = max(function->num_args, id+1);
            break;
        case LOCAL_UPVAR:
            function->num_upvars = max(function->num_upvars, id+1);
            break;
        default:;
        }
    }

    fclose(f);
    return true;
}

void ExtendedDebugInfo::nestFunctions(std::map<FlowPtr,bool> &ftable, const std::string global)
{
    int idx = 0;
    std::vector<std::string> stack;
    stack.push_back(global+"$init");

    for (std::map<FlowPtr,bool>::iterator it = ftable.begin(); it != ftable.end(); ++it)
    {
        if (it->second) {
            std::string name = global;
            if (idx > 0) name += stl_sprintf("$%d", idx);
            idx++;

            stack.push_back(name);
            addFunctionRange(it->first, name);
        } else {
            // bah, just in case balance is somehow messed up
            if (stack.size() <= 1)
                continue;

            stack.pop_back();
            addFunctionRange(it->first, stack.back());
        }
    }
}

void ExtendedDebugInfo::load_code(FlowInstruction::Map &insns)
{
    clear();

    std::string cur_global;
    FlowPtr cur_global_start = MakeFlowPtr(0);
    std::map<FlowPtr, bool> func_starts;

    FlowInstruction::Map::iterator it = insns.begin();
    for (; it != insns.end(); ++it)
    {
        switch (it->second.op)
        {
        case CDebugInfo:
            nestFunctions(func_starts, cur_global);
            func_starts.clear();
            cur_global_start = it->first;
            cur_global = it->second.StrValue;
            addFunctionRange(cur_global_start, cur_global + "$init");
            break;

        case CCodePointer:
        case CClosurePointer:
            // Closures are numbered in the order they start, but can be detected only
            // by their ends. Thus it is necessary to first store both ends in a table.
            if (it->second.PtrValue >= cur_global_start && it->second.PtrValue < it->first)
            {
                func_starts[it->second.PtrValue] = true;
                func_starts[it->first] = false;
            }
            break;

        default:
            break;
        }
    }

    nestFunctions(func_starts, cur_global);
}

std::string ExtendedDebugInfo::getFunctionLocation(FlowPtr insn, bool only_line)
{
    std::stringstream ss;

    if (!only_line) {
        ExtendedDebugInfo::FunctionEntry *function = find_function(insn);

        ss << (function ? function->name : "?");
    }

    ExtendedDebugInfo::ChunkEntry *chunk = find_chunk(insn);

    if (chunk)
        ss << " at " << chunk->line->file->name << ":" << chunk->line->line_idx;

    return ss.str();
}

ExtendedDebugInfo::LocalEntry *ExtendedDebugInfo::FunctionEntry::find_local(std::string name)
{
    int index = safeMapAt(local_name_idx, name, -1);
    return index >= 0 ? &locals[index] : NULL;
}

ExtendedDebugInfo::LocalEntry *ExtendedDebugInfo::FunctionEntry::find_local(LocalType type, int id)
{
    int index = safeMapAt(local_id_idx, std::make_pair(type,id), -1);
    return index >= 0 ? &locals[index] : NULL;
}
