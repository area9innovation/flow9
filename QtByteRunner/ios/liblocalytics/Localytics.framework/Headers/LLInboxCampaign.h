//
//  LLInboxCampaign.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Localytics/LLWebViewCampaign.h>

/**
 * The campaign class containing information relevant to a single inbox campaign.
 *
 * @see LLWebViewCampaign
 * @see LLCampaignBase
 */
@interface LLInboxCampaign : LLWebViewCampaign
// Make sure to override all properties in copyWithZone!

/**
 * The flag indicating whether the campaign has been read.
 *
 * Note: Changing this value will automatically update the inbox campaign record
 * in the Localytics database.
 */
@property (nonatomic, assign, getter=isRead) BOOL read;

/**
 * The preview title text.
 */
@property (nonatomic, copy, readonly, nullable) NSString *titleText;

/**
 * The preview description text.
 */
@property (nonatomic, copy, readonly, nullable) NSString *summaryText;

/**
 * The remote url of the thumbnail.
 */
@property (nonatomic, copy, readonly, nullable) NSURL *thumbnailUrl;

/**
 * Value indicating if the campaign has a creative.
 */
@property (nonatomic, assign, readonly) BOOL hasCreative;

/**
 * The sort order of the campaign.
 */
@property (nonatomic, assign, readonly) NSInteger sortOrder;

/**
 * The received date of the campaign.
 */
@property (nonatomic, assign, readonly) NSTimeInterval receivedDate;

/**
 * The deep link of the campaign.
 */
@property (nonatomic, copy, readonly, nullable) NSURL *deepLinkURL;

/**
 * True if this inbox campaign was created from a push campaign.
 */
@property (nonatomic, assign, readonly) BOOL isPushToInboxCampaign;

/**
 * True if this inbox campaign has been deleted.
 */
@property (nonatomic, assign, getter=isDeleted, readonly) BOOL deleted;

- (void)delete;

@end
