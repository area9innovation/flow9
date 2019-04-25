//
//  LLInboxDetailViewController.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <UIKit/UIKit.h>

@class LLInboxCampaign;

/**
 * UIViewController class that displays an inbox campaign's full creative. This class also handles tagging
 * impression events when a call to action is tapped within the creative or when the UIViewController is
 * dismissed.
 *
 * Customization options:
 * - Error view, @see errorView
 *
 * @see LLInboxViewController
 */
@interface LLInboxDetailViewController : UIViewController

/**
 * The inbox campaign being displayed
 */
@property (nonatomic, strong, readonly, nonnull) LLInboxCampaign *campaign;

/**
 * The UIView to show when the full creative fails to load. If this property is not set, a gray 'X' will
 * be shown in the center of the view.
 *
 * Note: All subviews of this view should include appropriate Auto Layout constraints because this
 * view's leading edge, top edge, trailing edge, and bottom edge will be constrained to match
 * the main view in LLInboxDetailViewController.
 */
@property (nonatomic, strong, nullable) UIView *creativeLoadErrorView;

/**
 * Flag indicating whether delete should be implemented as a navigation item on the detail view controller.
 */
@property (nonatomic, assign) BOOL deleteInNavBar;

@end
