#ifndef ABSTRACT_APPLE_STORE_PURCHASE_H
#define ABSTRACT_APPLE_STORE_PURCHASE_H

#include "core/ByteCodeRunner.h"

typedef STL_HASH_MAP<unicode_string, StackSlot> T_Callbacks;
typedef std::pair<unicode_string, StackSlot> T_CallbackPair;

class AbstractInAppPurchase : public NativeMethodHost {
public:
    AbstractInAppPurchase(ByteCodeRunner *owner);
    
    virtual void loadProductsInfo(std::vector<unicode_string> str) {};
    virtual unicode_string getLocalePrice(double price, unicode_string locale) { return unicode_string(); }
    
    virtual void paymentRequest(unicode_string _id, int count) {};
    virtual void restoreRequest() {};
    
    virtual void callbackProduct(unicode_string _id, unicode_string title, unicode_string description, double price, unicode_string priceLocale);
    virtual void callbackPayment(unicode_string _id, unicode_string status, unicode_string errorMsg);
    virtual void callbackRestore(unicode_string _id, int quantity, unicode_string errorMsg);
    
protected:
    ByteCodeRunner * _owner;
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
    
    T_Callbacks loadCallbacks;
    T_Callbacks purchaseCallbacks;
    StackSlot restoreCallback;
private:
    DECLARE_NATIVE_METHOD(loadPurchaseProductInfo);
    
    DECLARE_NATIVE_METHOD(getLocalePriceString);
    DECLARE_NATIVE_METHOD(proceedPaymentRequest);
    
    DECLARE_NATIVE_METHOD(restorePurchasedProducts);
};

#endif
