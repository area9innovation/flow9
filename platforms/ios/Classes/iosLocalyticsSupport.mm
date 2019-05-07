#import <Foundation/Foundation.h>

#import "iosLocalyticsSupport.h"
#import "utils.h"

#ifdef LOCALYTICS_APP_KEY
#import <Localytics/Localytics.h>
#endif

void iosLocalyticsSupport::doTagEventWithAttributes(const unicode_string &event_name, const std::map<unicode_string, unicode_string> &event_attributes) {
#ifdef LOCALYTICS_APP_KEY
    [Localytics tagEvent: UNICODE2NS(event_name) attributes: dictionaryFromStdMap(event_attributes)];
#else
    LogW(@"Trying to track Localytics events without setting LOCALYTICS_APP_KEY in the build settings");
#endif
}
