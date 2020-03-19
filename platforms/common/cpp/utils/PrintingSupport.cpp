#include "PrintingSupport.h"

#include "core/RunnerMacros.h"

PrintingSupport::PrintingSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{

}

NativeFunction *PrintingSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "PrintingSupport."

    TRY_USE_NATIVE_METHOD(PrintingSupport, printHTMLDocument, 1);
    TRY_USE_NATIVE_METHOD(PrintingSupport, printDocumentFromURL, 1);

    return NULL;
}

StackSlot PrintingSupport::printHTMLDocument(RUNNER_ARGS)
{
    doPrintHTMLDocument(RUNNER->GetString(RUNNER_ARG(0)));
    RETVOID;
}

StackSlot PrintingSupport::printDocumentFromURL(RUNNER_ARGS)
{
    doPrintDocumentFromURL(RUNNER->GetString(RUNNER_ARG(0)));
    RETVOID;
}
