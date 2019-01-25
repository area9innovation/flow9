#ifndef WEBSOCKETSUPPORT_H
#define WEBSOCKETSUPPORT_H

#include "core/ByteCodeRunner.h"

class WebSocketSupport : public NativeMethodHost
{
public:
    WebSocketSupport(ByteCodeRunner *Runner);

    void onClose(int cbOnCloseRoot, int closeCode, unicode_string reason, bool wasClean);
    void onError(int cbOnErrorRoot, unicode_string error);
    void onMessage(int cbOnMessageRoot, unicode_string message);
    void onOpen(int cbOnOpenRoot);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
private:
    virtual StackSlot doOpen(unicode_string url, int cbOnCloseRoot, int cbOnErrorRoot, int cbOnMessageRoot, int cbOnOpenRoot) { return StackSlot::MakeVoid(); }
    virtual StackSlot doSend(StackSlot websocket, unicode_string message) { return StackSlot::MakeVoid(); }
    virtual StackSlot doHasBufferedData(StackSlot websocket) { return StackSlot::MakeVoid(); }
    virtual void doClose(StackSlot websocket, int code, unicode_string reason) {}

    DECLARE_NATIVE_METHOD(open)
    DECLARE_NATIVE_METHOD(send)
    DECLARE_NATIVE_METHOD(hasBufferedData)
    DECLARE_NATIVE_METHOD(close)
};

#endif // WEBSOCKETSUPPORT_H
