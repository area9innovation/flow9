package dk.area9.flowrunner;

import androidx.annotation.NonNull;

import org.java_websocket.client.DefaultSSLWebSocketClientFactory;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.net.URI;
import java.security.NoSuchAlgorithmException;

import javax.net.ssl.SSLContext;

public class FlowWebSocketClient extends WebSocketClient {
    FlowWebSocketClient(@NonNull URI serverURI) {
        super(serverURI);
        if (serverURI.getScheme().equals("wss")) {
            try {
                SSLContext sslContext = SSLContext.getDefault();
                setWebSocketFactory(new DefaultSSLWebSocketClientFactory(sslContext));
            } catch (NoSuchAlgorithmException e) {
                e.printStackTrace();
            }
        }
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
