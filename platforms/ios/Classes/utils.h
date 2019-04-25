#ifndef UTILS_H
#define UTILS_H

#include "STLHelpers.h"
#import <UIKit/UIKit.h>
#include <streambuf>
#import "DebugLog.h"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define ESC_URL_QUERY_ITEM(arg) ([(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)(arg), CFSTR(""), CFSTR("+&=?.@"), kCFStringEncodingUTF8) autorelease])

#define DELAY(ms, block) (dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ms / 1000.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), block))

#define UNICODE2NS(ARG) [[NSString alloc] initWithBytes:ARG.c_str() length:2*ARG.size() encoding:NSUTF16LittleEndianStringEncoding]
inline unicode_string NS2UNICODE(NSString * ARG) {
    if ([ARG canBeConvertedToEncoding:NSUTF16LittleEndianStringEncoding]) {
        NSData * DATA = [ARG dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
        return unicode_string((const uint16_t*)DATA.bytes, DATA.length / 2);
    } else {
        return NULL;
    }
}

// 0 - only errors, 1 - errors and warnings, 2 - errors, warnings and info
#define LOG_LEVEL 2

#define LogMsg(fmt, ...) [[DebugLog sharedLog] logMessage: [NSString stringWithFormat: fmt, ##__VA_ARGS__]]

#define LogE(fmt, ...) LogMsg(@"[E] " fmt, ##__VA_ARGS__)

#if LOG_LEVEL > 0
    #define LogW(fmt, ...) LogMsg(@"[W] " fmt, ##__VA_ARGS__)
#else
    #define LogW(fmt, ...)
#endif

#if LOG_LEVEL > 1
    #define LogI(fmt, ...) LogMsg(@"[I] " fmt, ##__VA_ARGS__)
#else
    #define LogI(fmt, ...)
#endif

#define RUN_IN_MAIN_THREAD(block) (dispatch_async(dispatch_get_main_queue(), block))

// iOS 8 returns screen/keyboard bounds in the current orientation screen space
// Earlier it returned those values for fixed portrait coordinate space
CGRect boundsInFixedCoordinateSpace(const CGRect& bounds);
CGRect screenBounds();
NSDictionary * dictionaryFromStdMap(const std::map<unicode_string, unicode_string> & source);

NSString * applicationLibraryDirectory();

class IOSLogStreambuf : public std::streambuf
{
protected:
    std::vector<char> buffer;
    
public:
    IOSLogStreambuf();
    virtual ~IOSLogStreambuf();
    
protected:
    int flushBuffer ();
    virtual int overflow(int c = EOF);
    virtual int sync();
};
#endif
