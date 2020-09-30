//
//  iosClassKitSupport.h
//  flow
//
//  Created by Ivan Vereschaga on 07.07.2020.
//

#ifndef iosClassKitSupport_h
#define iosClassKitSupport_h

#include "ByteCodeRunner.h"
#include "AbstractClassKitSupport.h"

#import <ClassKit/ClassKit.h>

class API_AVAILABLE(ios(11.3)) iosClassKitSupport : public AbstractClassKitSupport
{
    ByteCodeRunner *owner;
public:
    iosClassKitSupport(ByteCodeRunner *runner);

protected:
    virtual void doSetupContext(unicode_string identifier, unicode_string title, unicode_string type, std::function<void()> onOK, std::function<void(unicode_string)> onError);
    virtual void doStartContextActivity(unicode_string identifier);
    virtual void doAddAdditionalBinaryItem(unicode_string identifier, unicode_string title, bool value);
    virtual void doAddAdditionalScoreItem(unicode_string identifier, unicode_string title, double score, double maxScore);
    virtual void doAddAdditionalQuantityItem(unicode_string identifier, unicode_string title, double quantity);
    virtual void doSetPrimaryScoreItem(unicode_string identifier, unicode_string title, double score, double maxScore);
    virtual void doEndContextActivity(std::function<void()> onOK, std::function<void(unicode_string)> onError);
    
private:
    CLSActivity* currentActivity;
    CLSContextType parseContextType(NSString* type);
};

#endif /* iosClassKitSupport_h */
