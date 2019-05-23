#include "AbstractNotificationsSupport.h"

#include "core/RunnerMacros.h"

#include <stdlib.h>

AbstractNotificationsSupport::AbstractNotificationsSupport(ByteCodeRunner *owner) : NativeMethodHost(owner)
{
}

NativeFunction *AbstractNotificationsSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "NotificationsSupport."

    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, hasPermissionLocalNotification, 0);
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, requestPermissionLocalNotification, 1);
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, scheduleLocalNotification, 7);
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, cancelLocalNotification, 1);
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, addOnClickListenerLocalNotification, 1);

    // Firebase notifications

    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, addFBNotificationListener, 1);
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, onRefreshFBToken, 1);

    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, subscribeToFBTopic, 1);
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, unsubscribeFromFBTopic, 1);
    
    // Badger count manage
    
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, getBadgerCount, 0);
    TRY_USE_NATIVE_METHOD(AbstractNotificationsSupport, setBadgerCount, 1);

    return NULL;
}

void AbstractNotificationsSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    NotificationClickListeners.clear();
    FBNotificationListener.clear();
    FBRefreshTokenListener.clear();
}

void AbstractNotificationsSupport::flowGCObject(GarbageCollectorFn ref)
{
}

void AbstractNotificationsSupport::executeRequestPermissionLocalNotificationCallback(bool result, int cb_root)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(cb_root), 1, StackSlot::MakeBool(result));
    RUNNER->ReleaseRoot(cb_root);
}

void AbstractNotificationsSupport::executeNotificationCallbacks(int notificationId, std::string notificationCallbackArgs)
{
    RUNNER_VAR = getFlowRunner();

    const StackSlot &notificationCallbackArgs_str = RUNNER->AllocateString(parseUtf8(notificationCallbackArgs));
    const StackSlot &notificationId_arg = StackSlot::MakeInt(notificationId);

    for(T_NotificationListeners::iterator it = NotificationClickListeners.begin(); it != NotificationClickListeners.end(); ++it)
    {
        RUNNER->EvalFunction(RUNNER->LookupRoot(*it), 2, notificationId_arg, notificationCallbackArgs_str);
    }
}

StackSlot AbstractNotificationsSupport::hasPermissionLocalNotification(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeBool(doHasPermissionLocalNotification());
}

StackSlot AbstractNotificationsSupport::requestPermissionLocalNotification(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);
    int cb_root = RUNNER->RegisterRoot(cb);
    doRequestPermissionLocalNotification(cb_root);
    RETVOID;
}

StackSlot AbstractNotificationsSupport::scheduleLocalNotification(RUNNER_ARGS)
{
    RUNNER_PopArgs7(time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound, pin);
    RUNNER_CheckTag1(TDouble, time);
    RUNNER_CheckTag1(TInt, notificationId);
    RUNNER_CheckTag3(TString, notificationCallbackArgs, notificationTitle, notificationText);
    RUNNER_CheckTag2(TBool, withSound, pin);

    doScheduleLocalNotification(time.GetDouble(), notificationId.GetInt(), encodeUtf8(RUNNER->GetString(notificationCallbackArgs)), encodeUtf8(RUNNER->GetString(notificationTitle)), encodeUtf8(RUNNER->GetString(notificationText)), withSound.GetBool(), pin.GetBool());

    RETVOID;
}

StackSlot AbstractNotificationsSupport::cancelLocalNotification(RUNNER_ARGS)
{
    RUNNER_PopArgs1(notificationId);
    RUNNER_CheckTag1(TInt, notificationId);
    doCancelLocalNotification(notificationId.GetInt());
    RETVOID;
}

StackSlot AbstractNotificationsSupport::removeListenerNotification(RUNNER_ARGS, void * data)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_root = slot[0].GetInt();
    T_NotificationListeners *listeners = (T_NotificationListeners *)data;
    T_NotificationListeners::iterator itListeners = std::find(listeners->begin(), listeners->end(), cb_root);
    if (itListeners != listeners->end()) {
        listeners->erase(itListeners);
    }
    RUNNER->ReleaseRoot(cb_root);

    RETVOID;
}

StackSlot AbstractNotificationsSupport::addOnClickListenerLocalNotification(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);
    NotificationClickListeners.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeListenerNotification, "addOnClickListenerLocalNotification$disposer", 0, &NotificationClickListeners,
        1, StackSlot::MakeInt(cb_root));
}

StackSlot AbstractNotificationsSupport::addFBNotificationListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);
    FBNotificationListener.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeListenerNotification, "addFBNotificationListener$disposer", 0, &FBNotificationListener,
        1, StackSlot::MakeInt(cb_root));
}

StackSlot AbstractNotificationsSupport::onRefreshFBToken(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_root = RUNNER->RegisterRoot(cb);
    FBRefreshTokenListener.push_back(cb_root);

    return RUNNER->AllocateNativeClosure(removeListenerNotification, "onRefreshFBToken$disposer", 0, &FBRefreshTokenListener,
        1, StackSlot::MakeInt(cb_root));
}

void AbstractNotificationsSupport::deliverFBMessage(
        unicode_string id,
        unicode_string body,
        unicode_string title,
        unicode_string from,
        long stamp,
        T_MessageData data)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlots6(_id, _title, _body, _from, _stamp, _data);

    _id =    RUNNER->AllocateString(id.c_str());
    _title = RUNNER->AllocateString(title.c_str());
    _body =  RUNNER->AllocateString(body.c_str());
    _from =  RUNNER->AllocateString(from.c_str());
    _stamp = StackSlot::MakeInt(stamp);

    int i = 0;
    _data = RUNNER->AllocateArray(data.size());
    for (T_MessageData::iterator it = data.begin(); it != data.end(); ++it) {
        RUNNER_DefSlots1(_keyvalue);
        _keyvalue = RUNNER->AllocateArray(2);

        RUNNER->SetArraySlot(_keyvalue, 0, RUNNER->AllocateString(it->first.c_str()));
        RUNNER->SetArraySlot(_keyvalue, 1, RUNNER->AllocateString(it->second.c_str()));

        RUNNER->SetArraySlot(_data, i, _keyvalue);
        i++;
    }

    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    for (T_NotificationListeners::iterator it = FBNotificationListener.begin(); it != FBNotificationListener.end(); ++it) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(*it), 6, _id, _title, _body, _from, _stamp, _data);
    }
}

void AbstractNotificationsSupport::deliverFBToken(unicode_string token)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlots1(_token);

    _token = RUNNER->AllocateString(token.c_str());

    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    for (T_NotificationListeners::iterator it = FBRefreshTokenListener.begin(); it != FBRefreshTokenListener.end(); ++it) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(*it), 1, _token);
    }
}

StackSlot AbstractNotificationsSupport::subscribeToFBTopic(RUNNER_ARGS)
{
    RUNNER_PopArgs1(_name);
    RUNNER_CheckTag(TString, _name);

    doSubscribeToFBTopic(RUNNER->GetString(_name));

    RETVOID;
}

StackSlot AbstractNotificationsSupport::unsubscribeFromFBTopic(RUNNER_ARGS)
{
    RUNNER_PopArgs1(_name);
    RUNNER_CheckTag(TString, _name);

    doUnsubscribeFromFBTopic(RUNNER->GetString(_name));

    RETVOID;
}

StackSlot AbstractNotificationsSupport::getBadgerCount(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    
    return StackSlot::MakeInt(doGetBadgerCount());
}

StackSlot AbstractNotificationsSupport::setBadgerCount(RUNNER_ARGS)
{
    RUNNER_PopArgs1(value);
    RUNNER_CheckTag1(TInt, value);
    
    doSetBadgerCount(value.GetInt());
    
    RETVOID;
}
