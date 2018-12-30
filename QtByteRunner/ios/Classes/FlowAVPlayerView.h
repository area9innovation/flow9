#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "utils.h"
#import "GLRenderer.h"
#import "GLVideoClip.h"

typedef void (^VoidBlock)();
typedef void (^SuccessBlock)(float);
typedef void (^ResolutionBlock)(float, float);
typedef void (^PositionBlock)(CMTime);

@interface FlowAVPlayerView : UIView {
    CGContextRef RenderingContext;
    GLTextureBitmap::Ptr VideoTextureBitmap;
    CIContext * CoreImageContext;
}

@property (nonatomic, retain) AVPlayer *player;
@property (nonatomic, retain) AVPlayerItem * playerItem;
@property (nonatomic, retain) id timeObserver;
@property (nonatomic, assign) BOOL looping;
@property (nonatomic, assign) BOOL playing;
@property (readwrite, copy) SuccessBlock OnSuccess;
@property (readwrite, copy) ResolutionBlock OnResolutionReceived;
@property (readwrite, copy) PositionBlock OnFrame;
@property (readwrite, copy) VoidBlock OnError;
@property (readwrite, copy) VoidBlock OnPlayEnd;
@property (readwrite, copy) VoidBlock OnUserResume;
@property (readwrite, copy) VoidBlock OnUserPause;

- (void) loadVideo: (NSURL*) videoUrl onResolutionReceived: (void (^)(float width, float height)) on_resolution_received
        onSuccess: (void (^)(float duration)) on_success
        onError: (void (^)()) on_error onFrameReady: (void (^)(CMTime)) on_frame;
- (void) renderFrameImage: (CGImageRef) cgi;
- (void) renderFrame: (CMTime) cur_time;
- (void) setTargetVideoTexture: (GLTextureBitmap::Ptr) video_texture;
- (void) playVideo;
- (void) pauseVideo;
- (void) seekTo: (int64_t)offset;
- (void) removeFromSuperview;
+ (BOOL) useOpenGLVideo;
@end
