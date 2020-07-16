//
//  AbstractClassKitSupport.h
//  flow
//
//  Created by Ivan Vereschaga on 07.07.2020.
//

#ifndef AbstractClassKitSupport_h
#define AbstractClassKitSupport_h

#include "core/ByteCodeRunner.h"
#include "core/RunnerMacros.h"

class AbstractClassKitSupport : public NativeMethodHost
{
public:
    AbstractClassKitSupport(ByteCodeRunner *Runner);

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
private:


    DECLARE_NATIVE_METHOD(setupContext)
    DECLARE_NATIVE_METHOD(startContextActivity)
    DECLARE_NATIVE_METHOD(addAdditionalBinaryItem)
    DECLARE_NATIVE_METHOD(addAdditionalScoreItem)
    DECLARE_NATIVE_METHOD(addAdditionalQuantityItem)
    DECLARE_NATIVE_METHOD(setPrimaryScoreItem)
    DECLARE_NATIVE_METHOD(endContextActivity)
    
    
    virtual void doSetupContext(unicode_string /*identifier*/, unicode_string /*title*/, unicode_string /*type*/, std::function<void()> /*onOK*/, std::function<void(unicode_string)> /*onError*/) {}
    virtual void doStartContextActivity(unicode_string /*identifier*/) {}
    virtual void doAddAdditionalBinaryItem(unicode_string /*identifier*/, unicode_string /*title*/, bool /*value*/) {}
    virtual void doAddAdditionalScoreItem(unicode_string /*identifier*/, unicode_string /*title*/, double /*score*/, double /*maxScore*/) {}
    virtual void doAddAdditionalQuantityItem(unicode_string /*identifier*/, unicode_string /*title*/, double /*quantity*/) {}
    virtual void doSetPrimaryScoreItem(unicode_string /*identifier*/, unicode_string /*title*/, double /*score*/, double /*maxScore*/) {}
    virtual void doEndContextActivity(std::function<void()> /*onOK*/, std::function<void(unicode_string)> /*onError*/) {}
};

#endif /* AbstractClassKitSupport_h */
