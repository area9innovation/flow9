package dk.area9.flowrunner;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.support.v4.app.NotificationCompat;

// We interact with NotificationManager in this receiver
// onReceive will be called at scheduled time for every scheduled notification
public class FlowNotificationsBroadcastReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        String pkgName = context.getPackageName();
        if (action.equals(pkgName + FlowNotificationsAPI.CREATE_NOTIFICATION)) {
            createNotification(pkgName, context, intent);
        } else if (action.equals(pkgName + FlowNotificationsAPI.ON_NOTIFICATION_CANCEL)) {
            cancelNotification(pkgName, context, intent);
        } else {
            //LOG.e(Utils.LOG_TAG, "in FlowNotificationsBroadcastReceiver. Unknown action: " + intent.getAction());
        }
    }
    
    private void createNotification(String pkgName, Context context, Intent intent) {
        String notificationTitle = intent.getExtras().getString(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_TITLE);
        String notificationText = intent.getExtras().getString(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_TEXT);
        int notificationId = intent.getExtras().getInt(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_ID);
        PendingIntent onClickIntent = (PendingIntent)intent.getExtras().getParcelable(pkgName + FlowNotificationsAPI.EXTRA_ON_CLICK_INTENT);
        PendingIntent onCancelIntent = (PendingIntent)intent.getExtras().getParcelable(pkgName + FlowNotificationsAPI.EXTRA_ON_CANCEL_INTENT);
        boolean withSound = intent.getExtras().getBoolean(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_WITH_SOUND);
        boolean pinNotification = intent.getExtras().getBoolean(pkgName + FlowNotificationsAPI.EXTRA_PINNED_NOTIFICATION);

        int notificationIconID = context.getResources().getIdentifier("ic_flow_local_notification", "drawable", context.getPackageName());
        if (notificationIconID == 0) {
            notificationIconID = android.R.drawable.ic_popup_reminder;
        }

        NotificationCompat.Builder mBuilder = new NotificationCompat.Builder(context);

        mBuilder.setSmallIcon(notificationIconID)
                .setContentTitle(notificationTitle)
                .setContentText(notificationText)
                .setContentIntent(onClickIntent)
                .setDeleteIntent(onCancelIntent)
                .setOngoing(pinNotification)
                .setAutoCancel(!pinNotification);

        if (withSound) {
            mBuilder.setDefaults(Notification.DEFAULT_SOUND);
        }

        NotificationManager notifyManager = (NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);
        notifyManager.notify(notificationId, mBuilder.build());
    }
    
    private void cancelNotification(String pkgName, Context context, Intent intent) {
        int notificationId = intent.getExtras().getInt(pkgName + FlowNotificationsAPI.EXTRA_NOTIFICATION_ID);
        //LOG.e(Utils.LOG_TAG, "in cancelNotification. Trying to cancel notifiation with ID: " + notificationId);
        // false, because already removed from notification center
        FlowRunnerService.cancelLocalNotification(context, notificationId, false);
    }

}
