package dk.area9.flowrunner;

import java.io.IOException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.HashSet;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.pm.ApplicationInfo;
import androidx.annotation.Nullable;

import android.os.Handler;
import android.util.Log;

public class FlowNotificationsAPI {

    /* constants for reflection */
    private static final String APP_OPS_MANAGER = "android.app.AppOpsManager";
    public static final String APP_OPS_SERVICE = "appops";
    private static final String CHECK_OP_NO_THROW = "checkOpNoThrow";
    private static final int OP_POST_NOTIFICATION = 11;
    private static final int MODE_ALLOWED = 0;
    
    private Context activityContext;
    private FlowRunnerWrapper wrapper;
    private volatile static FlowNotificationsAPI uniqueInstance;
    
    // 31 year of creating notifications every second
    public static final int CANCEL_INTENT_OFFSET = 1000000000;

    // Package name of the app will be a string like: dk.area9.*
    // We don't know what will be instead of * before execution
    public static final String CREATE_NOTIFICATION = ".CREATE_NOTIFICATION";
    public static final String ON_NOTIFICATION_CLICK = ".ON_NOTIFICATION_CLICK";
    public static final String ON_NOTIFICATION_CANCEL = ".ON_NOTIFICATION_CANCEL";
    public static final String EXTRA_ON_CLICK_INTENT = ".EXTRA_ON_CLICK_INTENT";
    public static final String EXTRA_ON_CANCEL_INTENT = ".EXTRA_ON_CANCEL_INTENT";
    public static final String EXTRA_NOTIFICATION_TITLE = ".EXTRA_NOTIFICATION_TITLE";
    public static final String EXTRA_NOTIFICATION_TEXT = ".EXTRA_NOTIFICATION_TEXT";
    public static final String EXTRA_NOTIFICATION_CALLBACK_ARGS = ".EXTRA_NOTIFICATION_CALLBACK_ARGS";
    public static final String EXTRA_NOTIFICATION_TIME = ".EXTRA_NOTIFICATION_TIME";
    public static final String EXTRA_NOTIFICATION_ID = ".EXTRA_NOTIFICATION_ID";
    public static final String EXTRA_NOTIFICATION_WITH_SOUND = ".EXTRA_NOTIFICATION_WITH_SOUND";
    public static final String EXTRA_PINNED_NOTIFICATION = ".EXTRA_PINNED_NOTIFICATION";

    public static final String CHANNEL_ID = "local_channel";
    public static final String CHANNEL_NAME = "Local Notifications";

    public static final String PUSH_CHANNEL_ID = "push_channel";
    public static final String PUSH_CHANNEL_NAME = "Remote Notifications";

    private FlowNotificationsAPI() {
    }
    
    private FlowNotificationsAPI(FlowRunnerWrapper wrapper) {
        this.wrapper = wrapper;
    }
    
    public static FlowNotificationsAPI getInstance() {
        return uniqueInstance;
    }
    
    public static FlowNotificationsAPI getInstance(FlowRunnerWrapper wrapper) {
        if (uniqueInstance == null) {
            uniqueInstance = new FlowNotificationsAPI(wrapper);
        } else {
            uniqueInstance.wrapper = wrapper;
        }
        return uniqueInstance;
    }

    public void setContext(Context context) {
        this.activityContext = context;
    }

    public boolean hasPermissionLocalNotification() {
        try {
            Object mAppOps = activityContext.getSystemService(APP_OPS_SERVICE);
            ApplicationInfo appInfo = activityContext.getApplicationInfo();
            int uid = appInfo.uid;
            String pkg = activityContext.getPackageName();

            Class<?> appOpsClass = Class.forName(APP_OPS_MANAGER);
            Method checkOpNoThrowMethod = appOpsClass.getMethod(CHECK_OP_NO_THROW, Integer.TYPE, Integer.TYPE, String.class);
            return (((Integer)checkOpNoThrowMethod.invoke(mAppOps, OP_POST_NOTIFICATION, uid, pkg)) == MODE_ALLOWED);
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        } catch (NoSuchMethodException e) {
            e.printStackTrace();
        } catch (InvocationTargetException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        }

        return true;
    }

    public void requestPermissionLocalNotification(int cb_root) {
        wrapper.RequestPermissionLocalNotificationResult(hasPermissionLocalNotification(), cb_root);
    }

    public synchronized void scheduleLocalNotification(double time, int notificationId, String notificationCallbackArgs,
            String notificationTitle, String notificationText, boolean withSound, boolean pinNotification) {
        FlowRunnerServiceWrapper.getInstance().scheduleNotification(time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound, pinNotification, false);
    }
    
    public synchronized void cancelLocalNotification(int notificationId, Boolean removeFromNotificationManager) {
        FlowRunnerServiceWrapper.getInstance().cancelLocalNotification(notificationId, removeFromNotificationManager);
    }

    public void onLocalNotificationClick(int notificationId, String notificationCallbackArgs) {
        wrapper.ExecuteNotificationCallbacks(notificationId, notificationCallbackArgs);
        // false, because already removed from notification center

        // Delay for service to have a chance to be created and bound
		new java.util.Timer().schedule( 
			new java.util.TimerTask() {
				@Override
				public void run() {
					cancelLocalNotification(notificationId, true);
				}
			}, 
			500
		);
    }
    
    public static FlowLocalNotificationIntents getNotificationIntents(Context context, int pendingIntentFlags, double time, int notificationId, String notificationCallbackArgs,
            String notificationTitle, String notificationText, boolean withSound, boolean pinNotification) {
        String pkgName = context.getPackageName();

        Intent alarmIntent = new Intent(context, FlowNotificationsBroadcastReceiver.class)
                .setAction(pkgName + FlowNotificationsAPI.CREATE_NOTIFICATION);
        Intent onClickIntent = new Intent(context, FlowRunnerActivity.class)
                .setAction(pkgName + FlowNotificationsAPI.ON_NOTIFICATION_CLICK)
                .putExtra(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_ID, notificationId)
                .putExtra(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_CALLBACK_ARGS, notificationCallbackArgs);
        Intent onCancelIntent = new Intent(context, FlowNotificationsBroadcastReceiver.class)
                .setAction(pkgName + FlowNotificationsAPI.ON_NOTIFICATION_CANCEL)
                .putExtra(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_ID, notificationId);

		if (android.os.Build.VERSION.SDK_INT >= 31) {
			pendingIntentFlags |= 0x02000000; //PendingIntent.FLAG_MUTABLE;
		}

		PendingIntent onClickPendingIntent = PendingIntent.getActivity(context, notificationId, onClickIntent, pendingIntentFlags);
        PendingIntent onCancelPendingIntent = PendingIntent.getBroadcast(context, notificationId + FlowNotificationsAPI.CANCEL_INTENT_OFFSET, onCancelIntent, pendingIntentFlags);

        alarmIntent.putExtra(pkgName + FlowNotificationsAPI.EXTRA_ON_CLICK_INTENT, onClickPendingIntent);
        alarmIntent.putExtra(pkgName + FlowNotificationsAPI.EXTRA_ON_CANCEL_INTENT, onCancelPendingIntent);
        alarmIntent.putExtra(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_TITLE, notificationTitle);
        alarmIntent.putExtra(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_TEXT, notificationText);
        alarmIntent.putExtra(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_ID, notificationId);
        alarmIntent.putExtra(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_WITH_SOUND, withSound);
        alarmIntent.putExtra(pkgName + FlowNotificationsAPI.EXTRA_PINNED_NOTIFICATION, pinNotification);

        PendingIntent alarmPendingIntent = PendingIntent.getBroadcast(context, notificationId, alarmIntent, pendingIntentFlags);
        
        return new FlowLocalNotificationIntents(alarmPendingIntent, onClickPendingIntent, onCancelPendingIntent);
    }
    
    public static void saveNotificationInfo(Context context, double time, int notificationId, String notificationCallbackArgs,
            String notificationTitle, String notificationText, boolean withSound, boolean pinNotification) {
        SharedPreferences preferences = context.getSharedPreferences(context.getPackageName() + "_preferences", Context.MODE_PRIVATE);
        Editor editor = preferences.edit();
        String keyPrefix = "notification_" + notificationId;
        Utils.sharedPreferencesPutDouble(editor, keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TIME, time);
        editor.putString(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_CALLBACK_ARGS, notificationCallbackArgs);
        editor.putString(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TITLE, notificationTitle);
        editor.putString(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TEXT, notificationText);
        editor.putBoolean(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_WITH_SOUND, withSound);
        editor.putBoolean(keyPrefix + FlowNotificationsAPI.EXTRA_PINNED_NOTIFICATION, pinNotification);
        String idsList = preferences.getString("notification_id_list", "");
        Object setCandidate = Utils.deserializeStringToObject(idsList);
        HashSet<Integer> set = (setCandidate == null) ? new HashSet<Integer>() : (HashSet<Integer>)setCandidate;
        set.add(notificationId);
        editor.putString("notification_id_list", Utils.serializeObjectToString(set));
        editor.apply();
    }
    
    @Nullable
    public static FlowLocalNotificationInfo getNotificationInfo(Context context, int notificationId, boolean removeFromPreferences, @Nullable HashSet<Integer> set) {
        SharedPreferences preferences = context.getSharedPreferences(context.getPackageName() + "_preferences", Context.MODE_PRIVATE);
        String keyPrefix = "notification_" + notificationId;
        double time = Utils.sharedPreferencesGetDouble(preferences, keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TIME, -1.0);
        String notificationCallbackArgs = preferences.getString(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_CALLBACK_ARGS, "");
        String notificationTitle = preferences.getString(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TITLE, "");
        String notificationText = preferences.getString(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TEXT, "");
        boolean withSound = preferences.getBoolean(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_WITH_SOUND, false);
        boolean pinNotification = preferences.getBoolean(keyPrefix + FlowNotificationsAPI.EXTRA_PINNED_NOTIFICATION, false);
        
        FlowLocalNotificationInfo result = null;
        if (set == null) {
            String idsList = preferences.getString("notification_id_list", "");
            Object setCandidate = Utils.deserializeStringToObject(idsList);
            set = (setCandidate == null) ? new HashSet<Integer>() : (HashSet<Integer>)setCandidate;
            if (set.contains(notificationId)) {
                result = new FlowLocalNotificationInfo(time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound, pinNotification);
            }
        }
        if (removeFromPreferences) {
            Editor editor = preferences.edit();
            editor.remove(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TIME);
            editor.remove(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_CALLBACK_ARGS);
            editor.remove(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TITLE);
            editor.remove(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_TEXT);
            editor.remove(keyPrefix + FlowNotificationsAPI.EXTRA_NOTIFICATION_WITH_SOUND);
            editor.remove(keyPrefix + FlowNotificationsAPI.EXTRA_PINNED_NOTIFICATION);
            set.remove(notificationId);
            editor.putString("notification_id_list", Utils.serializeObjectToString(set));
            editor.apply();
        }
        return result;
    }
}