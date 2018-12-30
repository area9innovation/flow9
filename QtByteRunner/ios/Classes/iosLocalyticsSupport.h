#include "ByteCodeRunner.h"
#include "RunnerMacros.h"
#import "AbstractLocalyticsSupport.h"

class iosLocalyticsSupport : public AbstractLocalyticsSupport
{
public:
    iosLocalyticsSupport(ByteCodeRunner *Runner) : AbstractLocalyticsSupport(Runner) {}
protected:
    void doTagEventWithAttributes(const unicode_string &event_name, const std::map<unicode_string, unicode_string> &event_attributes);
};
