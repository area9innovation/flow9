package dk.area9.flowrunner;

import androidx.annotation.NonNull;

import org.java_websocket.WebSocket;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.net.URI;

class FlowWebSocketSupport {
    private FlowRunnerWrapper wrapper;

    FlowWebSocketSupport(FlowRunnerWrapper wrp) {
        wrapper = wrp;
    }

    @NonNull
    WebSocketClient open(@NonNull String url, final int callbacksKey) {
        FlowWebSocketClient webSocketClient = new FlowWebSocketClient(URI.create(url)) {
            @Override
            public void onOpen(ServerHandshake handshakedata) {
                wrapper.deliverWebSocketOnOpen(callbacksKey);
            }

            @Override
            public void onMessage(String message) {
                wrapper.deliverWebSocketOnMessage(callbacksKey, message);
            }

            @Override
            public void onClose(int code, String reason, boolean remote) {
                wrapper.deliverWebSocketOnClose(callbacksKey, code, reason, code == 1000);
            }

            @Override
            public void onError(Exception ex) {
                wrapper.deliverWebSocketOnError(callbacksKey, ex.getMessage());
            }
        };
        webSocketClient.connect();
        return webSocketClient;
    }

    boolean send(@NonNull WebSocketClient webSocketClient, String message) {
        boolean isConnected = webSocketClient.getReadyState() == WebSocket.READYSTATE.OPEN;
        if (isConnected)
            webSocketClient.send(message);
        return isConnected;
    }

    boolean hasBufferedData(@NonNull WebSocketClient webSocketClient) {
        return webSocketClient.getConnection().hasBufferedData();
    }

    void close(@NonNull WebSocketClient webSocketClient, int code, String reason) {
        webSocketClient.getConnection().close(code, reason);
    }
}
