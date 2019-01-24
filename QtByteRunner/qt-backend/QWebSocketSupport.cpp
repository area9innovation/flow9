#include "QWebSocketSupport.h"

#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(QWebSocketSupport::FlowNativeWebSocket, FlowNativeObject)

QWebSocketSupport::FlowNativeWebSocket::FlowNativeWebSocket(QWebSocketSupport *owner) : FlowNativeObject(owner->getFlowRunner()) {}

QWebSocketSupport::QWebSocketSupport(ByteCodeRunner *Runner)
    : WebSocketSupport(Runner), owner(Runner)
{
}

StackSlot QWebSocketSupport::doOpen(unicode_string url, int cbOnCloseRoot, int cbOnErrorRoot, int cbOnMessageRoot, int cbOnOpenRoot)
{
    RUNNER_VAR = owner;

    FlowNativeWebSocket *websocketNative = new FlowNativeWebSocket(this);

    connect(&websocketNative->websocket, &QWebSocket::disconnected, this, [websocketNative, cbOnCloseRoot, RUNNER](){
        WITH_RUNNER_LOCK_DEFERRED(RUNNER);
        bool wasClean = websocketNative->websocket.closeCode() == QWebSocketProtocol::CloseCodeNormal;
        RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnCloseRoot), 3,
                             StackSlot::MakeInt(websocketNative->websocket.closeCode()), RUNNER->AllocateString(websocketNative->websocket.closeReason()), StackSlot::MakeBool(wasClean));
    });

    connect(&websocketNative->websocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error), [websocketNative, cbOnErrorRoot, RUNNER](QAbstractSocket::SocketError error){
            WITH_RUNNER_LOCK_DEFERRED(RUNNER);
            RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnErrorRoot), 1, RUNNER->AllocateString(websocketNative->websocket.errorString()));
    });

    connect(&websocketNative->websocket, &QWebSocket::textMessageReceived, this, [cbOnMessageRoot, RUNNER](QString message){
        WITH_RUNNER_LOCK_DEFERRED(RUNNER);
        RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnMessageRoot), 1, RUNNER->AllocateString(message));
    });

    connect(&websocketNative->websocket, &QWebSocket::connected, this, [cbOnOpenRoot, RUNNER](){
        WITH_RUNNER_LOCK_DEFERRED(RUNNER);
        RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnOpenRoot), 0);
    });

    websocketNative->websocket.open(QUrl(unicode2qt(url)));

    return websocketNative->getFlowValue();
}

StackSlot QWebSocketSupport::doSend(StackSlot websocket, unicode_string message)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    bool isValid = websocketNative->websocket.isValid();
    if (isValid) {
        websocketNative->websocket.sendTextMessage(unicode2qt(message));
    }
    return StackSlot::MakeBool(isValid);
}

void QWebSocketSupport::doClose(StackSlot websocket, int code, unicode_string reason)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    websocketNative->websocket.close(static_cast<QWebSocketProtocol::CloseCode>(code), unicode2qt(reason));
}

StackSlot QWebSocketSupport::doHasBufferedData(StackSlot websocket)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    return StackSlot::MakeBool(websocketNative->websocket.bytesToWrite() > 0);
}
