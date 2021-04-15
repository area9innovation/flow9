package dk.area9.flowrunner;

/**
 * Created by ivan on 4/5/17.
 */

import android.content.Intent;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import android.util.Log;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.iid.FirebaseInstanceIdService;

public class FlowFirebaseInstanceIDService extends FirebaseInstanceIdService {
    private LocalBroadcastManager broadcastManager;

    @Override
    public void onCreate() {
        broadcastManager = LocalBroadcastManager.getInstance(this);
    }

    @Override
    public void onTokenRefresh() {
        String token = FirebaseInstanceId.getInstance().getToken();

        Intent intent = new Intent("FBToken");
        intent.putExtra("token", token);

        broadcastManager.sendBroadcast(intent);
    }
}
