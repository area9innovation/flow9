package dk.area9.flowrunner;

import java.util.ArrayList;
import java.util.List;

import android.app.Activity;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.ConsumeParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

public class AndroidStorePurchase implements PurchasesUpdatedListener {

    private final Activity activity;
    private final FlowRunnerWrapper runnerWrapper;

    @Nullable
    private BillingClient billingClient = null;

    private boolean callRestoreOnInit = false;

    @NonNull
    private final ArrayList<String> awaitPids = new ArrayList<>();

    // Tracks the product ID of the most recent purchase flow for callback delivery
    @Nullable
    private String pendingPurchaseProductId = null;

    public AndroidStorePurchase(Activity activity, FlowRunnerWrapper wrapper) {
        this.activity = activity;
        this.runnerWrapper = wrapper;

        billingClient = BillingClient.newBuilder(activity)
                .setListener(this)
                .enablePendingPurchases()
                .build();

        billingClient.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
                if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    Log.i(Utils.LOG_TAG, "Billing client connected successfully.");

                    if (!awaitPids.isEmpty()) {
                        loadProductsInfo(new ArrayList<>());
                    }

                    if (callRestoreOnInit) {
                        callRestoreOnInit = false;
                        restoreProducts();
                    }
                } else {
                    Log.e(Utils.LOG_TAG, "Billing client setup failed: " + billingResult.getDebugMessage());
                }
            }

            @Override
            public void onBillingServiceDisconnected() {
                Log.w(Utils.LOG_TAG, "Billing service disconnected.");
            }
        });
    }

    public void destroyServiceConnection() {
        if (billingClient != null) {
            billingClient.endConnection();
            billingClient = null;
        }
    }

    private boolean isReady() {
        return billingClient != null && billingClient.isReady();
    }

    /**
     * Reconnects to billing service if disconnected, then runs the action.
     */
    private void ensureConnected(final Runnable action) {
        if (isReady()) {
            action.run();
            return;
        }
        if (billingClient == null) return;

        billingClient.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
                if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    action.run();
                } else {
                    Log.e(Utils.LOG_TAG, "Billing reconnect failed: " + billingResult.getDebugMessage());
                }
            }

            @Override
            public void onBillingServiceDisconnected() {
                Log.w(Utils.LOG_TAG, "Billing service disconnected during reconnect.");
            }
        });
    }

    // ---- Product info loading ----

    public void loadProductsInfo(@NonNull ArrayList<String> pids) {
        Log.i(Utils.LOG_TAG, "called loadProductsInfo: " + pids.size());
        awaitPids.addAll(pids);

        if (!awaitPids.isEmpty()) {
            ensureConnected(this::doLoadProductsInfo);
        }
    }

    private void doLoadProductsInfo() {
        if (awaitPids.isEmpty()) return;

        List<QueryProductDetailsParams.Product> productList = new ArrayList<>();
        for (String pid : awaitPids) {
            productList.add(
                    QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(pid)
                            .setProductType(BillingClient.ProductType.INAPP)
                            .build()
            );
        }
        awaitPids.clear();

        QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
                .setProductList(productList)
                .build();

        billingClient.queryProductDetailsAsync(params, (billingResult, productDetailsList) -> {
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && productDetailsList != null) {
                Log.i(Utils.LOG_TAG, "Count of product details: " + productDetailsList.size());
                for (ProductDetails details : productDetailsList) {
                    Log.i(Utils.LOG_TAG, "Product: " + details.getProductId());

                    String title = details.getTitle();
                    String description = details.getDescription();
                    double price = 0;
                    String currencyCode = "";

                    ProductDetails.OneTimePurchaseOfferDetails offerDetails = details.getOneTimePurchaseOfferDetails();
                    if (offerDetails != null) {
                        price = offerDetails.getPriceAmountMicros() / 1_000_000.0;
                        currencyCode = offerDetails.getPriceCurrencyCode();
                    }

                    runnerWrapper.CallbackPurchaseProduct(
                            details.getProductId(),
                            title,
                            description,
                            price,
                            currencyCode
                    );
                }
            } else {
                Log.e(Utils.LOG_TAG, "queryProductDetailsAsync failed: " + billingResult.getDebugMessage());
            }
        });
    }

    // ---- Purchase flow ----

    public void buyProduct(final String id, int count) {
        Log.i(Utils.LOG_TAG, "Attempt to buy product " + id + " with quantity " + count);

        ensureConnected(() -> {
            // First query the product details, then launch the billing flow
            List<QueryProductDetailsParams.Product> productList = new ArrayList<>();
            productList.add(
                    QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(id)
                            .setProductType(BillingClient.ProductType.INAPP)
                            .build()
            );

            QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
                    .setProductList(productList)
                    .build();

            billingClient.queryProductDetailsAsync(params, (billingResult, productDetailsList) -> {
                if (billingResult.getResponseCode() != BillingClient.BillingResponseCode.OK
                        || productDetailsList == null || productDetailsList.isEmpty()) {
                    runnerWrapper.CallbackPurchasePayment(id, "Error",
                            "Could not query product details. Code: " + billingResult.getResponseCode());
                    return;
                }

                ProductDetails productDetails = productDetailsList.get(0);
                pendingPurchaseProductId = id;

                List<BillingFlowParams.ProductDetailsParams> productDetailsParamsList = new ArrayList<>();
                productDetailsParamsList.add(
                        BillingFlowParams.ProductDetailsParams.newBuilder()
                                .setProductDetails(productDetails)
                                .build()
                );

                BillingFlowParams billingFlowParams = BillingFlowParams.newBuilder()
                        .setProductDetailsParamsList(productDetailsParamsList)
                        .build();

                // launchBillingFlow must be called on the UI thread
                activity.runOnUiThread(() -> {
                    BillingResult launchResult = billingClient.launchBillingFlow(activity, billingFlowParams);
                    if (launchResult.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                        runnerWrapper.CallbackPurchasePayment(id, "Error",
                                "Google Play Store rejected purchase. Code: " + launchResult.getResponseCode());
                    }
                });
            });
        });
    }

    // ---- PurchasesUpdatedListener (replaces onActivityResult handling) ----

    @Override
    public void onPurchasesUpdated(@NonNull BillingResult billingResult, @Nullable List<Purchase> purchases) {
        int responseCode = billingResult.getResponseCode();

        if (responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            for (Purchase purchase : purchases) {
                handlePurchase(purchase);
            }
        } else if (responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            String productId = pendingPurchaseProductId != null ? pendingPurchaseProductId : "";
            Log.i(Utils.LOG_TAG, "Purchase cancelled by user for " + productId);
            runnerWrapper.CallbackPurchasePayment(productId, "Error", "Purchase cancelled by user.");
        } else {
            String productId = pendingPurchaseProductId != null ? pendingPurchaseProductId : "";
            Log.e(Utils.LOG_TAG, "Purchase error. Code: " + responseCode);
            runnerWrapper.CallbackPurchasePayment(productId, "Error",
                    "Purchase responded with error. Code: " + responseCode);
        }

        pendingPurchaseProductId = null;
    }

    private void handlePurchase(@NonNull Purchase purchase) {
        List<String> products = purchase.getProducts();
        String productId = products.isEmpty() ? "" : products.get(0);

        if (purchase.getPurchaseState() == Purchase.PurchaseState.PURCHASED) {
            Log.i(Utils.LOG_TAG, "RESPONDED OK for " + productId);
            runnerWrapper.CallbackPurchasePayment(productId, "OK", "");

            // Consume the purchase so it can be bought again (consumable items)
            consumePurchase(purchase);
        } else if (purchase.getPurchaseState() == Purchase.PurchaseState.PENDING) {
            Log.i(Utils.LOG_TAG, "Purchase pending for " + productId);
            runnerWrapper.CallbackPurchasePayment(productId, "Error", "Purchase is pending.");
        }
    }

    private void consumePurchase(@NonNull Purchase purchase) {
        ConsumeParams consumeParams = ConsumeParams.newBuilder()
                .setPurchaseToken(purchase.getPurchaseToken())
                .build();

        billingClient.consumeAsync(consumeParams, (billingResult, purchaseToken) -> {
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                Log.i(Utils.LOG_TAG, "Purchase consumed successfully.");
            } else {
                Log.e(Utils.LOG_TAG, "Failed to consume purchase: " + billingResult.getDebugMessage());
            }
        });
    }

    // ---- Restore purchases ----

    public void restoreProducts() {
        Log.i(Utils.LOG_TAG, "Attempt to restore products");

        if (!isReady()) {
            callRestoreOnInit = true;
            return;
        }

        ensureConnected(() -> {
            QueryPurchasesParams queryParams = QueryPurchasesParams.newBuilder()
                    .setProductType(BillingClient.ProductType.INAPP)
                    .build();

            billingClient.queryPurchasesAsync(queryParams, (billingResult, purchases) -> {
                if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    if (purchases != null && !purchases.isEmpty()) {
                        for (Purchase purchase : purchases) {
                            List<String> products = purchase.getProducts();
                            if (!products.isEmpty()) {
                                for (String productId : products) {
                                    runnerWrapper.CallbackPurchaseRestore(productId, 1, "");
                                }
                            }
                        }
                    } else {
                        runnerWrapper.CallbackPurchaseRestore("", 0, "No products");
                    }
                } else {
                    Log.e(Utils.LOG_TAG, "Restore purchases failed: " + billingResult.getDebugMessage());
                    runnerWrapper.CallbackPurchaseRestore("", 0,
                            "Cannot restore products: " + billingResult.getDebugMessage());
                }
            });
        });
    }

    /**
     * No longer needed with Billing Library — purchase results come through
     * {@link #onPurchasesUpdated}. Kept as a no-op for API compatibility.
     */
    public void callbackPurchase(int resultCode, @NonNull android.content.Intent data) {
        // Intentionally empty: the Billing Library delivers results via onPurchasesUpdated.
    }
}
