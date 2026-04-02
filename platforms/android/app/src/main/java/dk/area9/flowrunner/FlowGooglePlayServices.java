package dk.area9.flowrunner;

import android.location.Location;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;

public class FlowGooglePlayServices implements IFlowGooglePlayServices {

    private boolean initSuccess = false;
    @Nullable
    private FusedLocationProviderClient fusedLocationClient = null;
    private FlowGooglePlayServicesLocationListener balancedListener;
    private FlowGooglePlayServicesLocationListener highAccuracyListener;
    private FlowGooglePlayServicesLocationListener balancedWatchListener;
    private FlowGooglePlayServicesLocationListener highAccuracyWatchListener;

    private final FlowRunnerActivity activity;
    @Nullable
    private FlowGeolocationAPI flowGeolocationAPI = null;

    public FlowGooglePlayServices(FlowRunnerActivity activity) {
        this.activity = activity;

        int status = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(activity);
        if (ConnectionResult.SUCCESS == status) {
            initSuccess = true;
        } else {
            initSuccess = false;
            GoogleApiAvailability.getInstance().getErrorDialog(activity, status, 0).show();
            return;
        }

        balancedListener = new FlowGooglePlayServicesLocationListener(this, false);
        highAccuracyListener = new FlowGooglePlayServicesLocationListener(this, true);
        balancedWatchListener = new FlowGooglePlayServicesLocationListener(this, false);
        highAccuracyWatchListener = new FlowGooglePlayServicesLocationListener(this, true);

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(activity);
    }

    @Override
    public void connectGooglePlayServices() {
        // FusedLocationProviderClient does not require explicit connect/disconnect.
        // Notify the activity that services are ready.
        if (initSuccess) {
            activity.onGoogleServicesConnected();
        }
    }

    @Override
    public void disconnectGooglePlayServices() {
        // Remove any active location updates on disconnect
        if (initSuccess && fusedLocationClient != null) {
            try {
                fusedLocationClient.removeLocationUpdates(balancedListener);
                fusedLocationClient.removeLocationUpdates(highAccuracyListener);
                fusedLocationClient.removeLocationUpdates(balancedWatchListener);
                fusedLocationClient.removeLocationUpdates(highAccuracyWatchListener);
            } catch (SecurityException e) {
                Log.e(Utils.LOG_TAG, "Security exception removing location updates", e);
            }
            activity.onGoogleServicesDisconnected();
        }
    }

    @Override
    public void requestLocationUpdates(boolean isHighAccuracy) {
        if (initSuccess && fusedLocationClient != null) {
            try {
                FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyListener : balancedListener;
                fusedLocationClient.requestLocationUpdates(listener.getLocationRequest(), listener, Looper.getMainLooper());
            } catch (SecurityException e) {
                Log.e(Utils.LOG_TAG, "Security exception requesting location updates", e);
            }
        }
    }

    @Override
    public void requestLocationWatch(boolean isHighAccuracy, int interval) {
        if (initSuccess && fusedLocationClient != null) {
            try {
                FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyWatchListener : balancedWatchListener;
                listener.setInterval(interval);
                fusedLocationClient.requestLocationUpdates(listener.getLocationRequest(), listener, Looper.getMainLooper());
            } catch (SecurityException e) {
                Log.e(Utils.LOG_TAG, "Security exception requesting location watch", e);
            }
        }
    }

    @Override
    public void removeLocationWatch(boolean isHighAccuracy) {
        if (initSuccess && fusedLocationClient != null) {
            FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyWatchListener : balancedWatchListener;
            fusedLocationClient.removeLocationUpdates(listener);
        }
    }

    @Override
    public void removeLocationUpdates(boolean isHighAccuracy) {
        if (initSuccess && fusedLocationClient != null) {
            FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyListener : balancedListener;
            fusedLocationClient.removeLocationUpdates(listener);
        }
    }

    @Nullable
    @Override
    public Location getLastLocation() {
        // Note: getLastLocation() returns a Task<Location> in the new API.
        // For synchronous callers, return null and let location updates deliver results.
        // A proper async implementation would use task.addOnSuccessListener().
        return null;
    }

    @Override
    public void onLocationChanged(Location newLocation, boolean isHighAccuracy) {
        if (flowGeolocationAPI != null) {
            flowGeolocationAPI.onLocationChanged(newLocation, isHighAccuracy);
        }
    }

    @Override
    public void setFlowGeolocationAPI(FlowGeolocationAPI flowGeolocationAPI) {
        this.flowGeolocationAPI = flowGeolocationAPI;
    }
}