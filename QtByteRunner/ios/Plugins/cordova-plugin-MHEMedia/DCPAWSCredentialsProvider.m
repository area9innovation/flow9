//
//  DCPAWSCredentialsProvider.m
//  S3UploadDemo
//
//  Created by Marat Strelets on 2015-04-23.
//
//

#import "DCPAWSCredentialsProvider.h"

@implementation DCPAWSCredentialsProvider

+ (instancetype)credentialsWithAccessKey:(NSString *)accessKey
                               secretKey:(NSString *)secretKey
                              sessionKey:(NSString *)sessionKey {
    
    DCPAWSCredentialsProvider *credentials = [[DCPAWSCredentialsProvider alloc] initWithAccessKey:accessKey
                                                                                        secretKey:secretKey
                                                                                       sessionKey:sessionKey];
    return credentials;
}

- (instancetype)initWithAccessKey:(NSString *)accessKey
                        secretKey:(NSString *)secretKey
                       sessionKey:(NSString *)sessionKey {
    
    if (self = [super init]) {
        _accessKey = accessKey;
        _secretKey = secretKey;
        _sessionKey = sessionKey;
    }
    return self;
}

- (BFTask *)refresh {
    
    NSLog(@"Credentials expired, but can not be refreshed.");
    return [BFTask taskWithResult:nil];
}

@end
