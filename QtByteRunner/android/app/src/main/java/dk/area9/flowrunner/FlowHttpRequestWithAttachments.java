package dk.area9.flowrunner;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

import android.net.Uri;
import android.os.AsyncTask;
import dk.area9.flowrunner.FlowRunnerWrapper.HttpResolver;

public class FlowHttpRequestWithAttachments extends AsyncTask<Void, Void, byte[]> {
    
    private static final int MAX_BUFFER_SIZE = 1 * 1024 * 1024;
    
    private String url;
    private String[] headers;
    private String[] requestParams;
    private String[] attachments;
    private HttpResolver httpCallbackResolver;
    
    private int serverResponseCode;
    private String exceptionMessage;

    public FlowHttpRequestWithAttachments(String url, String[] headers, String[] requestParams, String[] attachments, HttpResolver cb) {
       this.url = url;
       this.headers = headers;
       this.requestParams = requestParams;
       this.attachments = attachments;
       this.httpCallbackResolver = cb;
    }
    
    @Override
    protected byte[] doInBackground(Void... params) {
        final String lineEnd = "\r\n";
        final String twoHyphens = "--";
        final String boundary = "*****";
        
        HttpURLConnection conn = null;
        DataOutputStream dos = null;
        byte[] buffer = new byte[MAX_BUFFER_SIZE];
        byte[] serverResponse = null;
        
        try {
            URL uploadUrl = new URL(url);
            conn = (HttpURLConnection) uploadUrl.openConnection();
            
            conn.setDoInput(true);
            conn.setDoOutput(true);
            conn.setUseCaches(false);
            conn.setRequestMethod("POST");
            
            conn.setRequestProperty("Connection", "Keep-Alive");
            conn.setRequestProperty("Cache-Control", "no-cache");
            conn.setRequestProperty("Content-Type", "multipart/form-data;boundary=" + boundary);
            for (int i = 0; i < headers.length; i+=2) {
                conn.setRequestProperty(headers[i], headers[i + 1]);
            }
            
            dos = new DataOutputStream(conn.getOutputStream());
            // write parameters from requestParams array
            for (int i = 0; i < requestParams.length; i += 2) {
                dos.writeBytes(twoHyphens + boundary + lineEnd);
                dos.writeBytes("Content-Disposition: form-data; name=\"" + requestParams[i] + "\"" + lineEnd + lineEnd + requestParams[i + 1] + lineEnd);
            }

            for (int i = 0; i < attachments.length; i += 2) {
                dos.writeBytes(twoHyphens + boundary + lineEnd);
                dos.writeBytes("Content-Disposition: form-data; name=\"" + attachments[i] + "\";filename=\""+ attachments[i] + "\"" + lineEnd + lineEnd);
                // We can't just pass attachments[i + 1]. For some reason if there uri in string, like
                // file:/some/path/to/file, we will get FileNotFoundException after new FileInputStream
                Uri attachmentUri = Uri.parse(attachments[i + 1]);
                File file = new File(attachmentUri.getPath());
                InputStream fis = new FileInputStream(file);
                int bytesRead = 0;
                while ((bytesRead = fis.read(buffer)) != -1) {
                    dos.write(buffer, 0, bytesRead);
                }

                dos.writeBytes(lineEnd);
                fis.close();
            }

            dos.writeBytes(lineEnd);
            dos.writeBytes(twoHyphens + boundary + twoHyphens);
            dos.flush();
            dos.close();
            
            serverResponseCode = conn.getResponseCode();
            serverResponse = readServerResponse(conn.getInputStream(), buffer);
        } catch (MalformedURLException e) {
            exceptionMessage = "Url is incorrect: " + e.getMessage();
            serverResponse = null;
        } catch (IOException e) {
            exceptionMessage = "I/O error: " + e.getMessage();
            serverResponse = null;
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
        
        return serverResponse;
    }
    
    private byte[] readServerResponse(InputStream ris, byte[] tmpBuffer) throws IOException {
        ByteArrayOutputStream byteArrayStream = new ByteArrayOutputStream();
        int bytesRead = 0;
        while ((bytesRead = ris.read(tmpBuffer)) != -1) {
            byteArrayStream.write(tmpBuffer, 0, bytesRead);
        }
        return byteArrayStream.toByteArray();
    }
    
    @Override
    protected void onPostExecute(byte[] serverResponse) {
        // add serverResponseCode checking
        if (serverResponse != null) {
            httpCallbackResolver.deliverData(serverResponse, true);
        } else {
            httpCallbackResolver.resolveError("runner: failed to upload files. message: " + exceptionMessage);
        }
    }

}