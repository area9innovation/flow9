#import <sys/utsname.h>
#import "DeviceInfo.h"
#import "utils.h"

@interface DeviceInfo ()
+ (NSArray *) getDeviceInfo;
@end

@implementation DeviceInfo
+ (NSArray *) getDeviceInfo {
    struct utsname systemInfo;
    
    uname(&systemInfo);
    
    NSString* code = [NSString stringWithCString: systemInfo.machine
                                        encoding: NSUTF8StringEncoding];
    
    LogI(@"Device code (systemInfo.machine) : %@", code);
    
    static NSDictionary* deviceNamesByCode = nil;
    
    if (!deviceNamesByCode) {
        // [Name, screen diagonal inches]
        deviceNamesByCode = @{
                              @"iPhone1,2" : @[@"iPhone", @3.5f],            // (3G)
                              @"iPhone2,1" : @[@"iPhone", @3.5f],            // (3GS)
                              @"iPad1,1"   : @[@"iPad", @9.7f],              // (Original)
                              @"iPad2,1"   : @[@"iPad 2", @9.7f],            //
                              @"iPad3,1"   : @[@"iPad", @9.7f],             // (3rd Generation)
                              @"iPhone3,1" : @[@"iPhone 4", @3.5f],          // (GSM)
                              @"iPhone3,3" : @[@"iPhone 4", @3.5f],          // (CDMA/Verizon/Sprint)
                              @"iPhone4,1" : @[@"iPhone 4S", @3.5f],         //
                              @"iPhone5,1" : @[@"iPhone 5", @4.0f],          // (model A1428, AT&T/Canada)
                              @"iPhone5,2" : @[@"iPhone 5", @4.0f],          // (model A1429, everything else)
                              @"iPad3,4"   : @[@"iPad", @9.7f],             // (4th Generation)
                              @"iPad2,5"   : @[@"iPad Mini", @7.85f],         // (Original)
                              @"iPhone5,3" : @[@"iPhone 5c", @4.0f],         // (model A1456, A1532 | GSM)
                              @"iPhone5,4" : @[@"iPhone 5c", @4.0f],          // (model A1507, A1516, A1526 (China), A1529 | Global)
                              @"iPhone6,1" : @[@"iPhone 5s", @4.0f],        // (model A1433, A1533 | GSM)
                              @"iPhone6,2" : @[@"iPhone 5s", @4.0f],        // (model A1457, A1518, A1528 (China), A1530 | Global)
                              @"iPhone7,1" : @[@"iPhone 6 Plus", @5.5f],    //
                              @"iPhone7,2" : @[@"iPhone 6", @4.7f],          // TO DO
                              @"iPhone8,1" : @[@"iPhone 6S", @4.7f],         //
                              @"iPhone8,2" : @[@"iPhone 6S Plus", @5.5f],    //
                              @"iPhone8,4" : @[@"iPhone SE", @4.0f],         //
                              
                              @"iPhone9,1" : @[@"iPhone 7", @4.7f],         // iPhone 7 (CDMA)
                              @"iPhone9,3" : @[@"iPhone 7", @4.7f],         // iPhone 7 (GSM)
                              @"iPhone9,2" : @[@"iPhone 7 Plus", @5.5f],    // iPhone 7 Plus (CDMA)
                              @"iPhone9,4" : @[@"iPhone 7 Plus", @5.5f],    // iPhone 7 Plus (GSM)
                              
                              @"iPhone10,1": @[@"iPhone 8", @4.7f],         // iPhone 8 (CDMA)
                              @"iPhone10,4": @[@"iPhone 8", @4.7f],         // iPhone 8 (GSM)
                              @"iPhone10,2": @[@"iPhone 8 Plus", @5.5f],    // iPhone 8 Plus (CDMA)
                              @"iPhone10,5": @[@"iPhone 8 Plus", @5.5f],    // iPhone 8 Plus (GSM)
                              @"iPhone10,3": @[@"iPhone 10", @5.8f],        // iPhone X (CDMA)
                              @"iPhone10,6": @[@"iPhone 10", @5.8f],        // iPhone X (GSM)

                              @"iPhone11,2": @[@"iPhone XS", @0.0f],
                              @"iPhone11,4": @[@"iPhone XS Max", @0.0f],
                              @"iPhone11,6": @[@"iPhone XS Max", @0.0f],
                              @"iPhone11,8": @[@"iPhone XR", @0.0f],
                              @"iPhone12,1": @[@"iPhone 11", @0.0f],
                              @"iPhone12,3": @[@"iPhone 11 Pro", @0.0f],
                              @"iPhone12,5": @[@"iPhone 11 Pro Max", @0.0f],
                              @"iPhone13,1": @[@"iPhone 12 mini", @0.0f],
                              @"iPhone13,2": @[@"iPhone 12", @0.0f],
                              @"iPhone13,3": @[@"iPhone 12 Pro", @0.0f],
                              @"iPhone13,4": @[@"iPhone 12 Pro Max", @0.0f],
                              @"iPhone14,4": @[@"iPhone 13 mini", @0.0f],
                              @"iPhone14,5": @[@"iPhone 13", @0.0f],
                              @"iPhone14,2": @[@"iPhone 13 Pro", @0.0f],
                              @"iPhone14,3": @[@"iPhone 13 Pro Max", @0.0f],
                              @"iPhone14,7": @[@"iPhone 14", @0.0f],
                              @"iPhone14,8": @[@"iPhone 14 Plus", @0.0f],
                              @"iPhone15,2": @[@"iPhone 14 Pro", @0.0f],
                              @"iPhone15,3": @[@"iPhone 14 Pro Max", @0.0f],
                              @"iPhone8,4":  @[@"iPhone SE", @0.0f],
                              @"iPhone12,8": @[@"iPhone SE (2nd)", @0.0f],
                              @"iPhone14,6": @[@"iPhone SE (3rd)", @0.0f],
                              
                              @"iPad4,1"   : @[@"iPad Air", @9.7f],         // 5th Generation iPad (iPad Air) - Wifi
                              @"iPad4,2"   : @[@"iPad Air", @9.7f],         // 5th Generation iPad (iPad Air) - Cellular
                              @"iPad4,4"   : @[@"iPad Mini", @7.85f],       // (2nd Generation iPad Mini - Wifi)
                              @"iPad4,5"   : @[@"iPad Mini", @7.85f],        // (2nd Generation iPad Mini - Cellular)
                              @"iPad4,7"   : @[@"iPad Mini", @7.85f],        // (3rd Generation iPad Mini - Wifi (model A1599))
                              @"iPad6,7"   : @[@"iPad Pro (12.9-inch)", @12.9f], // iPad Pro 12.9 inches - (model A1584)
                              @"iPad6,8"   : @[@"iPad Pro (12.9-inch)", @12.9f], // iPad Pro 12.9 inches - (model A1652)
                              @"iPad6,3"   : @[@"iPad Pro (9.7-inch)", @9.7f],  // iPad Pro 9.7 inches - (model A1673)
                              @"iPad6,4"   : @[@"iPad Pro (9.7-inch)", @9.7f],   // iPad Pro 9.7 inches - (models A1674 and A1675)
 
                              @"iPad6,11"  : @[@"iPad (5th)", @0.0f],
                              @"iPad6,12"  : @[@"iPad (5th)", @0.0f],
                              @"iPad7,5"   : @[@"iPad (6th)", @0.0f],
                              @"iPad7,6"   : @[@"iPad (6th)", @0.0f],
                              @"iPad7,11"  : @[@"iPad (7th)", @0.0f],
                              @"iPad7,12"  : @[@"iPad (7th)", @0.0f],
                              @"iPad11,6"  : @[@"iPad (8th)", @0.0f],
                              @"iPad11,7"  : @[@"iPad (8th)", @0.0f],
                              @"iPad12,1"  : @[@"iPad (9th)", @0.0f],
                              @"iPad12,2"  : @[@"iPad (9th)", @0.0f],
                              @"iPad5,3"   : @[@"iPad Air 2", @0.0f],
                              @"iPad5,4"   : @[@"iPad Air 2", @0.0f],
                              @"iPad11,3"  : @[@"iPad Air (3rd)", @0.0f],
                              @"iPad11,4"  : @[@"iPad Air (3rd)", @0.0f],
                              @"iPad13,1"  : @[@"iPad Air (4th)", @0.0f],
                              @"iPad13,2"  : @[@"iPad Air (4th)", @0.0f],
                              @"iPad13,16" : @[@"iPad Air (5th)", @0.0f],
                              @"iPad13,17" : @[@"iPad Air (5th)", @0.0f],
                              @"iPad2,5"   : @[@"iPad mini", @0.0f],
                              @"iPad2,6"   : @[@"iPad mini", @0.0f],
                              @"iPad2,7"   : @[@"iPad mini", @0.0f],
                              @"iPad4,4"   : @[@"iPad mini 2", @0.0f],
                              @"iPad4,5"   : @[@"iPad mini 2", @0.0f],
                              @"iPad4,6"   : @[@"iPad mini 2", @0.0f],
                              @"iPad4,7"   : @[@"iPad mini 3", @0.0f],
                              @"iPad4,8"   : @[@"iPad mini 3", @0.0f],
                              @"iPad4,9"   : @[@"iPad mini 3", @0.0f],
                              @"iPad5,1"   : @[@"iPad mini 4", @0.0f],
                              @"iPad5,2"   : @[@"iPad mini 4", @0.0f],
                              @"iPad11,1"  : @[@"iPad mini (5th)", @0.0f],
                              @"iPad11,2"  : @[@"iPad mini (5th)", @0.0f],
                              @"iPad14,1"  : @[@"iPad mini (6th)", @0.0f],
                              @"iPad14,2"  : @[@"iPad mini (6th)", @0.0f],
                              @"iPad6,3"   : @[@"iPad Pro (9.7-inch)", @0.0f],
                              @"iPad6,4"   : @[@"iPad Pro (9.7-inch)", @0.0f],
                              @"iPad7,3"   : @[@"iPad Pro (10.5-inch)", @0.0f],
                              @"iPad7,4"   : @[@"iPad Pro (10.5-inch)", @0.0f],
                              @"iPad8,1"   : @[@"iPad Pro (11-inch) (1st)", @0.0f],
                              @"iPad8,2"   : @[@"iPad Pro (11-inch) (1st)", @0.0f],
                              @"iPad8,3"   : @[@"iPad Pro (11-inch) (1st)", @0.0f],
                              @"iPad8,4"   : @[@"iPad Pro (11-inch) (1st)", @0.0f],
                              @"iPad8,9"   : @[@"iPad Pro (11-inch) (2nd)", @0.0f],
                              @"iPad8,10"  : @[@"iPad Pro (11-inch) (2nd)", @0.0f],
                              @"iPad13,4"  : @[@"iPad Pro (11-inch) (3rd)", @0.0f],
                              @"iPad13,5"  : @[@"iPad Pro (11-inch) (3rd)", @0.0f],
                              @"iPad13,6"  : @[@"iPad Pro (11-inch) (3rd)", @0.0f],
                              @"iPad13,7"  : @[@"iPad Pro (11-inch) (3rd)", @0.0f],
                              @"iPad6,7"   : @[@"iPad Pro (12.9-inch) (1st)", @0.0f],
                              @"iPad6,8"   : @[@"iPad Pro (12.9-inch) (1st)", @0.0f],
                              @"iPad7,1"   : @[@"iPad Pro (12.9-inch) (2nd)", @0.0f],
                              @"iPad7,2"   : @[@"iPad Pro (12.9-inch) (2nd)", @0.0f],
                              @"iPad8,5"   : @[@"iPad Pro (12.9-inch) (3rd)", @0.0f],
                              @"iPad8,6"   : @[@"iPad Pro (12.9-inch) (3rd)", @0.0f],
                              @"iPad8,7"   : @[@"iPad Pro (12.9-inch) (3rd)", @0.0f],
                              @"iPad8,8"   : @[@"iPad Pro (12.9-inch) (3rd)", @0.0f],
                              @"iPad8,11"  : @[@"iPad Pro (12.9-inch) (4th)", @0.0f],
                              @"iPad8,12"  : @[@"iPad Pro (12.9-inch) (4th)", @0.0f],
                              @"iPad13,8"  : @[@"iPad Pro (12.9-inch) (5th)", @0.0f],
                              @"iPad13,9"  : @[@"iPad Pro (12.9-inch) (5th)", @0.0f],
                              @"iPad13,10" : @[@"iPad Pro (12.9-inch) (5th)", @0.0f],
                              @"iPad13,11" : @[@"iPad Pro (12.9-inch) (5th)", @0.0f],
                              @"AppleTV5,3": @[@"Apple TV", @0.0f],
                              @"AppleTV6,2": @[@"Apple TV 4K", @0.0f],
                              @"AudioAccessory1,1": @[@"HomePod", @0.0f],
                              @"AudioAccessory5,1": @[@"HomePod mini", @0.0f],
                              @"i386"      : @[@"Simulator iOS(i386)", @0.0f],
                              @"x86_64"    : @[@"Simulator iOS(x86_64)", @0.0f],
                              @"arm64"     : @[@"Simulator iOS(arm64)", @0.0f]
                       };
        [deviceNamesByCode retain];
    }
    
    return [deviceNamesByCode objectForKey: code];
}

+ (NSString*) getDeviceName {
    NSArray * info = [DeviceInfo getDeviceInfo];
    return info != nil ? [info objectAtIndex: 0] : @"Unknown";
}

+ (NSString*) getMachineName {
    struct utsname systemInfo;
    
    uname(&systemInfo);
    
    NSString* param = [NSString stringWithCString: systemInfo.machine
                                        encoding: NSUTF8StringEncoding];
    return param;
}

+ (NSString*) getSysVersion {
    struct utsname systemInfo;
    
    uname(&systemInfo);
    
    NSString* param = [NSString stringWithCString: systemInfo.version
                                        encoding: NSUTF8StringEncoding];
    return param;
}

+ (float) getScreenDiagonalIn {
    NSArray * info = [DeviceInfo getDeviceInfo];
    NSNumber * diagonal_in = info != nil ? [info objectAtIndex: 1] : @0.0f;
    return [diagonal_in floatValue];
}
@end
