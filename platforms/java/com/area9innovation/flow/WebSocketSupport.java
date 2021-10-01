package com.area9innovation.flow;

import org.java_websocket.WebSocket;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.net.URI;

public class WebSocketSupport extends NativeHost{
    public static Object open(
            String url,
            Func3<Object, Integer, String, Boolean> onClose,
            Func1<Object, String> onError,
            Func1<Object, String> onMessage,
            Func0<Object> onOpen) {
        WebSocketClient webSocketClient = new WebSocketClient(URI.create(url)) {
            @Override
            public void onOpen(ServerHandshake handshakedata) {
                onOpen.invoke();
            }

            @Override
            public void onMessage(String message) {
                onMessage.invoke(message);
            }

            @Override
            public void onClose(int code, String reason, boolean remote) {
                onClose.invoke(code, reason, remote);
            }

            @Override
            public void onError(Exception ex) {
                onError.invoke(ex.getMessage());
            }
        };
        webSocketClient.connect();
        return webSocketClient;
    }

    public static Boolean send(Object webSocketClient, String message) {
        WebSocketClient client = (WebSocketClient) webSocketClient;
		
        boolean isConnected = client.getReadyState() == org.java_websocket.enums.ReadyState.OPEN;
        if (isConnected)
            client.send(message);
        return isConnected;
    }

    public static Boolean hasBufferedData(Object webSocketClient) {
        WebSocketClient client = (WebSocketClient) webSocketClient;
        return client.getConnection().hasBufferedData();
    }

    public static Object close(Object webSocketClient, int code, String reason) {
        WebSocketClient client = (WebSocketClient) webSocketClient;
        client.getConnection().close(code, reason);
        return null;
    }
}
