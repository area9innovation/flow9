#include "iosPrintingSupport.h"

#include "RunnerMacros.h"
#import "utils.h"


iosPrintingSupport::iosPrintingSupport(ByteCodeRunner *runner) : PrintingSupport(runner)
{
}

void iosPrintingSupport::doPrintHTMLDocument(unicode_string html) {
    NSString* printContents = UNICODE2NS(html);
    UIMarkupTextPrintFormatter *text = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:printContents];
    
    UIPrintInteractionController* printController = [UIPrintInteractionController sharedPrintController];
    if (printController) {
        [printController setPrintFormatter:text];
        [printController presentAnimated:YES completionHandler:^(UIPrintInteractionController *printInteractionController, BOOL completed, NSError *error) {}];
    }
}

void iosPrintingSupport::doPrintDocumentFromURL(unicode_string url) {
    NSURL* sourceUrl = [NSURL URLWithString:UNICODE2NS(url)];
    UIPrintInteractionController *printController = [UIPrintInteractionController sharedPrintController];
    if (printController && [UIPrintInteractionController canPrintURL:sourceUrl] ) {
        printController.printingItem = sourceUrl;
        [printController presentAnimated:YES completionHandler:^(UIPrintInteractionController *printInteractionController, BOOL completed, NSError *error) {}];
    }
}
