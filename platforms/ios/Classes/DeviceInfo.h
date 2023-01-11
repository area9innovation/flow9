#import <Foundation/Foundation.h>

@interface DeviceInfo : NSObject
+ (NSString *) getDeviceName;
+ (NSString *) getMachineName;
+ (NSString *) getSysVersion;
+ (float) getScreenDiagonalIn;
@end
