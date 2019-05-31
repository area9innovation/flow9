#ifndef iosMediaRecorderSupport_h
#define iosMediaRecorderSupport_h

#include "ByteCodeRunner.h"
#include "MediaRecorderSupport.h"
#include "iosWebSocketSupport.h"
#include "iosMediaStreamSupport.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

class iosMediaRecorderSupport;

typedef void (^MediaRecorderDataListener)(AVCaptureOutput*, CMSampleBufferRef, AVCaptureConnection*);

@interface FlowCaptureMediaDataDelegate : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate> {
}
@property(readwrite, copy) void (^sampleListener)(CMSampleBufferRef);
- (id) initWithSampleBufferListener:(void (^)(CMSampleBufferRef)) sampleListener;
- (void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
@end

class FlowNativeMediaRecorder : public FlowNativeObject
{
public:
    
    FlowNativeMediaRecorder(iosMediaRecorderSupport* owner);
    ~FlowNativeMediaRecorder();
    
    RTCVideoRotation videoFrameRotation;
    
    FlowNativeMediaStream *flowMediaStream;
    AVCaptureSession *audioSession;
    FlowRTCVideoRenderer *videoRenderer;
    CIContext *context;
    
    AVAssetWriter *assetWriter;
    AVAssetWriterInput *audioWriterInput;
    AVAssetWriterInput *videoWriterInput;
    
    NSURL *fileUrl;
    BOOL useTempFile;
    SRWebSocket *websocket;
    
    void retain();
    void release();
    
    DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaRecorder, FlowNativeObject)
};

class iosMediaRecorderSupport : public MediaRecorderSupport
{
    ByteCodeRunner *owner;
    iosWebSocketSupport *WebSocketSupport;
    dispatch_queue_t recorderQueue;
public:
    iosMediaRecorderSupport(ByteCodeRunner *runner, iosWebSocketSupport *WebSocketSupport);
    
protected:
    void makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice, int onReadyRoot, int onErrorRoot);
    
    void startMediaRecorder(StackSlot recorder, int timeslice);
    void resumeMediaRecorder(StackSlot recorder);
    void pauseMediaRecorder(StackSlot recorder);
    void stopMediaRecorder(StackSlot recorder);
    
private:
    void addAudioInput(FlowNativeMediaRecorder *flowRecorder);
    void addVideoInput(FlowNativeMediaRecorder *flowRecorder, FlowNativeMediaStream *flowMediaStream);
    void addDeviceToSession(AVCaptureSession *session, AVMediaType mediaType);
    void addAudioDataOutput(AVCaptureSession *session, FlowCaptureMediaDataDelegate *delegate);
    void addFileOutput(FlowNativeMediaRecorder *flowRecorder, NSURL *filePath);
    void addWebSocketOutput(FlowNativeMediaRecorder *flowRecorder, NSString *websocketUri, int cbOnWebsocketErrorRoot);
};

#endif /* iosMediaRecorderSupport_h */
