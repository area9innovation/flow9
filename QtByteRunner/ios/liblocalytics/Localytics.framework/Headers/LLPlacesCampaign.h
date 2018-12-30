//
//  LLPlacesCampaign.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Localytics/LLCampaignBase.h>
#import <Localytics/LocalyticsTypes.h>

@class LLRegion;

/**
 * The campaign class containing information relevant to a single places campaign.
 *
 * @see LLCampaignBase
 */
@interface LLPlacesCampaign : LLCampaignBase
// Make sure to override all properties in copyWithZone!

/**
 * The push message
 */
@property (nonatomic, copy, readonly, nonnull) NSString *message;

/**
 * The sound filename of the UILocalNotification
 */
@property (nonatomic, copy, readonly, nullable) NSString *soundFilename;

/**
 * The region object associated with this campaign
 */
@property (nonatomic, copy, readonly, nonnull) LLRegion *region;

/**
 * The event which triggered this campaign
 */
@property (nonatomic, assign, readonly) LLRegionEvent event;

/**
 * The category for the local notification
 */
@property (nonatomic, copy, readonly, nullable) NSString *category;

/**
 * The attachment URL for the UNNotificationAttachment
 */
@property (nonatomic, copy, readonly, nullable) NSString *attachmentURL;

/**
 * The attachment URL type for the UNNotificationAttachment
 */
@property (nonatomic, copy, readonly, nullable) NSString *attachmentType;

@end
