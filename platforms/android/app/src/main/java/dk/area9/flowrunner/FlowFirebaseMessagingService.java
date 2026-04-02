package dk.area9.flowrunner;

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
        super.onCreate();
        broadcastManager = LocalBroadcastManager.getInstance(this);
    }

    /**
     * Called when a new FCM token is generated. Replaces the removed
     * FirebaseInstanceIdService.onTokenRefresh() callback.
     */
    @Override
    public void onNewToken(@NonNull String token) {
        Log.d(Utils.LOG_TAG, "FCM token refreshed");
        Intent intent = new Intent("FBToken");
        intent.putExtra("token", token);
        broadcastManager.sendBroadcast(intent);
    }

    @Override
    public void onMessageReceived(@NonNull RemoteMessage remoteMessage) {
        HashMap<String, String> dataMap = new HashMap<>(remoteMessage.getData());

        String body = "";
        String title = "";
        RemoteMessage.Notification notification = remoteMessage.getNotification();
        if (notification != null) {
            body = notification.getBody() != null ? notification.getBody() : "";
            title = notification.getTitle() != null ? notification.getTitle() : "";
        }

        Intent intent = new Intent("FBMessage");
        intent.putExtra("id", remoteMessage.getMessageId());
        intent.putExtra("body", body);
        intent.putExtra("title", title);
        intent.putExtra("from", remoteMessage.getFrom());
        intent.putExtra("stamp", remoteMessage.getSentTime());
        intent.putExtra("data", dataMap);

        broadcastManager.sendBroadcast(intent);
    }
}
