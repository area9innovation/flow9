#import "NSString+MD5.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (MD5)

- (NSString *)MD5 {
    const char *data = [self UTF8String];
    unsigned char md[CC_MD5_DIGEST_LENGTH + 1];

    CC_MD5(data, (CC_LONG)strlen(data), md);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [hex appendFormat:@"%02x", md[i]];
    
    return hex;
}

@end
