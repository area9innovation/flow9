package dk.area9.flowrunner;

/**
 * Created by ivan on 4/5/17.
 */

import android.content.Intent;
import androidx.annotation.NonNull;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import android.util.Log;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.HashMap;

public class FlowFirebaseMessagingService extends FirebaseMessagingService {
    private LocalBroadcastManager broadcastManager;

    @Override
    public void onCreate() {
        broadcastManager = LocalBroadcastManager.getInstance(this);
    }

    @Override
    public void onMessageReceived(@NonNull RemoteMessage remoteMessage) {
        HashMap<String, String> dataMap = new HashMap(remoteMessage.getData());

        Intent intent = new Intent("FBMessage");
        intent.putExtra("id", remoteMessage.getMessageId());
        intent.putExtra("body", remoteMessage.getNotification().getBody());
        intent.putExtra("title", remoteMessage.getNotification().getTitle());
        intent.putExtra("from", remoteMessage.getFrom());
        intent.putExtra("stamp", remoteMessage.getSentTime());
        intent.putExtra("data", dataMap);

        broadcastManager.sendBroadcast(intent);
    }
}
