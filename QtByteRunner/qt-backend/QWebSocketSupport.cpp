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

    connect(&websocketNative->websocket, &QWebSocket::disconnected, this,
        [this, websocketNative, cbOnCloseRoot](){
            bool wasClean = websocketNative->websocket.closeCode() == QWebSocketProtocol::CloseCodeNormal;
            this->onClose(cbOnCloseRoot, websocketNative->websocket.closeCode(), qt2unicode(websocketNative->websocket.closeReason()), wasClean);
    });

    connect(&websocketNative->websocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
        [this, websocketNative, cbOnErrorRoot](QAbstractSocket::SocketError error){
            this->onError(cbOnErrorRoot, qt2unicode(websocketNative->websocket.errorString()));
    });

    connect(&websocketNative->websocket, &QWebSocket::textMessageReceived, this,
        [this, cbOnMessageRoot](QString message){
            this->onMessage(cbOnMessageRoot, qt2unicode(message));
    });

    connect(&websocketNative->websocket, &QWebSocket::connected, this,
        [this, cbOnOpenRoot](){
            this->onOpen(cbOnOpenRoot);
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

StackSlot QWebSocketSupport::doHasBufferedData(StackSlot websocket)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    return StackSlot::MakeBool(websocketNative->websocket.bytesToWrite() > 0);
}

void QWebSocketSupport::doClose(StackSlot websocket, int code, unicode_string reason)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    websocketNative->websocket.close(static_cast<QWebSocketProtocol::CloseCode>(code), unicode2qt(reason));
}
