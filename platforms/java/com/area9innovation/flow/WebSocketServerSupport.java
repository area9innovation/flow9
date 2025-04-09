package com.area9innovation.flow;

import org.java_websocket.WebSocket;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.DefaultSSLWebSocketServerFactory;
import org.java_websocket.server.WebSocketServer;

import java.net.InetSocketAddress;
import java.util.HashMap;
import java.util.Map;

import javax.net.ssl.SSLContext;

public class WebSocketServerSupport extends NativeHost {

    private static Map<WebSocket, FlowWebSocketListeners> webSocketListeners = new HashMap<>();

    public static Func0<Object> createWsServerNative(
            int port,
            boolean isHttps,
            String pfxPath,
            String pfxPassword,
            Func1<Object, Object> onOpen,
            Func1<Object, String> onError
    ) {

        WebSocketServer server = new WebSocketServer(new InetSocketAddress(port)) {
            @Override
            public void onOpen(WebSocket webSocket, ClientHandshake clientHandshake) {
                onOpen.invoke(webSocket);
                FlowRuntime.eventLoop();
            }

            @Override
            public void onClose(WebSocket webSocket, int code, String reason, boolean remote) {
                if (webSocketListeners.containsKey(webSocket)) {
                    webSocketListeners.get(webSocket).onClose.invoke(code);
                    webSocketListeners.remove(webSocket);
                    FlowRuntime.eventLoop();
                }
            }

            @Override
            public void onMessage(WebSocket webSocket, String message) {
                if (webSocketListeners.containsKey(webSocket)) {
                    webSocketListeners.get(webSocket).onMessage.invoke(message);
                    FlowRuntime.eventLoop();
                }
            }

            @Override
            public void onError(WebSocket webSocket, Exception e) {
                if (webSocket != null) {
                    if (webSocketListeners.containsKey(webSocket)) {
                        webSocketListeners.get(webSocket).onError.invoke(e.getMessage());
                        FlowRuntime.eventLoop();
                    }
                } else {
                    onError.invoke(e.getMessage());
                }
            }

            @Override
            public void onStart() {
            }
        };
        if (isHttps) {
            try {
                SSLContext sslContext = HttpServerSupport.setupSSLContext(pfxPath, pfxPassword);
                server.setWebSocketFactory(new DefaultSSLWebSocketServerFactory(sslContext));
            } catch (Exception e) {
                onError.invoke(e.getMessage());
            }
        }
        server.start();
        return () -> {
            try {
                server.stop();
            } catch (Exception e) {
                onError.invoke(e.getMessage());
            }
            return null;
        };
    }

    public static Object embedListeners(
            Object webSocket,
            Func1<Object, Integer> onClose,
            Func1<Object, String> onError,
            Func1<Object, String> onMessage
    ) {
        WebSocket socket = (WebSocket) webSocket;
        webSocketListeners.put(socket, new FlowWebSocketListeners(onClose, onError, onMessage));
        return null;
    }

    public static boolean send(
            Object webSocket,
            String msg
    ) {
        WebSocket socket = (WebSocket) webSocket;
        if (socket.isOpen()) {
            socket.send(msg);
            return true;
        }
        return false;
    }

    public static Object close(
            Object webSocket,
            int code,
            String reason
    ) {
        WebSocket socket = (WebSocket) webSocket;
        socket.close(code, reason);
        return null;
    }

    public static int getBufferedAmount(
            Object webSocket
    ) {
        WebSocket socket = (WebSocket) webSocket;
        return socket.hasBufferedData() ? 1 : 0;
    }

    static class FlowWebSocketListeners {
        Func1<Object, Integer> onClose;
        Func1<Object, String> onError;
        Func1<Object, String> onMessage;

        FlowWebSocketListeners(Func1<Object, Integer> onClose, Func1<Object, String> onError, Func1<Object, String> onMessage) {
            this.onClose = onClose;
            this.onError = onError;
            this.onMessage = onMessage;
        }
    }
}
