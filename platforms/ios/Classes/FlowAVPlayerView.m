#import "FlowAVPlayerView.h"
#import "utils.h"
#import <mach/mach_time.h>

#import <AVFoundation/AVFoundation.h>

#define VIDEO_FPS 48

@interface CustomAssetResourceLoaderDelegate : NSObject <AVAssetResourceLoaderDelegate>
@property (nonatomic, strong) NSDictionary *headers;
@end

@implementation CustomAssetResourceLoaderDelegate

- (instancetype)initWithHeaders:(NSDictionary *)headers {
    self = [super init];
    if (self) {
        _headers = headers;
    }
    return self;
}

// Intercept and modify the URL loading request
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSMutableURLRequest *newRequest = [loadingRequest.request mutableCopy];

    // Add custom headers
    for (NSString *key in self.headers) {
        [newRequest setValue:self.headers[key] forHTTPHeaderField:key];
    }

    // Perform the modified request
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:newRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && response) {
            loadingRequest.response = response;
            [loadingRequest.dataRequest respondWithData:data];
            [loadingRequest finishLoading];
        } else {
            [loadingRequest finishLoadingWithError:error];
        }
    }];
    
    [task resume];
    return YES;
}

@end

@implementation FlowAVPlayerView

@synthesize looping;

static BOOL UseOpenGLVideo = NO;
+ (void) initialize {
    UseOpenGLVideo = [[NSUserDefaults standardUserDefaults] boolForKey:@"opengl_video"];
    LogI(@"UseOpenGLVideo = %d", UseOpenGLVideo);
}

+ (BOOL) useOpenGLVideo {
    return UseOpenGLVideo;
}

- (void) updateSubtitle: (NSString *) subtitle {

}

- (void) dealloc {
    if (self.playerItem != nil) {
        [self.player removeTimeObserver: self.timeObserver];
    
        if (self.playerItem.outputs[0] != nil)
            [self.playerItem removeOutput:[self.playerItem.outputs[0] autorelease]];
    
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
    
        [self.playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [self.playerItem removeObserver:self forKeyPath:@"status"];
    
        [self.playerItem release];
    }
    
    [super dealloc];
}

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayer*) player {
    return ((AVPlayerLayer *)self.layer).player;
}

- (void) setPlayer:(AVPlayer *)player {
    ((AVPlayerLayer *)self.layer).player = player;
}

- (void) initTapGesture {
    //The setup code (in viewDidLoad in your view controller)
    UITapGestureRecognizer *singleFingerTap =
        [[UITapGestureRecognizer alloc] initWithTarget: self
                                            action: @selector(handleSingleTap:)];
    [self addGestureRecognizer: singleFingerTap];
    [singleFingerTap release];
}

- (void) playVideo {
    [self.player play];
    if (![self isPlaying])
        self.OnUserResume();
    self.playing = YES;
}

- (void) pauseVideo {
    [self.player pause];
    if ([self isPlaying])
        self.OnUserPause();
    self.playing = NO;
}

- (void) seekTo: (int64_t)offset {
    int32_t timeScale = self.playerItem.asset.duration.timescale;
    CMTime time = CMTimeMakeWithSeconds(offset / 1000, timeScale);
    
    [self.playerItem cancelPendingSeeks];
    [self.playerItem seekToTime: time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (finished && self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
            [self renderFrame:time];
            self.OnFrame(time);
        }
    }];
}

- (void) setVolume: (float) volume {
    [self.player setVolume:volume];
}

- (void) setRate: (float) rate {
    [self.player setRate:rate];
}

- (BOOL) isPlaying {
    return self.playing;
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if ([self isPlaying]) {
        self.OnUserPause();
        [self pauseVideo];
    } else {
        self.OnUserResume();
        [self playVideo];
    }
}

// TO DO : move to controller

- (void) loadVideo: (NSURL*) videoUrl withHeaders: (NSDictionary*) headers onResolutionReceived: (void (^)(float width, float height)) on_resolution_received
        onSuccess: (void (^)(float duration)) on_success
        onError: (void (^)()) on_error onFrameReady: (void (^)(CMTime)) on_frame {
    self.OnFrame = on_frame;
    self.OnSuccess = on_success;
    self.OnResolutionReceived = on_resolution_received;
    self.OnError = on_error;
    
    __block FlowAVPlayerView* blockSelf = self;
    
    CustomAssetResourceLoaderDelegate *resourceLoaderDelegate = [[CustomAssetResourceLoaderDelegate alloc] initWithHeaders:headers];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL: videoUrl options: nil];
    [asset.resourceLoader setDelegate:resourceLoaderDelegate queue:dispatch_get_main_queue()];
    NSString *tracksKey = @"tracks";
    
    AVAssetImageGenerator* imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    [imageGenerator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:CMTimeMake(0, 1)]] completionHandler:^(CMTime requestedTime, CGImageRef _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        if (image != nil) {
            CGImageRef image_copy = CGImageCreateCopy(image);
            RUN_IN_MAIN_THREAD(^void{
                blockSelf.OnResolutionReceived(asset.naturalSize.width,  asset.naturalSize.height);
                blockSelf.OnResolutionReceived = ^(float width, float height) {};
                [blockSelf renderFrameImage:image_copy];
                blockSelf.OnFrame(CMTimeMake(0, 1));
                CGImageRelease(image_copy);
            });
        }
    }];
    
    [asset loadValuesAsynchronouslyForKeys: @[tracksKey] completionHandler:
     ^{
         RUN_IN_MAIN_THREAD(^void{
             NSError *error;
             AVKeyValueStatus status = [asset statusOfValueForKey: tracksKey error: &error];
             
             if (status == AVKeyValueStatusLoaded) {
                 blockSelf.playerItem = [AVPlayerItem playerItemWithAsset: asset];
                 [blockSelf.playerItem addObserver:blockSelf forKeyPath:@"status" options: NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
                 [blockSelf.playerItem addObserver:blockSelf forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
                     
                 [[NSNotificationCenter defaultCenter] addObserver: blockSelf
                                                          selector:@selector(playerItemDidReachEnd:)
                                                              name: AVPlayerItemDidPlayToEndTimeNotification
                                                            object: blockSelf.playerItem];
                 
                 if (UseOpenGLVideo) {
                     blockSelf.player = [AVPlayer playerWithPlayerItem: blockSelf.playerItem];
                    
                     blockSelf.timeObserver = [blockSelf.player addPeriodicTimeObserverForInterval: CMTimeMake(1, VIDEO_FPS) queue: NULL
                                                                              usingBlock: ^void(CMTime time) {
                                                                                  if (blockSelf != nil && [blockSelf.playerItem status] == AVPlayerItemStatusReadyToPlay) {
                                                                                      [blockSelf renderFrame: time];
                                                                                      on_frame(time);
                                                                                  }
                                                                              }];
                     
                    CoreImageContext = [[CIContext contextWithOptions: nil] retain];
                } else {
                    blockSelf.player = [AVPlayer playerWithPlayerItem: blockSelf.playerItem];
                    [blockSelf initTapGesture];
                }
            } else {
                on_error();
                LogE(@"Video asset's tracks were not loaded:\n%@", [error localizedDescription]);
            }
        });
     }];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if ([self isPlaying] && CMTimeGetSeconds(self.playerItem.duration) != CMTimeGetSeconds(self.playerItem.currentTime))
            [self playVideo];
        else if (![self isPlaying] && CMTimeGetSeconds(self.playerItem.currentTime) == 0.0) {
            [self renderFrame: self.playerItem.currentTime]; // Render the first frame even if paused.
            // Call onFrameReady function
            if (self.OnFrame != nil)
                self.OnFrame(self.playerItem.currentTime);
        }
    } else if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = AVPlayerItemStatusUnknown;
        // Get the status change from the change dictionary
        NSNumber *statusNumber = change[NSKeyValueChangeNewKey];
        if ([statusNumber isKindOfClass:[NSNumber class]]) {
            status = (AVPlayerItemStatus)statusNumber.integerValue;
        }
        
        switch (status) {
            case AVPlayerItemStatusReadyToPlay: {
                __block FlowAVPlayerView *blockSelf = self;
                
                RUN_IN_MAIN_THREAD(^void() {
                    if (UseOpenGLVideo && [[blockSelf.playerItem outputs] count] == 0) {
                        NSDictionary* settings = @{ (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32RGBA] };
                    
                        [blockSelf.playerItem addOutput: [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:settings]];
                    }
                    
                    AVAsset *asset = blockSelf.playerItem.asset;
                    
                    blockSelf.OnResolutionReceived(asset.naturalSize.width, asset.naturalSize.height);
                    blockSelf.OnSuccess(CMTimeGetSeconds(asset.duration));
                    // Make an empty function here to call OnSuccess and OnResolutionReceived only once
                    blockSelf.OnResolutionReceived = ^(float width, float height) {};
                    blockSelf.OnSuccess = ^(float duration) {};
                });
                
                break;
            }
            case AVPlayerItemStatusFailed: {
                self.OnError();
                LogE(@"Video player failed with message: %@", [[self.playerItem error] localizedDescription]);
                break;
            }
            case AVPlayerItemStatusUnknown: {
                break;
            }
        }
    }
}

- (void) playerItemDidReachEnd: (NSNotification *)notification {
    self.OnPlayEnd();
    
    if (self.looping) {
        [self seekTo: 0];
        [self playVideo];
    } else {
        [self pauseVideo];
    }
}

- (void) renderFrame: (CMTime) cur_time {
    if ([self.playerItem.outputs count] != 1 ||
        self.playerItem.outputs[0] == nil ||
        RenderingContext == nil) return;
    
    // TO DO : can be optimised with CVOpenGLESTextureCache
    @autoreleasepool {
        AVPlayerItemVideoOutput * output = (AVPlayerItemVideoOutput*)self.playerItem.outputs[0];
        CVPixelBufferRef buffer = [output copyPixelBufferForItemTime: cur_time itemTimeForDisplay: nil];
        
        if (buffer != nil) {
            CGRect rect = {{0,0},{(CGFloat)CVPixelBufferGetWidth(buffer), (CGFloat)CVPixelBufferGetHeight(buffer)}};
            CIImage * cii = [CIImage imageWithCVPixelBuffer: buffer]; // NOTE: Not supported on simulator
            CGImageRef cgi = [CoreImageContext createCGImage: cii fromRect: rect];
            if (cgi != nil) {
                [self renderFrameImage:cgi];
                CGImageRelease(cgi);
            }
            
            CVBufferRelease(buffer);
        }
    }
}
@end
