package dk.area9.flowrunner;

import org.java_websocket.WebSocket;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.net.URI;

class FlowWebSocketSupport {
    private FlowRunnerWrapper wrapper;

    FlowWebSocketSupport(FlowRunnerWrapper wrp) {
        wrapper = wrp;
    }

    WebSocketClient open(String url, final int cbOnCloseRoot, final int cbOnErrorRoot, final int cbOnMessageRoot, final int cbOnOpenRoot) {
        FlowWebSocketClient webSocketClient = new FlowWebSocketClient(URI.create("wss://demos.kaazing.com/echo")) {
            @Override
            public void onOpen(ServerHandshake handshakedata) {
                wrapper.deliverWebSocketOnOpen(cbOnOpenRoot);
            }

            @Override
            public void onMessage(String message) {
                wrapper.deliverWebSocketOnMessage(cbOnMessageRoot, message);
            }

            @Override
            public void onClose(int code, String reason, boolean remote) {
                wrapper.deliverWebSocketOnClose(cbOnCloseRoot, code, reason, code == 1000);
            }

            @Override
            public void onError(Exception ex) {
                wrapper.deliverWebSocketOnError(cbOnErrorRoot, ex.getMessage());
            }
        };
        webSocketClient.connect();
        return webSocketClient;
    }

    boolean send(WebSocketClient webSocketClient, String message) {
        boolean isConnected = webSocketClient.getReadyState() == WebSocket.READYSTATE.OPEN;
        if (isConnected)
            webSocketClient.send(message);
        return isConnected;
    }

    boolean hasBufferedData(WebSocketClient webSocketClient) {
        return webSocketClient.getConnection().hasBufferedData();
    }

    void close(WebSocketClient webSocketClient, int code, String reason) {
        webSocketClient.getConnection().close(code, reason);
    }
}
