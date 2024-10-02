package com.area9innovation.flow;

import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.ArrayList;

public final class FastCgi extends NativeHost {
    public static final byte REQUEST_COMPLETE = 0;
    public static final byte NO_MULTIPLEX_CONNECTION = 1;

    private static final int FCGI_KEEP_CONN = 1;
    private static final int FCGI_RESPONDER = 1;


    public static Object runFastCGIServer(int port, Func5<String, String, String, String, String, Object[]> callback, Func0<String> onError) {
        try {
            ServerSocket serverSocket = new ServerSocket(port);
            System.out.println("FastCGI server stared " + serverSocket);
            try {
                Socket socket = null;
                InputStream inputStream = null;
                OutputStream outputStream = null;
                while (true) {
                    if (socket == null) {
                        socket = serverSocket.accept();
                        inputStream = socket.getInputStream();
                        outputStream = socket.getOutputStream();
                        System.out.println("accepted socket " + socket);
                    }
                    HashMap<String, String> properties = null;
                    int requestId = 0;
                    boolean closeConnection = true;
                    byte[] data = null;

                    FastCgiMessage message;
                    do {
                        message = new FastCgiMessage(inputStream);
                        switch (message.type) {
                            case FastCgiMessage.BEGIN_REQUEST:
                                if (requestId != 0) {
                                    System.out.println("reject extra request with id " + message.requestId);
                                    //server tries to send multiplexed connection, but we process it only one by one, reject request:
                                    new FastCgiMessage(FastCgiMessage.END_REQUEST, message.requestId, NO_MULTIPLEX_CONNECTION).write(outputStream);
                                } else {
                                    requestId = message.requestId;
                                    closeConnection = (message.content[2] & FCGI_KEEP_CONN) == 0;
                                    int requestRole = ((message.content[0] & 0xff) << 8) | (message.content[1] & 0xff);
                                    if (requestRole != FCGI_RESPONDER) {
                                        throw new IOException("Only responder role is supported");
                                    }
                                    properties = new HashMap<String, String>();
                                    System.out.println("accept request id " + requestId);
                                }
                                break;

                            case FastCgiMessage.STDIN:
                                // Debug output
                                // System.out.println("STDIN " + message.contentLength);
                                if (message.contentLength > 0) {
                                    if (data == null) {
                                        data = message.content;
                                    } else {
                                        byte[] concatenated = new byte[data.length + message.contentLength];
                                        System.arraycopy(data, 0, concatenated, 0, data.length);
                                        System.arraycopy(message.content, 0, concatenated, data.length, message.contentLength);
                                        data = concatenated;
                                    }
                                }
                                break;

                            case FastCgiMessage.PARAMETERS:
                                if (message.contentLength > 0) {
                                    int[] length = new int[2];
                                    int offset = 0;
                                    while (offset < message.contentLength) {
                                        for (int i = 0; i < 2; i++) {
                                            length[i] = message.content[offset++];
                                            if ((length[i] & 0x80) != 0) {
                                                length[i] = ((length[i] & 0x7f) << 24) |
                                                        ((message.content[offset++] & 0xff) << 16) |
                                                        ((message.content[offset++] & 0xff) << 8) |
                                                        (message.content[offset++] & 0xff);
                                            }
                                        }
                                        String name = new String(message.content, offset, length[0]);
                                        String value = new String(message.content, offset + length[0], length[1]);
                                        // Debug output
                                        // System.out.println("PARAM " + name + " = " + value);
                                        properties.put(name, value);
                                        offset += length[0] + length[1];
                                    }
                                }
                                break;
                        }
                    }
                    while (message.type != FastCgiMessage.STDIN || message.contentLength != 0);

                    new FastCgiMessage(FastCgiMessage.STDOUT, requestId, processRequest(data, properties, callback, onError).getBytes()).write(outputStream);
                    new FastCgiMessage(FastCgiMessage.STDOUT, requestId).write(outputStream);
                    new FastCgiMessage(FastCgiMessage.END_REQUEST, requestId, REQUEST_COMPLETE).write(outputStream);

                    if (closeConnection) {
                        System.out.println("finished request id " + requestId);
                        try {
                            outputStream.close();
                        } catch (IOException ignored) {
                        }
                        try {
                            inputStream.close();
                        } catch (IOException ignored) {
                        }
                        try {
                            socket.close();
                        } catch (IOException ignored) {
                        }
                        socket = null;
                    } else {
                        System.out.println("finished request id " + requestId);
                        outputStream.flush();
                    }
                }
            } finally {
                serverSocket.close();
            }
        }
        catch (IOException e) {
            System.out.println("FastCGI server failed: " + e.getMessage());
            return null;
        }
    }
    private static String[][] emptyarr = new String[0][];
    private static String processRequest(byte[] data,
        HashMap<String, String> properties,
        Func5<String, String, String, String, String, Object[]> callback,
        Func0<String> onError) throws IOException
    {
	    ArrayList<String[]> callbackParams = new ArrayList<String[]>();
	    String[][] props = null;
        if (properties == null) {
	        return onError.invoke();
        } else {
            String query = properties.get("QUERY_STRING");
            String path = properties.get("SCRIPT_NAME");
            String method = properties.get("REQUEST_METHOD");

            String sdata = "";

            if (data != null && data.length > 0) {
                sdata = new String(data, "UTF-8");
            }

            for (Map.Entry<String, String> stringStringEntry : properties.entrySet()) {
                callbackParams.add(new String[] {stringStringEntry.getKey(), stringStringEntry.getValue()});
            }

            props = callbackParams.toArray(emptyarr);
            return callback.invoke(path, method, query, sdata, props);
        }
    }
}

