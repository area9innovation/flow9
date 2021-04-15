package dk.area9.flowrunner;

import android.location.Location;
import androidx.annotation.Nullable;

public interface IFlowGooglePlayServices {
    void connectGooglePlayServices();
    void disconnectGooglePlayServices();
    void requestLocationUpdates(boolean isHighAccuracy);
    void requestLocationWatch(boolean isHighAccuracy, int interval);
    void removeLocationWatch(boolean isHighAccuracy);
    void removeLocationUpdates(boolean isHighAccuracy);
    @Nullable
    Location getLastLocation();
    void onLocationChanged(Location newLocation, boolean isHighAccuracy);
    void setFlowGeolocationAPI(FlowGeolocationAPI flowGeolocationAPI);
}
