#import "iosGLRenderSupport.h"
#import "iosHttpSupport.h"
#import "URLLoader.h"
#include "utils.h"

//#define IGNORE_MEDIA_PRELOAD

@implementation ConnectionDelegate

- (id) initWithRequestId:(int)req_id owner: (iosHttpSupport *) ownr
{
    self = [super init];
    RequestId = req_id;
    Owner = ownr;
    return self;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    DownloadedLength += [data length];
    Owner->deliverProgress(RequestId, (FlowDouble)DownloadedLength, (FlowDouble)ExpectedContentLength);
    Owner->deliverPartialData(RequestId, [data bytes], [data length], false);
    
    if (ExpectedContentLength > 0 && ExpectedContentLength < 1024) {
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [str autorelease];
        LogI(@"Data for %@ = %@", connection.originalRequest.URL, str);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    Owner->deliverPartialData(RequestId, "", 0, true);
    Owner->removeActiveConnection(connection);
    [connection release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    LogE(@"%@", error);
    unicode_string message = parseUtf8([[error localizedDescription] UTF8String]);
    Owner->deliverError(RequestId, message.data(), message.size());
    Owner->getFlowRunner()->RunDeferredActions();
    Owner->removeActiveConnection(connection);
    [connection release];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{ 
	ExpectedContentLength = [response expectedContentLength];
    DownloadedLength = 0;
    
    if ([response isKindOfClass: [NSHTTPURLResponse class] ])
    {
        int statusCode = [((NSHTTPURLResponse *)response) statusCode];
        
        LogI(@"Response status %d for %@", statusCode, response.URL);
        
        Owner->deliverStatus(RequestId, statusCode);
        if (statusCode >= 400) // There will be no FailWithError message
        {
            [connection cancel];
            NSString * error_msg = [NSString stringWithFormat: @"Connection failed with status code %d", statusCode];
            unicode_string message = parseUtf8([error_msg UTF8String]);
            Owner->deliverError(RequestId, message.data(), message.size());
        }
    }
}
@end

iosHttpSupport::iosHttpSupport(ByteCodeRunner * owner, iosGLRenderSupport * RenderSupport, NSString * user_agent)
    : AbstractHttpSupport(owner), RenderSupport(RenderSupport)
{
    ActiveConnections = [[NSMutableArray alloc] init];
    LogI(@"Base URL for all HTTP requests : %@", [URLLoader getBaseURL]);
    userAgent = [user_agent retain];
    LogI(@"User-Agent for flow HTTP requests = %@", userAgent);
}

iosHttpSupport::~iosHttpSupport()
{
    cancelActiveConnections();
    [URLLoader cancelAllPendingRequests]; // Cancel other requests here too
    [ActiveConnections release];
    [userAgent release];
}

void iosHttpSupport::cancelActiveConnections() {
    // Cancel all pending connections
    LogI(@"Cancel %d pending connections", [ActiveConnections count]);
    for (NSURLConnection * c in ActiveConnections) [c cancel];
    [ActiveConnections removeAllObjects];
}

void iosHttpSupport::OnRunnerReset(bool inDestructor)
{
    AbstractHttpSupport::OnRunnerReset(inDestructor);
    cancelActiveConnections();
    [URLLoader cancelAllPendingRequests]; // Cancel other requests here too 
}

void iosHttpSupport::removeActiveConnection(NSURLConnection *c)
{
    [ActiveConnections removeObject: c];
}

void iosHttpSupport::doRequest(HttpRequest &rq)
{
    NSString * url_string = UNICODE2NS( rq.url );
    
    if (rq.is_media_preload) {
#if !defined(IGNORE_MEDIA_PRELOAD)
        LogI(@"Starting media preload %@", url_string);
        
        URLLoader * loader = nil;
        
        void (^on_success)(NSData * data) = ^(NSData * data) {
            deliverPartialData(rq.req_id, "", 0, true);
        };
        
        void (^on_error)(void) = ^(void) {
            unicode_string message = parseUtf8("Cannot preload media");
            deliverError(rq.req_id, message.data(), message.size());
        };
        
        if ([URLLoader isCached: url_string] && ![URLLoader hasConnection]) {
            deliverPartialData(rq.req_id, "", 0, true);
        } else {
            loader = [[URLLoader alloc] initWithURL: url_string onSuccess: on_success onError: on_error onProgress: ^(float) {} onlyCache: true];
            [loader start];
        }
#else
        LogI(@"Ignore media preload %@", url_string);
        deliverPartialData(rq.req_id, "", 0, true);
#endif
        return;
    }
    
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] init];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    if (userAgent != nil) [request addValue: userAgent forHTTPHeaderField: @"User-Agent"];
    
    // Setting up headers
    for (HttpRequest::T_SMap::iterator it = rq.headers.begin(); it != rq.headers.end(); ++it)
        [request setValue: UNICODE2NS(it->second) forHTTPHeaderField: UNICODE2NS( it->first ) ];
    
    if (!rq.attachments.empty()) {
        // based on this code: https://gist.github.com/mombrea/8467128
        [request setURL: [NSURL URLWithString: url_string relativeToURL: [URLLoader getBaseURL]] ];
        [request setHTTPMethod:@"POST"];
        //NSString * lineEnd = @"\r\n";
        //NSString * twoHyphens = @"--";
        NSString * boundary = @"*****";
        
        NSString * contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
        [request setValue: contentType forHTTPHeaderField: @"Content-Type"];
        [request setValue: @"Keep-Alive" forHTTPHeaderField: @"Connection"];
        
        NSMutableData * body = [NSMutableData data];
        // loop for params
        for (HttpRequest::T_SMap::iterator it = rq.params.begin(); it != rq.params.end(); ++it)
        {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding: NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", UNICODE2NS(it->first), UNICODE2NS(it->second)] dataUsingEncoding: NSUTF8StringEncoding]];
        }
        
        // loop for attachments
        for (HttpRequest::T_SMap::iterator it = rq.attachments.begin(); it != rq.attachments.end(); ++it)
        {
            NSData * fileData = nil;
            NSString * attachmentPath = UNICODE2NS(it->second);
            NSURL * localFileUrl = [NSURL URLWithString: attachmentPath];
            if ([[NSFileManager defaultManager] fileExistsAtPath: [localFileUrl path]]) {
                fileData = [[NSFileManager defaultManager] contentsAtPath:[localFileUrl path]];
            } else if ([[NSFileManager defaultManager] fileExistsAtPath: attachmentPath]) {
                fileData = [[NSFileManager defaultManager] contentsAtPath: attachmentPath];
            }
            if (fileData == nil) {
                continue;
            }
            
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding: NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\";filename=\"%@\"\r\n\r\n", UNICODE2NS(it->first), UNICODE2NS(it->first)] dataUsingEncoding: NSUTF8StringEncoding]];
            [body appendData: fileData];
            [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        
        [request setHTTPBody:body];
        NSString *postLength = [NSString stringWithFormat:@"%d", [body length]];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    } else {
        NSMutableString * parameters = [NSMutableString stringWithString:@""];
        
        // The same looping for params, as for headers
        for (HttpRequest::T_SMap::iterator it = rq.params.begin(); it != rq.params.end(); ++it)
        {
            [parameters appendFormat:@"%@=%@&",
             ESC_URL_QUERY_ITEM(UNICODE2NS(it->first)),
             ESC_URL_QUERY_ITEM(UNICODE2NS(it->second))];
        }
        
        if (rq.is_post)
        {
            [request setURL: [NSURL URLWithString: url_string relativeToURL: [URLLoader getBaseURL]] ];
            [request setHTTPMethod:@"POST"];
            [request setHTTPBody: [parameters dataUsingEncoding: NSUTF8StringEncoding] ];
        }
        else
        {
            [request setURL: [NSURL URLWithString: [url_string stringByAppendingFormat: ([parameters length] > 0 ? @"?%@" : @"%@"), parameters] relativeToURL: [URLLoader getBaseURL]] ];
            [request setHTTPMethod:@"GET"];
        }
    }
    
    //[request setTimeoutInterval: 20.0];
    
    LogI(@"Starting HTTP request %@", [[request URL] absoluteString]);
    
    ConnectionDelegate * delegate = [[[ConnectionDelegate alloc] initWithRequestId: rq.req_id owner: this] autorelease];
    NSURLConnection * connection = [[NSURLConnection  alloc  ] initWithRequest: request delegate: delegate];
    
    if ( connection == nil)
    {
        unicode_string message = parseUtf8("Cannot create connection");
        deliverError(rq.req_id, message.data(), message.size());
    }
    else
    {
        rq.aux_data = connection;
        [ActiveConnections addObject: connection];
        [connection start];
    }
}

void iosHttpSupport::doCancelRequest(HttpRequest &rq)
{
    if (rq.aux_data == nil) return;
    
    NSURLConnection *connection = (NSURLConnection*) rq.aux_data;
    removeActiveConnection(connection);
    [connection cancel];
}

void iosHttpSupport::doRemoveUrlFromCache(const unicode_string & url)
{
    [URLLoader removeFromeCache: UNICODE2NS(url)];
    RenderSupport->removeUrlFromPicturesCache(url);
}

void iosHttpSupport::doClearUrlCache()
{
    [URLLoader clearCache];
}

int iosHttpSupport::doGetAvailableCacheSpaceMb()
{
    NSDictionary * lib_dir_attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath: applicationLibraryDirectory() error: NULL];
    unsigned long long available_bytes = [[lib_dir_attrs objectForKey: NSFileSystemFreeSize] unsignedLongLongValue];
    return int(available_bytes / (1024 * 1024));
}

void iosHttpSupport::doDeleteAppCookies()
{
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSHTTPCookie *cookie;
    for(cookie in [storage cookies]) {
         [storage deleteCookie:cookie];
     }
}
