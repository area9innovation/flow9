#include "AbstractInAppPurchase.h"
#include "core/RunnerMacros.h"

#include <stdio.h>
#include <sys/types.h>

AbstractInAppPurchase::AbstractInAppPurchase(ByteCodeRunner *owner) : NativeMethodHost(owner) {
    _owner = owner;
    restoreCallback = StackSlot::MakeVoid();
}

NativeFunction * AbstractInAppPurchase::MakeNativeFunction(const char *name, int num_args) {
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "AppPurchases."
    TRY_USE_NATIVE_METHOD(AbstractInAppPurchase, loadPurchaseProductInfo, 2);
    TRY_USE_NATIVE_METHOD(AbstractInAppPurchase, getLocalePriceString, 2);
    TRY_USE_NATIVE_METHOD(AbstractInAppPurchase, proceedPaymentRequest, 3);
    TRY_USE_NATIVE_METHOD(AbstractInAppPurchase, restorePurchasedProducts, 1);
    return NULL;
}

void AbstractInAppPurchase::callbackProduct(unicode_string _id, unicode_string title, unicode_string description, double price, unicode_string priceLocale) {
    StackSlot cb = safeMapAt(loadCallbacks, _id, StackSlot::MakeVoid());
    
    if (!cb.IsVoid()) {
        _owner->EvalFunction(cb, 5, _owner->AllocateString(_id),
                                    _owner->AllocateString(title),
                                    _owner->AllocateString(description),
                                    StackSlot::MakeDouble(price),
                                    _owner->AllocateString(priceLocale));
    }
}

void AbstractInAppPurchase::callbackPayment(unicode_string _id, unicode_string status, unicode_string errorMsg) {
    StackSlot cb = safeMapAt(purchaseCallbacks, _id, StackSlot::MakeVoid());
    
    if (!cb.IsVoid()) {
        _owner->EvalFunction(cb, 3, _owner->AllocateString(_id),
                                    _owner->AllocateString(status),
                                    _owner->AllocateString(errorMsg));
    }
}

void AbstractInAppPurchase::callbackRestore(unicode_string _id, int quantity, unicode_string errorMsg) {
    if (!restoreCallback.IsVoid()) {
        _owner->EvalFunction(restoreCallback, 3, _owner->AllocateString(_id),
                                                 StackSlot::MakeInt(quantity),
                                                 _owner->AllocateString(errorMsg));
    }
}

StackSlot AbstractInAppPurchase::loadPurchaseProductInfo(RUNNER_ARGS) {
    RUNNER_PopArgs2(ids, cb);
    RUNNER_CheckTag(TArray, ids);
    
    std::vector<unicode_string> pids;
    
    for (int i = 0; i < RUNNER->GetArraySize(ids); i++) {
        unicode_string id = RUNNER->GetString(RUNNER->GetArraySlot(ids, i));
        
        loadCallbacks.insert(T_CallbackPair(id, cb));
        pids.push_back(id);
    }
    
    loadProductsInfo(pids);
    
    RETVOID;
}

StackSlot AbstractInAppPurchase::getLocalePriceString(RUNNER_ARGS) {
    RUNNER_PopArgs2(_price, _locale);
    RUNNER_CheckTag(TDouble, _price);
    RUNNER_CheckTag(TString, _locale);
    
    unicode_string str = getLocalePrice(_price.GetDouble(), RUNNER->GetString(_locale));
    
    return RUNNER->AllocateString(str);
}

StackSlot AbstractInAppPurchase::proceedPaymentRequest(RUNNER_ARGS) {
    RUNNER_PopArgs3(_id, _count, cb);
    RUNNER_CheckTag(TString, _id);
    RUNNER_CheckTag(TInt, _count);
    
    unicode_string id = RUNNER->GetString(_id);
    
    purchaseCallbacks.insert(T_CallbackPair(id, cb));
    paymentRequest(id, _count.GetInt());
    
    RETVOID;
}

StackSlot AbstractInAppPurchase::restorePurchasedProducts(RUNNER_ARGS) {
    RUNNER_PopArgs1(cb);
    
    restoreCallback = cb;
    restoreRequest();
    
    RETVOID;
}
