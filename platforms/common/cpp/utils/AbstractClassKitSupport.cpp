//
//  AbstractClassKitSupport.cpp
//  flow
//
//  Created by Ivan Vereschaga on 07.07.2020.
//
#include "AbstractClassKitSupport.h"

AbstractClassKitSupport::AbstractClassKitSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{
}

NativeFunction *AbstractClassKitSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "ClassKitSupport."
    
    TRY_USE_NATIVE_METHOD(AbstractClassKitSupport, setupContext, 5);
    TRY_USE_NATIVE_METHOD(AbstractClassKitSupport, startContextActivity, 1);

    TRY_USE_NATIVE_METHOD(AbstractClassKitSupport, addAdditionalBinaryItem, 3);
    TRY_USE_NATIVE_METHOD(AbstractClassKitSupport, addAdditionalScoreItem, 4);
    TRY_USE_NATIVE_METHOD(AbstractClassKitSupport, addAdditionalQuantityItem, 3);
    
    TRY_USE_NATIVE_METHOD(AbstractClassKitSupport, setPrimaryScoreItem, 4);

    TRY_USE_NATIVE_METHOD(AbstractClassKitSupport, endContextActivity, 2);

    return NULL;
}

StackSlot AbstractClassKitSupport::setupContext(RUNNER_ARGS)
{
    RUNNER_PopArgs5(identifier, title, type, onOK, onError);
    RUNNER_CheckTag3(TString, identifier, title, type);
    
    int onOKRoot = RUNNER->RegisterRoot(onOK);
    int onErrorRoot = RUNNER->RegisterRoot(onError);
    
    std::function<void()> onOKFn = [RUNNER, onOKRoot, onErrorRoot]() {
        RUNNER->EvalFunction(RUNNER->LookupRoot(onOKRoot), 0);
        RUNNER->ReleaseRoot(onOKRoot);
        RUNNER->ReleaseRoot(onErrorRoot);
    };
    
    std::function<void(unicode_string)> onErrorFn = [RUNNER, onOKRoot, onErrorRoot](unicode_string error) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, RUNNER->AllocateString(error));
        RUNNER->ReleaseRoot(onOKRoot);
        RUNNER->ReleaseRoot(onErrorRoot);
    };
    
    doSetupContext(RUNNER->GetString(identifier), RUNNER->GetString(title), RUNNER->GetString(type), onOKFn, onErrorFn);
    RETVOID;
}

StackSlot AbstractClassKitSupport::startContextActivity(RUNNER_ARGS)
{
    RUNNER_PopArgs1(identifier);
    RUNNER_CheckTag1(TString, identifier);

    doStartContextActivity(RUNNER->GetString(identifier));
    RETVOID;
}

StackSlot AbstractClassKitSupport::addAdditionalBinaryItem(RUNNER_ARGS)
{
    RUNNER_PopArgs3(identifier, title, value);
    RUNNER_CheckTag2(TString, identifier, title);
    RUNNER_CheckTag1(TBool, value);

    doAddAdditionalBinaryItem(RUNNER->GetString(identifier), RUNNER->GetString(title), value.GetBool());
    RETVOID;
}

StackSlot AbstractClassKitSupport::addAdditionalScoreItem(RUNNER_ARGS)
{
    RUNNER_PopArgs4(identifier, title, score, maxScore);
    RUNNER_CheckTag2(TString, identifier, title);
    RUNNER_CheckTag2(TDouble, score, maxScore);

    doAddAdditionalScoreItem(RUNNER->GetString(identifier), RUNNER->GetString(title), score.GetDouble(), maxScore.GetDouble());
    RETVOID;
}

StackSlot AbstractClassKitSupport::addAdditionalQuantityItem(RUNNER_ARGS)
{
    RUNNER_PopArgs3(identifier, title, quantity);
    RUNNER_CheckTag2(TString, identifier, title);
    RUNNER_CheckTag1(TDouble, quantity);

    doAddAdditionalQuantityItem(RUNNER->GetString(identifier), RUNNER->GetString(title), quantity.GetDouble());
    RETVOID;
}

StackSlot AbstractClassKitSupport::setPrimaryScoreItem(RUNNER_ARGS)
{
    RUNNER_PopArgs4(identifier, title, score, maxScore);
    RUNNER_CheckTag2(TString, identifier, title);
    RUNNER_CheckTag2(TDouble, score, maxScore);

    doSetPrimaryScoreItem(RUNNER->GetString(identifier), RUNNER->GetString(title), score.GetDouble(), maxScore.GetDouble());
    RETVOID;
}

StackSlot AbstractClassKitSupport::endContextActivity(RUNNER_ARGS)
{
    RUNNER_PopArgs2(onOK, onError);

    int onOKRoot = RUNNER->RegisterRoot(onOK);
    int onErrorRoot = RUNNER->RegisterRoot(onError);

    std::function<void()> onOKFn = [RUNNER, onOKRoot, onErrorRoot]() {
        RUNNER->EvalFunction(RUNNER->LookupRoot(onOKRoot), 0);
        RUNNER->ReleaseRoot(onOKRoot);
        RUNNER->ReleaseRoot(onErrorRoot);
    };

    std::function<void(unicode_string)> onErrorFn = [RUNNER, onOKRoot, onErrorRoot](unicode_string error) {
       RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, RUNNER->AllocateString(error));
       RUNNER->ReleaseRoot(onOKRoot);
       RUNNER->ReleaseRoot(onErrorRoot);
    };

    doEndContextActivity(onOKFn, onErrorFn);
    RETVOID;
}
