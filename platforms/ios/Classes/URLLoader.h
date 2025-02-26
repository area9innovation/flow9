#import <Foundation/Foundation.h>

#ifndef DEFAULT_BASE_URL
#define DEFAULT_BASE_URL @"https://localhost/flow/"
#endif

@class URLLoader;

@interface URLLoader : NSObject {
@private
    NSURLConnection * connection;
    NSFileHandle * cachedFile;
    long long expectedContentLength;
    void (^onSuccess)(NSData * data);
    void (^onError)(void);
    void (^onProgress)(float p);
    bool onlyCache;
    NSString * tmpFilePath;
    NSString * lastModifiedResponseHeader;
    NSURLRequest * rawRequest;
    NSDictionary* requestHeaders;
}

@property (nonatomic, assign) NSString * relativeURL;

// Init immediately starts downloading
- (id) initWithURL: (NSString *) relative_url onSuccess: (void (^)(NSData * data)) on_success onError: (void (^) (void)) on_error onProgress: (void (^)(float p)) on_progress onlyCache: (bool) only_cache;
- (id) initWithURL: (NSString *) relative_url withHeaders: (NSDictionary*) headers onSuccess: (void (^)(NSData * data)) on_success onError: (void (^) (void)) on_error onProgress: (void (^)(float p)) on_progress onlyCache: (bool) only_cache;
- (id) initWithURLRequest: (NSURLRequest *) request onSuccess: (void (^)(NSData * data)) on_success onError: (void (^) (void)) on_error onProgress: (void (^)(float p)) on_progress onlyCache: (bool) only_cache;
- (void) start;

+(BOOL)hasConnection;
+ (void) setBaseURL: (NSString*) base_url;
+ (NSURL*) getBaseURL;

+ (NSString *) cachePath;
+ (NSString *) cachePathForURL: (NSString *) relative_url; // Returns full path for cached url, nil if it doesnot exist
+ (NSData *) cacheDataForURL: (NSString *) relative_url;   // Returns data for cached url, nil if it doesnot exist
+ (BOOL) isCached: (NSString *) relative_url;
+ (void) removeFromeCache: (NSString*) relative_url;
+ (void) clearCache; // Simply removes folder at cachePath
+ (void) cancelPendingRequest: (NSString*) relative_url;
+ (void) cancelAllPendingRequests;
+ (BOOL)addSkipBackupAttributeToItemAtURL: (NSURL *)URL;
@end
