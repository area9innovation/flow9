#ifndef ABSTRACTWEBSOCKETSUPPORT_H
#define ABSTRACTWEBSOCKETSUPPORT_H

#include "core/ByteCodeRunner.h"

class AbstractWebSocketSupport : public NativeMethodHost
{
public:
    AbstractWebSocketSupport(ByteCodeRunner *Runner);

    void onClose(int callbacksKey, int closeCode, unicode_string reason, bool wasClean);
    void onError(int callbacksKey, unicode_string error);
    void onMessage(int callbacksKey, unicode_string message);
    void onOpen(int callbacksKey);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
private:

    struct WebSocketCallbacksRoot {
        int onClose, onError, onMessage, onOpen;
        WebSocketCallbacksRoot();
        WebSocketCallbacksRoot(int onClose, int onError, int onMessage, int onOpen);
    };

    typedef STL_HASH_MAP<int, WebSocketCallbacksRoot> T_WebSocketCallbacksRoots;
    T_WebSocketCallbacksRoots CallbackRoots;
    int nCallbackRoots;

    virtual StackSlot doOpen(unicode_string url, int callbacksKey) { return StackSlot::MakeVoid(); }
    virtual StackSlot doSend(StackSlot websocket, unicode_string message) { return StackSlot::MakeVoid(); }
    virtual StackSlot doHasBufferedData(StackSlot websocket) { return StackSlot::MakeVoid(); }
    virtual void doClose(StackSlot websocket, int code, unicode_string reason) {}

    DECLARE_NATIVE_METHOD(open)
    DECLARE_NATIVE_METHOD(send)
    DECLARE_NATIVE_METHOD(hasBufferedData)
    DECLARE_NATIVE_METHOD(close)
};

#endif // ABSTRACTWEBSOCKETSUPPORT_H
