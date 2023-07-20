#import "iosGLRenderSupport.h"
#import "iosHttpSupport.h"
#import "URLLoader.h"
#include "utils.h"

#include <fstream>
#include <streambuf>

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
    AbstractHttpSupport::HeadersMap headers = AbstractHttpSupport::HeadersMap();
    NSDictionary* headersDict = [response allHeaderFields];
    
    NSArray* keys = [headersDict allKeys];
    for (size_t i = 0; i < keys.count; i++) {
        headers[NS2UNICODE(keys[i])] = NS2UNICODE([headersDict valueForKey:keys[i]]);
    }
    
    Owner->deliverPartialData(RequestId, "", 0, true);
    Owner->deliverResponse(RequestId, (int)response.statusCode, headers);
    Owner->removeActiveConnection(connection);
    
    [connection release];
    [response release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    LogE(@"%@", error);
    unicode_string message = parseUtf8([[error localizedDescription] UTF8String]);
    Owner->deliverError(RequestId, message.data(), message.size());
    Owner->getFlowRunner()->RunDeferredActions();
    
    Owner->removeActiveConnection(connection);
    
    [connection release];
    [response release];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{ 
	ExpectedContentLength = [response expectedContentLength];
    DownloadedLength = 0;
    
    if ([response isKindOfClass: [NSHTTPURLResponse class] ])
    {
        self->response = [((NSHTTPURLResponse *)response) retain];
        int statusCode = (int)self->response.statusCode;
        
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
    NSString * url_string = UNICODE2NS(rq.url);
    
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
        [request setValue: UNICODE2NS(it->second) forHTTPHeaderField: UNICODE2NS(it->first)];
    
    [request setHTTPMethod: UNICODE2NS(rq.method)];
    [request setURL: [NSURL URLWithString: url_string relativeToURL: [URLLoader getBaseURL]]];
    [request setHTTPBody: [NSData dataWithBytesNoCopy:rq.payload.data() length:rq.payload.size() freeWhenDone:NO]];
    
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
