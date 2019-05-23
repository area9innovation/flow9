#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "utils.h"
#import "GLRenderer.h"
#import "GLVideoClip.h"
#import "FlowVideoPlayerView.h"
#import "iosMediaStreamSupport.h"

@interface FlowRTCVideoPreview : FlowVideoPlayerView {
}
@property int width;
@property int height;
@property(retain) FlowRTCVideoRenderer *videoRenderer;
@property(assign) FlowNativeMediaStream *flowMediaStream;

- (void) loadVideoFromRTCMediaStream: (FlowNativeMediaStream*) flowMediaStream onSuccess: (void (^)(int width, int height)) on_success onDimensionsChanged: (void (^)(int width, int height)) on_dimensions_changed onFrameReady: (void (^)()) on_frame;
@end
