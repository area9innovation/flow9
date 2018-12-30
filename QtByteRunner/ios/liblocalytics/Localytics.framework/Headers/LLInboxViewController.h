//
//  LLInboxViewController.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <UIKit/UIKit.h>
#import <Localytics/LLInboxCampaign.h>

@protocol LLInboxCampaignsRefreshingDelegate <NSObject>
@optional

- (void)localyticsDidBeginRefreshingInboxCampaigns;
- (void)localyticsDidFinishRefreshingInboxCampaigns;

@end

/**
 * UIViewController class that loads inbox campaigns and displays them in a UITableView.
 * This class also handles marking inbox campaigns as read and displaying the inbox
 * campaign's full creative when it is tapped by pushing an LLInboxDetailViewController
 * onto the UINavigationController stack.
 *
 * By default this class uses custom UITableViewCells which include an unread indicator, title text,
 * summary text (when available), thumbnail image (when available), and created time text.
 *
 * Customization options:
 * - Empty campaigns view, @see property emptyCampaignsView
 * - Show UIActivityIndicatorView while loading campaigns, @see property showsActivityIndicatorView
 * - UITableViewCells, override tableView:cellForRowAtIndexPath:
 * - Full creative display, override tableView:didSelectRowAtIndexPath:, Note: You must also handle
 *   setting the LLInboxCampaign to be read and checking the existense of the creativeUrl property of
 *   the LLInboxCampaign object.
 * - Implement delete using a swipe action @see property enableSwipeDelete or in the navigation bar from
 *   the detail view @see property enableDetailViewDelete
 *
 * @see LLInboxDetailViewController
 */
@interface LLInboxViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, LLInboxCampaignsRefreshingDelegate>

/**
 * The UITableView that shows the inbox campaigns.
 */
@property (nonatomic, strong, nonnull) UITableView *tableView;

/**
 * The NSArray of LLInboxCampaigns backing the UITableView
 */
@property (nonatomic, strong, nullable) NSArray *tableData;

/**
 * The UIView to show when there are no inbox campaigns to display.
 *
 * Note: All subviews of this view should include appropriate Auto Layout constraints because this
 * view's leading edge, top edge, trailing edge, and bottom edge will be constrained to match
 * the main view in LLInboxViewController.
 */
@property (nonatomic, strong, nonnull) UIView *emptyCampaignsView;

/**
 * Flag indicating whether a UIActivityIndicatorView should be shown will campaigns are loading.
 */
@property (nonatomic, assign) BOOL showsActivityIndicatorView;

/**
 * Flag indicating whether delete should be implemented as a swipe action on the list view
 */
@property (nonatomic, assign) BOOL enableSwipeDelete;

/**
 * Flag indicating whether delete should be implemented as a navigation item on the detail view controller.
 */
@property (nonatomic, assign) BOOL enableDetailViewDelete;

/**
 * Flag indicating whether thumbnail images are automatically downloaded and loading into LLInboxThumbnailCell.
 * Defaults to YES. Set this property to NO to manually manage thumbnail downloading and caching (such as through
 * a 3rd party networking library).
 */
@property (nonatomic, assign) BOOL downloadsThumbnails;

/**
 * The font of the UITableViewCell textLabel. Default is 16 point system bold.
 */
@property (nonatomic, strong, nonnull) UIFont *textLabelFont;

/**
 * The color of the UITableViewCell textLabel. Default is black.
 */
@property (nonatomic, strong, nonnull) UIColor *textLabelColor;

/**
 * The font of the UITableViewCell detailTextLabel. Default is 14 point system.
 */
@property (nonatomic, strong, nonnull) UIFont *detailTextLabelFont;

/**
 * The color of the UITableViewCell detailTextLabel. Default is black.
 */
@property (nonatomic, strong, nonnull) UIColor *detailTextLabelColor;

/**
 * The font of the UITableViewCell timeTextLabel. Default is 10 point system.
 */
@property (nonatomic, strong, nonnull) UIFont *timeTextLabelFont;

/**
 * The color of the UITableViewCell timeTextLabel. Default is gray.
 */
@property (nonatomic, strong, nonnull) UIColor *timeTextLabelColor;

/**
 * The color of the UITableViewCell unread indicator. Default is #007AFF.
 */
@property (nonatomic, strong, nonnull) UIColor *unreadIndicatorColor;

/**
 * The color of the UITablviewCell background
 */
@property (nonatomic, strong, nonnull) UIColor *cellBackgroundColor;

/**
 * The UIView to show when a creative fails to load in a detail view. This property is used to set the
 * creativeLoadErrorView of LLInboxDetailViewControllers created when the user opens a campaign.
 * If this property is not set, a gray 'X' will be shown in the center of the view.
 *
 * Note: All subviews of this view should include appropriate Auto Layout constraints because this
 * view's leading edge, top edge, trailing edge, and bottom edge will be constrained to match
 * the main view in LLInboxDetailViewController.
 */
@property (nonatomic, strong, nullable) UIView *creativeLoadErrorView;

/**
 * Returns the inbox campaign for an index path (useful for overriding tableView:cellForRowAtIndexPath:)
 *
 * @return An LLInboxCampaign object for the index path.
 */
- (nullable LLInboxCampaign *)campaignForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

@end
