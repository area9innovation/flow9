//
//  LLCampaignBase.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CampaignType) {
    CampaignTypeInApp,
    CampaignTypePush,
    CampaignTypeInbox,
    CampaignTypePlaces
};

/**
 * A base campaign class containing information relevant to all campaign types
 */
@interface LLCampaignBase : NSObject
// Make sure to override all properties in copyWithZone!

/**
 * The unique campaign id.
 */
@property (nonatomic, assign, readonly) NSInteger campaignId;

/**
 * The campaign name
 */
@property (nonatomic, copy, readonly, nonnull) NSString *name;

/**
 * The attributes associated with the campaign.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *,NSString *> *attributes;

@end
