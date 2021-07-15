package dk.area9.flowrunner;

import android.location.Location;
import android.os.Bundle;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GoogleApiAvailability;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.location.LocationServices;

public class FlowGooglePlayServices implements GoogleApiClient.ConnectionCallbacks,
        GoogleApiClient.OnConnectionFailedListener, IFlowGooglePlayServices {

    private boolean initSuccess = false;
    @Nullable
    private GoogleApiClient googleApiClient = null;
    private FlowGooglePlayServicesLocationListener balancedListener;
    private FlowGooglePlayServicesLocationListener highAccuracyListener;
    private FlowGooglePlayServicesLocationListener balancedWatchListener;
    private FlowGooglePlayServicesLocationListener highAccuracyWatchListener;

    private FlowRunnerActivity activity;
    @Nullable
    private FlowGeolocationAPI flowGeolocationAPI = null;
    
    public FlowGooglePlayServices(FlowRunnerActivity activity) {
        initSuccess = true;
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

        googleApiClient = new GoogleApiClient.Builder(activity)
            .addApi(LocationServices.API)
            .addConnectionCallbacks(this)
            .addOnConnectionFailedListener(this)
            .build();
    }

    @Override
    public void connectGooglePlayServices() {
        if (initSuccess) {
            googleApiClient.connect();
        }
    }

    @Override
    public void disconnectGooglePlayServices() {
        if (initSuccess) {
            googleApiClient.disconnect();
        }
    }

    @Override
    public void requestLocationUpdates(boolean isHighAccuracy) {
        if (initSuccess) {
            FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyListener : balancedListener;
            LocationServices.FusedLocationApi.requestLocationUpdates(googleApiClient, listener.getLocationRequest(), listener, Looper.getMainLooper());
        }
    }

    @Override
    public void requestLocationWatch(boolean isHighAccuracy, int interval) {
        if (initSuccess) {
            FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyWatchListener : balancedWatchListener;
            listener.setInterval(interval);
            LocationServices.FusedLocationApi.requestLocationUpdates(googleApiClient, listener.getLocationRequest(), listener, Looper.getMainLooper());
        }
    }

    @Override
    public void removeLocationWatch(boolean isHighAccuracy) {
        if (initSuccess) {
            FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyWatchListener : balancedWatchListener;
            LocationServices.FusedLocationApi.removeLocationUpdates(googleApiClient, listener);
        }
    }

    @Override
    public void removeLocationUpdates(boolean isHighAccuracy) {
        if (initSuccess) {
            FlowGooglePlayServicesLocationListener listener = isHighAccuracy ? highAccuracyListener : balancedListener;
            LocationServices.FusedLocationApi.removeLocationUpdates(googleApiClient, listener);
        }
    }

    @Nullable
    @Override
    public Location getLastLocation() {
        Location result = null;
        if (initSuccess) {
            LocationServices.FusedLocationApi.getLastLocation(googleApiClient);
        }
        return result;
    }

    @Override
    public void onLocationChanged(Location newLocation, boolean isHighAccuracy) {
        flowGeolocationAPI.onLocationChanged(newLocation, isHighAccuracy);
    }

    @Override
    public void setFlowGeolocationAPI(FlowGeolocationAPI flowGeolocationAPI) {
        this.flowGeolocationAPI = flowGeolocationAPI;
    }

    @Override
    public void onConnectionFailed(@NonNull ConnectionResult connectionResult) {
        Log.e(Utils.LOG_TAG, "GoogleApiClient connection failed. ErrorMessage: " + connectionResult.toString());
    }

    @Override
    public void onConnected(Bundle bundle) {
        if (initSuccess) {
            activity.onGoogleServicesConnected();
        }
    }

    @Override
    public void onConnectionSuspended(int cause) {
        if (initSuccess) {
            activity.onGoogleServicesDisconnected();
        }
    }
}