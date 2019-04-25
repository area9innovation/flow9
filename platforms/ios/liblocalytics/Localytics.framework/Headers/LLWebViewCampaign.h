//
//  LLWebViewCampaign.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Localytics/LLCampaignBase.h>

/**
 * A base campaign class containing information relevant to campaigns which
 * include a web component.
 *
 * @see LLCampaignBase
 */
@interface LLWebViewCampaign : LLCampaignBase
// Make sure to override all properties in copyWithZone!

/**
 * The file path on disk of the creative associated with this campaign.
 */
@property (nonatomic, copy, readonly, nullable) NSString *creativeFilePath;

@end
