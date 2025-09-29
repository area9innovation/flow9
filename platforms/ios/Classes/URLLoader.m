#import "URLLoader.h"
#import "utils.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "NSString+MD5.h"

#define MAX_REQUESTS_NUM 5

@implementation URLLoader

static NSMutableArray * pendingConnections;
static NSMutableArray * queuedRequests;

+ (void) initialize {
    pendingConnections = [[NSMutableArray alloc] init];
    queuedRequests = [[NSMutableArray alloc] init];
}


// Connectivity testing code pulled from Apple's Reachability Example: http://developer.apple.com/library/ios/#samplecode/Reachability
+(BOOL)hasConnection {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
    if(reachability != NULL) {
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(reachability, &flags)) {
            CFRelease(reachability);
            if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) return NO;
            if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) return YES;
            if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
                 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
                if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) return YES;
            if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) return YES;
        } else {
            CFRelease(reachability);
        }
    }

    return NO;
}

- (id) initWithURL: (NSString *) relative_url withHeaders: (NSDictionary*) headers onSuccess: (void (^)(NSData * data)) on_success onError: (void (^) (void)) on_error onProgress: (void (^)(float p)) on_progress onlyCache: (bool) only_cache
{
    self = [super init];
    
    LogI(@"URLLoader initWithURL %@", relative_url);
    
    // TO DO: Try to use simple "copy" message later when apple fix the bug
    onSuccess = Block_copy(on_success);
    onError = Block_copy(on_error);
    onProgress = Block_copy(on_progress);
    onlyCache = only_cache;
    requestHeaders = [headers retain];
    
    self.relativeURL = [relative_url retain];
    
    lastModifiedResponseHeader = nil;
    expectedContentLength = 0;
    
    rawRequest = nil;
    
    // Create unique temp file path
    CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef newUniqueIdString = CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
    tmpFilePath = [[[URLLoader cachePathForURL: self.relativeURL] stringByAppendingPathExtension: (NSString *)newUniqueIdString] retain];
    CFRelease(newUniqueId);
    CFRelease(newUniqueIdString);
    
    return self;
}

- (id) initWithURL: (NSString *) relative_url onSuccess: (void (^)(NSData * data)) on_success onError: (void (^) (void)) on_error onProgress: (void (^)(float p)) on_progress onlyCache: (bool) only_cache
{
    return [self initWithURL:relative_url withHeaders: [NSDictionary dictionary] onSuccess:on_success onError:on_error onProgress:on_progress onlyCache:only_cache];
}

- (id) initWithURLRequest: (NSURLRequest *) request onSuccess: (void (^)(NSData * data)) on_success onError: (void (^) (void)) on_error onProgress: (void (^)(float p)) on_progress onlyCache: (bool) only_cache
{
    NSString * url = request.URL.absoluteString;
    NSDictionary* headers = request.allHTTPHeaderFields;
    [self initWithURL: url withHeaders: headers onSuccess: on_success onError: on_error onProgress: on_progress onlyCache: only_cache];
    
    rawRequest = [request retain];
    
    return self;
}

- (void) dealloc {
    [connection release];
    [self.relativeURL release];
    [cachedFile release];
    
    [onSuccess release];
    [onError release];
    [onProgress release];
    
    [tmpFilePath release];
    [lastModifiedResponseHeader release];
    
    [rawRequest release];
    [requestHeaders release];
    
    [super dealloc];
}

+ (void) checkQueuedRequests {
    @synchronized(pendingConnections) {
        @synchronized(queuedRequests) {
            if ([pendingConnections count] < MAX_REQUESTS_NUM && [queuedRequests count] > 0) {
                NSUInteger requests_to_start = MIN(MAX_REQUESTS_NUM - [pendingConnections count], [queuedRequests count]);
                LogI(@"Starting %lu queued HTTP requests...", (unsigned long)requests_to_start);
                for (int i = 0; i < requests_to_start; ++i) {
                    if ([queuedRequests count] == 0) break;
                    
                    URLLoader * ldr = [queuedRequests objectAtIndex: 0];
                    if (ldr == nil) {
                        LogE(@"URLLoader: Found nil object in queuedRequests, removing it");
                        [queuedRequests removeObjectAtIndex: 0];
                        continue;
                    }
                    
                    [queuedRequests removeObjectAtIndex: 0];
                    [ldr start];
                }
            }
        }
    }
}

- (void) removePendingConnection: (NSURLConnection *) conn {
    @synchronized(pendingConnections) {
        [pendingConnections removeObject: conn];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [URLLoader checkQueuedRequests];
    });
}

- (void) start {
    @synchronized(pendingConnections) {
        if ([pendingConnections count] >= MAX_REQUESTS_NUM) {
            @synchronized(queuedRequests) {
                [queuedRequests addObject: self];
            }
            return;
        }
    }
    
    [[NSFileManager defaultManager] createFileAtPath: tmpFilePath contents: nil attributes: nil];
    cachedFile = [[NSFileHandle fileHandleForWritingAtPath: tmpFilePath] retain];
    
    if (!cachedFile) {
        LogE(@"Cannot open file at \"%@\" to download \"%@\"", tmpFilePath, self.relativeURL);
        onError();
        return;
    }
    
    NSURL * requestURL = [NSURL URLWithString: [self.relativeURL stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding] relativeToURL: BaseUrl];
    
    NSMutableURLRequest * request = nil;
    if (rawRequest != nil) {
        request = [rawRequest mutableCopy];
    } else {
        request = [NSMutableURLRequest requestWithURL: requestURL];
    }
    
    [NSURLProtocol setProperty: @YES forKey: @"URLLoaderHandling" inRequest: request];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    
    if ([URLLoader isCached: self.relativeURL]) { // Already have cached. Check if modified on the server.
        NSString * last_modified = [URLLoader metadaForUrl: self.relativeURL];
        if (last_modified != nil) [request addValue: last_modified forHTTPHeaderField: @"If-Modified-Since"];
    }
    
    for (NSString* key in requestHeaders) {
        [request addValue: requestHeaders[key] forHTTPHeaderField: key];
    }
    
    connection = [[NSURLConnection alloc] initWithRequest: request delegate: self];
    
    if (connection == nil) {
        LogE(@"Cannot create connection for \"%@\"", self.relativeURL);
        onError();
    } else {
        @synchronized(pendingConnections) {
            [pendingConnections addObject: connection];
        }
        [connection start];
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil; // Prevent using default cache. We use own
}

- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data {
    [cachedFile writeData: data];
    if ( expectedContentLength ) onProgress([cachedFile offsetInFile] / (float)expectedContentLength);
}

+ (BOOL)addSkipBackupAttributeToItemAtURL: (NSURL *)URL // Notice: that is recursive
{
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success) {
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn {
    [cachedFile closeFile];
    
    
    NSString * cached_path = [URLLoader cachePathForURL: self.relativeURL];
    NSError * err = nil;
    
    [[NSFileManager defaultManager] removeItemAtPath: cached_path error: nil]; // Overwrite the old
    [[NSFileManager defaultManager] moveItemAtPath: tmpFilePath toPath: cached_path error: &err];

    if (nil != err) {
        LogE(@"%@ for %@", [err localizedDescription], cached_path);
        onError();
        [self autorelease];
        return;
    }
    
    // [self addSkipBackupAttributeToItemAtURL: [NSURL fileURLWithPath: cached_path]];
    
    // Handle metadata
    NSString * metadata_file = [URLLoader metadataPathForURL: self.relativeURL];
    if (lastModifiedResponseHeader != nil) {
        [lastModifiedResponseHeader writeToFile: metadata_file atomically: YES encoding: NSUTF8StringEncoding error: &err];
        if (nil != err) {
            LogE(@"Cannot create cache metadata file for url %@", self.relativeURL);
        } else {
           // [self addSkipBackupAttributeToItemAtURL: [NSURL fileURLWithPath: metadata_file]];
        }
    } else {
        [[NSFileManager defaultManager] removeItemAtPath: metadata_file error: nil];
    }
    
    if (!onlyCache) {
        @autoreleasepool { onSuccess([URLLoader cacheDataForURL: self.relativeURL] ); }
    } else {
        onSuccess(nil);
    }
    
    [self removePendingConnection: conn];
    [self autorelease];
}

- (void) removeTempFile {
    [cachedFile closeFile];
    NSError * err = nil;
    [[NSFileManager defaultManager] removeItemAtPath: tmpFilePath error: &err];
    if (nil != err) LogE(@"Cannot remove temp file: %@. Url = %@", [err localizedDescription], self.relativeURL);
}

- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error {
    LogE(@"Error loading %@ (%@)", self.relativeURL, error);
    onError();
    [self removePendingConnection: connection];
    [self removeTempFile];
    [self autorelease];
}

- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass: [NSHTTPURLResponse class] ]) {
        NSHTTPURLResponse * http_response =(NSHTTPURLResponse *)response;
        NSInteger statusCode = [http_response statusCode];
        
        if (statusCode >= 400) {
            // There will be no didFailWithError message because we have received the response
            LogE(@"Status %ld for request \"%@\"", (long)statusCode, self.relativeURL);
            [conn cancel]; [self removePendingConnection: conn];
            [self removeTempFile];
            onError();
            [self autorelease];
        } else if (statusCode == 304) {
            LogI(@"Not modified for %@. Will use cached", self.relativeURL);
            [self removeTempFile];
            
            if (!onlyCache) {
                @autoreleasepool { onSuccess([URLLoader cacheDataForURL: self.relativeURL]); }
            } else {
                onSuccess(nil);
            }
            
            [conn cancel]; [self removePendingConnection: conn];
            [self autorelease];
        } else {
            // Save headers values
            expectedContentLength = [response expectedContentLength];
            lastModifiedResponseHeader = [[[http_response allHeaderFields] objectForKey:@"Last-Modified"] retain];
        }
    }
}

static NSURL * BaseUrl = [[NSURL alloc] initWithString: DEFAULT_BASE_URL];
+ (void) setBaseURL:(NSString *)base_url {
    if (base_url != nil) {
        [BaseUrl release];
        BaseUrl = [[NSURL alloc] initWithString: base_url];
    }
}

+ (NSURL*) getBaseURL {
    return BaseUrl;
}

+ (NSString *) cachePath {
    static NSString * cache_path = nil;
    
    if (cache_path == nil) {
        NSArray * library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,  NSUserDomainMask, YES);
        NSString * library_path = [library objectAtIndex: 0];
        cache_path = [library_path stringByAppendingPathComponent: @"urlcache"];
        [cache_path retain];
        if (![[NSFileManager defaultManager] fileExistsAtPath: cache_path])
            [[NSFileManager defaultManager] createDirectoryAtPath: cache_path withIntermediateDirectories: YES attributes: nil error: nil];
        // Do not backup the cache with iCloud etc.
        [URLLoader addSkipBackupAttributeToItemAtURL: [NSURL fileURLWithPath: cache_path isDirectory: YES]];
    }
    
    return cache_path;
}

+ (NSString *) cachePathForURL: (NSString *) relativeUrl {
    // Trim whitespaces around url just to be safe
    relativeUrl = [relativeUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSString * last_path_component = [relativeUrl lastPathComponent];
    NSRange range = [last_path_component rangeOfString: @"?"]; // Remove query
    if (range.location != NSNotFound) last_path_component = [last_path_component substringToIndex: range.location];
    
    NSString * hash_for_url = [NSString stringWithFormat: @"cache_%@_%@", [relativeUrl MD5], last_path_component];
    NSString * cache_file_path = [[self cachePath] stringByAppendingPathComponent: hash_for_url];
    
    return cache_file_path;
}

+ (NSData *) cacheDataForURL: (NSString *) relativeUrl {
    NSURL* cacheFileUrl = [[NSURL alloc] initFileURLWithPath:[self cachePathForURL: relativeUrl]];
    return [NSData dataWithContentsOfURL: cacheFileUrl];
}

+ (NSString*) metadataPathForURL: (NSString*) relativeUrl {
    return [[URLLoader cachePathForURL: relativeUrl] stringByAppendingPathExtension: @"meta"];
}

+ (NSString*) metadaForUrl: (NSString*) relativeUrl {
    return [NSString stringWithContentsOfFile: [URLLoader metadataPathForURL: relativeUrl] encoding: NSUTF8StringEncoding error: nil];
}

+ (BOOL) isCached: (NSString *) relative_url {
    return [[NSFileManager defaultManager] fileExistsAtPath: [self cachePathForURL: relative_url]];
}

+ (void) removeFromeCache: (NSString*) relative_url {
    [[NSFileManager defaultManager] removeItemAtPath: [self cachePathForURL: relative_url] error: nil];
    [[NSFileManager defaultManager] removeItemAtPath: [self metadataPathForURL: relative_url] error: nil];
}

+ (void) clearCache {
    LogI(@"URLoader: clearCache");
    NSString  * cache_path = [self cachePath];
    [ [NSFileManager defaultManager] removeItemAtPath: cache_path error: nil ];
    [[NSFileManager defaultManager] createDirectoryAtPath: cache_path withIntermediateDirectories:YES attributes:nil error:nil];
}

+ (void) cancelAllPendingRequests {
    if ([pendingConnections count] > 0) {
        LogI(@"URLLoader: cancelling all %lu pending HTTP requests", (unsigned long)[pendingConnections count]);
        for (NSURLConnection * c in pendingConnections) [c cancel];
        [pendingConnections removeAllObjects];
    }
    if ([queuedRequests count] > 0) {
        LogI(@"URLLoader: removing all %lu queued HTTP requests", (unsigned long)[pendingConnections count]);
        [queuedRequests removeAllObjects];
    }
}

+ (void) cancelPendingRequest:(NSString *)relative_url {
    NSURL* url = [NSURL URLWithString: [relative_url stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding] relativeToURL:BaseUrl];
    
    @synchronized(pendingConnections) {
        for (NSUInteger i = 0; i < pendingConnections.count; i++) {
            NSURLConnection* connection = [pendingConnections objectAtIndex:i];
            NSURLRequest* request = [connection currentRequest];
            
            if ([request.URL.absoluteString isEqualToString:url.absoluteString]) {
                [connection cancel];
                [pendingConnections removeObjectAtIndex:i];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [URLLoader checkQueuedRequests];
                });
                return;
            }
        }
    }
    
    @synchronized(queuedRequests) {
        for (NSUInteger i = 0; i < queuedRequests.count; i++) {
            URLLoader* loader = [queuedRequests objectAtIndex: i];
            
            if ([loader.relativeURL isEqualToString: relative_url]) {
                [queuedRequests removeObjectAtIndex:i];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [URLLoader checkQueuedRequests];
                });
                return;
            }
        }
    }
}
@end
