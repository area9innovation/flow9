#include "utils.h"
#import <UIKit/UIKit.h>

CGRect boundsInFixedCoordinateSpace(const CGRect& bounds) {
#ifdef __IPHONE_8_0
    UIScreen *screen = [UIScreen mainScreen];
    if ([screen respondsToSelector: @selector(fixedCoordinateSpace)]) {
        return [screen.coordinateSpace convertRect: bounds toCoordinateSpace:screen.fixedCoordinateSpace];
    }
#endif
    
    return bounds;
}

CGRect screenBounds() {
    return boundsInFixedCoordinateSpace([[UIScreen mainScreen] bounds]);
}

NSString * applicationLibraryDirectory() {
    NSURL * url = [[[NSFileManager defaultManager] URLsForDirectory: NSLibraryDirectory inDomains: NSUserDomainMask] lastObject];
    // Add "private" to unify folders with C++ part
    return [@"/private" stringByAppendingString:[url path]];
}


NSDictionary * dictionaryFromStdMap(const std::map<unicode_string, unicode_string> & source) {
    NSMutableDictionary * dic = [[[NSMutableDictionary alloc] init] autorelease];
    for (std::map<unicode_string, unicode_string>::const_iterator it = source.begin(); it != source.end(); ++it) {
        [dic setObject: UNICODE2NS(it->second) forKey: UNICODE2NS(it->first)];
    }
    return dic;
}

IOSLogStreambuf::IOSLogStreambuf() : buffer(8*1024+2)
{
    // Leave 2 characters beyond the end
    setp(&buffer[0], &buffer[buffer.size()-2]);
}

IOSLogStreambuf::~IOSLogStreambuf()
{
    sync();
}

int IOSLogStreambuf::flushBuffer () {
    char *base = pbase();
    int num = pptr() - base, last_nl;
    
    // Nothing to do
    if (num <= 0) return 0;
    
    // Find last newline
    for (last_nl = num-1; last_nl >= 0 && base[last_nl] != '\n'; --last_nl);
    
    // If none, do a line break at the end
    if (last_nl < 0) last_nl = num;
    
    // Output the lines if there's anything to output
    if (last_nl > 0) {
        base[last_nl] = 0;
        LogMsg(@"[C] %s", base);
    }
    
    // Shift the remaining characters
    if (last_nl < num) {
        last_nl++;
        memmove(base, base + last_nl, num - last_nl);
    }
    
    pbump(-last_nl);
    
    return num;
}

int IOSLogStreambuf::overflow (int c) {
    if (c != EOF) {
        *pptr() = c;    // insert character into the buffer
        pbump(1);
    }
    if (flushBuffer() == EOF)
        return EOF;
    return c;
}

int IOSLogStreambuf::sync() {
    if (flushBuffer() == EOF)
        return -1;    // ERROR
    return 0;
}
