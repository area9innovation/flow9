#ifndef iosNotificationsSupport_h
#define iosNotificationsSupport_h

#include "ByteCodeRunner.h"
#include "AbstractNotificationsSupport.h"

class iosNotificationsSupport : public AbstractNotificationsSupport
{
public:
    iosNotificationsSupport(ByteCodeRunner *runner);
    ~iosNotificationsSupport();
    
    void executeAllRequestPermissionCallbacks(bool result); // because we can't pass to didRegisterUserNotificationSettings cb_root to be able to differ requests
    void onNotificationClickHandle(UILocalNotification * notification);
protected:
    virtual bool doHasPermissionLocalNotification();
    virtual void doRequestPermissionLocalNotification(int cb_root);
    virtual void doScheduleLocalNotification(double time, int notificationId, std::string notificationCallbackArgs, std::string notificationTitle, std::string notificationText, bool withSound, bool pinned);
    virtual void doCancelLocalNotification(int notificationId);
    
    virtual void doGetFBToken(int cb_root);
    virtual void doSubscribeToFBTopic(unicode_string name);
    virtual void doUnsubscribeFromFBTopic(unicode_string name);
    
    virtual int doGetBadgerCount();
    virtual void doSetBadgerCount(int value);
    
    virtual void OnRunnerReset(bool inDestructor);
private:
    NSMutableArray * requestPermissionCallbackRoots;
};

#endif /* iosNotificationsSupport_h */
