package dk.area9.flowrunner;

public class FlowLocalNotificationInfo {
    public final double time;
    public final int notificationId;
    public final String notificationCallbackArgs;
    public final String notificationTitle;
    public final String notificationText;
    public final boolean withSound;
    public final boolean pinned;
    
    public FlowLocalNotificationInfo(double time, int notificationId, String notificationCallbackArgs,
            String notificationTitle, String notificationText, boolean withSound, boolean pinNotification) {
        this.time = time;
        this.notificationId = notificationId;
        this.notificationCallbackArgs = notificationCallbackArgs;
        this.notificationTitle = notificationTitle;
        this.notificationText = notificationText;
        this.withSound = withSound;
        this.pinned = pinNotification;
    }
}