#include "iosWebSocketSupport.h"

#include "RunnerMacros.h"
#import "utils.h"

@implementation WebSocketDelegate
        
- (id) init: (iosWebSocketSupport *) ownr callbacksKey:(int)cbKey
{
    self = [super init];
    if (self) {
        owner = ownr;
        callbacksKey = cbKey;
    }
    return self;
}
    
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    owner->onMessage(callbacksKey, NS2UNICODE((NSString*)message));
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    owner->onOpen(callbacksKey);
}
    
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    owner->onError(callbacksKey, NS2UNICODE([error localizedDescription]));
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    owner->onClose(callbacksKey, code, NS2UNICODE(reason), wasClean);
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
    websocketNative->webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:UNICODE2NS(url)]];
    websocketNative->webSocket.delegate = [[WebSocketDelegate alloc] init:this callbacksKey:callbacksKey];
    
    [websocketNative->webSocket open];
    
    return websocketNative->getFlowValue();
}

StackSlot iosWebSocketSupport::doSend(StackSlot websocket, unicode_string message)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    bool isValid = [websocketNative->webSocket readyState] == SR_OPEN;
    if (isValid)
        [websocketNative->webSocket send:UNICODE2NS(message)];
    return StackSlot::MakeBool(isValid);
}

StackSlot iosWebSocketSupport::doHasBufferedData(StackSlot websocket)
{
    return StackSlot::MakeBool(false);
}

void iosWebSocketSupport::doClose(StackSlot websocket, int code, unicode_string reason)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    [websocketNative->webSocket closeWithCode:code reason:UNICODE2NS(reason)];
}
