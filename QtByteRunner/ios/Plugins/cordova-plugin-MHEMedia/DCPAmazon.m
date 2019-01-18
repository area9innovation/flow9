//
//  DCPAmazon.m
//  DCPAmazon
//
//  Created by Marat Strelets on 2015-04-22.
//
//

#import "DCPAmazon.h"
#import "DCPAWSCredentialsProvider.h"

#import <AWSS3/AWSS3.h>
#import <AWSCore/AWSCore.h>

@implementation DCPAmazon {
    AWSS3TransferManager *transferManager;
    AWSS3TransferManagerUploadRequest *uploadRequest;

    NSDictionary *args;
}

- (void) cordovaUploadFile:(CDVInvokedUrlCommand *)command {

    [self.commandDelegate runInBackground:^{

        @try
        {
            // Enable AWS SDK Logging here:
            //[AWSLogger defaultLogger].logLevel = AWSLogLevelVerbose;

            // Prepare a dictionary from args
            args = @{@"sourceFile"                  : [command.arguments objectAtIndex:0],
                    @"regionName"                   : [command.arguments objectAtIndex:1],
                    @"bucketName"                   : [command.arguments objectAtIndex:2],
                    @"destinationFilePath"          : [command.arguments objectAtIndex:3],
                    @"destinationFileNamePrefix"    : [command.arguments objectAtIndex:4],
                    @"accessKey"                    : [command.arguments objectAtIndex:5],
                    @"secretKey"                    : [command.arguments objectAtIndex:6],
                    @"sessionToken"                 : [command.arguments objectAtIndex:7],
                    @"deleteFileAfterUpload"        : [command.arguments objectAtIndex:8],
                    @"progressUpdateFunctionName"       : [command.arguments objectAtIndex:9]};

            NSLog(@"cordovaUploadFile args: %@", [self getJSONFromDictionary:args]);

            // Configure Transfer Manager
            AWSRegionType regionType = [self getRegionFromString:args[@"regionName"]];

            DCPAWSCredentialsProvider *credentialsProvider = [DCPAWSCredentialsProvider credentialsWithAccessKey:args[@"accessKey"]
                                                                                                       secretKey:args[@"secretKey"]
                                                                                                      sessionKey:args[@"sessionToken"]];

            AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:regionType
                                                                                 credentialsProvider:credentialsProvider];

            [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
            transferManager = [AWSS3TransferManager defaultS3TransferManager];

            // Start upload
            long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:args[@"sourceFile"] error:nil][NSFileSize] longLongValue];

            uploadRequest = [AWSS3TransferManagerUploadRequest new];

            NSString *keyString = [NSString stringWithFormat:@"%@%@.%@",
                                   args[@"destinationFilePath"],
                                   args[@"destinationFileNamePrefix"],
                                   [args[@"sourceFile"] pathExtension]];

            uploadRequest.bucket = args[@"bucketName"];
            uploadRequest.key = keyString;
            uploadRequest.body = [NSURL URLWithString:args[@"sourceFile"]];
            uploadRequest.contentLength = [NSNumber numberWithUnsignedLongLong:fileSize];

            uploadRequest.uploadProgress = [self getUploadUpdateProgressBlock];

            // Start upload
            [[transferManager upload:uploadRequest] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                               withBlock:[self getUploadCompletionBlock:command.callbackId]];
        } @catch (NSException *exception) {
            
            // Print exception information
            NSLog( @"NSException caught" );
            NSLog( @"Name: %@", exception.name);
            NSLog( @"Reason: %@", exception.reason );

            NSDictionary *jsonObj = @{ @"success"   : @"false",
                                       @"error"     : exception.reason};
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_ERROR
                                                          messageAsDictionary : jsonObj];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

            return;
        } // catch end
    }]; // runInBackground block end
} // cordovaUploadFile end

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

            NSString *progressUpdateFunctionName = args[@"progressUpdateFunctionName"];
            NSString *jsProgressUpdateInvokeString = [NSString stringWithFormat:@"%@('%lld', '%lld', '%lld', '%.2f%%');",
                                                      progressUpdateFunctionName,
                                                      totalBytesExpectedToSend,
                                                      bytesSent,
                                                      totalBytesSent,
                                                      uploadPercent*100];

            NSLog(@"Exec JS function: %@", jsProgressUpdateInvokeString);

            [(UIWebView*)self.webView stringByEvaluatingJavaScriptFromString:jsProgressUpdateInvokeString];

        });
    };

    return nil;
}

-(BFContinuationBlock)getUploadCompletionBlock:(NSString *)callbackId {
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

            NSDictionary *jsonObj = @{ @"success"   : @"false",
                                       @"error"     : task.error.localizedDescription};

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_ERROR
                                                          messageAsDictionary : jsonObj];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }

        if (task.result) {

            if ([args[@"deleteFileAfterUpload"] isEqualToString:@"true"])
            {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                [fileManager removeItemAtPath:[args[@"sourceFile"] absoluteString] error:nil];
            }


            NSDictionary *jsonObj = @{ @"success" : @"true" };
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_OK
                                                          messageAsDictionary : jsonObj];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }


        return nil;
    };
}

@end
