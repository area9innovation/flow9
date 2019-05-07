package dk.area9.flowrunner;

import com.google.android.gms.location.LocationListener;
import com.google.android.gms.location.LocationRequest;

import android.location.Location;

public class FlowGooglePlayServicesLocationListener implements LocationListener {
    private final static int GEOLOCATION_WATCH_INTERVAL = 30 * 1000; // 30s

    private FlowGooglePlayServices client;
    private boolean isHighAccuracy;
    private LocationRequest locationRequest;

    public FlowGooglePlayServicesLocationListener(FlowGooglePlayServices client, boolean isHighAccuracy) {
        this(client, isHighAccuracy, GEOLOCATION_WATCH_INTERVAL);
    }

    public FlowGooglePlayServicesLocationListener(FlowGooglePlayServices client, boolean isHighAccuracy, int interval) {
        this.client = client;
        this.isHighAccuracy = isHighAccuracy;

        locationRequest = new LocationRequest()
                .setInterval(interval)
                .setFastestInterval(interval / 2)
                .setPriority(isHighAccuracy ?
                        LocationRequest.PRIORITY_HIGH_ACCURACY :
                        LocationRequest.PRIORITY_BALANCED_POWER_ACCURACY);
    }

    public LocationRequest getLocationRequest() {
        return locationRequest;
    }

    public void setInterval(int interval) {
        locationRequest.setFastestInterval(interval / 2);
        locationRequest.setInterval(interval);
    }

    @Override
    public void onLocationChanged(Location newLocation) {
        client.onLocationChanged(newLocation, isHighAccuracy);
    }

}