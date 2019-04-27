//
//  LocalyticsTypes.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

typedef NS_ENUM(NSUInteger, LLInAppMessageDismissButtonLocation){
    LLInAppMessageDismissButtonLocationLeft,
    LLInAppMessageDismissButtonLocationRight
};

typedef NS_ENUM(NSInteger, LLRegionEvent){
    LLRegionEventEnter,
    LLRegionEventExit
};

typedef NS_ENUM(NSInteger, LLProfileScope){
    LLProfileScopeApplication,
    LLProfileScopeOrganization
};

typedef NS_ENUM(NSInteger, LLInAppMessageType) {
    LLInAppMessageTypeTop,
    LLInAppMessageTypeBottom,
    LLInAppMessageTypeCenter,
    LLInAppMessageTypeFull
};

typedef NS_ENUM(NSInteger, LLImpressionType) {
    LLImpressionTypeClick,
    LLImpressionTypeDismiss
};

/**
 Represents the interval at which the Localytics SDK will upload data in the case of a WiFi
 connection. Having a WiFi connection will supersede any mobile data connection. Default value
 is 5 seconds. To disable uploading for this connectivity set the value to -1
 */
#define LOCALYTICS_WIFI_UPLOAD_INTERVAL_SECONDS @"ll_wifi_upload_interval_seconds"

/**
 Represents the interval at which the Localytics SDK will upload data in the case of 4G
 or LTE connections. Default value is 10 seconds. To disable uploading for this connectivity
 set the value to -1
 */
#define LOCALYTICS_GREAT_NETWORK_UPLOAD_INTERVAL_SECONDS @"ll_great_network_upload_interval_seconds"

/**
 Represents the interval at which the Localytics SDK will upload data in the case of 3G
 connection. Default value is 30 seconds. To disable uploading for this connectivity
 set the value to -1
 */
#define LOCALYTICS_DECENT_NETWORK_UPLOAD_INTERVAL_SECONDS @"ll_decent_network_upload_interval_seconds"

/**
 Represents the interval at which the Localytics SDK will upload data in the case of 2G
 or EDGE connections. Default value is 90 seconds. To disable uploading for this connectivity
 set the value to -1
 */
#define LOCALYTICS_BAD_NETWORK_UPLOAD_INTERVAL_SECONDS @"ll_bad_network_upload_interval_seconds"

