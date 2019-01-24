#ifndef QWEBSOCKETSUPPORT_H
#define QWEBSOCKETSUPPORT_H

#include <QObject>
#include <QtWebSockets/QtWebSockets>

#include "core/ByteCodeRunner.h"
#include "utils/WebSocketSupport.h"

class QWebSocketSupport : public QObject, public WebSocketSupport
{
    Q_OBJECT
    ByteCodeRunner *owner;
public:
    QWebSocketSupport(ByteCodeRunner *Runner);

    class FlowNativeWebSocket : public FlowNativeObject
    {
    public:
        FlowNativeWebSocket(QWebSocketSupport* owner);
        QWebSocket websocket;
        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeWebSocket, FlowNativeObject)
    };

protected:
    virtual StackSlot doOpen(unicode_string url, int cbOnCloseRoot, int cbOnErrorRoot, int cbOnMessageRoot, int cbOnOpenRoot);
    virtual StackSlot doSend(StackSlot websocket, unicode_string message);
    virtual void doClose(StackSlot websocket, int code, unicode_string reason);
    virtual StackSlot doHasBufferedData(StackSlot websocket);
};

#endif // QWEBSOCKETSUPPORT_H
