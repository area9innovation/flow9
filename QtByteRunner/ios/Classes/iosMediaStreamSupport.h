#ifndef iosMediaStreamSupport_h
#define iosMediaStreamSupport_h

#include "ByteCodeRunner.h"
#include "MediaStreamSupport.h"

#import <AVFoundation/AVFoundation.h>
#import "WebRTC/WebRTC.h"

class iosMediaStreamSupport;

@interface FlowRTCVideoRenderer : NSObject<RTCVideoRenderer> {
}
@property(readwrite, copy) void (^frameListener)(RTCVideoFrame*);
- (id) initWithFrameListener:(void (^)(RTCVideoFrame*)) frameListener;
- (void)setSize:(CGSize)size;
- (void)renderFrame:(RTCVideoFrame *)frame;
+ (CGImageRef) convertVideoFrame:(RTCVideoFrame*) frame;
@end

class FlowNativeMediaStream : public FlowNativeObject
{
public:
    bool isLocalStream;
    int width;
    int height;
    
    int onReadyRoot;
    int onErrorRoot;
    
    FlowNativeMediaStream(NativeMethodHost* owner);
    ~FlowNativeMediaStream();
    
    RTCPeerConnectionFactory *peerConnectionFactory;
    RTCCameraVideoCapturer *videoCapturer;
    RTCMediaStream *mediaStream;
    
    void retain();
    void release();
    
    DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaRecorder, FlowNativeObject)
};

class iosMediaStreamSupport : public MediaStreamSupport
{
    NSArray<AVCaptureDevice*> *videoDevices;
    NSArray<AVCaptureDevice*> *audioDevices;
    ByteCodeRunner *owner;
    
public:
    iosMediaStreamSupport(ByteCodeRunner *runner);
    
protected:
    void makeStream(bool recordAudio, bool recordVideo, unicode_string audioDeviceId, unicode_string videoDeviceId, int onReadyRoot, int onErrorRoot);
    void stopStream(StackSlot mediaStream);
    void initializeDeviceInfo(int OnDeviceInfoReadyRoot);
    void getAudioInputDevices(int OnDeviceInfoReadyRoot);
    void getVideoInputDevices(int OnDeviceInfoReadyRoot);
private:
    void returnDevices(int callbackRoot, NSArray<AVCaptureDevice*>  *devices);
};

#endif /* iosMediaStreamSupport_h */
