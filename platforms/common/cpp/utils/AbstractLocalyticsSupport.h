#ifndef ABSTRACT_LOCALYTICS_SUPPORT_H
#define ABSTRACT_LOCALYTICS_SUPPORT_H

#include "core/ByteCodeRunner.h"

std::string urlEscapePath(std::string path);
bool endsWithAsterisk(std::string str);

class AbstractLocalyticsSupport : public NativeMethodHost {
public:
    AbstractLocalyticsSupport(ByteCodeRunner *owner);
    
protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
    virtual void doTagEventWithAttributes(const unicode_string &event_name, const std::map<unicode_string, unicode_string> &event_attributes) {}
private:
    DECLARE_NATIVE_METHOD(tagEventWithAttributes);
};

#endif // ABSTRACT_LOCALYTICS_SUPPORT_H
