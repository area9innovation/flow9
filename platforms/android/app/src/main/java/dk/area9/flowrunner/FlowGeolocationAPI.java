package dk.area9.flowrunner;

import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.location.Location;
import android.location.LocationManager;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;

public class FlowGeolocationAPI {
    
    public final static int GEOLOCATIONERROR_PERMISSIONDENIED= 1;
    public final static int GEOLOCATIONERROR_POSITIONUNAVAILABLE = 2;
    public final static int GEOLOCATIONERROR_ERRORTIMEOUT = 3;

    private final Context context;
    private final FlowRunnerWrapper wrapper;
    private final IFlowGooglePlayServices flowGooglePlayServices;
    private boolean askedToTurnGeolocationOn = false;
    private final boolean geolocationPermissionGranted; // permission for geolocation requested in manifest
    private final FlowLocationListener balancedListener;
    private final FlowLocationListener highAccuracyListener;

    @Nullable
    private String lastTurnOnGeolocationMessage = null;
    @Nullable
    private String lastOkButtonText = null;
    @Nullable
    private String lastCancelButtonText = null;

    public FlowGeolocationAPI(Context context, FlowRunnerWrapper wrapper, IFlowGooglePlayServices flowGooglePlayServices, boolean geolocationPermissionGranted) {
        this.context = context;
        this.wrapper = wrapper;
        this.flowGooglePlayServices = flowGooglePlayServices;
        this.geolocationPermissionGranted = geolocationPermissionGranted;
        
        balancedListener = new FlowLocationListener(this, this.flowGooglePlayServices, false);
        highAccuracyListener = new FlowLocationListener(this, this.flowGooglePlayServices, true);
    }
    
    public void pauseListeners() {
        balancedListener.stopSingleTimeListener();
        highAccuracyListener.stopSingleTimeListener();
    }
    
    public void resumeListeners() {
        if (!isGeolocationEnabled() && lastTurnOnGeolocationMessage != null) {
            askUserToTurnGeolocationOn(lastTurnOnGeolocationMessage, lastOkButtonText, lastCancelButtonText);
        }
        balancedListener.startSingleTimeListener();
        highAccuracyListener.startSingleTimeListener();
    }
    
    public void getCurrentPosition(int callbacksRoot, boolean enableHighAccuracy, double timeout, double maximumAge, String turnOnGeolocationMessage, String okButtonText, String cancelButtonText) {
        lastTurnOnGeolocationMessage = turnOnGeolocationMessage;
        lastOkButtonText = okButtonText;
        lastCancelButtonText = cancelButtonText;
        if (!geolocationPermissionGranted) {
            GeolocationExecuteOnErrorCallback(callbacksRoot, true, GEOLOCATIONERROR_PERMISSIONDENIED, "Permission for geolocation is not defined in manifest.");
        } else if (!isGeolocationEnabled()) {
            askUserToTurnGeolocationOn(turnOnGeolocationMessage, okButtonText, cancelButtonText);
        }
        Location lastKnownLocation = flowGooglePlayServices.getLastLocation();
        if (lastKnownLocation != null && (System.currentTimeMillis() - lastKnownLocation.getTime()) <= maximumAge) {
            GeolocationExecuteOnOkCallback(callbacksRoot, true, lastKnownLocation);
        } else {
            addSingleTimeWatch(callbacksRoot, timeout, enableHighAccuracy);
        }
    }

    public void watchPosition(int callbacksRoot, boolean enableHighAccuracy, double timeout, double maximumInterval, String turnOnGeolocationMessage, String okButtonText, String cancelButtonText) {
        lastTurnOnGeolocationMessage = turnOnGeolocationMessage;
        lastOkButtonText = okButtonText;
        lastCancelButtonText = cancelButtonText;
        if (!geolocationPermissionGranted) {
            GeolocationExecuteOnErrorCallback(callbacksRoot, true, GEOLOCATIONERROR_PERMISSIONDENIED, "Permission for geolocation is not defined in manifest.");
        } else if (!isGeolocationEnabled()) {
            askUserToTurnGeolocationOn(turnOnGeolocationMessage, okButtonText, cancelButtonText);
        }
        addRepeatableWatch(callbacksRoot, timeout, enableHighAccuracy, (int) maximumInterval);
    }
    
    public boolean isGeolocationEnabled() {
        String le = Context.LOCATION_SERVICE;
        LocationManager locationManager = (LocationManager) context.getSystemService(le);
        if(!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)){
            return false;
        } else {
            return true;
        }
    }
    
    public void GeolocationExecuteOnOkCallback(int callbacksRoot, boolean removeAfterCall, @NonNull Location location) {
        wrapper.GeolocationExecuteOnOkCallback(callbacksRoot, removeAfterCall, location.getLatitude(), location.getLongitude(),
                location.getAltitude(), location.getAccuracy(), 0.0, location.getBearing(), location.getSpeed(), location.getTime());
    }
    
    public void GeolocationExecuteOnErrorCallback(int callbacksRoot, boolean removeAfterCall, int code, String message) {
        wrapper.GeolocationExecuteOnErrorCallback(callbacksRoot, removeAfterCall, code, message);
    }
    
    public void watchDisposed(int callbacksRoot) {
        balancedListener.watchDisposed(callbacksRoot);
        highAccuracyListener.watchDisposed(callbacksRoot);
    }
    
    private void addSingleTimeWatch(int callbacksRoot, double timeout, boolean enableHighAccuracy) {
        if (enableHighAccuracy) {
            highAccuracyListener.addSingleTimeWatch(callbacksRoot, timeout);
        } else {
            balancedListener.addSingleTimeWatch(callbacksRoot, timeout);
        }
    }

    private void addRepeatableWatch(int callbacksRoot, double timeout, boolean enableHighAccuracy, int interval) {
        if (enableHighAccuracy) {
            highAccuracyListener.addRepeadableWatch(callbacksRoot, timeout, interval);
        } else {
            balancedListener.addRepeadableWatch(callbacksRoot, timeout, interval);
        }
    }
    
    private void askUserToTurnGeolocationOn(String turnOnGeolocationMessage, String okButtonText, String cancelButtonText) {
        if (askedToTurnGeolocationOn == false) {
            askedToTurnGeolocationOn = true;
            Dialog alertDialog = new AlertDialog.Builder(context)
                    .setMessage(turnOnGeolocationMessage)
                    .setPositiveButton(okButtonText, new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface paramDialogInterface, int paramInt) {
                            context.startActivity(new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS));
                        }
                    })
                    .setNegativeButton(cancelButtonText, new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface paramDialogInterface, int paramInt) {
                            Log.e(Utils.LOG_TAG, "User denied request to turn on geolocation.");
                        }
                    })
                    .setCancelable(true)
                    .create();
            alertDialog.setCanceledOnTouchOutside(true);
            alertDialog.show();
        }
    }

    public void onLocationChanged(Location newLocation, boolean isHighAccuracy) {
        if (isHighAccuracy) {
            highAccuracyListener.onLocationChanged(newLocation);
        } else {
            balancedListener.onLocationChanged(newLocation);
        }
    }
}
