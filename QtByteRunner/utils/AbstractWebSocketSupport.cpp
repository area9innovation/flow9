#include "AbstractWebSocketSupport.h"

#include "core/RunnerMacros.h"

AbstractWebSocketSupport::AbstractWebSocketSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{
    nCallbackRoots = 0;
}
AbstractWebSocketSupport::WebSocketCallbacksRoot::WebSocketCallbacksRoot()
    : onClose(-1),  onError(-1), onMessage(-1), onOpen(-1)
{
}

AbstractWebSocketSupport::WebSocketCallbacksRoot::WebSocketCallbacksRoot(int onClose, int onError, int onMessage, int onOpen)
    : onClose(onClose),  onError(onError), onMessage(onMessage), onOpen(onOpen)
{
}

NativeFunction *AbstractWebSocketSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "WebSocketSupport."

    TRY_USE_NATIVE_METHOD(AbstractWebSocketSupport, open, 5);

    TRY_USE_NATIVE_METHOD(AbstractWebSocketSupport, send, 2);

    TRY_USE_NATIVE_METHOD(AbstractWebSocketSupport, hasBufferedData, 1);

    TRY_USE_NATIVE_METHOD(AbstractWebSocketSupport, close, 3);

    return NULL;
}

StackSlot AbstractWebSocketSupport::open(RUNNER_ARGS)
{
    RUNNER_PopArgs1(url);
    RUNNER_CheckTag1(TString, url);

    int cbOnCloseRoot = RUNNER->RegisterRoot(RUNNER_ARG(1));
    int cbOnErrorRoot = RUNNER->RegisterRoot(RUNNER_ARG(2));
    int cbOnMessageRoot = RUNNER->RegisterRoot(RUNNER_ARG(3));
    int cbOnOpenRoot = RUNNER->RegisterRoot(RUNNER_ARG(4));

    int key = nCallbackRoots++;
    CallbackRoots[key] = AbstractWebSocketSupport::WebSocketCallbacksRoot(cbOnCloseRoot, cbOnErrorRoot, cbOnMessageRoot, cbOnOpenRoot);

    return doOpen(RUNNER->GetString(url), key);
}

StackSlot AbstractWebSocketSupport::send(RUNNER_ARGS)
{
    RUNNER_PopArgs2(websocket, message);
    RUNNER_CheckTag1(TNative, websocket);
    RUNNER_CheckTag1(TString, message);

    return doSend(websocket, RUNNER->GetString(message));
}

StackSlot AbstractWebSocketSupport::hasBufferedData(RUNNER_ARGS)
{
    RUNNER_PopArgs1(websocket);
    RUNNER_CheckTag1(TNative, websocket);

    return doHasBufferedData(websocket);
}

StackSlot AbstractWebSocketSupport::close(RUNNER_ARGS)
{
    RUNNER_PopArgs3(websocket, code, reason);
    RUNNER_CheckTag1(TNative, websocket);
    RUNNER_CheckTag1(TInt, code);
    RUNNER_CheckTag1(TString, reason);

    doClose(websocket, code.GetInt(), RUNNER->GetString(reason));

    RETVOID;
}

void AbstractWebSocketSupport::onClose(int callbacksKey, int closeCode, unicode_string reason, bool wasClean)
{
    RUNNER_VAR = getFlowRunner();
    WebSocketCallbacksRoot callbacksRoot = CallbackRoots[callbacksKey];
    RUNNER->EvalFunction(RUNNER->LookupRoot(callbacksRoot.onClose), 3,
                         StackSlot::MakeInt(closeCode), RUNNER->AllocateString(reason), StackSlot::MakeBool(wasClean));

    RUNNER->ReleaseRoot(callbacksRoot.onClose);
    RUNNER->ReleaseRoot(callbacksRoot.onError);
    RUNNER->ReleaseRoot(callbacksRoot.onMessage);
    RUNNER->ReleaseRoot(callbacksRoot.onOpen);

    CallbackRoots.erase(callbacksKey);
}

void AbstractWebSocketSupport::onError(int callbacksKey, unicode_string error)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(CallbackRoots[callbacksKey].onError), 1, RUNNER->AllocateString(error));
}

void AbstractWebSocketSupport::onMessage(int callbacksKey, unicode_string message)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(CallbackRoots[callbacksKey].onMessage), 1, RUNNER->AllocateString(message));
}

void AbstractWebSocketSupport::onOpen(int callbacksKey)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER->EvalFunction(RUNNER->LookupRoot(CallbackRoots[callbacksKey].onOpen), 0);
}
