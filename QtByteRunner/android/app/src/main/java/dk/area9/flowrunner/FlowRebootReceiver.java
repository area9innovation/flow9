package dk.area9.flowrunner;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

// We will be notified about device reboot in this receiver
public class FlowRebootReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        Intent serviceIntent = new Intent(context, FlowRunnerOnRebootService.class);
        serviceIntent.putExtra(context.getPackageName() + "_SENDER", "FlowRebootReceiver");
        context.startService(serviceIntent);
    }
}