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


/** An enum to define the location that the In-App dismiss button should be shown. */
typedef NS_ENUM(NSUInteger, LLInAppMessageDismissButtonLocation){
    /** A value to specify rendering of the In-App dismiss button on the left. */
    LLInAppMessageDismissButtonLocationLeft,
    /** A value to specify rendering of the In-App dismiss button on the right. */
    LLInAppMessageDismissButtonLocationRight
};

/** An enum to define the event type that triggered a geofence. */
typedef NS_ENUM(NSInteger, LLRegionEvent){
    /** A value to specify that the geofence boundary was crossed as an entrance into the geofence */
    LLRegionEventEnter,
    /** A value to specify that the geofence boundary was crossed as an exit out the geofence */
    LLRegionEventExit
};

/** An enum to define the scope a profile attribute should be associated with. */
typedef NS_ENUM(NSInteger, LLProfileScope){
    /** A value to specify that the profile attribute is scoped to this specific application and doesn't apply in other applications */
    LLProfileScopeApplication,
    /** A value to specify that the profile attribute is scoped to the organization and applies across all apps */
    LLProfileScopeOrganization
};

/** An enum to define the type of In-App. */
typedef NS_ENUM(NSInteger, LLInAppMessageType) {
    /** A value to specify that the In-App is a top banner campaign. */
    LLInAppMessageTypeTop,
    /** A value to specify that the In-App is a bottom banner campaign. */
    LLInAppMessageTypeBottom,
    /** A value to specify that the In-App is a center campaign. */
    LLInAppMessageTypeCenter,
    /** A value to specify that the In-App is a full screen campaign. */
    LLInAppMessageTypeFull
};

/** An enum to specify the default conversion type of an In-App. */
typedef NS_ENUM(NSInteger, LLImpressionType) {
    /** A value to specify the default value of click, which will be counted as a conversion */
    LLImpressionTypeClick,
    /** A value to specify the default value of dismiss, which will not be counted as a conversion */
    LLImpressionTypeDismiss
};

// For iOS 13.x and below compatibility, numbers match to ATTrackingManagerAuthorizationStatus enum
typedef NS_ENUM(NSInteger, LLAdIdStatus) {
    LL_IDFA_NOT_DETERMINED = 0,
    LL_IDFA_RESTRICTED = 1,
    LL_IDFA_DENIED = 2,
    LL_IDFA_AUTHORIZED = 3,
    LL_IDFA_NOT_REQUIRED = 4
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

