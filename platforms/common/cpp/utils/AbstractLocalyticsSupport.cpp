#include "AbstractLocalyticsSupport.h"
#include "core/RunnerMacros.h"

AbstractLocalyticsSupport::AbstractLocalyticsSupport(ByteCodeRunner *owner)
: NativeMethodHost(owner) {
    
}

NativeFunction * AbstractLocalyticsSupport::MakeNativeFunction(const char *name, int num_args) {
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "LocalyticsSupport."
    
    TRY_USE_NATIVE_METHOD(AbstractLocalyticsSupport, tagEventWithAttributes, 2);
    return NULL;
}

StackSlot AbstractLocalyticsSupport::tagEventWithAttributes(RUNNER_ARGS) {
    RUNNER_PopArgs2(event_name, event_attributes);
    RUNNER_CheckTag(TString, event_name);
    RUNNER_CheckTag(TArray, event_attributes);
    
    std::map<unicode_string, unicode_string> attributes_map;
    for (int i = 0; i < RUNNER->GetArraySize(event_attributes); i++) {
        const StackSlot & attributes_item = RUNNER->GetArraySlot(event_attributes,i);
        RUNNER_CheckTag(TArray, attributes_item);
        
        unicode_string key = RUNNER->GetString(RUNNER->GetArraySlot(attributes_item,0));
        unicode_string value = RUNNER->GetString(RUNNER->GetArraySlot(attributes_item,1));
        attributes_map[key] = value;
    }
    
    doTagEventWithAttributes(RUNNER->GetString(event_name), attributes_map);
    
    RETVOID;
}
