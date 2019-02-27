#include "QtTimerSupport.h"
#include "core/RunnerMacros.h"

QtTimerSupport::QtTimerSupport(ByteCodeRunner *Runner)
    : NativeMethodHost(Runner), Runner(Runner)
{
}

NativeFunction *QtTimerSupport::MakeNativeFunction(const char *name, int num_args)
{
    #undef NATIVE_NAME_PREFIX
    #define NATIVE_NAME_PREFIX "Native."
    TRY_USE_NATIVE_METHOD_NAME(QtTimerSupport, Timer, "timer", 2);

    return nullptr;
}

void QtTimerSupport::timerEvent(QTimerEvent *event)
{
    int id = event->timerId();

    killTimer(id);

    if (TimersMap.contains(id))
    {
        int root = TimersMap[id];

        TimersMap.remove(id);

        WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

        StackSlot cb = Runner->LookupRoot(root);
        Runner->ReleaseRoot(root); // One timeout only
        if (!cb.IsVoid())
    	    Runner->EvalFunction(cb, 0);

        getFlowRunner()->NotifyHostEvent(HostEventTimer);
    }
}

StackSlot QtTimerSupport::Timer(RUNNER_ARGS)
{
    InterruptibleTimer(RUNNER, pRunnerArgs__);

    RETVOID;
}

StackSlot QtTimerSupport::InterruptibleTimer(RUNNER_ARGS)
{
    RUNNER_PopArgs2(time_ms, cb);
    RUNNER_CheckTag(TInt, time_ms);

    if (time_ms.GetInt() <= 5) {
        RUNNER->AddDeferredAction(cb);
        return RUNNER->AllocateNativeClosure(ByteCodeRunner::RemoveDeferredAction, "InterruptibleTimer$disposer", 0, nullptr, 1, &static_cast<StackSlot const&>(cb));
    } else {
        int cbroot = RUNNER->RegisterRoot(cb);
        int id = startTimer(time_ms.GetInt());
        TimersMap[id] = cbroot;
        return RUNNER->AllocateNativeClosure(KillTimer, "InterruptibleTimer$disposer", 0, this, 1, id);
    }

    RETVOID;
}

StackSlot QtTimerSupport::KillTimer(RUNNER_ARGS, void *data)
{
    RUNNER_PopArgs1(id);
    RUNNER_CheckTag(TInt, id);

    QtTimerSupport *instance = reinterpret_cast<QtTimerSupport*>(data);
    instance->killTimer(id.GetInt());

    RETVOID;
}
