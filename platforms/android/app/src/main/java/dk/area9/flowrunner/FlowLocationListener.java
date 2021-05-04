package dk.area9.flowrunner;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;

import android.location.Location;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class FlowLocationListener {
    
    private FlowGeolocationAPI flowGeolocationApi;
    private IFlowGooglePlayServices flowGooglePlayServices;
    @Nullable
    private Timer timer = null;
    // HashMap used to be able to easy handle unsubscribe process
    private HashMap<Integer, FlowGeolocationWatcher> singleTimeWatchers;
    private HashMap<Integer, FlowGeolocationWatcher> repeatableWatchers;
    private HashMap<Integer, Integer> repeatableWatchersIntervals;
    private int currentInterval = -1;
    private boolean isHighAccuracy;

    private boolean locationUpdatesRequested;
    private boolean locationWatchRequested;

    public FlowLocationListener(FlowGeolocationAPI flowGeolocationApi, IFlowGooglePlayServices flowGooglePlayServices, boolean isHighAccuracy) {
        this.flowGeolocationApi = flowGeolocationApi;
        this.flowGooglePlayServices = flowGooglePlayServices;
        this.isHighAccuracy = isHighAccuracy;
        this.singleTimeWatchers = new HashMap();
        this.repeatableWatchers = new HashMap();
        this.repeatableWatchersIntervals = new HashMap();
        this.locationUpdatesRequested = false;
        this.locationWatchRequested = false;
    }
    
    public void addSingleTimeWatch(int callbacksRoot, double timeout) {
        FlowGeolocationTimeoutTask timerTask = new FlowGeolocationTimeoutTask(this, callbacksRoot, true);
        singleTimeWatchers.put(callbacksRoot, new FlowGeolocationWatcher(timeout, timerTask));
        addTaskToTimer(timerTask, (long)timeout);
        if (singleTimeWatchers.size() == 1) {
            startSingleTimeListener();
        }
    }

    public void addRepeadableWatch(int callbacksRoot, double timeout, int interval) {
        FlowGeolocationTimeoutTask timerTask = new FlowGeolocationTimeoutTask(this, callbacksRoot, true);
        repeatableWatchers.put(callbacksRoot, new FlowGeolocationWatcher(timeout, timerTask));
        repeatableWatchersIntervals.put(callbacksRoot, interval);
        addTaskToTimer(timerTask, (long)timeout);
        startWatchListener(interval);
    }
    
    public void startSingleTimeListener() {
        if (!locationUpdatesRequested) {
            if (flowGeolocationApi.isGeolocationEnabled() && singleTimeWatchers.size() > 0) {
                flowGooglePlayServices.requestLocationUpdates(isHighAccuracy);
                locationUpdatesRequested = true;
            } else {
                executeOnErrorCallbacks(FlowGeolocationAPI.GEOLOCATIONERROR_POSITIONUNAVAILABLE, "User disabled geolocation.");
            }
        }
    }

    public void startWatchListener(int interval) {
        if(!locationWatchRequested){
            if (flowGeolocationApi.isGeolocationEnabled()) {
                flowGooglePlayServices.requestLocationWatch(isHighAccuracy, interval);
                locationWatchRequested = true;
            } else {
                executeOnErrorCallbacks(FlowGeolocationAPI.GEOLOCATIONERROR_POSITIONUNAVAILABLE, "User disabled geolocation.");
            }
        } else if(currentInterval > interval){
            flowGooglePlayServices.removeLocationWatch(isHighAccuracy);
            flowGooglePlayServices.requestLocationWatch(isHighAccuracy, interval);
            currentInterval = interval;
        }
    }
    
    public void stopSingleTimeListener() {
        //cancelTimer();
        if (locationUpdatesRequested) {
            locationUpdatesRequested = false;
            flowGooglePlayServices.removeLocationUpdates(isHighAccuracy);
        }
    }
    
    public void watchDisposed(int callbacksRoot) {
        // may be we should add here synchronized block? what if timerTask event fired when we disposing watch
        if (repeatableWatchers.containsKey(callbacksRoot)) {
            repeatableWatchers.get(callbacksRoot).getTimerTask().cancel();
            repeatableWatchers.remove(callbacksRoot);
            repeatableWatchersIntervals.remove(callbacksRoot);
            if (repeatableWatchers.size() == 0){
                flowGooglePlayServices.removeLocationWatch(isHighAccuracy);
                locationWatchRequested = false;
            } else {
                int new_interval = Collections.min(repeatableWatchersIntervals.values());
                if (new_interval > currentInterval){
                    flowGooglePlayServices.removeLocationWatch(isHighAccuracy);
                    flowGooglePlayServices.requestLocationWatch(isHighAccuracy, new_interval);
                    currentInterval = new_interval;
                }
            }
        }
    }
    
    public void watchTimeoutFired(int callbacksRoot, boolean singleTime) {
        // do we really need synchronized blocks here?
        // Remove if case "timer fired, but in flow it is already disposed" impossible
        if (singleTime) {
            flowGeolocationApi.GeolocationExecuteOnErrorCallback(callbacksRoot, singleTime, FlowGeolocationAPI.GEOLOCATIONERROR_ERRORTIMEOUT, "Geolocation request timeout.");
            singleTimeWatchers.remove(callbacksRoot);
            if (repeatableWatchers.size() == 0) {
                stopSingleTimeListener();
            }
        } else {
            if (repeatableWatchers.containsKey(callbacksRoot)) {
                flowGeolocationApi.GeolocationExecuteOnErrorCallback(callbacksRoot, singleTime, FlowGeolocationAPI.GEOLOCATIONERROR_ERRORTIMEOUT, "Geolocation request timeout.");
                FlowGeolocationWatcher watcher = repeatableWatchers.get(callbacksRoot);
                watcher.setTimerTask(new FlowGeolocationTimeoutTask(this, callbacksRoot, singleTime));
                addTaskToTimer(watcher.getTimerTask(), (long)watcher.getTimeout());
            }
        }
    }
    

    public synchronized void onLocationChanged(@NonNull Location newLocation) {
        executeOnOkCallbacks(newLocation);
    }
    
    private void addTaskToTimer(FlowGeolocationTimeoutTask timerTask, long delay) {
        if (timer == null) {
            timer = new Timer();
        }
        timer.schedule(timerTask, delay);
    }
    
    private void cancelTimer() {
       if(timer != null) {
           timer.cancel();
           timer.purge();
           timer = null;
       }
    }
    
    private void executeOnOkCallbacks(@NonNull Location location) {
        // Pause timeout timer tasks
        cancelTimer();
        // callOnOK for single time watchers
        for (Map.Entry<Integer, FlowGeolocationWatcher> entry : singleTimeWatchers.entrySet()) {
            flowGeolocationApi.GeolocationExecuteOnOkCallback(entry.getKey(), true, location);
        }
        // clearList of single time watchers
        singleTimeWatchers.clear();
        // callOnOK for timer watchers
        HashMap<Integer, FlowGeolocationWatcher> newRepeatableWatchers = new HashMap<Integer, FlowGeolocationWatcher>();
        for (Map.Entry<Integer, FlowGeolocationWatcher> entry : repeatableWatchers.entrySet()) {
            flowGeolocationApi.GeolocationExecuteOnOkCallback(entry.getKey(), false, location);
            // Recreate geolocationTimeout timer task
            FlowGeolocationTimeoutTask timerTask = new FlowGeolocationTimeoutTask(this, entry.getKey(), false);
            newRepeatableWatchers.put(entry.getKey(), new FlowGeolocationWatcher(entry.getValue().getTimeout(), timerTask));
            addTaskToTimer(timerTask, (long)entry.getValue().getTimeout());
        }
        repeatableWatchers = newRepeatableWatchers;
        if (singleTimeWatchers.size() == 0) {
            stopSingleTimeListener();
        }
    }
    
    private void executeOnErrorCallbacks(int code, String message) {
        // Pause timeout timer tasks
        cancelTimer();
        // callOnError for single time watchers
        for (Map.Entry<Integer, FlowGeolocationWatcher> entry : singleTimeWatchers.entrySet()) {
            flowGeolocationApi.GeolocationExecuteOnErrorCallback(entry.getKey(), true, code, message);
        }
        // clearList of single time watchers
        singleTimeWatchers.clear();
        // callOnError for timer watchers
        HashMap<Integer, FlowGeolocationWatcher> newRepeatableWatchers = new HashMap<Integer, FlowGeolocationWatcher>();
        for (Map.Entry<Integer, FlowGeolocationWatcher> entry : repeatableWatchers.entrySet()) {
            flowGeolocationApi.GeolocationExecuteOnErrorCallback(entry.getKey(), false, code, message);
            // Recreate geolocationTimeout timer task
            FlowGeolocationTimeoutTask timerTask = new FlowGeolocationTimeoutTask(this, entry.getKey(), false);
            newRepeatableWatchers.put(entry.getKey(), new FlowGeolocationWatcher(entry.getValue().getTimeout(), timerTask));
            addTaskToTimer(timerTask, (long)entry.getValue().getTimeout());
        }
        repeatableWatchers = newRepeatableWatchers;
        if (singleTimeWatchers.size() == 0) {
            stopSingleTimeListener();
        }
    }
}

class FlowGeolocationWatcher {
    private final double timeout;
    private FlowGeolocationTimeoutTask timerTask;
    
    public FlowGeolocationWatcher(double timeout, FlowGeolocationTimeoutTask timerTask) {
        this.timeout = timeout;
        this.timerTask = timerTask;
    }
    
    public double getTimeout() {
        return timeout;
    }
    
    public void setTimerTask(FlowGeolocationTimeoutTask timerTask) {
        this.timerTask = timerTask;
    }
    
    public FlowGeolocationTimeoutTask getTimerTask() {
        return timerTask;
    
    }
}

class FlowGeolocationTimeoutTask extends TimerTask {

    private FlowLocationListener flowLocationListener;
    private int callbacksRoot;
    private boolean removeAfterCall;

    public FlowGeolocationTimeoutTask(FlowLocationListener flowLocationListener, int callbacksRoot, boolean removeAfterCall) {
        this.flowLocationListener = flowLocationListener;
        this.callbacksRoot = callbacksRoot;
        this.removeAfterCall = removeAfterCall;
    }
    
    @Override
    public void run() {
        flowLocationListener.watchTimeoutFired(callbacksRoot, removeAfterCall);
    }
}