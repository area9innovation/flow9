package dk.area9.flowrunner;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;
import dk.area9.flowrunner.FlowRunnerService.FlowRunnerServiceBinder;

// Responsible for FlowRunnerService start and bind/unbind from FlowRunner to FlowRunnerService
public class FlowRunnerServiceWrapper {

    @Nullable
    private Context context = null;
    @Nullable
    private volatile static FlowRunnerServiceWrapper uniqueInstance = null;
    @Nullable
    private FlowRunnerService flowRunnerService = null;
    private boolean serviceBound = false;
    private boolean serviceAlarmSet = false;
    @Nullable
    private FlowRunnerOnRebootCallback lastOnBindCallback = null;
    
    @NonNull
    private ServiceConnection serviceConnection = new ServiceConnection() {

        @Override
        public void onServiceConnected(ComponentName className, IBinder service) {
            //Log.e(Utils.LOG_TAG, "TAG: Inside wrapper.onServiceConnected");
            // We've bound to LocalService, cast the IBinder and get LocalService instance
            FlowRunnerServiceBinder binder = (FlowRunnerServiceBinder)service;
            flowRunnerService = binder.getService();
            serviceBound = true;
            if (lastOnBindCallback != null) {
                lastOnBindCallback.execute();
            }
        }

        @Override
        public void onServiceDisconnected(ComponentName arg0) {
            //Log.e(Utils.LOG_TAG, "TAG: Inside wrapper.onServiceDisconnected");
            serviceBound = false;
        }
    };
    
    public interface FlowRunnerOnRebootCallback {
        void execute();
    }

    private FlowRunnerServiceWrapper() {
    }

    @Nullable
    public static FlowRunnerServiceWrapper getInstance() {
        if (uniqueInstance == null) {
            uniqueInstance = new FlowRunnerServiceWrapper();
        }
        return uniqueInstance;
    }

    public void setContext(Context context) {
        this.context = context;
    }
    
    public void startService() {
        if (!serviceAlarmSet) {
            Intent startServiceIntent = new Intent(context, FlowRunnerService.class);
            context.startService(startServiceIntent);
            serviceAlarmSet = true;
        }
    }
    
    public void bindService(FlowRunnerOnRebootCallback lastOnBindCallback) {
        if(!serviceBound) {
            Intent intent = new Intent(context, FlowRunnerService.class);
            boolean bindResult = context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE);
            if (bindResult) {
                this.lastOnBindCallback = lastOnBindCallback;
                //Log.e(Utils.LOG_TAG, "TAG: BIND YAY!!!! ");
            } else {
                //Log.e(Utils.LOG_TAG, "TAG: FAILED TO BIND");
            }
        } else {
            Log.e(Utils.LOG_TAG, "TAG: Service bounded already!!!");
        }
    }
    
    public void bindService() {
        bindService(null);
    }
    
    public void unbindService() {
        //Log.e(Utils.LOG_TAG, "TAG: Inside wrapper.unbindService");
        if (serviceBound) {
            context.unbindService(serviceConnection);
            serviceBound = false;
        }
    }
    
    public void scheduleNotification(double time, int notificationId, String notificationCallbackArgs,
            String notificationTitle, String notificationText, boolean withSound, boolean pinNotification, boolean afterBoot) {
        Log.i(Utils.LOG_TAG, "TAG: Inside wrapper.scheduleNotification. serviceBound: " + serviceBound);
        if (serviceBound) {
            flowRunnerService.scheduleNotification(time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound, pinNotification, afterBoot);
        }
    }

    public void cancelLocalNotification(int notificationId, Boolean removeFromNotificationManager) {
        //Log.e(Utils.LOG_TAG, "TAG: Inside wrapper.cancelNotification");
        if (serviceBound) {
            flowRunnerService.cancelLocalNotification(notificationId, removeFromNotificationManager);
        }
    }
}