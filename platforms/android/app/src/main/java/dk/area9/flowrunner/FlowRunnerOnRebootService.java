package dk.area9.flowrunner;

import java.io.IOException;
import java.util.HashSet;

import android.app.IntentService;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import androidx.annotation.NonNull;

// We use this service to run some operations after device boot, like:
// - Recreating and rescheduling local notifications
// Because we can't do some things from FlowRebootReceiver, link bind to service
public class FlowRunnerOnRebootService extends IntentService {

    public FlowRunnerOnRebootService() {
        super("FlowRunnerOnRebootService");
    }

    @Override
    protected void onHandleIntent(@NonNull Intent intent) {
        String intentType = intent.getExtras().getString(getPackageName() + "_SENDER");
        if(intentType == null || !intentType.equals("FlowRebootReceiver")) {
            return;
        }
        
        final FlowRunnerOnRebootService me = this;

        FlowRunnerServiceWrapper.FlowRunnerOnRebootCallback callback = new FlowRunnerServiceWrapper.FlowRunnerOnRebootCallback() {
            public void execute() {
                SharedPreferences preferences = getSharedPreferences(getPackageName() + "_preferences", Context.MODE_PRIVATE);
                String idsList = preferences.getString("notification_id_list", "");
                Object setCandidate = Utils.deserializeStringToObject(idsList);
                HashSet<Integer> set = (setCandidate == null) ? new HashSet<Integer>() : (HashSet<Integer>)setCandidate;
                for(Integer notificationId : set) {
                    FlowLocalNotificationInfo info = FlowNotificationsAPI.getNotificationInfo(me, notificationId, false, null);
                    if (info != null) {
                        FlowRunnerServiceWrapper.getInstance().scheduleNotification(info.time, notificationId, info.notificationCallbackArgs, info.notificationTitle, info.notificationText, info.withSound, info.pinned, true);
                    }
                }
                FlowRunnerServiceWrapper.getInstance().unbindService();
            }
        };

        FlowRunnerServiceWrapper.getInstance().setContext(this);
        FlowRunnerServiceWrapper.getInstance().startService();
        FlowRunnerServiceWrapper.getInstance().bindService(callback);
    }
}