//
//  CDVMheSound.m
//  MHEMediaRebuild
//
//  Created by Rony on 22/03/2016.
//
//

#import "CDVMHESound.h"
#import "DCPAWSCredentialsProvider.h"
#import <AWSS3/AWSS3.h>
#import <AWSCore/AWSCore.h>

#define RECORDING_WAV @"wav"
#define RECORDING_M4A @"m4a"

@implementation CDVMHESound {
AWSS3TransferManager *transferManager;
AWSS3TransferManagerUploadRequest *uploadRequest;
NSDictionary *args;
NSURL *pathUrl;
NSString *strPercent;
NSString *callbackFunction;
NSMutableArray *recordingArray;
BOOL uploadInProgress;
BOOL isStillRecordingAudio;
}

- (void)create:(CDVInvokedUrlCommand*)command {
    [super create:command];
}

-(void)getVersion:(CDVInvokedUrlCommand*)command {
    NSString *versionNumber = @"2.0.0";
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_OK messageAsString:versionNumber];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSURL*)urlForRecording:(NSString*)resourcePath {
    NSString* tempPath = [[resourcePath stringByDeletingPathExtension] stringByAppendingPathExtension:RECORDING_WAV];
    NSURL* tempURL = [super urlForRecording:tempPath];
    NSString* tempAbsURL = [tempURL absoluteString];
    NSString* absURL = [[tempAbsURL stringByDeletingPathExtension] stringByAppendingPathExtension:RECORDING_M4A];
    return [NSURL URLWithString:absURL];
}

- (void)startRecordingAudio:(CDVInvokedUrlCommand*)command {
    NSString* callbackId = command.callbackId;
    #pragma unused(callbackId)
    
    NSString* mediaId = [command argumentAtIndex:0];
    CDVAudioFile* audioFile = [super audioFileForResource:[command argumentAtIndex:1] withId:mediaId doValidation:YES forRecording:YES];
    __block NSString* jsString = nil;
    __block NSString* errorMsg = @"";
    
    if ((audioFile != nil) && (audioFile.resourceURL != nil)) {
        void (^startRecording)(void) = ^{
            NSError* __autoreleasing error = nil;
            
        if (audioFile.recorder != nil) {
            [audioFile.recorder stop];
            audioFile.recorder = nil;
        }
        // get the audioSession and set the category to allow recording when device is locked or ring/silent switch engaged
        if ([self hasAudioSession]) {
            if (![self.avSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
                [self.avSession setCategory:AVAudioSessionCategoryRecord error:nil];
            }
            if (![self.avSession setActive:YES error:&error]) {
                // other audio with higher priority that does not allow mixing could cause this to fail
                errorMsg = [NSString stringWithFormat:@"Unable to record audio: %@", [error localizedFailureReason]];
                jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('cordova-plugin-MHEMedia.MHEMedia').onStatus", mediaId, MEDIA_ERROR, [self createMediaErrorWithCode:MEDIA_ERR_ABORTED message:errorMsg]];
                [self.commandDelegate evalJs:jsString];
                return;
            }
        }
            // Set the audio file
            NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:kAudioFormatMPEG4AAC],  AVFormatIDKey,
            [NSNumber numberWithFloat:44100],               AVSampleRateKey,
            [NSNumber numberWithInt:1],                     AVNumberOfChannelsKey,
            [NSNumber numberWithInt:64000],                 AVEncoderBitRateKey,
            nil];
            // create a new recorder for each start record.
            audioFile.recorder = [[CDVAudioRecorder alloc] initWithURL:audioFile.resourceURL settings:recordSettings error:&error];
            
            bool recordingSuccess = NO;
            if (error == nil) {
                audioFile.recorder.delegate = self;
                audioFile.recorder.mediaId = mediaId;
                recordingSuccess = [audioFile.recorder record];
                if (recordingSuccess) {
                    NSLog(@"the array contains : %@",command.arguments);
                    NSLog(@"Started recording audio sample '%@'", audioFile.resourcePath);
                    NSLog(@"file path is : %@",audioFile.resourceURL);
                    isStillRecordingAudio = YES;
                    jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%d);", @"cordova-plugin-MHEMedia.MHEMedia').onStatus", mediaId, MEDIA_STATE, MEDIA_RUNNING];
                    [self.commandDelegate evalJs:jsString];
                    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
                }
            }
            
            if ((error != nil) || (recordingSuccess == NO)) {
                if (error != nil) {
                    errorMsg = [NSString stringWithFormat:@"Failed to initialize AVAudioRecorder: %@\n", [error localizedFailureReason]];
                } else {
                    errorMsg = @"Failed to start recording using AVAudioRecorder";
                }
                audioFile.recorder = nil;
                if (self.avSession) {
                    [self.avSession setActive:NO error:nil];
                }
                jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('cordova-plugin-MHEMedia.MHEMedia').onStatus", mediaId, MEDIA_ERROR, [self createMediaErrorWithCode:MEDIA_ERR_ABORTED message:errorMsg]];
                [self.commandDelegate evalJs:jsString];
            }
        };
        
        SEL rrpSel = NSSelectorFromString(@"requestRecordPermission:");
        if ([self hasAudioSession] && [self.avSession respondsToSelector:rrpSel])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.avSession performSelector:rrpSel withObject:^(BOOL granted){
                if (granted) {
                    startRecording();
                } else {
                    NSString* msg = @"Error creating audio session, microphone permission denied.";
                    NSLog(@"%@", msg);
                    audioFile.recorder = nil;
                    if (self.avSession) {
                        [self.avSession setActive:NO error:nil];
                    }
                    jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('cordova-plugin-MHEMedia.MHEMedia').onStatus", mediaId, MEDIA_ERROR, [self createMediaErrorWithCode:MEDIA_ERR_ABORTED message:msg]];
                    [self.commandDelegate evalJs:jsString];
                }
            }];
#pragma clang diagnostic pop
        } else {
            startRecording();
        }
        
    } else {
        // file did not validate
        NSString* errorMsg = [NSString stringWithFormat:@"Could not record audio at '%@'", audioFile.resourcePath];
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('cordova-plugin-MHEMedia.MHEMedia').onStatus", mediaId, MEDIA_ERROR, [self createMediaErrorWithCode:MEDIA_ERR_ABORTED message:errorMsg]];
        [self.commandDelegate evalJs:jsString];
    }
}

- (void)stopRecordingAudio:(CDVInvokedUrlCommand*)command {
    NSString* mediaId = [command argumentAtIndex:0];
    
    CDVAudioFile* audioFile = [[self soundCache] objectForKey:mediaId];
    NSString* jsString = nil;
    
    if ((audioFile != nil) && (audioFile.recorder != nil)) {
        NSLog(@"Stopped recording audio sample '%@'", audioFile.resourcePath);
        [audioFile.recorder stop];
        // no callback - that will happen in audioRecorderDidFinishRecording
    }
    // ignore if no media recording
    if (jsString) {
        [self.commandDelegate evalJs:jsString];
    }
    // Allow the avSession to start playback
    [self.avSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    if(!uploadInProgress)
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    isStillRecordingAudio = NO;
}

-(void)startPlayingAudio:(CDVInvokedUrlCommand *)command {
    [super startPlayingAudio:command];
}

-(void)stopPlayingAudio:(CDVInvokedUrlCommand *)command {
    [super stopPlayingAudio:command];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)flag
{
    CDVAudioPlayer* aPlayer = (CDVAudioPlayer*)player;
    NSString* mediaId = aPlayer.mediaId;
    CDVAudioFile* audioFile = [[self soundCache] objectForKey:mediaId];
    NSString* jsString = nil;
    
    if (audioFile != nil) {
        NSLog(@"Finished playing audio sample '%@'", audioFile.resourcePath);
    }
    if (flag) {
        audioFile.player.currentTime = 0;
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%d);", @"cordova.require('cordova-plugin-MHEMedia.MHEMedia').onStatus", mediaId, MEDIA_STATE, MEDIA_STOPPED];
    } else {
        jsString = [NSString stringWithFormat:@"%@(\"%@\",%d,%@);", @"cordova.require('cordova-plugin-MHEMedia.MHEMedia').onStatus", mediaId, MEDIA_ERROR, [self createMediaErrorWithCode:MEDIA_ERR_DECODE message:nil]];
    }
    if (self.avSession) {
        [self.avSession setActive:NO error:nil];
    }
    [self.commandDelegate evalJs:jsString];
}

- (void)release:(CDVInvokedUrlCommand*)command {
    NSString* mediaId = [command argumentAtIndex:0];
    if (mediaId != nil) {
        CDVAudioFile* audioFile = [[self soundCache] objectForKey:mediaId];
        if (audioFile != nil) {
            if (audioFile.player && [audioFile.player isPlaying]) {
                [audioFile.player stop];
            }
            if (audioFile.recorder && [audioFile.recorder isRecording]) {
                [audioFile.recorder stop];
            }
            if (self.avSession) {
                [self.avSession setActive:NO error:nil];
                self.avSession = nil;
            }
            [[self soundCache] removeObjectForKey:mediaId];
            NSLog(@"Media with id %@ released", mediaId);
        }
    }
}

- (void) upload:(CDVInvokedUrlCommand *)command {
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [self.commandDelegate runInBackground:^{
        if(uploadInProgress) {
            if(!recordingArray)
                recordingArray = [[NSMutableArray alloc]init];
            [recordingArray addObject:command];
        }else {
            [self performUpload:command];
        }
    }];
}

-(void)performUpload:(CDVInvokedUrlCommand *)command {
    @try
    {
        uploadInProgress = true;
        callbackFunction = command.callbackId;
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(pauseUpload) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(resumeUpload) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        // Enable AWS SDK Logging here:
        //[AWSLogger defaultLogger].logLevel = AWSLogLevelVerbose;
        NSString* mediaId = [command argumentAtIndex:0];
        NSString* resourcePath = [command argumentAtIndex:1];
        CDVAudioFile* audioFile = [self audioFileForResource:resourcePath withId:mediaId doValidation:YES forRecording:NO];
        args = [command.arguments objectAtIndex:2];
        pathUrl = audioFile.resourceURL;
        
        // Configure Transfer Manager
        AWSRegionType regionType = [self getRegionFromString:[args valueForKeyPath:@"token.identifier.region"]];
        
        DCPAWSCredentialsProvider *credentialsProvider = [DCPAWSCredentialsProvider credentialsWithAccessKey:
          [args valueForKeyPath:@"token.accessToken.accessKey"]
           secretKey:[args valueForKeyPath:@"token.accessToken.secretKey"]
          sessionKey:[args valueForKeyPath:@"token.accessToken.sessionToken"]];
        
        AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:regionType
                                                                             credentialsProvider:credentialsProvider];
        
        [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
        
        NSString* transferId = [args valueForKey:@"id"];
        [AWSS3TransferManager registerS3TransferManagerWithConfiguration:configuration
                                                                  forKey:transferId];
        
        transferManager = [AWSS3TransferManager S3TransferManagerForKey:transferId];
        
        long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[audioFile.resourceURL absoluteString] error:nil][NSFileSize] longLongValue];
        
        uploadRequest = [AWSS3TransferManagerUploadRequest new];
        
        NSString *keyStr = [NSString stringWithFormat:@"%@.%@",[args valueForKeyPath:@"token.identifier.keyPrefix"],[[audioFile.resourceURL absoluteString]pathExtension]];
        
        NSLog(@"key str is  =  %@",keyStr);
        uploadRequest.bucket = [args valueForKeyPath:@"token.identifier.container"];
        uploadRequest.key = keyStr;
        //          uploadRequest.body = pathUrl;
        uploadRequest.body = audioFile.resourceURL;
        
        
        uploadRequest.contentLength = [NSNumber numberWithUnsignedLongLong:fileSize];
        NSLog(@"Upload request params are : %@ , %@ , %@ , %@",uploadRequest.bucket,uploadRequest.key,uploadRequest.body,uploadRequest.contentLength);
        uploadRequest.uploadProgress = [self getUploadUpdateProgressBlock];
        
        // Start upload
        [[transferManager upload:uploadRequest] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                           withBlock:[self getUploadCompletionBlock:command.callbackId]];
    }
    @catch (NSException *exception)
    {
        // Print exception information
        NSLog( @"NSException caught" );
        NSLog( @"Name: %@", exception.name);
        NSLog( @"Reason: %@", exception.reason );
        
        NSDictionary *jsonObj = @{ @"event"   : @"upload",
                                   @"success"     : @"false"};
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_ERROR
                                                      messageAsDictionary : jsonObj];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    } // catch end
    
}

#pragma mark - Helper Methods

- (AWSRegionType)getRegionFromString: (NSString *)regionName
{
    AWSRegionType regionType = AWSRegionUnknown;
    
    if ([regionName isEqualToString:@"us-east-1"])
        regionType = AWSRegionUSEast1;
    else if ([regionName isEqualToString:@"us-west-1"])
        regionType = AWSRegionUSWest1;
    else if ([regionName isEqualToString:@"us-west-2"])
        regionType = AWSRegionUSWest2;
    else if ([regionName isEqualToString:@"us-east-1"])
        regionType = AWSRegionEUWest1;
    else if ([regionName isEqualToString:@"eu-central-1"])
        regionType = AWSRegionEUCentral1;
    else if ([regionName isEqualToString:@"ap-southeast-1"])
        regionType = AWSRegionAPSoutheast1;
    else if ([regionName isEqualToString:@"ap-northeast-1"])
        regionType = AWSRegionAPNortheast1;
    else if ([regionName isEqualToString:@"ap-southeast-2"])
        regionType = AWSRegionAPSoutheast2;
    else if ([regionName isEqualToString:@"sa-east-1"])
        regionType = AWSRegionSAEast1;
    else if ([regionName isEqualToString:@"cn-north-1"])
        regionType = AWSRegionCNNorth1;
    
    return regionType;
}

-(NSString *)getJSONFromDictionary:(NSDictionary *)dict
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (jsonData)
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    else
        return nil;
}

#pragma mark - Blocks

-(AWSNetworkingUploadProgressBlock)getUploadUpdateProgressBlock {
    return ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend){
        dispatch_async(dispatch_get_main_queue(), ^{
            float uploadPercent = (float)totalBytesSent / (float)totalBytesExpectedToSend;
            NSLog(@"TransferManager: totalBytesExpectedToSend: %lld, bytes sent: %lld, totalBytesSent: %lld, completed: %.2f%%", totalBytesExpectedToSend, bytesSent, totalBytesSent, uploadPercent*100);
            
            NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *responseParams = [[NSMutableDictionary alloc] init];
            
            [response setObject:@"progress" forKey:@"event"];
            [response setObject:responseParams forKey:@"params"];
            
            NSString *uploadProgressPercentsString = [NSString stringWithFormat:@"%.2f",uploadPercent*100];
            
            [responseParams setObject:uploadProgressPercentsString forKey:@"progress"];
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus   : CDVCommandStatus_OK
                                                            messageAsDictionary : response];
            
            pluginResult.keepCallback = [NSNumber numberWithInt:1]; // That will tell it to keep the callback valid for future use.****
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackFunction];
            
        });
    };
    
    return nil;
}

-(BFContinuationBlock)getUploadCompletionBlock:(NSString *)callback {
    return ^id(BFTask *task) {
        
        if (task.error) {
            NSString *errorMessage;
            
            errorMessage = [NSString stringWithFormat:@"Error in uploading to S3: %@", task.error];
            if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]) {
                switch (task.error.code) {
                    case AWSS3TransferManagerErrorCancelled:
                        errorMessage = [NSString stringWithFormat:@"AWSS3TransferManagerErrorCancelled: %@", task.error];
                        break;
                    case AWSS3TransferManagerErrorPaused:
                        break;
                        errorMessage = [NSString stringWithFormat:@"AWSS3TransferManagerErrorPaused: %@", task.error];
                    default:
                        errorMessage = [NSString stringWithFormat:@"AWS S3 Transfer Manager Error: %@", task.error];
                        break;
                }
            } else if ([task.error.domain isEqualToString:AWSS3ErrorDomain])
            {
                errorMessage = [NSString stringWithFormat:@"AWS S3 Error: %@", task.error];
            } else {
                // Unknown error.
                errorMessage = [NSString stringWithFormat:@"Upload Uknown Error: %@", task.error];
            }
            
            NSLog(@"%@", errorMessage);
            
            NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *responseParams = [[NSMutableDictionary alloc] init];
            
            [response setObject:@"upload" forKey:@"event"];
            [response setObject:responseParams forKey:@"params"];
            
            [responseParams setObject:@"false" forKey:@"success"];
            [responseParams setObject:errorMessage forKey:@"error"];
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_ERROR
                                                          messageAsDictionary : response];
            
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callback];
        }
        
        if (task.result) {
            
            NSLog(@"Upload completed for file:%@", [pathUrl absoluteString]);
            
            NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *responseParams = [[NSMutableDictionary alloc] init];
            
            [response setObject:@"upload" forKey:@"event"];
            [response setObject:responseParams forKey:@"params"];
            
            [responseParams setObject:@"true" forKey:@"success"];
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_OK
                                                          messageAsDictionary : response];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackFunction];
            
        }
        
        NSString* transferId = [args valueForKey:@"id"];
        [AWSS3TransferManager removeS3TransferManagerForKey:transferId];
        transferManager = nil;
        pathUrl = nil;
        uploadInProgress = false;
        
        if(recordingArray.lastObject != nil) {
            CDVInvokedUrlCommand *temp = recordingArray.lastObject;
            [recordingArray removeLastObject];
            [self performUpload:temp];
            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        }else if(recordingArray.lastObject == nil && !isStillRecordingAudio) {
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
        }else {
            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        }
        
        return nil;
    };
}

#pragma mark Hnadle Upload Pause/Resume

-(void)resumeUpload:(AWSS3TransferManagerUploadRequest *)pausedUploadRequest {
    pausedUploadRequest.uploadProgress = [self getUploadUpdateProgressBlock];
    [[transferManager upload:pausedUploadRequest] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                             withBlock:[self getUploadCompletionBlock:callbackFunction]];
}

-(void)pauseUpload {
    // [uploadRequest pause];
    NSLog(@"upload Paused");
}

-(void)resumeUpload {
    // [self resumeUpload:uploadRequest];
    NSLog(@"upload Resumed");
}

@end
