#ifndef iosWebSocketSupport_h
#define iosWebSocketSupport_h

#include "ByteCodeRunner.h"
#include "AbstractWebSocketSupport.h"

#import "SocketRocket/SocketRocket.h"

class iosWebSocketSupport;

@interface WebSocketDelegate : NSObject<SRWebSocketDelegate> {
}
@property (readwrite, copy) void (^onOpen)();
@property (readwrite, copy) void (^onMessage)(NSString*);
@property (readwrite, copy) void (^onError)(NSError*);
@property (readwrite, copy) void (^onClose)(NSInteger, NSString*, BOOL);

- (id) onOpen:(void (^)()) on_open onMessage:(void (^)(NSString*)) on_message onError:(void (^)(NSError*)) on_error onClose:(void (^)(NSInteger, NSString*, BOOL)) on_close;
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

    SRWebSocket* init(NSString *url, WebSocketDelegate *delegate);
    BOOL send(SRWebSocket *websocket, id message);
    BOOL hasBufferedData(SRWebSocket *websocket);
    void close(SRWebSocket *websocket, int code, NSString *reason);
protected:
    virtual StackSlot doOpen(unicode_string url, int callbacksKey);
    virtual StackSlot doSend(StackSlot websocket, unicode_string message);
    virtual StackSlot doHasBufferedData(StackSlot websocket);
    virtual void doClose(StackSlot websocket, int code, unicode_string reason);
};

#endif /* iosWebSocketSupport_h */
