#include "iosMediaRecorderSupport.h"

#include "RunnerMacros.h"
#import "utils.h"

@implementation FlowCaptureMediaDataDelegate

- (id) initWithSampleBufferListener:(void (^)(CMSampleBufferRef)) sampleListener;
{
    self = [super init];
    self.sampleListener = sampleListener;
    return self;
}

- (void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    self.sampleListener(sampleBuffer);
}

@end

IMPLEMENT_FLOW_NATIVE_OBJECT(FlowNativeMediaRecorder, FlowNativeObject)

FlowNativeMediaRecorder::FlowNativeMediaRecorder(iosMediaRecorderSupport *owner) : FlowNativeObject(owner->getFlowRunner())
{
    flowMediaStream = nil;
    audioSession = nil;
    videoRenderer = nil;
    context = [CIContext contextWithOptions:nil];
    
    assetWriter = nil;
    audioWriterInput = nil;
    videoWriterInput = nil;
    
    fileUrl = nil;
    websocket = nil;
    useTempFile = NO;
}

void FlowNativeMediaRecorder::retain()
{
    [audioSession retain];
    [videoRenderer retain];
    [context retain];
    
    [assetWriter retain];
    [audioWriterInput retain];
    [videoWriterInput retain];
    
    [fileUrl retain];
    [websocket retain];
}

void FlowNativeMediaRecorder::release()
{
    [audioSession release];
    [videoRenderer release];
    [context release];
    
    [assetWriter release];
    [audioWriterInput release];
    [videoWriterInput release];
    
    [fileUrl release];
    [websocket release];
}

FlowNativeMediaRecorder::~FlowNativeMediaRecorder()
{
    release();
}

iosMediaRecorderSupport::iosMediaRecorderSupport(ByteCodeRunner *runner, iosWebSocketSupport *WebSocketSupport) : MediaRecorderSupport(runner), owner(runner), WebSocketSupport(WebSocketSupport)
{
    recorderQueue = dispatch_queue_create("dk.area9.mediarecorder", DISPATCH_QUEUE_SERIAL);
}

void iosMediaRecorderSupport::makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice, int onReadyRoot, int onErrorRoot)
{
    RUNNER_VAR = owner;
    FlowNativeMediaStream* flowMediaStream = RUNNER->GetNative<FlowNativeMediaStream*>(mediaStream);
    FlowNativeMediaRecorder* flowRecorder = new FlowNativeMediaRecorder(this);
    flowRecorder->flowMediaStream = flowMediaStream;
    
    @try {
        if (flowMediaStream->isLocalStream && [[flowMediaStream->mediaStream audioTracks] count] != 0) {
            addAudioInput(flowRecorder);
        }
        
        if ([[flowMediaStream->mediaStream videoTracks] count] != 0) {
            addVideoInput(flowRecorder, flowMediaStream);
        }
        
        if (!filePath.empty()) {
            addFileOutput(flowRecorder, [NSURL fileURLWithPath:UNICODE2NS(filePath)]);
        }
        
        if(!websocketUri.empty()) {
            addWebSocketOutput(flowRecorder, UNICODE2NS(websocketUri), onErrorRoot);
        }
        flowRecorder->retain();
        RUNNER->EvalFunction(RUNNER->LookupRoot(onReadyRoot), 1, flowRecorder->getFlowValue());
    } @catch(NSException *ex) {
        NSString *message = [NSString stringWithFormat:@"%@:%@", ex.name, ex.reason];
        RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, RUNNER->AllocateString(NS2UNICODE(message)));
    }
}

void iosMediaRecorderSupport::addAudioInput(FlowNativeMediaRecorder *flowRecorder)
{
    NSDictionary *audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [ NSNumber numberWithInt: kAudioFormatMPEG4AAC ], AVFormatIDKey,
                                         [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                         [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                                         nil];
    AVAssetWriterInput *audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    [audioWriterInput setExpectsMediaDataInRealTime:YES];
    AVCaptureSession *audioSession = [[AVCaptureSession alloc] init];
    addDeviceToSession(audioSession, AVMediaTypeAudio);
    FlowCaptureMediaDataDelegate *audioDelegate = [[FlowCaptureMediaDataDelegate alloc] initWithSampleBufferListener:^(CMSampleBufferRef sampleBuffer) {
        if ([audioWriterInput isReadyForMoreMediaData]) {
            [audioWriterInput appendSampleBuffer:sampleBuffer];
        }
    }];
    addAudioDataOutput(audioSession, audioDelegate);
    flowRecorder->audioSession = audioSession;
    flowRecorder->audioWriterInput = audioWriterInput;
}

void iosMediaRecorderSupport::addVideoInput(FlowNativeMediaRecorder *flowRecorder, FlowNativeMediaStream *flowMediaStream)
{
    switch([UIApplication sharedApplication].statusBarOrientation) {
        case UIInterfaceOrientationUnknown: flowRecorder->videoFrameRotation = RTCVideoRotation_0; break;
        case UIInterfaceOrientationPortrait: flowRecorder->videoFrameRotation = RTCVideoRotation_90; break;
        case UIInterfaceOrientationPortraitUpsideDown: flowRecorder->videoFrameRotation = RTCVideoRotation_270; break;
        case UIInterfaceOrientationLandscapeLeft: flowRecorder->videoFrameRotation = RTCVideoRotation_0; break;
        case UIInterfaceOrientationLandscapeRight: flowRecorder->videoFrameRotation = RTCVideoRotation_180; break;
    }
    int width = flowMediaStream->width;
    int height = flowMediaStream->height;
    if(flowRecorder->videoFrameRotation % 180 != 0) {
        width = flowMediaStream->height;
        height = flowMediaStream->width;
    }
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:height], AVVideoHeightKey,
                                   nil];
    AVAssetWriterInput *videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    [videoWriterInput setExpectsMediaDataInRealTime:YES];
    AVAssetWriterInputPixelBufferAdaptor *videoWriterAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:nil];
    flowRecorder->videoRenderer = [[FlowRTCVideoRenderer alloc] initWithFrameListener:^void(RTCVideoFrame *frame) {
        [frame initWithBuffer:[frame buffer] rotation:flowRecorder->videoFrameRotation timeStampNs:[frame timeStampNs]];
        CIImage *image = [FlowRTCVideoRenderer videoFrame2CIImage:frame];
        CVPixelBufferRef rotatedBuffer = nil;
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, [flowMediaStream->videoCapturer preferredOutputPixelFormat], nil, &rotatedBuffer);
        if (status == kCVReturnSuccess) {
            [flowRecorder->context render:image toCVPixelBuffer:rotatedBuffer];
            if ([videoWriterInput isReadyForMoreMediaData]) {
                [videoWriterAdaptor appendPixelBuffer:rotatedBuffer withPresentationTime:CMTimeMake([frame timeStampNs], CMTimeScale(NSEC_PER_SEC))];
            }
            CVPixelBufferRelease(rotatedBuffer);
        }
    }];
    flowRecorder->videoWriterInput = videoWriterInput;
}

void iosMediaRecorderSupport::addDeviceToSession(AVCaptureSession *session, AVMediaType mediaType)
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:mediaType];
    NSError *error = nil;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (error)
        @throw [NSException exceptionWithName:error.localizedDescription reason:error.localizedFailureReason userInfo:error.userInfo];
    
    if ([session canAddInput:deviceInput]) {
        [session beginConfiguration];
        [session addInput:deviceInput];
        [session commitConfiguration];
    }
}

void iosMediaRecorderSupport::addAudioDataOutput(AVCaptureSession *session, FlowCaptureMediaDataDelegate *delegate)
{
    AVCaptureAudioDataOutput *audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioDataOutput setSampleBufferDelegate:delegate queue:recorderQueue];
    if ([session canAddOutput:audioDataOutput]) {
        [session beginConfiguration];
        [session addOutput:audioDataOutput];
        [session commitConfiguration];
    }
}

void iosMediaRecorderSupport::addFileOutput(FlowNativeMediaRecorder *flowRecorder, NSURL *filePath) {
    NSError *error = nil;
    AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:filePath fileType:AVFileTypeMPEG4 error:&error];
    if (flowRecorder->audioWriterInput && [assetWriter canAddInput:flowRecorder->audioWriterInput]) {
        [assetWriter addInput:flowRecorder->audioWriterInput];
    }
    if (flowRecorder->videoWriterInput && [assetWriter canAddInput:flowRecorder->videoWriterInput]) {
        [assetWriter addInput:flowRecorder->videoWriterInput];
    }
    
    flowRecorder->assetWriter = assetWriter;
    flowRecorder->fileUrl = filePath;
}

void iosMediaRecorderSupport::addWebSocketOutput(FlowNativeMediaRecorder *flowRecorder, NSString *websocketUri, int onErrorRoot) {
    RUNNER_VAR = owner;
    
    if (flowRecorder->assetWriter == nil) {
        NSString *filename = [[NSUUID new] UUIDString];
        addFileOutput(flowRecorder, [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:filename]]);
        flowRecorder->useTempFile = YES;
    }
    
    __block FlowNativeMediaRecorder *bRecorder = flowRecorder;
    WebSocketDelegate *delegate = [[WebSocketDelegate alloc] init];
    [delegate
     onOpen:^{
         NSData *recordedVideo= [NSData dataWithContentsOfFile:[bRecorder->fileUrl path]];
         WebSocketSupport->send(bRecorder->websocket, recordedVideo);
         [bRecorder->websocket close];
         if (bRecorder->useTempFile) {
             NSError* error = nil;
             [[NSFileManager defaultManager] removeItemAtPath:[bRecorder->fileUrl path] error:&error];
         }
     }
     onMessage:^(NSString *message) {
     }
     onError:^(NSError *error) {
         RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, [error localizedDescription].UTF8String);
     }
     onClose:^(NSInteger code, NSString *reason, BOOL wasClean) {
     }];
    flowRecorder->websocket = WebSocketSupport->init(websocketUri, delegate);
}

void iosMediaRecorderSupport::startMediaRecorder(StackSlot recorder, int timeslice)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);
    if([flowRecorder->assetWriter startWriting]) {
        [flowRecorder->assetWriter startSessionAtSourceTime:CMClockGetTime(CMClockGetHostTimeClock())];
        [flowRecorder->audioSession startRunning];
        [[[flowRecorder->flowMediaStream->mediaStream videoTracks] firstObject] addRenderer:flowRecorder->videoRenderer];
    }
}

void iosMediaRecorderSupport::resumeMediaRecorder(StackSlot recorder)
{
}

void iosMediaRecorderSupport::pauseMediaRecorder(StackSlot recorder)
{
}

void iosMediaRecorderSupport::stopMediaRecorder(StackSlot recorder)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);
    [flowRecorder->audioSession stopRunning];
    [[[flowRecorder->flowMediaStream->mediaStream videoTracks] firstObject] removeRenderer:flowRecorder->videoRenderer];
    [flowRecorder->audioWriterInput markAsFinished];
    [flowRecorder->videoWriterInput markAsFinished];
    [flowRecorder->assetWriter finishWritingWithCompletionHandler:^{
        if(flowRecorder->websocket) {
            [flowRecorder->websocket open];
        }
    }];
    flowRecorder->release();
}
