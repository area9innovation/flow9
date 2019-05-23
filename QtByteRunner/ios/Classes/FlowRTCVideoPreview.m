#import "FlowRTCVideoPreview.h"
#import "utils.h"

@implementation FlowRTCVideoPreview

- (void) loadVideoFromRTCMediaStream: (FlowNativeMediaStream*) flowMediaStream onSuccess: (void (^)(int width, int height)) on_success onDimensionsChanged: (void (^)(int width, int height)) on_dimensions_changed onFrameReady: (void (^)()) on_frame
{
    self.width = flowMediaStream->width;
    self.height = flowMediaStream->height;
    self.flowMediaStream = flowMediaStream;
    self.flowMediaStream->retain();
    
    RUN_IN_MAIN_THREAD(^{
        on_success(self.width, self.height);
        if ([[flowMediaStream->mediaStream videoTracks] count] != 0) {
            self.videoRenderer = [[FlowRTCVideoRenderer alloc] initWithFrameListener:^void(RTCVideoFrame *frame) {
                RUN_IN_MAIN_THREAD(^{
                    CGImageRef cgImage = [FlowRTCVideoRenderer convertVideoFrame:frame];
                    int width = CGImageGetWidth(cgImage);
                    int height = CGImageGetHeight(cgImage);
                    if(self.width != width || self.height != height) {
                        self.width = width;
                        self.height = height;
                        on_dimensions_changed(self.width, self.height);
                    }
                    
                    [self renderFrameImage:cgImage];
                    CGImageRelease(cgImage);
                    on_frame();
                });
            }];
            [[[flowMediaStream->mediaStream videoTracks] firstObject] addRenderer:self.videoRenderer];
        }
    });
}

- (void) setVolume: (float) volume {
    RTCAudioTrack *audioTrack = [[self.flowMediaStream->mediaStream audioTracks] firstObject];
    if (audioTrack != nil) {
        [[audioTrack source] setVolume: volume * 10];
    }
}

- (void) dealloc {
    if (self.videoRenderer != nil) {
        RTCVideoTrack *videoTrack = [[self.flowMediaStream->mediaStream videoTracks] firstObject];
        if (videoTrack != nil) {
            [videoTrack removeRenderer:self.videoRenderer];
        }
        [self.videoRenderer release];
    }
    if (self.flowMediaStream != nil) {
        self.flowMediaStream->release();
    }
    
    [super dealloc];
}

@end
