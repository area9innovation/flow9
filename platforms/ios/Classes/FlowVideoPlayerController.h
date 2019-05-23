#import <UIKit/UIKit.h>

@interface FlowVideoPlayerController : UIViewController {
    IBOutlet UILabel * SubtitleText;
    IBOutlet UIImageView * PlayButtonImage;
}

- (void) setVideoSubtitle: (NSString*) subtitle;
- (void) showPlayButton;
- (void) hidePlayButton;
@end
