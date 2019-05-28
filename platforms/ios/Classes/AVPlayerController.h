#import <UIKit/UIKit.h>

@interface FlowAVPlayerController : UIViewController {
    IBOutlet UILabel * SubtitleText;
    IBOutlet UIImageView * PlayButtonImage;
}

- (void) setVideoSubtitle: (NSString*) subtitle;
- (void) showPlayButton;
- (void) hidePlayButton;
@end
