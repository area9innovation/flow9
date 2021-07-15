package dk.area9.flowrunner;

import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.io.OutputStream;
import java.io.Serializable;
import java.io.UnsupportedEncodingException;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.util.HashMap;

import java.net.HttpURLConnection;
import java.net.URL;
import java.util.List;
import java.util.Map;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.res.AssetManager;
import android.content.res.Resources;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.renderscript.ScriptGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.content.FileProvider;
import android.util.Log;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.CookieSyncManager;
import dk.area9.flowrunner.FlowRunnerWrapper.HttpResolver;

public class Utils {
    // if you want to make another tag for logging, please make it the same at the beginning, i.e. dk.area9.newtag
    // it will be easier to filter with adb or in Eclipse
    public static final String LOG_TAG = "dk.area9.flowrunner";

    //request codes for Activity.startActivityForResult
    static final int CAMERA_APP_PHOTO_MODE = 0;
    static final int CAMERA_APP_VIDEO_MODE = 1;
    static final int GALLERY_PHOTO_PICKER_MODE = 2;
    static final int GALLERY_VIDEO_PICKER_MODE = 3;
    static final int OPEN_FILE_DIALOG_MODE = 4;

    protected static boolean httpProfiling = false;

    public static final boolean isRequestPermissionsSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M;
    public static final boolean isFileProviderRequired = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N;

    //Camera2 is supported starting from API Level 21, but Camera2Enumerator(WebRTC) causes crashes on devices with API Level 21
    public static boolean isCamera2Supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1;
    public static boolean isMediaRecorderSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP;
    public static boolean isMediaRecorderPauseResumeSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N;

    public static void setHttpProfiling(boolean onoff) {
        httpProfiling = onoff;
    }
    
    @Nullable
    public static byte[] loadAssetData(@Nullable AssetManager assets, String name) {
        if (assets == null)
            return null;

        try {
            InputStream is = assets.open(name, AssetManager.ACCESS_STREAMING);

            return readToByteBufferAndClose(is);
        } catch (Exception e) {
            Log.e(LOG_TAG, "loadAssetData: " + e);
            return null;
        }
    }
    
    @Nullable
    public static byte[] loadRawData(@Nullable Resources resources, int id) {
        if (resources == null)
            return null;
        
        try {
            InputStream is = resources.openRawResource(id);

            return readToByteBufferAndClose(is);
        } catch (Exception e) {
            Log.e(LOG_TAG, "loadRawData: " + e);
            return null;
        }
    }
    
    public interface CopyProgressCallback {
        void copyProgress(long bytes);
    }
        
    public static void copyData(@NonNull OutputStream output, InputStream input, @Nullable CopyProgressCallback cb) throws IOException {
        int nRead;
        long progress = 0;
        byte[] data = new byte[65536];

        while ((nRead = input.read(data, 0, data.length)) != -1) {
            output.write(data, 0, nRead);
            if (cb != null)
                cb.copyProgress(progress += nRead);
        }
        
        output.flush();
    }
    
    public static byte[] readToByteBuffer(@NonNull InputStream input) throws IOException {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        copyData(buffer, input, null);
        return buffer.toByteArray();
    }
    
    public static byte[] readToByteBufferAndClose(@NonNull InputStream input) throws IOException {
        try {
            return readToByteBuffer(input);
        } finally {
            input.close();
        }
    }
    
    // fills HashMap with Keys and Values from query string
    @NonNull
    public static HashMap<String,String> decodeUrlQuery(String query) {
        HashMap<String,String> parameters = new HashMap<String,String>();
        
        for (String arg : query.split("&")) {
            String key = arg;
            String val = "";

            int ideq = key.indexOf('=');
            if (ideq >= 0) {
                key = arg.substring(0, ideq);
                val = arg.substring(ideq+1);
            }

            try {
                key = URLDecoder.decode(key, "UTF-8");
                val = URLDecoder.decode(val, "UTF-8");
            } catch (UnsupportedEncodingException e) {
                Log.wtf(LOG_TAG, "decodeUrlQuery: " + e);
            }

            parameters.put(key, val);
        }

        return parameters;
    }

    // makes query string from params
    public static String paramStringsToQuery(String[] params) throws UnsupportedEncodingException {
        StringBuffer sb = new StringBuffer();
        
        for (int i = 0; i < params.length; i+=2) {
            if (sb.length() > 0)
                sb.append("&");
            sb.append(URLEncoder.encode(params[i], "UTF-8"));
            sb.append("=");
            sb.append(URLEncoder.encode(params[i+1], "UTF-8"));
        }

        return sb.toString();
    }
    
    public interface HttpLoadCallback extends CopyProgressCallback {
        void httpFinished(int status, HashMap<String, String> headers, boolean withData);
        void httpOpened(HttpURLConnection connection);
        boolean httpStatus(int status);
        void httpError(String message);
        void httpAbort(String message);
        void httpContentLength(long bytes);
    }
    
    public static class HttpLoadAdaptor implements HttpLoadCallback {
        /**
         * Make sure you are invoking super.httpFinished(withData, status, headers) when overriding this method!
         */
        public void httpFinished(int status, HashMap<String, String> headers, boolean withData) {
            if (httpProfiling) {
                long ctm = System.currentTimeMillis();                
                Log.i(LOG_TAG, ">> Finished http request at {" + ctm + "}, took {" + (ctm - createdAt) + "} ms: {" + uriString + "}");
            }
        }
        public void httpOpened(HttpURLConnection connection) {}
        public boolean httpStatus(int status) { return status >= 200 && status < 300; }
        public void httpError(String message) {}
        public void httpAbort(String message) {}
        public void copyProgress(long bytes) {}
        public void httpContentLength(long bytes) {}
        
        private long createdAt;
        private String uriString;
        /**
         * All descendants of this class are created for single request and just before
         * it happens, so we can consider construction time and request start time similar. 
         * @param uriString -- string to identify it when profiling
         */
        public HttpLoadAdaptor(String uriString) {
            if (httpProfiling) {
                this.uriString = uriString;
                createdAt = System.currentTimeMillis();
                Log.i(LOG_TAG, "<< Started http request at {" + createdAt + "}: {" + uriString + "}");
            }
        }
        
    }

    public static void loadHttp(HttpURLConnection connection, @NonNull OutputStream output, HttpLoadCallback callback) throws IOException {
        int status = connection.getResponseCode();
        boolean ok = callback.httpStatus(status);
        boolean data_done = false;

        connection.connect();

        HashMap<String, String> headers = new HashMap<>();
        Map<String, List<String>> rawHeaders = connection.getHeaderFields();
        for (String headerName : rawHeaders.keySet()) {
            headers.put(headerName, rawHeaders.get(headerName).get(0));
        }

        InputStream contentStream = new BufferedInputStream(connection.getInputStream());
        int contentLength = contentStream.available();

        callback.httpContentLength(contentLength);
        try {
            if (ok) {
                copyData(output, contentStream, callback);
                data_done = true;
            }
        } finally {
            contentStream.close();
        }

        if (ok)
            callback.httpFinished(status, headers, data_done);
        else
            callback.httpError("HTTP " + status + " error");
    }

    public static byte[] loadHttpUrl(String link) {
        try{
            final boolean[] ok = new boolean[] { false };
            ByteArrayOutputStream buffer = new ByteArrayOutputStream();

            loadHttp((HttpURLConnection)new URL(link).openConnection(), buffer, new HttpLoadAdaptor(link) {
                public void httpFinished(int status, HashMap<String, String> headers, boolean withData) {
                    super.httpFinished(status, headers, withData);
                    ok[0] = withData;
                }
            });

            return ok[0] ? buffer.toByteArray() : null;
        } catch(Exception e){
            Log.e(LOG_TAG, "loadHttpUrl: " + e);
            return null;
        }
    }

    public static boolean loadHttpFile(String link, @NonNull String filename, @NonNull HttpLoadCallback callback) {
        try{
            FileOutputStream buffer = new FileOutputStream(filename);
            
            try {
                loadHttp((HttpURLConnection) new URL(link).openConnection(), buffer, callback);
            } finally {
                buffer.close();
            }

            return true;
        } catch(Exception e){
            Log.e(LOG_TAG, "loadHttpFile: " + e);
            return false;
        }
    }

    public static void loadHttpAsync(@NonNull final URL url, @Nullable final String method, @Nullable final Map<String, String> headers, @Nullable final byte[]  payload, @NonNull final OutputStream output, @NonNull final HttpLoadCallback callback) {
        Thread worker = new Thread(new Runnable() {
            public void run() {
                try {
                    HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                    if (method != null)
                        connection.setRequestMethod(method);

                    if (headers != null)
                        for (String headerName : headers.keySet())
                            connection.setRequestProperty(headerName, headers.get(headerName));

                    if (payload != null && payload.length != 0 && method != null && method.equals("POST")) {
                        connection.setDoOutput(true);
                        connection.getOutputStream().write(payload);
                    }

                    connection.setInstanceFollowRedirects(true);

                    callback.httpOpened(connection);

                    loadHttp(connection, output, callback);

                    connection.disconnect();
                } catch (IOException e) {
                    callback.httpError("I/O error: " + e.getMessage());
                } catch (Exception e) {
                    callback.httpError(e.getMessage());
                }
            }
        });

        worker.start();
    }

    public static void loadHttpAsync(@NonNull final URL url, @Nullable final String method, @Nullable final Map<String, String> headers, @Nullable final byte[]  payload, @NonNull final HttpResolver callback) {
        final OutputStream buffer = new OutputStream() {
            public void write(byte[] data, int start, int length) {
                byte[] buf = data;
                if (start != 0 || length != data.length) {
                    buf = new byte[length];
                    System.arraycopy(data, start, buf, 0, length);
                }
                callback.deliverData(buf, false);
            }
            public void write(int oneByte) {
                callback.deliverData(new byte[] { (byte)oneByte }, false);
            }
        };
        loadHttpAsync(url, method, headers, payload, buffer, new HttpLoadAdaptor(url.toString()) {
            public void httpFinished(int status, HashMap<String, String> headers, boolean withData) {
                super.httpFinished(status, headers, withData);
                callback.deliverData(null, true);
                callback.deliverDone(status, headers);
            }
            public boolean httpStatus(int status) {
                callback.reportStatus(status);
                return super.httpStatus(status);
            }
            public void httpError(String message) {
                callback.resolveError(message);
            }       
            long expectedContentLength = 0; 
            public void copyProgress(long bytes) {
                callback.reportProgress(bytes, expectedContentLength);
            }
            public void httpContentLength(long bytes) {
                expectedContentLength = bytes;
            }
        });
    }

    public static boolean urlHasExtension(URI link, @NonNull String ext) {
        return link.getScheme() != null &&
               link.getRawAuthority() != null &&
               link.getRawPath() != null &&
               link.getRawPath().toLowerCase().endsWith(ext);
    }

    public static URI urlWithExtension(URI link, int rsize, String new_ext) throws IOException {
        String path = link.getRawPath();
        path = path.substring(0, path.length() - rsize) + new_ext;
        
        String query = (link.getRawQuery() != null ? "?" + link.getRawQuery() : "");
        String fragment = (link.getRawFragment() != null ? "#" + link.getRawFragment() : "");
        
        try {
            return new URI(link.getScheme() + "://" + link.getAuthority() + path + query + fragment);
        } catch (URISyntaxException e) {
            throw new IOException("Cannot change URI extension");
        }        
    }

    // retrieves meta-data strings from manifest file
    @NonNull
    public static String getAppMetadata(Context ctx, String key) {
        try {
            ApplicationInfo ai = ctx.getPackageManager().getApplicationInfo(ctx.getPackageName(), PackageManager.GET_META_DATA);
            if (ai.metaData == null) return "";
            String val = ai.metaData.getString(key);  
            return val == null ? "" : val;
        } catch (NameNotFoundException e) {
            return "";
        }
    }
    
    // retrieves meta-data strings from manifest file
    public static boolean getAppMetadataBoolean(Context ctx, String key) {
        try {
            ApplicationInfo ai = ctx.getPackageManager().getApplicationInfo(ctx.getPackageName(), PackageManager.GET_META_DATA);
            if (ai.metaData == null) return false;
            return ai.metaData.getBoolean(key);  
        } catch (NameNotFoundException e) {
            return false;
        }
    }

    public static boolean isParamTrue(@Nullable String param) {
        return param != null && (param.equalsIgnoreCase("true") || param.equalsIgnoreCase("1"));
    }

    @NonNull
    public static HashMap<String,String> pref_url_parameters = new HashMap<String,String>(), manifest_url_params = new HashMap<String,String>();
    public static String getManifestParam(String key) {
        return manifest_url_params.get(key);
    }
    
    public static String getPrefsUrlParam(String key) {
        return pref_url_parameters.get(key);
    }
    
    public static Uri intent_Uri;
    public static String getIntentUrlParam(String key) {
        return intent_Uri.getQueryParameter(key);
    }
    
    // tries to get parameter's value from Intent, then from app's settings, then from manifest
    public static String getParam(String key) {
        String s = getIntentUrlParam(key);
        if (s != null) return s;
        
        s = getPrefsUrlParam(key);
        if (s != null) return s;
        
        s = getManifestParam(key);
        return s == null ? "" : s;
    }

    /**
     * Returns true if the given Activity has hardware acceleration enabled
     * in its foreground window.
     * There are three other different levels where it could be controlled, according
     * to documentation, but here we disable it in manifest and then enable in Activity
     */
    protected static boolean hasHardwareAcceleration(Activity activity) {
        // Has HW acceleration been enabled manually in the current window?
        Window window = activity.getWindow();
        if (window != null) {
            return (window.getAttributes().flags
                    & WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED) != 0; 
        }

        // Has HW acceleration been enabled in the manifest?
        // try {
        //    ActivityInfo info = activity.getPackageManager().getActivityInfo(
        //            activity.getComponentName(), 0);
        //    if ((info.flags & ActivityInfo.FLAG_HARDWARE_ACCELERATED) != 0) {
        //        return true;
        //    }
        // } catch (PackageManager.NameNotFoundException e) {
        //    Log.e(LOG_TAG, "getActivityInfo(self) should not fail");
        // }

        return false;
    }
    
    public static void handleHardwareAcceleration(boolean initialized, @NonNull Activity activity) {
        String haParam = Utils.getParam("ha");
        boolean haSetting = haParam == null || Utils.isParamTrue(haParam); // true by default
        if (!initialized) {
         // this could be executed only from main thread, not from LoadThread class
            activity.getWindow().setFlags(
                haSetting ? WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED : 0,
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
            Log.i(LOG_TAG, "Hardware acceleration : " + hasHardwareAcceleration(activity));
        } else if ( haSetting != hasHardwareAcceleration(activity)) {
            Log.w(LOG_TAG, "Can't toggle HA during run time in this build, stopping");
        }
    }
    
    public static void systemDownloadFile(Context context, String url) {
        Uri uri = Uri.parse(url);
        DownloadManager.Request r = new DownloadManager.Request(uri);
        r.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, uri.getLastPathSegment());
        r.allowScanningByMediaScanner();
        r.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
//        Activity a = (Activity)group.getContext();
//        DownloadManager dm = (DownloadManager)  a.getSystemService(Activity.DOWNLOAD_SERVICE);
        DownloadManager dm = (DownloadManager)context.getSystemService(Context.DOWNLOAD_SERVICE);
        dm.enqueue(r);
    }

    public static void deleteAppCookies(Context context) {
//        add this on 21 api level
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
//            CookieManager.getInstance().removeAllCookies(null);
//        } else {
            CookieSyncManager.createInstance(context);
            CookieSyncManager cookieSyncMngr = CookieSyncManager.getInstance();
            cookieSyncMngr.startSync();
            CookieManager cookieManager = CookieManager.getInstance();
            cookieManager.removeAllCookie();
            cookieManager.removeSessionCookie();
            cookieSyncMngr.stopSync();
            cookieSyncMngr.sync();
//        }
    }
    
    public static Editor sharedPreferencesPutDouble(final Editor edit, final String key, final double value) {
        return edit.putLong(key, Double.doubleToRawLongBits(value));
    }
    
    public static double sharedPreferencesGetDouble(final SharedPreferences prefs, final String key, final double defaultValue) {
        return Double.longBitsToDouble(prefs.getLong(key, Double.doubleToLongBits(defaultValue)));
    }

    /**
     *
     * @return true if permissions are granted. otherwise returns false and requests permissions
     */
    @RequiresApi(api = Build.VERSION_CODES.M)
    public static boolean checkAndRequestPermissions(@NonNull Activity activity, String[] permissions, int requestCode) {
        boolean granted = true;
        for(String permission : permissions) {
            if(activity.checkSelfPermission(permission) == PackageManager.PERMISSION_DENIED) {
                granted = false;
                break;
            }
        }
        if (!granted)
            activity.requestPermissions(permissions, requestCode);
        return granted;
    }

    public static Uri fileUriToContentUri(Context context, File file) {
        if(Utils.isFileProviderRequired) {
            return FileProvider.getUriForFile(context, context.getPackageName() + ".fileprovider", file);
        }
        return Uri.fromFile(file);
    }
    
    // method to retrieve correct path from uri like: content://
    // More info here: http://stackoverflow.com/questions/19834842/android-gallery-on-kitkat-returns-different-uri-for-intent-action-get-content
    public static String getPath(@NonNull final Context context, @NonNull final Uri uri) {
        final boolean isKitKat = Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT;
        String result = uri + "";
        // DocumentProvider
        //  if (isKitKat && DocumentsContract.isDocumentUri(context, uri)) {
        if (isKitKat && (result.contains("media.documents"))) {

            String[] ary = result.split("/");
            int length = ary.length;
            String imgary = ary[length - 1];
            final String[] dat = imgary.split("%3A");

            //final String docId = dat[1];
            final String type = dat[0];

            Uri contentUri = null;
            if ("image".equals(type)) {
                contentUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
            } else if ("video".equals(type)) {
            } else if ("audio".equals(type)) {
            }

            final String selection = "_id=?";
            final String[] selectionArgs = new String[] {dat[1]};

            return getDataColumn(context, contentUri, selection, selectionArgs);
        } else if ("content".equalsIgnoreCase(uri.getScheme())) {
            return getDataColumn(context, uri, null, null);
        } else if ("file".equalsIgnoreCase(uri.getScheme())) { // File
            return uri.getPath();
        }

        return null;
    }

    public static String getDataColumn(Context context, @NonNull Uri uri, String selection, String[] selectionArgs) {
        Cursor cursor = null;
        final String column = "_data";
        final String[] projection = {column};

        try {
            cursor = context.getContentResolver().query(uri, projection, selection, selectionArgs, null);
            if (cursor != null && cursor.moveToFirst()) {
                final int column_index = cursor.getColumnIndexOrThrow(column);
                return cursor.getString(column_index);
            }
        } finally {
            if (cursor != null)
                cursor.close();
        }
        return null;
    }
    
    // Based on ObjectSerializer from Apache pig
    // deserialize will fail, if we will not encode bytes from ByteArrayOutputStream
    public static String serializeObjectToString(@Nullable Serializable obj) {
        if (obj == null) return "";
        try {
            ByteArrayOutputStream serialObj = new ByteArrayOutputStream();
            ObjectOutputStream objStream = new ObjectOutputStream(serialObj);
            objStream.writeObject(obj);
            objStream.close();
            return encodeBytes(serialObj.toByteArray());
        } catch (Exception e) {
            Log.e(Utils.LOG_TAG, "serializeObjectToString error: " + e.getMessage());
        }
        return "";
    }

    public static Object deserializeStringToObject(@Nullable String str) {
        if (str == null || str.length() == 0) return null;
        try {
            ByteArrayInputStream serialObj = new ByteArrayInputStream(decodeBytes(str));
            ObjectInputStream objStream = new ObjectInputStream(serialObj);
            return objStream.readObject();
        } catch (Exception e) {
            Log.e(Utils.LOG_TAG, "deserializeStringToObject error: " + e.getMessage());
        }
        return null;
    }
    
    private static String encodeBytes(byte[] bytes) {
        StringBuffer strBuf = new StringBuffer();
        for (int i = 0; i < bytes.length; i++) {
            strBuf.append((char) (((bytes[i] >> 4) & 0xF) + ((int) 'a')));
            strBuf.append((char) (((bytes[i]) & 0xF) + ((int) 'a')));
        }
        return strBuf.toString();
    }
    
    @NonNull
    private static byte[] decodeBytes(String str) {
        byte[] bytes = new byte[str.length() / 2];
        for (int i = 0; i < str.length(); i += 2) {
            char c = str.charAt(i);
            bytes[i / 2] = (byte)((c - 'a') << 4);
            c = str.charAt(i + 1);
            bytes[i / 2] += (c - 'a');
        }
        return bytes;
    }
}
