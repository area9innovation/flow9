#include "QtQuitSupport.h"
#include "core/RunnerMacros.h"

QtQuitSupport::QtQuitSupport(ByteCodeRunner *Runner)
    : NativeMethodHost(Runner), Runner(Runner)
{
}

NativeFunction *QtQuitSupport::MakeNativeFunction(const char *name, int num_args)
{
    #undef NATIVE_NAME_PREFIX
    #define NATIVE_NAME_PREFIX "Native."
    TRY_USE_NATIVE_METHOD_NAME(QtQuitSupport, quit, "quit", 1);

    return nullptr;
}

StackSlot QtQuitSupport::quit(RUNNER_ARGS)
{
    RUNNER_PopArgs1(rawcode);
    RUNNER_CheckTag(TInt, rawcode);
    int exitCode = rawcode.GetInt();
	exit(exitCode);
    RETVOID;
}
