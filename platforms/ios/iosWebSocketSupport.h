#ifndef iosWebSocketSupport_h
#define iosWebSocketSupport_h

#include "ByteCodeRunner.h"
#include "AbstractGeolocationSupport.h"
#include "AbstractWebSocketSupport.h"

#import "SocketRocket/SocketRocket.h"

class iosWebSocketSupport;

@interface WebSocketDelegate : NSObject<SRWebSocketDelegate> {
    iosWebSocketSupport * owner;
    int callbacksKey;
}
- (id) init: (iosWebSocketSupport *) owner callbacksKey:(int)callbacksKey;
@end

class FlowNativeWebSocket : public FlowNativeObject
{
public:
    SRWebSocket *webSocket;
    FlowNativeWebSocket(iosWebSocketSupport* owner);
    ~FlowNativeWebSocket();
    DEFINE_FLOW_NATIVE_OBJECT(FlowNativeWebSocket, FlowNativeObject)
};

class iosWebSocketSupport : public AbstractWebSocketSupport
{
    ByteCodeRunner *owner;
public:
    iosWebSocketSupport(ByteCodeRunner *runner);

protected:
    virtual StackSlot doOpen(unicode_string url, int callbacksKey);
    virtual StackSlot doSend(StackSlot websocket, unicode_string message);
    virtual StackSlot doHasBufferedData(StackSlot websocket);
    virtual void doClose(StackSlot websocket, int code, unicode_string reason);
};


#endif /* iosWebSocketSupport_h */
