#import "WebCacheProtocol.h"
#import "URLLoader.h"
#import "utils.h"

// Requests from WebViews to static resources are cached here on the low NSURLConnection level
// using URLLoader common cache

@implementation WebCacheProtocol

+ (BOOL) useCustomCacheForURL: (NSURL*) url {
    NSString * ext = url.pathExtension;
    return [ext isEqualToString: @"html"] || [ext isEqualToString: @"xhtml"] || [ext isEqualToString: @"htm"] ||
    [ext isEqualToString: @"css"] || [ext isEqualToString: @"js"] ||
    [ext isEqualToString: @"png"] || [ext isEqualToString: @"jpg"];
}

+ (NSString*) mimeTypeForPath: (NSURL *) url {
    NSString * ext = url.pathExtension;
    if ([ext isEqualToString: @"html"] || [ext isEqualToString: @"xhtml"]  || [ext isEqualToString: @"htm"] ) return @"text/html";
    if ([ext isEqualToString: @"css"] ) return @"text/css";
    if ([ext isEqualToString: @"js"] ) return @"application/javascript";
    if ([ext isEqualToString: @"png"] ) return @"image/png";
    if ([ext isEqualToString: @"jpg"] ) return @"image/jpeg";
    return @"text/plain";
}

// Removes hash from URL. It is only valid on the WebView side
+ (NSString *) stringByRemovingFragmentIdAndQuery: (NSString * ) str {
    NSRange range = [str rangeOfString: @"#"];
    if (range.location != NSNotFound) str = [str substringToIndex: range.location];
    range = [str rangeOfString: @"?"];
    if (range.location != NSNotFound) str = [str substringToIndex: range.location];
    return str;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
    /*
    NSMutableURLRequest * r = [request mutableCopy];
    r.URL = [NSURL URLWithString: [WebCacheProtocol stringByRemovingFragmentIdAndQuery: r.URL.absoluteString]];
    return r;*/
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return ([self useCustomCacheForURL: request.URL] && ![NSURLProtocol propertyForKey: @"URLLoaderHandling" inRequest: request]);
}

- (void) sendDataToClient: (NSData *) data {
    NSURLResponse * response = [[NSURLResponse alloc] initWithURL: self.request.URL MIMEType: [WebCacheProtocol mimeTypeForPath: self.request.URL] expectedContentLength: data.length textEncodingName: @"UTF-8"];
    [response autorelease];
    [self.client URLProtocol:self didReceiveResponse: response cacheStoragePolicy: NSURLCacheStorageAllowed];
    [self.client URLProtocol: self didLoadData: data];
    [self.client URLProtocolDidFinishLoading: self];
}

- (void) send404ToClient {
    NSHTTPURLResponse  *response = [[NSHTTPURLResponse alloc] initWithURL: self.request.URL statusCode: 404 HTTPVersion: @"1.1" headerFields: @{@"Content-Type" : @"text/html"}];
    [response autorelease];
    [self.client URLProtocol:self didReceiveResponse: response cacheStoragePolicy: NSURLCacheStorageAllowed];
    [self.client URLProtocol: self didLoadData: [@"<center><h1>404 Not Found</h1></center>" dataUsingEncoding: NSUTF8StringEncoding]];
    [self.client URLProtocolDidFinishLoading: self];
}

- (void)stopLoading {
    wasStopped = YES; // Do not stop loading. Just do not send the result
}

- (void)startLoading {
    wasStopped = NO;
    // Canonical path is already set only for >= iOS 8.0
    //NSString * absolute_path = [WebCacheProtocol stringByRemovingFragmentIdAndQuery: self.request.URL.absoluteString];
    NSString * absolute_path = self.request.URL.absoluteString;
    
    if ([URLLoader isCached: absolute_path] && ![URLLoader hasConnection]) {
        LogI(@"Use flow-cached data for WebView: %@", absolute_path);
        NSData * data = [URLLoader cacheDataForURL: absolute_path];
        if (!wasStopped) [self sendDataToClient: data];
    } else {
        URLLoader * loader = nil;
        void (^on_success)(NSData * data) = ^void(NSData * data) {
            if (!wasStopped )
                [self sendDataToClient: data];
        };
        void (^on_error)(void)= ^void(void) { if (!wasStopped) [self send404ToClient]; };
    
        loader = [[URLLoader alloc] initWithURLRequest: self.request onSuccess: on_success onError: on_error onProgress: ^(float) {} onlyCache: false];
        [loader start];
    }
}
@end
