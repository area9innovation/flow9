//
//  LLInAppConfiguration.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Foundation/Foundation.h>
#import <Localytics/LocalyticsTypes.h>

@class UIImage;

@interface LLInAppConfiguration : NSObject

/** The location of the dismiss button on an In-App message */
@property (nonatomic, assign) LLInAppMessageDismissButtonLocation dismissButtonLocation;
/** The image of the dismiss button on an In-App message */
@property (nonatomic, strong, nullable) UIImage *dismissButtonImage;
/** The hidden state of the dismiss button on an In-App message */
@property (nonatomic, assign) BOOL dismissButtonHidden;
/** The aspect ratio of the In-App msg.  This property is only relevant for center In-App messages */
@property (nonatomic, assign) CGFloat aspectRatio;
/** The offset of the In-App msg.  This property is only relevant for top or bottom banner In-App messages */
@property (nonatomic, assign) CGFloat offset;
/** The transparency of the background behind the In-App msg. Must be between 0 and 1. Relevant for center and full-screen In-App messages */
@property (nonatomic, assign) CGFloat backgroundAlpha;

/** Returns whether this is a center In-App message.
 @return YES if this is a center In-App message, NO otherwise
 */
- (BOOL)isCenterCampaign;
/** Returns whether this is a top banner In-App message.
 @return YES if this is a top banner In-App message, NO otherwise
 */
- (BOOL)isTopBannerCampaign;
/** Returns whether this is a bottom banner In-App message.
 @return YES if this is a bottom banner In-App message, NO otherwise
 */
- (BOOL)isBottomBannerCampaign;
/** Returns whether this is a full screen In-App message.
 @return YES if this is a full screen In-App message, NO otherwise
 */
- (BOOL)isFullScreenCampaign;

/** Set the image to be used for dimissing an In-App message by providing the name of the
 image to be loaded and used
 @param imageName The name of an image to be loaded and used for dismissing an In-App
 message. By default the image is a circle with an 'X' in the middle of it
 */
- (void)setDismissButtonImageWithName:(nonnull NSString *)imageName;

@end
