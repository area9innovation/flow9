#ifndef APPLE_STORE_PURCHASE_H
#define APPLE_STORE_PURCHASE_H

#include "ByteCodeRunner.h"
#include "AbstractInAppPurchase.h"

#import <StoreKit/StoreKit.h>

class AppleStorePurchase;


@interface ProductsRequestDelegate : NSObject<SKProductsRequestDelegate> {
@private
    AppleStorePurchase * _owner;
}

- (id)initWithOwner:(AppleStorePurchase *)owner;
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response;
@end



@interface PaymentTransactionObserver : NSObject<SKPaymentTransactionObserver> {
@private
    AppleStorePurchase * _owner;
}

- (id)initWithOwner:(AppleStorePurchase *)owner;
- (void)paymentQueue:(SKPaymentQueue *)queue
 updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
@end



class AppleStorePurchase : AbstractInAppPurchase {
public:
    AppleStorePurchase(ByteCodeRunner *Runner);
    void callbackProduct(unicode_string _id, unicode_string title, unicode_string description, double price, unicode_string priceLocale);
    void callbackPayment(unicode_string _id, unicode_string status, unicode_string errorMsg);
    void callbackRestore(unicode_string _id, int quantity, unicode_string errorMsg);
    
    void setProduct(SKProduct * product);

protected:
    void loadProductsInfo(std::vector<unicode_string> pids);
    unicode_string getLocalePrice(double price, unicode_string locale);
    
    void paymentRequest(unicode_string _id, int count);
    void restoreRequest();

private:
    SKPaymentQueue *paymentQueue;
    STL_HASH_MAP<unicode_string, SKProduct *> products;
    ProductsRequestDelegate *requestDelegate;
    SKProductsRequest* request;
};

#endif /* AppleStorePurchase_h */
