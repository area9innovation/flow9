#include "AbstractGeolocationSupport.h"

#include "core/RunnerMacros.h"

#include <stdlib.h>

AbstractGeolocationSupport::AbstractGeolocationSupport(ByteCodeRunner *owner) : NativeMethodHost(owner)
{
    nCallbackRoots = 0;
}

NativeFunction *AbstractGeolocationSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "GeolocationSupport."

    TRY_USE_NATIVE_METHOD(AbstractGeolocationSupport, geolocationGetCurrentPosition, 8);
    TRY_USE_NATIVE_METHOD(AbstractGeolocationSupport, geolocationWatchPosition, 8);

    return NULL;
}

void AbstractGeolocationSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);
}

void AbstractGeolocationSupport::flowGCObject(GarbageCollectorFn ref)
{
}

void AbstractGeolocationSupport::executeOnOkCallback(int callbacksRoot, bool removeAfterCall,
                         double latitude, double longitude, double altitude,
                         double accuracy, double altitudeAccuracy,
                         double heading , double speed, double time)
{
    RUNNER_VAR = getFlowRunner();
    T_GeolocationCallbackRoots::iterator itCallbackRoots = CallbackRoots.find(callbacksRoot);
    if (itCallbackRoots == CallbackRoots.end()) return;
    RUNNER->EvalFunction(RUNNER->LookupRoot((itCallbackRoots->second).onOkCbRoot), 8,
         StackSlot::MakeDouble(latitude), StackSlot::MakeDouble(longitude), StackSlot::MakeDouble(altitude),
         StackSlot::MakeDouble(accuracy), StackSlot::MakeDouble(altitudeAccuracy),
         StackSlot::MakeDouble(heading), StackSlot::MakeDouble(speed), StackSlot::MakeDouble(time)
    );
    if (removeAfterCall)
    {
        this->removeCallbackRoots(callbacksRoot);
    }
}

void AbstractGeolocationSupport::executeOnErrorCallback(int callbacksRoot, bool removeAfterCall, int code, std::string message)
{
    RUNNER_VAR = getFlowRunner();
    T_GeolocationCallbackRoots::iterator itCallbackRoots = CallbackRoots.find(callbacksRoot);
    if (itCallbackRoots == CallbackRoots.end()) return;
    const StackSlot &message_str = RUNNER->AllocateString(parseUtf8(message));
    RUNNER->EvalFunction(RUNNER->LookupRoot((itCallbackRoots->second).onErrorCbRoot), 2,
        StackSlot::MakeInt(code), message_str
    );
    if (removeAfterCall)
    {
        this->removeCallbackRoots(callbacksRoot);
    }
}

void AbstractGeolocationSupport::removeCallbackRoots(int callbacksRoot)
{
    RUNNER_VAR = getFlowRunner();
    T_GeolocationCallbackRoots::iterator itCallbackRoots = CallbackRoots.find(callbacksRoot);
    if (itCallbackRoots != CallbackRoots.end())
    {
        RUNNER->ReleaseRoot((itCallbackRoots->second).onOkCbRoot);
        RUNNER->ReleaseRoot((itCallbackRoots->second).onErrorCbRoot);
        this->ReleaseRoot(callbacksRoot);
    }
}

int AbstractGeolocationSupport::RegisterRoot(GeolocationCallbacksRoot geolocationCallbacksRoot)
{
    int n = nCallbackRoots++;
    CallbackRoots[n] = geolocationCallbacksRoot;
    return n;
}

void AbstractGeolocationSupport::ReleaseRoot(int i)
{
    CallbackRoots.erase(i);
}

StackSlot AbstractGeolocationSupport::geolocationGetCurrentPosition(RUNNER_ARGS)
{
    RUNNER_PopArgs8(onOkCb, onErrorCb, enableHighAccuracy, timeout, maximumAge, turnOnGeolocationMessage, okButtonText, cancelButtonText);
    RUNNER_CheckTag(TBool, enableHighAccuracy);
    RUNNER_CheckTag2(TDouble, timeout, maximumAge);
    RUNNER_CheckTag3(TString, turnOnGeolocationMessage, okButtonText, cancelButtonText);
    int callbacksRoot = this->RegisterRoot(GeolocationCallbacksRoot(RUNNER->RegisterRoot(onOkCb), RUNNER->RegisterRoot(onErrorCb)));
    doGeolocationGetCurrentPosition(callbacksRoot, enableHighAccuracy.GetBool(), timeout.GetDouble(), maximumAge.GetDouble(),
                                    encodeUtf8(RUNNER->GetString(turnOnGeolocationMessage)), encodeUtf8(RUNNER->GetString(okButtonText)), encodeUtf8(RUNNER->GetString(cancelButtonText)));
    RETVOID;
}

StackSlot AbstractGeolocationSupport::removeGeolocationWatchPosition(RUNNER_ARGS, void * data)
{
    AbstractGeolocationSupport *self = (AbstractGeolocationSupport*)data;
    int callbacksRoot = RUNNER->GetClosureSlot(RUNNER_CLOSURE, 0).GetInt();
    self->removeCallbackRoots(callbacksRoot);
    self->afterWatchDispose(callbacksRoot);
    RETVOID;
}

StackSlot AbstractGeolocationSupport::geolocationWatchPosition(RUNNER_ARGS)
{
    RUNNER_PopArgs8(onOkCb, onErrorCb, enableHighAccuracy, timeout, maximumAge, turnOnGeolocationMessage, okButtonText, cancelButtonText);
    RUNNER_CheckTag(TBool, enableHighAccuracy);
    RUNNER_CheckTag2(TDouble, timeout, maximumAge);
    RUNNER_CheckTag3(TString, turnOnGeolocationMessage, okButtonText, cancelButtonText);
    int callbacksRoot = this->RegisterRoot(GeolocationCallbacksRoot(RUNNER->RegisterRoot(onOkCb), RUNNER->RegisterRoot(onErrorCb)));

    doGeolocationWatchPosition(callbacksRoot, enableHighAccuracy.GetBool(), timeout.GetDouble(), maximumAge.GetDouble(),
                               encodeUtf8(RUNNER->GetString(turnOnGeolocationMessage)), encodeUtf8(RUNNER->GetString(okButtonText)), encodeUtf8(RUNNER->GetString(cancelButtonText)));

    return RUNNER->AllocateNativeClosure(removeGeolocationWatchPosition, "geolocationWatchPosition$disposer", 0, this,
        1, StackSlot::MakeInt(callbacksRoot));
}
