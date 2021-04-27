#include "iosNotificationsSupport.h"
#import <AVFoundation/AVFoundation.h>
#import "utils.h"

#ifdef FLOW_PUSH_NOTIFICATIONS
#import <Firebase/Firebase.h>
#endif

iosNotificationsSupport::iosNotificationsSupport(ByteCodeRunner *runner) : AbstractNotificationsSupport(runner)
{
    requestPermissionCallbackRoots = [[NSMutableArray alloc] init];
}

iosNotificationsSupport::~iosNotificationsSupport()
{
    [requestPermissionCallbackRoots removeAllObjects];
    [requestPermissionCallbackRoots release];
}

void iosNotificationsSupport::OnRunnerReset(bool inDestructor)
{
    AbstractNotificationsSupport::OnRunnerReset(inDestructor);
    [requestPermissionCallbackRoots removeAllObjects];
}

void iosNotificationsSupport::executeAllRequestPermissionCallbacks(bool result)
{
    for (NSNumber * cb_root in requestPermissionCallbackRoots) {
        executeRequestPermissionLocalNotificationCallback(result, [cb_root intValue]);
    }
    [requestPermissionCallbackRoots removeAllObjects];
}

void iosNotificationsSupport::onNotificationClickHandle(UILocalNotification *notification)
{
    // we compare dates, because this method will be called twice: once when notification moved to notification center
    // and after user click on it.
    if ([notification.userInfo objectForKey: @"flowLocalNotificationId"]) {
        NSDate * now = [NSDate date];
        NSDate * updatedAt = [notification.userInfo objectForKey: @"updatedAt"];
        int intervalUpdate = [now timeIntervalSinceDate: updatedAt];
        int intervalFire = [now timeIntervalSinceDate: [notification fireDate]];
        // we just updated/issued it
        if (intervalUpdate <= 1 || intervalFire <= 1) {
            AudioServicesPlaySystemSound(1315);
            return;
        }
        // Now we are sure that user clicked on our notification.
        int notificationId = [[notification.userInfo objectForKey: @"flowLocalNotificationId"] intValue];
        NSString * notificationCallbackArgs = [notification.userInfo objectForKey: @"flowNotificationCallbackArgs"];
        executeNotificationCallbacks(notificationId, [notificationCallbackArgs UTF8String]);
        [[NSUserDefaults standardUserDefaults] removeObjectForKey: [NSString stringWithFormat: @"flowLocalNotificationId_%i", notificationId]];
    }
}

bool iosNotificationsSupport::doHasPermissionLocalNotification()
{
    // Check it's iOS 8 and above
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]){
        UIUserNotificationSettings * grantedSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        if (grantedSettings.types == UIUserNotificationTypeNone) {
            return false;
        }
    }
    return true;
}

void iosNotificationsSupport::doRequestPermissionLocalNotification(int cb_root)
{
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationType types = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
        UIUserNotificationSettings * settings = [UIUserNotificationSettings settingsForTypes: types categories: nil];
        [application registerUserNotificationSettings: settings];
    } else {
        UIUserNotificationType types = (UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound);
        [application registerForRemoteNotificationTypes: types];
    }
    [requestPermissionCallbackRoots addObject: [NSNumber numberWithInt: cb_root]];
}

void iosNotificationsSupport::doScheduleLocalNotification(double time, int notificationId, std::string notificationCallbackArgs, std::string notificationTitle, std::string notificationText, bool withSound, bool pinned)
{
    doCancelLocalNotification(notificationId);
    
    UILocalNotification * localNotification = [[UILocalNotification alloc] init];
    if (localNotification == nil)
        return;

    NSDate * itemDate = [NSDate dateWithTimeIntervalSince1970: time / 1000.0];
    localNotification.fireDate = itemDate;
    localNotification.timeZone = [NSTimeZone defaultTimeZone];
    localNotification.alertBody = [NSString stringWithUTF8String: notificationText.c_str()];
    localNotification.alertTitle = [NSString stringWithUTF8String: notificationTitle.c_str()];
    if (withSound) {
        //localNotification.applicationIconBadgeNumber = [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
        localNotification.soundName = UILocalNotificationDefaultSoundName;
    }
    NSDictionary * infoDict = @{
        @"flowLocalNotificationId" : [NSNumber numberWithInt: notificationId],
        @"flowNotificationCallbackArgs" : [NSString stringWithUTF8String: notificationCallbackArgs.c_str()],
        @"updatedAt" : [NSDate date]
    };
    localNotification.userInfo = infoDict;
    
    [[UIApplication sharedApplication] scheduleLocalNotification: localNotification];
    
    NSString * key = [NSString stringWithFormat: @"flowLocalNotificationId_%i", notificationId];
    NSData * data = [NSKeyedArchiver archivedDataWithRootObject: localNotification];
    [[NSUserDefaults standardUserDefaults] setObject: data forKey: key];
}

void iosNotificationsSupport::doCancelLocalNotification(int notificationId)
{
    NSString * key = [NSString stringWithFormat: @"flowLocalNotificationId_%i", notificationId];
    if ([[NSUserDefaults standardUserDefaults] objectForKey: key]) {
        NSData * data = [[NSUserDefaults standardUserDefaults] objectForKey: key];
        UILocalNotification * localNotification = [NSKeyedUnarchiver unarchiveObjectWithData: data];
        [[UIApplication sharedApplication] cancelLocalNotification: localNotification];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey: key];
    }
}


void iosNotificationsSupport::doGetFBToken(int cb_root)
{
#ifdef FLOW_PUSH_NOTIFICATIONS
    NSString* token = [FIRMessaging messaging].FCMToken;
    deliverFBTokenTo(cb_root, NS2UNICODE(token != nil ? token : @""));
#endif
}

void iosNotificationsSupport::doSubscribeToFBTopic(unicode_string name)
{
#ifdef FLOW_PUSH_NOTIFICATIONS
    [[FIRMessaging messaging] subscribeToTopic:UNICODE2NS(name)];
#endif
}

void iosNotificationsSupport::doUnsubscribeFromFBTopic(unicode_string name)
{
#ifdef FLOW_PUSH_NOTIFICATIONS
    [[FIRMessaging messaging] unsubscribeFromTopic:UNICODE2NS(name)];
#endif
}

void iosNotificationsSupport::doSetBadgerCount(int value)
{
    [UIApplication sharedApplication].applicationIconBadgeNumber = value;
}

int iosNotificationsSupport::doGetBadgerCount()
{
    return [[UIApplication sharedApplication] applicationIconBadgeNumber];
}
