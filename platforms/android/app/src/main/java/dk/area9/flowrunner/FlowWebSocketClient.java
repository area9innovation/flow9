package dk.area9.flowrunner;

import android.os.Build;

import androidx.annotation.NonNull;

import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.net.URI;

import javax.net.ssl.SSLParameters;

// A wss connection uses the platform's default SSLSocketFactory.
public class FlowWebSocketClient extends WebSocketClient {
    FlowWebSocketClient(@NonNull URI serverURI) {
        super(serverURI);
    }

    // The library checks the certificate's host name; that needs API 24 (Android 7).
    @Override
    protected void onSetSSLParameters(SSLParameters sslParameters) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N)
            super.onSetSSLParameters(sslParameters);
    }

    @Override
    public void onOpen(ServerHandshake handshakedata) {
    }

    @Override
    public void onMessage(String message) {
    }

    @Override
    public void onClose(int code, String reason, boolean remote) {
    }

    @Override
    public void onError(Exception ex) {
    }
}
