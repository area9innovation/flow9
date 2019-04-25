//
//  FirebaseNotification.m
//  flow
//
//  Created by Ivan Vereschaga on 4/12/17.
//
//
#ifdef FLOW_PUSH_NOTIFICATIONS

#import <Foundation/Foundation.h>
#import "iosFirebaseAppDelegate.h"


@implementation iosFirebaseAppDelegate

- (instancetype) init {
    [super init];
    
    [FIRApp configure];
    [self registerForRemoteNotifications];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenRefresh:) name:FIRMessagingRegistrationTokenRefreshedNotification object:nil];
    
    return self;
}

- (void)tokenRefresh:(NSNotification *)notification {
    [self sendFirebaseToken:[[FIRMessaging messaging] FCMToken]];
}

// Next 2 methods, for older iOS versions, to be sure that callbacks will be called
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [super application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    
    [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeUnknown];
}

- (void) sendMessage:(NSDictionary *)info {
    NSString * kGCMMessageIDKey     = @"gcm.message_id";
    NSString * kGCMMessageTitleKey  = @"google.c.a.ttl";
    NSString * kGCMMessageFromIDKey = @"google.c.a.c_id";
    NSString * kGCMMessageStampKey  = @"google.c.a.ts";
    
    NSString * body;
    NSString * title;
    NSString * _id   = info[kGCMMessageIDKey] ? info[kGCMMessageIDKey] : @"";
    NSString * from  = info[kGCMMessageFromIDKey] ? info[kGCMMessageFromIDKey] : @"";
    NSUInteger stamp = (unsigned int)[info[kGCMMessageStampKey] integerValue];
    
    if ([info[@"aps"][@"alert"] isKindOfClass:[NSDictionary class]]) {
        body  = info[@"aps"][@"alert"][@"body"] ? info[@"aps"][@"alert"][@"body"] : @"";
        title = info[@"aps"][@"alert"][@"title"] ? info[@"aps"][@"alert"][@"title"] : @"";
    } else {
        body =  info[@"aps"][@"alert"] ? info[@"aps"][@"alert"] : @"";
        title = info[kGCMMessageTitleKey] ? info[kGCMMessageTitleKey] : @"";
    }
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    for (NSString * key in info) {
        if (![key hasPrefix:@"gcm"] && ![key hasPrefix:@"google"] && ![key hasPrefix:@"aps"]) {
            [data setValue:info[key] forKey:key];
        }
    }
    
    [self sendFirebaseMessage:_id body:body title:title from:from stamp:stamp data:data];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self sendMessage:userInfo];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(nonnull void (^)(UIBackgroundFetchResult))completionHandler {
    [self sendMessage:userInfo];

    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)registerForRemoteNotifications {
    UIUserNotificationType allNotificationTypes =
    (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
    UIUserNotificationSettings *settings =
    [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

@end
#endif 
