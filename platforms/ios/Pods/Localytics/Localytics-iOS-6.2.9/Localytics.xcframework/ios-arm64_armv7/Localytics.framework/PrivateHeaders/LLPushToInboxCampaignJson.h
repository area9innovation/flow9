#import <Foundation/Foundation.h>

@class LLApsDictionary;
@class LLMarketingLogger;
@protocol LLLocalyticsDelegate;

@interface LLPushToInboxCampaignJson : NSObject

@property (nonatomic, copy, readonly, nonnull) NSDictionary *attributes;
@property (nonatomic, copy, readonly, nonnull) NSDictionary<NSString *, id> *markerDictionary;

- (nonnull NSDictionary<NSString *, NSObject *> *)generateLoggingDictionary;

+ (nullable instancetype)withPayload:(nonnull NSDictionary *)payload
                       apsDictionary:(nonnull LLApsDictionary *)apsDictionary
                              logger:(nonnull LLMarketingLogger *)logger
                  localyticsDelegate:(nonnull id<LLLocalyticsDelegate>)localyticsDelegate;

- (nullable instancetype)initWithPayload:(nonnull NSDictionary *)payload
                           apsDictionary:(nonnull LLApsDictionary *)apsDictionary
                                  logger:(nonnull LLMarketingLogger *)logger
                      localyticsDelegate:(nonnull id<LLLocalyticsDelegate>)localyticsDelegate;

@end
