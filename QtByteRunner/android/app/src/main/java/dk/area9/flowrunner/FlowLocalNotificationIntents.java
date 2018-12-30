package dk.area9.flowrunner;

import android.app.PendingIntent;

public class FlowLocalNotificationIntents {
    public final PendingIntent alarmIntent;
    public final PendingIntent onClickIntent;
    public final PendingIntent onCancelIntent;
    
    public FlowLocalNotificationIntents(PendingIntent alarmIntent, PendingIntent onClickIntent, PendingIntent onCancelIntent) {
        this.alarmIntent = alarmIntent;
        this.onClickIntent = onClickIntent;
        this.onCancelIntent = onCancelIntent;
    }
}