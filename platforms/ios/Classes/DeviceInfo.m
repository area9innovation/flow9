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
                              
                              @"iPad4,1"   : @[@"iPad Air", @9.7f],         // 5th Generation iPad (iPad Air) - Wifi
                              @"iPad4,2"   : @[@"iPad Air", @9.7f],         // 5th Generation iPad (iPad Air) - Cellular
                              @"iPad4,4"   : @[@"iPad Mini", @7.85f],       // (2nd Generation iPad Mini - Wifi)
                              @"iPad4,5"   : @[@"iPad Mini", @7.85f],        // (2nd Generation iPad Mini - Cellular)
                              @"iPad4,7"   : @[@"iPad Mini", @7.85f],        // (3rd Generation iPad Mini - Wifi (model A1599))
                              @"iPad6,7"   : @[@"iPad Pro (12.9\")", @12.9f], // iPad Pro 12.9 inches - (model A1584)
                              @"iPad6,8"   : @[@"iPad Pro (12.9\")", @12.9f], // iPad Pro 12.9 inches - (model A1652)
                              @"iPad6,3"   : @[@"iPad Pro (9.7\")", @9.7f],  // iPad Pro 9.7 inches - (model A1673)
                              @"iPad6,4"   : @[@"iPad Pro (9.7\")", @9.7f]   // iPad Pro 9.7 inches - (models A1674 and A1675)
                        };
        [deviceNamesByCode retain];
    }
    
    return [deviceNamesByCode objectForKey: code];
}

+ (NSString*) getDeviceName {
    NSArray * info = [DeviceInfo getDeviceInfo];
    return info != nil ? [info objectAtIndex: 0] : @"Unkonown";
}

+ (float) getScreenDiagonalIn {
    NSArray * info = [DeviceInfo getDeviceInfo];
    NSNumber * diagonal_in = info != nil ? [info objectAtIndex: 1] : @0.0f;
    return [diagonal_in floatValue];
}
@end
