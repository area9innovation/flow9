#ifndef QWEBSOCKETSUPPORT_H
#define QWEBSOCKETSUPPORT_H

#include <QObject>
#include <QtWebSockets/QtWebSockets>

#include "core/ByteCodeRunner.h"
#include "utils/AbstractWebSocketSupport.h"

class QWebSocketSupport : public QObject, public AbstractWebSocketSupport
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
    virtual StackSlot doOpen(unicode_string url, int callbacksKey);
    virtual StackSlot doSend(StackSlot websocket, unicode_string message);
    virtual StackSlot doHasBufferedData(StackSlot websocket);
    virtual void doClose(StackSlot websocket, int code, unicode_string reason);
};

#endif // QWEBSOCKETSUPPORT_H
