#include "QWebSocketSupport.h"

#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(QWebSocketSupport::FlowNativeWebSocket, FlowNativeObject)

QWebSocketSupport::FlowNativeWebSocket::FlowNativeWebSocket(QWebSocketSupport *owner) : FlowNativeObject(owner->getFlowRunner()) {}

QWebSocketSupport::QWebSocketSupport(ByteCodeRunner *Runner)
    : AbstractWebSocketSupport(Runner), owner(Runner)
{
}

StackSlot QWebSocketSupport::doOpen(unicode_string url, int callbacksKey)
{

    FlowNativeWebSocket *websocketNative = new FlowNativeWebSocket(this);

    connect(&websocketNative->websocket, &QWebSocket::disconnected, this,
        [this, websocketNative, callbacksKey](){
            bool wasClean = websocketNative->websocket.closeCode() == QWebSocketProtocol::CloseCodeNormal;
            this->onClose(callbacksKey, websocketNative->websocket.closeCode(), qt2unicode(websocketNative->websocket.closeReason()), wasClean);
    });

    connect(&websocketNative->websocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
        [this, websocketNative, callbacksKey](QAbstractSocket::SocketError error){
            this->onError(callbacksKey, qt2unicode(websocketNative->websocket.errorString()));
    });

    connect(&websocketNative->websocket, &QWebSocket::textMessageReceived, this,
        [this, callbacksKey](QString message){
            this->onMessage(callbacksKey, qt2unicode(message));
    });

    connect(&websocketNative->websocket, &QWebSocket::connected, this,
        [this, callbacksKey](){
            this->onOpen(callbacksKey);
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
    bool hasBufferedData = false;
#if (QT_VERSION >= QT_VERSION_CHECK(5, 12, 0))
    hasBufferedData = websocketNative->websocket.bytesToWrite() > 0;
#endif
    return StackSlot::MakeBool(hasBufferedData);
}

void QWebSocketSupport::doClose(StackSlot websocket, int code, unicode_string reason)
{
    RUNNER_VAR = owner;
    FlowNativeWebSocket *websocketNative = RUNNER->GetNative<FlowNativeWebSocket*>(websocket);
    websocketNative->websocket.close(static_cast<QWebSocketProtocol::CloseCode>(code), unicode2qt(reason));
}
