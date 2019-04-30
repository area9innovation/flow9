//
//  FirebaseNotification.h
//  flow
//
//  Created by Ivan Vereschaga on 4/12/17.
//
//
#ifndef FirebaseNotification_h
#define FirebaseNotification_h

#ifdef FLOW_PUSH_NOTIFICATIONS

#import <Firebase/Firebase.h>

#import "iosAppDelegate.h"
#import "AbstractNotificationsSupport.h"

@interface iosFirebaseAppDelegate : iosAppDelegate

- (instancetype)init;
- (void)registerForRemoteNotifications;

@end


#endif /* FLOW_PUSH_NOTIFICATIONS */
#endif /* FirebaseNotification_h */
