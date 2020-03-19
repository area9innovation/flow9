#ifndef PRINTINGSUPPORT_H
#define PRINTINGSUPPORT_H

#include "core/ByteCodeRunner.h"

class PrintingSupport : public NativeMethodHost
{
public:
    PrintingSupport(ByteCodeRunner *Runner);
protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
private:

    virtual void doPrintHTMLDocument(unicode_string html) {}
    virtual void doPrintDocumentFromURL(unicode_string url) {}

    DECLARE_NATIVE_METHOD(printHTMLDocument)
    DECLARE_NATIVE_METHOD(printDocumentFromURL)
};


#endif // PRINTINGSUPPORT_H
