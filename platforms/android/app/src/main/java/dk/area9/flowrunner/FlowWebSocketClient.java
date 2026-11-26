package dk.area9.flowrunner;

import android.os.Build;

import androidx.annotation.NonNull;

import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.net.URI;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLParameters;
import javax.net.ssl.SSLSocket;

// A wss connection uses the platform's default SSLSocketFactory.
public class FlowWebSocketClient extends WebSocketClient {
    FlowWebSocketClient(@NonNull URI serverURI) {
        super(serverURI);
    }

    // The library's host name check needs API 24 (Android 7); below it, verify the
    // session ourselves before the upgrade request is sent. Throwing aborts the connect.
    @Override
    protected void onSetSSLParameters(SSLParameters sslParameters) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            super.onSetSSLParameters(sslParameters);
            return;
        }
        String host = getURI().getHost();
        SSLSocket socket = (SSLSocket) getSocket();
        if (!HttpsURLConnection.getDefaultHostnameVerifier().verify(host, socket.getSession()))
            throw new SecurityException("Certificate does not match host " + host);
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
