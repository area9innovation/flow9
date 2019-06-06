#include "iosWebSocketSupport.h"

#include "RunnerMacros.h"
#import "utils.h"

@implementation WebSocketDelegate
        
- (void) onOpen:(void (^)())on_open onMessage:(void (^)(NSString*)) on_message onError:(void (^)(NSError*)) on_error onClose:(void (^)(NSInteger, NSString*, BOOL)) on_close
{
    self.onOpen = on_open;
    self.onMessage = on_message;
    self.onError = on_error;
    self.onClose = on_close;
}
    
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    self.onMessage((NSString*)message);
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    self.onOpen();
}
    
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    self.onError(error);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
   self.onClose(code, reason, wasClean);
}

@end

IMPLEMENT_FLOW_NATIVE_OBJECT(FlowNativeWebSocket, FlowNativeObject)

FlowNativeWebSocket::FlowNativeWebSocket(iosWebSocketSupport *owner) : FlowNativeObject(owner->getFlowRunner()) {}

FlowNativeWebSocket::~FlowNativeWebSocket()
{
    [webSocket.delegate release];
    [webSocket release];
}

iosWebSocketSupport::iosWebSocketSupport(ByteCodeRunner *runner) : AbstractWebSocketSupport(runner), owner(runner)
{
}
StackSlot iosWebSocketSupport::doOpen(unicode_string url, int callbacksKey)
{
    FlowNativeWebSocket *websocketNative = new FlowNativeWebSocket(this);
    WebSocketDelegate *delegate = [[WebSocketDelegate alloc] init];
    [delegate
     onOpen:^{
         onOpen(callbacksKey);
     }
     onMessage:^(NSString *message) {
         onMessage(callbacksKey, NS2UNICODE(message));
     }
     onError:^(NSError *error) {
         onError(callbacksKey, NS2UNICODE([error localizedDescription]));
     }
     onClose:^(NSInteger code, NSString *reason, BOOL wasClean) {
         onClose(callbacksKey, code, NS2UNICODE(reason), wasClean);
     }];
    
    websocketNative->webSocket = init(UNICODE2NS(url), delegate);
    
    [websocketNative->webSocket open];
    return websocketNative->getFlowValue();
}

StackSlot iosWebSocketSupport::doSend(StackSlot websocket, unicode_string message)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    return StackSlot::MakeBool(send(websocketNative->webSocket, UNICODE2NS(message)));
}

StackSlot iosWebSocketSupport::doHasBufferedData(StackSlot websocket)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    return StackSlot::MakeBool(hasBufferedData(websocketNative->webSocket));
}

void iosWebSocketSupport::doClose(StackSlot websocket, int code, unicode_string reason)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    close(websocketNative->webSocket, code, UNICODE2NS(reason));
}

SRWebSocket* iosWebSocketSupport::init(NSString *url, WebSocketDelegate *delegate)
{
    SRWebSocket *webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:url]];
    webSocket.delegate = delegate;
    return webSocket;
}

BOOL iosWebSocketSupport::send(SRWebSocket *websocket, id message)
{
    bool isValid = [websocket readyState] == SR_OPEN;
    if (isValid)
        [websocket send:message];
    return isValid;
}

BOOL iosWebSocketSupport::hasBufferedData(SRWebSocket *websocket)
{
    return NO;
}

void iosWebSocketSupport::close(SRWebSocket *websocket, int code, NSString *reason)
{
    [websocket closeWithCode:code reason:reason];
}
