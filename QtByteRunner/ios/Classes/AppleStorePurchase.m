#import "AppleStorePurchase.h"
#import "utils.h"

#ifdef FLOW_INAPP_PURCHASE
AppleStorePurchase::AppleStorePurchase(ByteCodeRunner *Runner) : AbstractInAppPurchase(Runner) {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[[PaymentTransactionObserver alloc] initWithOwner:this]];
    
    requestDelegate = [[ProductsRequestDelegate alloc] initWithOwner:this];
}

void AppleStorePurchase::callbackProduct(unicode_string _id, unicode_string title, unicode_string description, double price, unicode_string priceLocale) {
    AbstractInAppPurchase::callbackProduct(_id, title, description, price, priceLocale);
}

void AppleStorePurchase::callbackPayment(unicode_string _id, unicode_string status, unicode_string errMessage) {
    AbstractInAppPurchase::callbackPayment(_id, status, errMessage);
}

void AppleStorePurchase::callbackRestore(unicode_string _id, int quantity, unicode_string errMessage) {
    AbstractInAppPurchase::callbackRestore(_id, quantity, errMessage);
}

void AppleStorePurchase::setProduct(SKProduct *product) {
    products.insert(std::pair<unicode_string, SKProduct *>(NS2UNICODE([product productIdentifier]), product));
};

void AppleStorePurchase::loadProductsInfo(std::vector<unicode_string> pids) {
    NSMutableSet<NSString *> *set = [[NSMutableSet alloc] init];
    
    for (int i = 0; i < pids.size(); ++i) {
        [set addObject: [[NSString alloc] initWithString:UNICODE2NS(pids[i])]];
    }
    
    SKProductsRequest *pRequest = [[SKProductsRequest alloc] initWithProductIdentifiers: set];
    this->request = pRequest;
    pRequest.delegate = requestDelegate;
    [pRequest start];
}

unicode_string AppleStorePurchase::getLocalePrice(double price, unicode_string locale)  {
    NSLocale * _locale = [[NSLocale alloc] initWithLocaleIdentifier:UNICODE2NS(locale)];
    
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:_locale];
    
    return NS2UNICODE([numberFormatter stringFromNumber:[[NSDecimalNumber alloc] initWithDouble:price]]);
}

void AppleStorePurchase::paymentRequest(unicode_string _id, int count) {
    SKProduct *product = safeMapAt(products, _id, nil);
    
    if (product) {
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = count;
        [[SKPaymentQueue defaultQueue] addPayment: payment];
    }
}

void AppleStorePurchase::restoreRequest() {
    NSLog(@"Try to restore products!");
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}


@implementation PaymentTransactionObserver
- (id)initWithOwner:(AppleStorePurchase *)owner
{
    self = [super init];
    _owner = owner;
    
    return self;
}

- (void)paymentQueue:(SKPaymentQueue *)queue
 updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for (size_t i = 0; i < [transactions count]; i++) {
        unicode_string _id = NS2UNICODE(transactions[i].payment.productIdentifier);
        
        switch (transactions[i].transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                self->_owner->callbackPayment(_id, NS2UNICODE(@"OK"), NS2UNICODE(@""));
                [queue finishTransaction:transactions[i]];
                break;
            case SKPaymentTransactionStateRestored:
                self->_owner->callbackRestore(_id, transactions[i].originalTransaction.payment.quantity, NS2UNICODE(@""));
                [queue finishTransaction:transactions[i]];
                break;
            case SKPaymentTransactionStateFailed:
                self->_owner->callbackPayment(_id, NS2UNICODE(@"Error"), NS2UNICODE(transactions[i].error.localizedDescription));
                [queue finishTransaction:transactions[i]];
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSLog(@"Restoring operation completed!");
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    NSLog(@"Restoring operation failed!");
    self->_owner->callbackRestore(NS2UNICODE(@""), 0, NS2UNICODE(error.localizedDescription));
}

@end

@implementation ProductsRequestDelegate
- (id)initWithOwner:(AppleStorePurchase *)owner
{
    self = [super init];
    _owner = owner;
    
    return self;
}

- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
    NSArray<SKProduct *> *products = [[response products] copy];
    for (size_t i = 0; i < [products count]; i++ ) {
        NSString *_id = products[i].productIdentifier;
        NSString *_title = products[i].localizedTitle;
        NSString *_description = products[i].localizedDescription;
        NSDecimalNumber *_price = products[i].price;
        NSString *_countryLocale = products[i].priceLocale.localeIdentifier;
        
        _owner->setProduct([products objectAtIndex:i]);
        
        _owner->callbackProduct(NS2UNICODE(_id), NS2UNICODE(_title), NS2UNICODE(_description), _price.doubleValue, NS2UNICODE(_countryLocale));
    }
    
    for (int i = 0; i < [[response invalidProductIdentifiers] count]; i++) {
        NSLog(@"Wrong id: %@", [response invalidProductIdentifiers][i]);
    }
}
@end

#endif
