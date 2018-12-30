#import <Foundation/Foundation.h>

@class LLApsDictionary;
@protocol LLLocalyticsDelegate;

@interface LLPushToInboxCampaignJson : NSObject

@property (nonatomic, copy, readonly, nonnull) NSDictionary *attributes;
@property (nonatomic, copy, readonly, nonnull) NSDictionary<NSString *, id> *markerDictionary;

+ (nullable instancetype)withPayload:(nonnull NSDictionary *)payload
                       apsDictionary:(nonnull LLApsDictionary *)apsDictionary
                  localyticsDelegate:(nonnull id<LLLocalyticsDelegate>)localyticsDelegate;

- (nullable instancetype)initWithPayload:(nonnull NSDictionary *)payload
                           apsDictionary:(nonnull LLApsDictionary *)apsDictionary
                      localyticsDelegate:(nonnull id<LLLocalyticsDelegate>)localyticsDelegate;

@end
