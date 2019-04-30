#import <Foundation/Foundation.h>

@protocol DebugLogListener
- (void) logUpdated;
@end


@interface DebugLog : NSObject

@property (nonatomic, retain) NSMutableArray * LogMessages;
@property (nonatomic, retain) NSObject<DebugLogListener> * delegate;

- (void) logMessage: (NSString*) msg;
+ (DebugLog * ) sharedLog;
@end
