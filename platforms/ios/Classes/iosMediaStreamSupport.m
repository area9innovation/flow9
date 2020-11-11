#ifdef FLOW_MEDIASTREAM

#include "iosMediaStreamSupport.h"

#include "RunnerMacros.h"
#import "utils.h"

@implementation FlowRTCVideoRenderer

- (id) initWithFrameListener:(void (^)(RTCVideoFrame*)) frameListener {
    self = [super init];
    self.frameListener = frameListener;
    return self;
}

- (void) setSize:(CGSize) size {
    
}

- (void) renderFrame:(RTCVideoFrame *) frame {
    self.frameListener(frame);
}

+ (CGSize) getRotatedFrameSize:(RTCVideoFrame*) frame {
    int rotatedWidth = frame.width;
    int rotatedHeight = frame.height;
    if(frame.rotation % 180 != 0) {
        rotatedWidth = frame.height;
        rotatedHeight = frame.width;
    }
    return CGSizeMake(rotatedWidth, rotatedHeight);
}

+ (CIImage*) videoFrame2CIImage:(RTCVideoFrame*) frame {
    RTCCVPixelBuffer* remotePixelBuffer = (RTCCVPixelBuffer *)frame.buffer;
    CVPixelBufferRef pixelBuffer = remotePixelBuffer.pixelBuffer;
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CGImagePropertyOrientation orientation;
    switch(frame.rotation) {
        case RTCVideoRotation_0: orientation = kCGImagePropertyOrientationUp; break;
        case RTCVideoRotation_90: orientation = kCGImagePropertyOrientationRight; break;
        case RTCVideoRotation_180: orientation = kCGImagePropertyOrientationDown; break;
        case RTCVideoRotation_270: orientation = kCGImagePropertyOrientationLeft; break;
    }
    ciImage = [ciImage imageByApplyingOrientation:orientation];
    
    return ciImage;
}

@end

@implementation MetadataObjectDelegate

- (id) initWithCallback: (void (^)(NSString*)) dataCallback {
    self = [super init];
    self.dataCallback = dataCallback;
    return self;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    AVMetadataMachineReadableCodeObject* firstObject = (AVMetadataMachineReadableCodeObject*)(metadataObjects.firstObject);
    if (firstObject.stringValue != nil)
        self.dataCallback(firstObject.stringValue);
}

@end

IMPLEMENT_FLOW_NATIVE_OBJECT(FlowNativeMediaStream, FlowNativeObject)

FlowNativeMediaStream::FlowNativeMediaStream(NativeMethodHost *owner) : FlowNativeObject(owner->getFlowRunner())
{
    isLocalStream = false;
    width = 640;
    height = 480;
    peerConnectionFactory = nil;
    videoCapturer = nil;
    mediaStream = nil;
}

void FlowNativeMediaStream::retain()
{
    [peerConnectionFactory retain];
    [videoCapturer retain];
    [mediaStream retain];
}

void FlowNativeMediaStream::release()
{
    [peerConnectionFactory release];
    [videoCapturer release];
    [mediaStream release];
}

FlowNativeMediaStream::~FlowNativeMediaStream()
{
}

iosMediaStreamSupport::iosMediaStreamSupport(ByteCodeRunner *runner) : MediaStreamSupport(runner), owner(runner)
{
}

void iosMediaStreamSupport::initializeDeviceInfo(int OnDeviceInfoReadyRoot)
{
    RUNNER_VAR = owner;
    
    AVCaptureDeviceDiscoverySession *videoDevicesSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    videoDevices = videoDevicesSession.devices;
    
    AVCaptureDeviceDiscoverySession *audioDevicesSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    audioDevices = audioDevicesSession.devices;
    
    RUNNER->EvalFunction(RUNNER->LookupRoot(OnDeviceInfoReadyRoot), 0);
}

void iosMediaStreamSupport::getAudioInputDevices(int OnDeviceInfoReadyRoot)
{
    returnDevices(OnDeviceInfoReadyRoot, audioDevices);
}

void iosMediaStreamSupport::getVideoInputDevices(int OnDeviceInfoReadyRoot)
{
    returnDevices(OnDeviceInfoReadyRoot, videoDevices);
}

void iosMediaStreamSupport::returnDevices(int callbackRoot, NSArray<AVCaptureDevice*>  *devices)
{
    RUNNER_VAR = owner;
    StackSlot devicesArray = RUNNER->AllocateArray([devices count]);
    [devices enumerateObjectsUsingBlock:^(AVCaptureDevice *avDevice, NSUInteger idx, BOOL *stop) {
        StackSlot device = RUNNER->AllocateArray(2);
        RUNNER->SetArraySlot(device, 0, RUNNER->AllocateString(NS2UNICODE(avDevice.uniqueID)));
        RUNNER->SetArraySlot(device, 1, RUNNER->AllocateString(NS2UNICODE(avDevice.localizedName)));
        RUNNER->SetArraySlot(devicesArray, idx, device);
    }];
    RUNNER->EvalFunction(RUNNER->LookupRoot(callbackRoot), 1, devicesArray);
}

void iosMediaStreamSupport::makeStream(bool recordAudio, bool recordVideo, unicode_string audioDeviceId, unicode_string videoDeviceId, int onReadyRoot, int onErrorRoot)
{
    RUNNER_VAR = owner;
    
    FlowNativeMediaStream *flowMediaStream = new FlowNativeMediaStream(this);
    flowMediaStream->isLocalStream = true;
    RTCPeerConnectionFactory *peerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
    RTCMediaStream *mediaStream = [peerConnectionFactory mediaStreamWithStreamId:@"LocalStream"];
    
    if (recordAudio) {
        RTCAudioTrack *audioTrack = [peerConnectionFactory audioTrackWithTrackId:@"Audio1"];
        [mediaStream addAudioTrack:audioTrack];
    }
    
    if (recordVideo) {
        RTCVideoSource *videoSource = [peerConnectionFactory videoSource];
        
        RTCCameraVideoCapturer *videoCapturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (!videoDeviceId.empty()) {
            device = [AVCaptureDevice deviceWithUniqueID:UNICODE2NS(videoDeviceId)];
        }
        
        AVCaptureDeviceFormat *format = nil;
        int min_diff = INT_MAX;
        for(AVCaptureDeviceFormat *deviceFormat in [device formats]) {
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions([deviceFormat formatDescription]);
            int diff = (flowMediaStream->width - dimensions.width) * (flowMediaStream->height - dimensions.height);
            if (diff < min_diff) {
                min_diff = diff;
                format = deviceFormat;
            }
        }
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions([format formatDescription]);
        flowMediaStream->width = dimensions.width;
        flowMediaStream->height = dimensions.height;
        
        [videoCapturer startCaptureWithDevice:device format:format fps:20 completionHandler:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error != nil) {
                    RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, RUNNER->AllocateString(NS2UNICODE(error.localizedDescription)));
                } else {
                    RUNNER->EvalFunction(RUNNER->LookupRoot(onReadyRoot), 1, flowMediaStream->getFlowValue());
                }
            });
        }];
        
        RTCVideoTrack *videoTrack = [peerConnectionFactory videoTrackWithSource:videoSource trackId:@"Video1"];
        [mediaStream addVideoTrack:videoTrack];
        flowMediaStream->videoCapturer = videoCapturer;        
    }
    
    flowMediaStream->onReadyRoot = onReadyRoot;
    flowMediaStream->onErrorRoot = onErrorRoot;
    flowMediaStream->peerConnectionFactory = peerConnectionFactory;
    flowMediaStream->mediaStream = mediaStream;
    
    flowMediaStream->retain();
}

void iosMediaStreamSupport::scanStream(StackSlot mediaStream, std::vector<std::string> scanTypes, int onResultRoot) {
    RUNNER_VAR = owner;

    FlowNativeMediaStream *flowMediaStream = RUNNER->GetNative<FlowNativeMediaStream*>(mediaStream);
    AVCaptureSession* session = flowMediaStream->videoCapturer.captureSession;

    AVCaptureMetadataOutput* output = [[AVCaptureMetadataOutput alloc] init];
    if ([session canAddOutput:output]) {
        [session addOutput:output];

        MetadataObjectDelegate* delegate = [[MetadataObjectDelegate alloc] initWithCallback: ^(NSString* data) {
            [session stopRunning];
            dispatch_async(dispatch_get_main_queue(), ^{
                RUNNER_VAR = owner;
                RUNNER->EvalFunction(RUNNER->LookupRoot(onResultRoot), 1, RUNNER->AllocateString(NS2UNICODE(data)));
                [session startRunning];
            });
        }];
        [output setMetadataObjectsDelegate: delegate queue:dispatch_get_main_queue()];

        [output setMetadataObjectTypes:scanTypesToAVMetadataObjectType(scanTypes)];
    }
}

NSArray<AVMetadataObjectType>* iosMediaStreamSupport::scanTypesToAVMetadataObjectType(std::vector<std::string> scanTypes) {
    NSMutableArray<AVMetadataObjectType>* array = [[NSMutableArray alloc] initWithCapacity:scanTypes.size()];
    
    for (std::vector<std::string>::iterator it = scanTypes.begin(); it != scanTypes.end(); it++) {
        AVMetadataObjectType type;
        if (*it == "code39") {
            type = AVMetadataObjectTypeCode39Code;
        } else if (*it == "code29mode43") {
            type = AVMetadataObjectTypeCode39Mod43Code;
        } else if (*it == "ean13") {
            type = AVMetadataObjectTypeEAN13Code;
        } else if (*it == "ean8") {
            type = AVMetadataObjectTypeEAN8Code;
        } else if (*it == "code93") {
            type = AVMetadataObjectTypeCode93Code;
        } else if (*it == "code128") {
            type = AVMetadataObjectTypeCode128Code;
        } else if (*it == "pdf417") {
            type = AVMetadataObjectTypePDF417Code;
        } else if (*it == "aztek") {
            type = AVMetadataObjectTypeAztecCode;
        } else if (*it == "interleaved2of5") {
            type = AVMetadataObjectTypeInterleaved2of5Code;
        } else if (*it == "itf14") {
            type = AVMetadataObjectTypeITF14Code;
        } else if (*it == "datamatrix") {
            type = AVMetadataObjectTypeDataMatrixCode;
        } else {
            type = AVMetadataObjectTypeQRCode;
        }
        [array addObject:type];
    }
    
    return array;
}

void iosMediaStreamSupport::stopStream(StackSlot mediaStream)
{
    RUNNER_VAR = owner;
    FlowNativeMediaStream *flowMediaStream = RUNNER->GetNative<FlowNativeMediaStream*>(mediaStream);
    [flowMediaStream->videoCapturer stopCaptureWithCompletionHandler:^() {
        RUNNER_VAR = owner;
        RUNNER->ReleaseRoot(flowMediaStream->onReadyRoot);
        RUNNER->ReleaseRoot(flowMediaStream->onErrorRoot);
        
        flowMediaStream->release();
    }];
}

#endif /* FLOW_MEDIASTREAM */
