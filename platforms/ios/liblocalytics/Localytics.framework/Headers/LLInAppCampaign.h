//
//  LLInAppCampaign.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Localytics/LLWebViewCampaign.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Localytics/LocalyticsTypes.h>

/**
 * The campaign class containing information relevant to a single In-App campaign.
 *
 * @see LLWebViewCampaign
 * @see LLCampaignBase
 */
@interface LLInAppCampaign : LLWebViewCampaign
// Make sure to override all properties in copyWithZone!

/**
 * The type of In-App message associated with this campaign.
 */
@property (nonatomic, assign, readonly) LLInAppMessageType type;

/**
 * Value indicating if the campaign has a responsive creative for various sizes.
 */
@property (nonatomic, assign, readonly) BOOL isResponsive;

/**
 * Value indicating the desired aspect ratio for presentation (only relevant for center campaigns).
 */
@property (nonatomic, assign, readonly) CGFloat aspectRatio;

/**
 * Value indicating the desired offset for presentation (only relevant for banner campaigns)
 */
@property (nonatomic, assign, readonly) CGFloat offset;

/**
 * Value indicating the desired background alpha for presentation (only relevant for center and fullscreen campaigns)
 */
@property (nonatomic, assign, readonly) CGFloat backgroundAlpha;

/**
 * Value indicating if the dismiss button is hidden
 */
@property (nonatomic, assign, getter=isDismissButtonHidden, readonly) BOOL dismissButtonHidden;

/**
 * Value indicating the location of the dismiss button (left or right)
 */
@property (nonatomic, assign, readonly) LLInAppMessageDismissButtonLocation dismissButtonLocation;

/**
 * Value indicating the name of the event that triggered the In-App campaign.
 */
@property (nonatomic, copy, readonly, nonnull) NSString *eventName;

/**
 * Value indicating the attributes on the event that triggered the In-App campaign.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary *eventAttributes;

@end
