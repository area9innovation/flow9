package dk.area9.flowrunner;

import android.location.Location;
import androidx.annotation.NonNull;

import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.Priority;

public class FlowGooglePlayServicesLocationListener extends LocationCallback {
    private static final int GEOLOCATION_WATCH_INTERVAL = 30 * 1000; // 30s

    private final FlowGooglePlayServices client;
    private final boolean isHighAccuracy;
    private LocationRequest locationRequest;

    public FlowGooglePlayServicesLocationListener(FlowGooglePlayServices client, boolean isHighAccuracy) {
        this(client, isHighAccuracy, GEOLOCATION_WATCH_INTERVAL);
    }

    public FlowGooglePlayServicesLocationListener(FlowGooglePlayServices client, boolean isHighAccuracy, int interval) {
        this.client = client;
        this.isHighAccuracy = isHighAccuracy;
        this.locationRequest = buildLocationRequest(interval, isHighAccuracy);
    }

    public LocationRequest getLocationRequest() {
        return locationRequest;
    }

    public void setInterval(int interval) {
        this.locationRequest = buildLocationRequest(interval, isHighAccuracy);
    }

    @Override
    public void onLocationResult(@NonNull LocationResult locationResult) {
        Location location = locationResult.getLastLocation();
        if (location != null) {
            client.onLocationChanged(location, isHighAccuracy);
        }
    }

    private static LocationRequest buildLocationRequest(int interval, boolean highAccuracy) {
        return new LocationRequest.Builder(
                highAccuracy ? Priority.PRIORITY_HIGH_ACCURACY : Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                interval
        )
        .setMinUpdateIntervalMillis(interval / 2)
        .build();
    }
}