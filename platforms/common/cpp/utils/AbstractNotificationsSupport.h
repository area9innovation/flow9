#ifndef ABSTRACTNOTIFICATIONSSUPPORT_H
#define ABSTRACTNOTIFICATIONSSUPPORT_H

#include "core/ByteCodeRunner.h"

class AbstractNotificationsSupport : public NativeMethodHost {

    typedef STL_HASH_MAP<unicode_string, unicode_string> T_MessageData;

public:
    AbstractNotificationsSupport(ByteCodeRunner *owner);

    void executeRequestPermissionLocalNotificationCallback(bool result, int cb_root);
    void executeNotificationCallbacks(int notificationId, std::string notificationCallbackArgs);

    void deliverFBMessage(unicode_string id, unicode_string body, unicode_string title, unicode_string from, long stamp, T_MessageData data);
    void deliverFBToken(unicode_string token);
    void deliverFBTokenTo(int cb_root, unicode_string token);

protected:
    NativeFunction *MakeNativeFunction(const char *, int);
    void OnRunnerReset(bool inDestructor);
    void flowGCObject(GarbageCollectorFn);
    virtual bool doHasPermissionLocalNotification() = 0;
    virtual void doRequestPermissionLocalNotification(int /*cb_root*/) = 0;
    virtual void doCancelLocalNotification(int /*notificationId*/) = 0;
    virtual void doScheduleLocalNotification(double /*time*/, int /*notificationId*/, std::string /*notificationCallbackArgs*/, std::string /*notificationTitle*/, std::string /*notificationText*/, bool /*withSound*/, bool /*pinned*/) = 0;

    virtual void doGetFBToken(int /*cb_root*/) {}
    virtual void doSubscribeToFBTopic(unicode_string /*name*/) {}
    virtual void doUnsubscribeFromFBTopic(unicode_string /*name*/) {}
    
    virtual void doSetBadgerCount(int /*value*/) {}
    virtual int doGetBadgerCount() { return 0; }

private:

    typedef std::vector<int> T_NotificationListeners;
    T_NotificationListeners NotificationClickListeners;
    T_NotificationListeners FBNotificationListener;
    T_NotificationListeners FBRefreshTokenListener;

    static StackSlot removeListenerNotification(ByteCodeRunner*, StackSlot*, void*);

    DECLARE_NATIVE_METHOD(hasPermissionLocalNotification)
    DECLARE_NATIVE_METHOD(requestPermissionLocalNotification)
    DECLARE_NATIVE_METHOD(scheduleLocalNotification)
    DECLARE_NATIVE_METHOD(cancelLocalNotification)
    DECLARE_NATIVE_METHOD(addOnClickListenerLocalNotification)

    DECLARE_NATIVE_METHOD(initializeFBApp)
    DECLARE_NATIVE_METHOD(addFBNotificationListener)
    DECLARE_NATIVE_METHOD(onRefreshFBToken)
    DECLARE_NATIVE_METHOD(getFBToken)
    DECLARE_NATIVE_METHOD(subscribeToFBTopic)
    DECLARE_NATIVE_METHOD(unsubscribeFromFBTopic)
    
    DECLARE_NATIVE_METHOD(getBadgerCount)
    DECLARE_NATIVE_METHOD(setBadgerCount)
};

#endif // ABSTRACTNOTIFICATIONSSUPPORT_H

