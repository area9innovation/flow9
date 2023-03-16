package dk.area9.flowrunner;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import androidx.annotation.NonNull;
import android.util.Log;

// This Service should be in running state all the time
// Responsible for local notifications scheduling
// Can be extended in the future
public class FlowRunnerService extends Service {

    private final IBinder mBinder = new FlowRunnerServiceBinder();
    
    public class FlowRunnerServiceBinder extends Binder {
        @NonNull
        FlowRunnerService getService() {
            // Return this instance of FlowRunnerService so clients can call public methods
            return FlowRunnerService.this;
        }
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

    public void scheduleNotification(double time, int notificationId, String notificationCallbackArgs,
            String notificationTitle, String notificationText, boolean withSound, boolean pinNotification, boolean afterBoot) {

//        Log.i(Utils.LOG_TAG, "TAG: Inside Service.scheduleNotification");
        if (!afterBoot) {
            cancelLocalNotification(notificationId, true);
            FlowNotificationsAPI.saveNotificationInfo(this, time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound, pinNotification);
        }

        FlowLocalNotificationIntents pendingIntents = FlowNotificationsAPI.getNotificationIntents(this, 0, time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound, pinNotification);

//        Log.i(Utils.LOG_TAG, "Schedule local notification with id " + notificationId + " in " + (long)((time - System.currentTimeMillis()) / 1000) + " seconds");

        AlarmManager alarmManager = (AlarmManager)getSystemService(Context.ALARM_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            alarmManager.setExact(AlarmManager.RTC, (long)time, pendingIntents.alarmIntent);
        } else {
            alarmManager.set(AlarmManager.RTC, (long)time, pendingIntents.alarmIntent);
        }
    }

    public void cancelLocalNotification(int notificationId, Boolean removeFromNotificationManager) {
        cancelLocalNotification(this, notificationId, removeFromNotificationManager);
    }
    
    public static void cancelLocalNotification(@NonNull Context context, int notificationId, Boolean removeFromNotificationManager) {
        FlowLocalNotificationInfo info = FlowNotificationsAPI.getNotificationInfo(context, notificationId, true, null);
        if (info != null) {
            FlowLocalNotificationIntents intents = FlowNotificationsAPI.getNotificationIntents(context, PendingIntent.FLAG_NO_CREATE, info.time, notificationId, info.notificationCallbackArgs, info.notificationTitle, info.notificationText, info.withSound, info.pinned);
            
            if (intents.alarmIntent != null) {
                intents.alarmIntent.cancel();

                AlarmManager alarmManager = (AlarmManager)context.getSystemService(Context.ALARM_SERVICE);
                alarmManager.cancel(intents.alarmIntent);
            }
            if (intents.onClickIntent != null) {
                intents.onClickIntent.cancel();
            }
            if (intents.onCancelIntent != null) {
                intents.onCancelIntent.cancel();
            }
        }
        if (removeFromNotificationManager) {
            NotificationManager notifyManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
            notifyManager.cancel(notificationId);
        }
    }
}