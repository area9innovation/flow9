#ifndef iosPrintingSupport_h
#define iosPrintingSupport_h

#include "ByteCodeRunner.h"
#include "printingsupport.h"


class iosPrintingSupport : public PrintingSupport
{
public:
    iosPrintingSupport(ByteCodeRunner *runner);
    
protected:
    void doPrintHTMLDocument(unicode_string html);
    void doPrintDocumentFromURL(unicode_string url);

};

#endif /* iosPrintingSupport_h */
