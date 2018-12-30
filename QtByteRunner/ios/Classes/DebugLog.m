#import "DebugLog.h"

@implementation DebugLog

@synthesize LogMessages;

- (instancetype) init {
    self = [super init];
    LogMessages = [[NSMutableArray alloc] init];
    return self;
}

- (void) dealloc {
    [LogMessages release];
    [super dealloc];
}

static DebugLog * shared = nil;
+ (DebugLog * ) sharedLog {
    if (shared == nil) shared = [[DebugLog alloc] init];
    return shared;
}

- (void) logMessage: (NSString*) msg {
    [LogMessages addObject: msg];
    [self.delegate logUpdated];
    NSLog(@"%@", msg);
}
@end
