
#include <QThread>
#include "QtNatives.h"
#include "core/RunnerMacros.h"

QtNatives::QtNatives(ByteCodeRunner *Runner)
    : NativeMethodHost(Runner), Runner(Runner)
{
}

NativeFunction *QtNatives::MakeNativeFunction(const char *name, int num_args)
{
    #undef NATIVE_NAME_PREFIX
    #define NATIVE_NAME_PREFIX "Native."
    TRY_USE_NATIVE_METHOD_NAME(QtNatives, quit, "quit", 1);
	TRY_USE_NATIVE_METHOD_NAME(QtNatives, availableProcessors, "availableProcessors", 0);

    return nullptr;
}

StackSlot QtNatives::quit(RUNNER_ARGS)
{
    RUNNER_PopArgs1(rawcode);
    RUNNER_CheckTag(TInt, rawcode);
    int exitCode = rawcode.GetInt();
	exit(exitCode);
    RETVOID;
}

StackSlot QtNatives::availableProcessors(RUNNER_ARGS)
{
	IGNORE_RUNNER_ARGS;
	return StackSlot::MakeInt(QThread::idealThreadCount());
}
