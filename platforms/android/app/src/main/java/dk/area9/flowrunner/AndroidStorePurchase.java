package dk.area9.flowrunner;

import java.util.ArrayList;

import com.android.vending.billing.IInAppBillingService;

import android.os.IBinder;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;
import android.content.Context;
import android.content.ComponentName;
import android.content.ServiceConnection;
import android.content.Intent;
import android.app.Activity;
import android.app.PendingIntent;

import org.json.JSONObject;

public class AndroidStorePurchase {
    private final int maxPidsPerRequest = 20;
    
    private FlowRunnerActivity runnerActivity;
    private FlowRunnerWrapper runnerWrapper;
    @Nullable
    private IInAppBillingService mService = null;
    
    private boolean callRestoreOnInit = false;
    
    @Nullable
    private ServiceConnection mServiceConnection;
    
    @NonNull
    private ArrayList<String> awaitPids = new ArrayList<String>();
    
    public AndroidStorePurchase(FlowRunnerActivity activity, FlowRunnerWrapper wrapper) {
        runnerActivity = activity;
        runnerWrapper = wrapper;
        
        mServiceConnection = new ServiceConnection() {
            @Override
            public void onServiceDisconnected(ComponentName name) {
                mService = null;
            }
            @Override
            public void onServiceConnected(ComponentName name,
               IBinder service) {
                mService = IInAppBillingService.Stub.asInterface(service);
                
                if (!awaitPids.isEmpty()) {
                    loadProductsInfo(new ArrayList<String>());
                }
                
                if (callRestoreOnInit) {
                    restoreProducts();
                }
            }
        };
        
        Intent serviceIntent =
                new Intent("com.android.vending.billing.InAppBillingService.BIND");
        serviceIntent.setPackage("com.android.vending");
        runnerActivity.bindService(serviceIntent, mServiceConnection, Context.BIND_AUTO_CREATE);
    }
    
    public void destroyServiceConnection() {
        if (mService != null) {
            runnerActivity.unbindService(mServiceConnection);
        }
    }
    
    public void loadProductsInfo(@NonNull ArrayList<String> pids) {
        Log.i(Utils.LOG_TAG, "called loadProductsInfo: " + pids.size());
        awaitPids.addAll(pids);
        
        if (mService != null && !awaitPids.isEmpty()) {
            Log.i(Utils.LOG_TAG, "first product id: " + pids.get(0));
            new Thread(new Runnable() {
               public void run() {
                   Bundle querySkus = new Bundle();
                   
                   // There are a bug in InApp Billing to allow only 20 elements per request
                   ArrayList<String> sublist = null;
                   if (awaitPids.size() > maxPidsPerRequest) {
                       sublist = (ArrayList<String>) awaitPids.subList(0, 19);
                       querySkus.putStringArrayList("ITEM_ID_LIST", sublist);
                   } else {
                       querySkus.putStringArrayList("ITEM_ID_LIST", awaitPids);
                   }
                   
                   try {
                       Bundle skuDetails = mService.getSkuDetails(3, runnerActivity.getPackageName(), "inapp", querySkus);
                       
                       int response = skuDetails.getInt("RESPONSE_CODE");
                       Log.i(Utils.LOG_TAG, "response code: " + response);
                       if (response == 0) {
                           ArrayList<String> responseList = skuDetails.getStringArrayList("DETAILS_LIST");
                           
                           Log.i(Utils.LOG_TAG, "Count of responses: " + responseList.size());
                           for (String thisResponse : responseList) {
                               Log.i(Utils.LOG_TAG, "Responded " + thisResponse);
                               JSONObject object = new JSONObject(thisResponse);
                               runnerWrapper.CallbackPurchaseProduct(
                                       object.getString("productId"), 
                                       object.getString("title"), 
                                       object.getString("description"), 
                                       Integer.parseInt(object.getString("price_amount_micros")) / 1000000, 
                                       object.getString("price_currency_code"));
                           }
                       }
                   } catch (@NonNull final Exception ex) {
                       Log.i(Utils.LOG_TAG, "Exception on gettin products info: " + ex.getMessage());
                       ex.printStackTrace();
                   }
                   
                   if (awaitPids.size() > maxPidsPerRequest && sublist != null) {
                       sublist.clear();
                       
                       loadProductsInfo(new ArrayList<String>());
                   } else {
                       awaitPids.clear();
                   }
               }
            }).start();
        }
    }
    
    public void buyProduct(final String id, int count) {
        Log.i(Utils.LOG_TAG, "Attempt to buy product " + id + " with quantity " + count);
        
        if (mService != null) {
            new Thread(new Runnable() {
                public void run() {
                    try {
                        Bundle bundle = mService.getBuyIntent(3, runnerActivity.getPackageName(), id, "inapp", null);
                        int response = bundle.getInt("RESPONSE_CODE");
                        if (response == 0) {
                            PendingIntent pendingIntent = bundle.getParcelable("BUY_INTENT");
                            runnerActivity.startIntentSenderForResult(pendingIntent.getIntentSender(), 1001, new Intent(), Integer.valueOf(0), Integer.valueOf(0), Integer.valueOf(0));
                        } else {
                            runnerWrapper.CallbackPurchasePayment(id, "Error", "Google Play Store rejected purchase of the product. Code: " + response);
                        }
                    } catch(Exception ex) {
                        Log.e(Utils.LOG_TAG, "Purchase product exception: " + ex.getMessage());
                    }
                }
            }).start();
        }
    }
    
    public void callbackPurchase(int resultCode, @NonNull Intent data) {
        String response = data.getStringExtra("INAPP_PURCHASE_DATA");
        try {
            JSONObject object = new JSONObject(response);
            
            if (resultCode == Activity.RESULT_OK) {
                Log.i(Utils.LOG_TAG, "RESPONDED OK for " + object.getString("productId"));
                runnerWrapper.CallbackPurchasePayment(object.getString("productId"), "OK", "");
            } else {
                Log.e(Utils.LOG_TAG, "Purhcase responded with error.");
                runnerWrapper.CallbackPurchasePayment(object.getString("productId"), "Error", "Purhcase responded with error.");
            }
        } catch (Exception ex) {
            Log.e(Utils.LOG_TAG, "Error while parsing buy product response JSON string.");
        }
    }
    
    public void restoreProducts() {
        Log.i(Utils.LOG_TAG, "Attempt to restorep products");
        
        if (mService != null) {
            new Thread(new Runnable() {
                public void run() {
                    try {
                        String continuation = null;
                        do {
                            Bundle restore = mService.getPurchases(3, runnerActivity.getPackageName(), "inapp", null);
                        
                            int response = restore.getInt("RESPONSE_CODE");
                            Log.i(Utils.LOG_TAG, "response code: " + response);
                            if (response == 0) {
                                ArrayList<String> pids = restore.getStringArrayList("INAPP_PURCHASE_ITEM_LIST");
                                
                                if (pids.size() != 0)
                                    for (String id : pids) {
                                        runnerWrapper.CallbackPurchaseRestore(id, 1, "");
                                    }
                                else
                                    runnerWrapper.CallbackPurchaseRestore("", 0, "No products");
                            }
                            
                            continuation = restore.getString("INAPP_CONTINUATION_TOKEN");
                        } while (continuation != null);
                             
                    } catch (Exception ex) {
                        Log.e(Utils.LOG_TAG, "Exception thrown while restoring products.");
                        runnerWrapper.CallbackPurchaseRestore("", 0, "Cannot restore product: exception thrown.");
                    }
                }
            }).start();
        } else {
            callRestoreOnInit = true;
        }
    }
}