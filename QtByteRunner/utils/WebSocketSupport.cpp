#include "WebSocketSupport.h"

#include "core/RunnerMacros.h"

WebSocketSupport::WebSocketSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{

}

NativeFunction *WebSocketSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "WebSocketSupport."

    TRY_USE_NATIVE_METHOD(WebSocketSupport, open, 5);

    TRY_USE_NATIVE_METHOD(WebSocketSupport, send, 2);

    TRY_USE_NATIVE_METHOD(WebSocketSupport, close, 3);

    TRY_USE_NATIVE_METHOD(WebSocketSupport, hasBufferedData, 1);

    return NULL;
}

StackSlot WebSocketSupport::open(RUNNER_ARGS)
{
    RUNNER_PopArgs1(url);
    RUNNER_CheckTag1(TString, url);

    int cbOnCloseRoot = RUNNER->RegisterRoot(RUNNER_ARG(1));
    int cbOnErrorRoot = RUNNER->RegisterRoot(RUNNER_ARG(2));
    int cbOnMessageRoot = RUNNER->RegisterRoot(RUNNER_ARG(3));
    int cbOnOpenRoot = RUNNER->RegisterRoot(RUNNER_ARG(4));

    return doOpen(RUNNER->GetString(url), cbOnCloseRoot, cbOnErrorRoot, cbOnMessageRoot, cbOnOpenRoot);
}

StackSlot WebSocketSupport::send(RUNNER_ARGS)
{
    RUNNER_PopArgs2(websocket, message);
    RUNNER_CheckTag1(TNative, websocket);
    RUNNER_CheckTag1(TString, message);

    return doSend(websocket, RUNNER->GetString(message));
}

StackSlot WebSocketSupport::close(RUNNER_ARGS)
{
    RUNNER_PopArgs3(websocket, code, reason);
    RUNNER_CheckTag1(TNative, websocket);
    RUNNER_CheckTag1(TInt, code);
    RUNNER_CheckTag1(TString, reason);

    doClose(websocket, code.GetInt(), RUNNER->GetString(reason));

    RETVOID;
}


StackSlot WebSocketSupport::hasBufferedData(RUNNER_ARGS)
{
    RUNNER_PopArgs1(websocket);
    RUNNER_CheckTag1(TNative, websocket);

    return doHasBufferedData(websocket);
}
