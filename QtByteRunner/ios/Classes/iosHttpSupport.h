#import <UIKit/UIkit.h>

#include "ByteCodeRunner.h"
#include "AbstractHttpSupport.h"

class iosGLRenderSupport;
class iosHttpSupport;
@class EAGLViewController;

@interface ConnectionDelegate : NSObject
{
    @private
    int RequestId;
    iosHttpSupport * Owner;
    long long ExpectedContentLength;
    long long DownloadedLength;
}

- (id) initWithRequestId:(int)req_id owner: (iosHttpSupport *) ownr;
@end

class iosHttpSupport : public AbstractHttpSupport
{
    iosGLRenderSupport *RenderSupport;
    
public:
    iosHttpSupport(ByteCodeRunner * owner, iosGLRenderSupport * RenderSupport, NSString * user_agent);
    ~iosHttpSupport();
    void selectRejected();
    void selectAccepted(NSString * path);
    void removeActiveConnection(NSURLConnection * c);
protected:
    virtual void doRequest(HttpRequest &rq);
    virtual void doCancelRequest(HttpRequest &rq);
    virtual void doRemoveUrlFromCache(const unicode_string & url);
    virtual void doClearUrlCache();
    virtual int doGetAvailableCacheSpaceMb();
    void doDeleteAppCookies();
    
    virtual void OnRunnerReset(bool inDestructor);
    void cancelActiveConnections();
    NSMutableArray * ActiveConnections;
    NSString * userAgent;
};
