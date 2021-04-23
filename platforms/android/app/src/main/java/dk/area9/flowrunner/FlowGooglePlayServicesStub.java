package dk.area9.flowrunner;

import android.location.Location;
import androidx.annotation.Nullable;

public class FlowGooglePlayServicesStub implements IFlowGooglePlayServices {
    @Override
    public void connectGooglePlayServices() {
    }

    @Override
    public void disconnectGooglePlayServices() {
    }

    @Override
    public void requestLocationUpdates(boolean isHighAccuracy) {
    }

    @Override
    public void requestLocationWatch(boolean isHighAccuracy, int interval) {
    }

    @Override
    public void removeLocationWatch(boolean isHighAccuracy) {
    }

    @Override
    public void removeLocationUpdates(boolean isHighAccuracy) {
    }

    @Nullable
    @Override
    public Location getLastLocation() {
        return null;
    }

    @Override
    public void onLocationChanged(Location newLocation, boolean isHighAccuracy) {
    }

    @Override
    public void setFlowGeolocationAPI(FlowGeolocationAPI flowGeolocationAPI) {
    }
}
