#import <UIKit/UIKit.h>
#import "utils.h"
#import "GLRenderer.h"
#import "GLVideoClip.h"

@interface FlowVideoPlayerView : UIView {
    CGContextRef RenderingContext;
    GLTextureBitmap::Ptr VideoTextureBitmap;
    CIContext * CoreImageContext;
}
- (void) playVideo;
- (void) pauseVideo;
- (void) seekTo: (int64_t) offset;
- (void) setVolume: (float) volume;
- (void) setRate: (float) rate;
- (void) renderFrameImage: (CGImageRef) cgi;
- (void) setTargetVideoTexture: (GLTextureBitmap::Ptr) video_texture;
- (void) removeFromSuperview;
@end
