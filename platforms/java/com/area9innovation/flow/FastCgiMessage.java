package com.area9innovation.flow;

import java.io.*;

public final class FastCgiMessage {
    public static final byte VERSION = 1;
    public static final int HEADER_LENGTH = 8;
    public static final int END_REQUEST_BODY_LENGTH = 8;

    public static final byte BEGIN_REQUEST = 1;
    public static final byte END_REQUEST = 3;
    public static final int PARAMETERS = 4;
    public static final byte STDIN = 5;
    public static final byte STDOUT = 6;

    public byte type;
    public int requestId;
    public int contentLength;
    public byte[] content;

    public FastCgiMessage(InputStream input) throws IOException {
        int version = input.read() & 0xff;
        if (version != VERSION) {
            throw new IOException("Invalid version");
        }
        type = (byte) (input.read() & 0xff);
        requestId = ((input.read() & 0xff) << 8) | (input.read() & 0xff);
        contentLength = ((input.read() & 0xff) << 8) | (input.read() & 0xff);
        int paddingLength = input.read() & 0xff;
        skip(1, input);
        if (contentLength > 0) {
            content = new byte[contentLength];
            readFully(content, input);
        }
        skip(paddingLength, input);
    }

    public FastCgiMessage(byte type, int requestId, byte content) {
        this(type, requestId);
        byte[] contentBytes = new byte[END_REQUEST_BODY_LENGTH];
        contentBytes[4] = content;
        setContent(contentBytes);
    }

    public FastCgiMessage(byte type, int requestId, byte[] content) {
        this(type, requestId);
        setContent(content);
    }

    public FastCgiMessage(byte type, int requestId) {
        this.type = type;
        this.requestId = requestId;
        setContent(null);
    }

    public static void readFully(byte[] content, InputStream input) throws IOException {
        int byteCount = content.length;
        int offset = 0;
        while (byteCount > 0) {
            int result = input.read(content, offset, byteCount);
            if (result < 0) {
                throw new EOFException();
            }
            offset += result;
            byteCount -= result;
        }
    }

    public static void skip(int len, InputStream input) throws IOException {
        int byteCount = len;
        while (byteCount > 0) {
            long result = input.skip(byteCount);
            if (result < 0) {
                throw new EOFException();
            }
            byteCount -= result;
        }
    }

    private static void writeToOutput(byte[] buffer, int offset, int length, int requestId, OutputStream outputStream) throws IOException {
        for (int offs = offset, len = Math.min(length, 0xffff);
             len != 0 && offs + len <= offset + length;
             offs += len, len = Math.min(offset + length - offs, 0xffff)) {
            byte[] content;
            if (offs == 0 && len == buffer.length) {
                content = buffer;
            } else {
                content = new byte[len];
                System.arraycopy(buffer, offs, content, 0, len);
            }
            FastCgiMessage message = new FastCgiMessage(STDOUT, requestId);
            message.setContent(content);
            message.write(outputStream);
        }
    }

    public void setContent(byte[] newContent) {
        contentLength = newContent == null ? 0 : newContent.length;
        content = contentLength == 0 ? null : newContent;
    }

    public void write(OutputStream output) throws IOException {
        byte[] header = new byte[HEADER_LENGTH];
        header[0] = VERSION;
        header[1] = type;
        header[2] = (byte) ((requestId >> 8) & 0xff);
        header[3] = (byte) (requestId & 0xff);
        header[4] = (byte) ((contentLength >> 8) & 0xff);
        header[5] = (byte) (contentLength & 0xff);
//        header[6] = 0;
//        header[7] = 0;
        output.write(header);
        if (content != null) {
            output.write(content);
        }
    }
}
