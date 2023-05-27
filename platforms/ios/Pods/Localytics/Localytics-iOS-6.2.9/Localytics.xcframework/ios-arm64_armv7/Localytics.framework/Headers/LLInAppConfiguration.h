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

/**
 * The In-App's configuration object used to define certain properties that can be modified on an In-App message.
 */
@interface LLInAppConfiguration : NSObject

/** The location of the dismiss button on an In-App message */
@property (nonatomic, assign) LLInAppMessageDismissButtonLocation dismissButtonLocation;
/** The image of the dismiss button on an In-App message */
@property (nonatomic, strong, nullable) UIImage *dismissButtonImage;
/** The hidden state of the dismiss button on an In-App message */
@property (nonatomic, assign) BOOL dismissButtonHidden;
/**
 Set the aspect ratio for this In-App.  The aspect ratio should be a float value representing a ratio of height to width (example 9:16 display is 0.56).
 Accepted values must be greater than 0. This property is only relevant for Center and Banner In-App messages.
 */
@property (nonatomic, assign) CGFloat aspectRatio;

/**
 Set the aspect ratio for this In-App.  The aspect ratio should be a float value representing a ratio of width to height (example 16:9 display is 1.77).
 Accepted values must be greater than 0. This property is only relevant for Center and Banner In-App messages.
 */
@property (nonatomic, assign) CGFloat widthToHeightRatio;
/** The offset of the In-App msg.  This property is only relevant for top or bottom banner In-App messages */
@property (nonatomic, assign) CGFloat offset;
/**
 * Set the background alpha for this in-app.  The background alpha should be a float value
 * representing the desired transparency for the backdrop of the creative.
 *
 * Accepted values must be greater than 0 and less than 1.
 *
 * This property is only relevant for <strong>center</strong> and <strong>full
 * screen</strong> in-app Campaigns
 *
 * @param backgroundAlpha a float value greater than 0 and less than 1
 *                        representing the transparency of the campaign backdrop.
 */
@property (nonatomic, assign) CGFloat backgroundAlpha;
/** AutoHide Home Screen Indicator */
@property (nonatomic, assign) BOOL autoHideHomeScreenIndicator;
/** The screen area covered by the In-app.
 * NO - Within Safe Area
 * YES - Covers Entire Screen and html needs to handle notch and screen curvature.
 */
@property (nonatomic, assign) BOOL notchFullScreen;

/** The percentage of the in-app video that needs to be watched before sending a video event */
@property(nonatomic, assign) CGFloat videoConversionPercentage;

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
