//
//  DCPAWSCredentialsProvider.h
//  S3UploadDemo
//
//  Created by Marat Strelets on 2015-04-23.
//
//

#import <Foundation/Foundation.h>
#import <AWSCore/AWSCredentialsProvider.h>
#import <Bolts/BFTask.h>

@interface DCPAWSCredentialsProvider : NSObject<AWSCredentialsProvider>

@property (nonatomic, strong, readonly) NSString    *accessKey;
@property (nonatomic, strong, readonly) NSString    *secretKey;
@property (nonatomic, strong, readonly) NSString    *sessionKey;
@property (nonatomic, strong, readonly) NSDate      *expiration;
@property (nonatomic, strong)           NSString    *recordingGUID;

+ (instancetype)credentialsWithAccessKey:(NSString *)accessKey
                               secretKey:(NSString *)secretKey
                              sessionKey:(NSString *)sessionKey;

- (BFTask *)refresh;

@end
