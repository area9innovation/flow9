package dk.area9.flowrunner;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.net.Uri;
import android.opengl.GLSurfaceView;
import android.opengl.GLUtils;
import android.os.Handler;
import android.preference.PreferenceManager;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.text.TextPaint;
import android.util.Log;
import android.content.Context;
import android.content.SharedPreferences;

import org.java_websocket.client.WebSocketClient;

public final class FlowRunnerWrapper implements GLSurfaceView.Renderer {
    /*
     * Native back-end initialization 
     */
    static {
        System.loadLibrary("flowrunner");
        initLibrary(true);
    }

    private static native void initLibrary(boolean logStreams);

    /**
     * Native object pointer.
     */
    private long c_ptr;
    
    private native long allocBackend();
    private native void deleteBackend(long obj); // safe to call on NULL
    
    public final boolean isValid() { return c_ptr != 0; }
    
    private final long cPtr() {
        if (c_ptr == 0)
            throw new IllegalStateException("FlowRunnerWrapper has already been destroyed");
        return c_ptr;
    }

    /* Timers */
    @NonNull
    private final Handler timer_engine;
    
    /**
     * Create a runner wrapper object, including the native back-end.
     */
    public FlowRunnerWrapper() {
        listeners = new ArrayList<Listener>();
        timer_engine = new Handler();
        c_ptr = allocBackend();
    }
    
    /**
     * Set the directory to use for temporary files.
     */
    public void setTmpPath(String path) {
        Log.i(Utils.LOG_TAG, "TmpPath " + path);
        nSetTmpPath(cPtr(), path);
    }
    
    public void onGoogleServicesConnected() {
        if (flowGeolocationAPI != null) {
            flowGeolocationAPI.resumeListeners();
        }
    }
    
    public void onGoogleServicesDisconnected() {
        if (flowGeolocationAPI != null) {
            flowGeolocationAPI.pauseListeners();
        }
    }

    public native void nSetTmpPath(long ptr, String path);

    /**
     * Set the directory to use for key storage.
     */
    public void setStorePath(String path) {
        Log.i(Utils.LOG_TAG, "StorePath " + path);
        nSetStorePath(cPtr(), path);
    }

    private native void nSetStorePath(long ptr, String path);

    /**
     * Explicitly destroys the native back-end.
     * The object becomes unusable after this.
     */
    public synchronized void destroy() {
        deleteBackend(c_ptr);
        c_ptr = 0;

        doRunnerReset(true);
        
        if (getStorePurchaseEnabled())
            storePurchaseAPI.destroyServiceConnection();
    }
    
    protected void finalize() {
        destroy();
    }
    
    /**
     * Reset the runner state.
     */
    public synchronized void reset() {
        nReset(cPtr());
    }
    
    private native void nReset(long ptr);
    
    /**
     * Load a bytecode file into the runner.
     * 
     * @param file Fully qualified name of the file.
     * @return true if successful.
     */
    public synchronized boolean loadBytecode(String file) {
        return nLoadBytecode(cPtr(), file);
    }
    
    private native boolean nLoadBytecode(long ptr, String file);

    /**
     * Load a bytecode buffer into the runner.
     * 
     * @param data Binary bytecode data.
     * @return true if successful.
     */
    public synchronized boolean loadBytecode(byte[] data) {
        Log.i(Utils.LOG_TAG, "loadBytecode: bytecode size = " + data.length);
        return nLoadBytecodeData(cPtr(), data);
    }
    
    private native boolean nLoadBytecodeData(long ptr, byte[] data);
    
    /**
     * Sets the screen DPI to report to the bytecode.
     */
    private int dpi = 120;
    
    
    private native void nSetDPI(long ptr, int dpi);
    
    public synchronized void setDPI(int dpi) {
        nSetDPI(cPtr(), this.dpi = dpi);
    }

    private native void nSetDensity(long ptr, float density);

    public synchronized void setDensity(float density) {
        nSetDensity(cPtr(), density);
    }
    
    public int getDPI() {
        return dpi;
    }

    private native void nSetScreenWidthHeight(long ptr, int width, int height);
    public synchronized void setScreenWidthHeight(int width, int height) {
        nSetScreenWidthHeight(cPtr(), width, height);
    }
    
    /**
     * Remove all url parameters.
     */
    public synchronized void setUrlParameters(String url) {
        nSetUrlParameters(cPtr(), url, new String[0]);
    }

    /**
     * Enable/Disable Flow runner time profiling
     * @param flow_time_profile
     */
    public synchronized void setFlowTimeProfile(boolean flow_time_profile, short flow_time_profile_trace_per) {
        nSetFlowTimeProfile(cPtr(), flow_time_profile, flow_time_profile_trace_per);
    }

    private native void nSetFlowTimeProfile(long ptr, boolean flow_time_profile, short flow_time_profile_trace_per);

    /**
     * Assign the url parameters for the bytecode from the map.
     */
    public synchronized void setUrlParameters(String url, @Nullable Map<String,String> string_map) {
        if (string_map == null) {
            setUrlParameters(url);
            return;
        }
        
        String[] data = new String[string_map.size()*2];
        int i = 0;
        
        for (Entry<String,String> item : string_map.entrySet()) {
            data[i++] = item.getKey();
            data[i++] = item.getValue();
        }
            
        nSetUrlParameters(cPtr(), url, data);
    }

    private native void nSetUrlParameters(long ptr, String url, String[] data);
    
    /**
     * Assign the url parameters from an url-encoded query.
     * @param query Sequence of name=value pairs, joined using &.
     */
    public synchronized void setUrlParameters(String url, @Nullable String query) {
        if (query == null) {
            setUrlParameters(url);
            return;
        }

        setUrlParameters(url, Utils.decodeUrlQuery(query));
    }
    
    public synchronized void setUrlParameters(Uri query) {
        setUrlParameters(query.toString(), query.getQuery());
    }

    /**
     * Run the main function of the bytecode file,
     * if not done already. It is safe to call this
     * multiple times.
     * 
     * @return true if successful or already done
     */
    
    public synchronized boolean runMain() {
        return nRunMain(cPtr());
    }
    
    private native boolean nRunMain(long ptr);
    
    /**
     * Retrieve the active runner error message.
     * 
     * @return error message, or null if no error
     */
    @NonNull
    public synchronized String getRunnerError() {
        return nGetRunnerError(cPtr());
    }

    @NonNull
    private native String nGetRunnerError(long ptr);
    
    /**
     * Retrieve the debugging info associated
     * with the active runner error.
     * 
     * @return error information, or null if no error
     */
    @NonNull
    public synchronized String getRunnerErrorInfo() {
        return nGetRunnerErrorInfo(cPtr());
    }

    @NonNull
    private native String nGetRunnerErrorInfo(long ptr);

    /**
     * Load a font file into the render engine. 
     * 
     * @param filename Name of the file to load.
     * @param aliases Font family names that it should be used for.
     * @param makeDefault 
     *   Set this font as a fall-back for unknown font names.
     *   The very first font to be loaded is set as default implicitly.
     */
    public synchronized void attachFontFile(String filename, String[] aliases, boolean makeDefault) {
        nAttachFontFile(cPtr(), filename, aliases, makeDefault);
    }

    private native void nAttachFontFile(long ptr, String filename, String[] aliases, boolean makeDefault);
    
    /**
     * Same as attachFontFile(filename, aliases, false);
     */
    public synchronized void attachFontFile(String filename, String[] aliases) {
        nAttachFontFile(cPtr(), filename, aliases, false);
    }
    
    /* GL renderer interface */
    public synchronized void onSurfaceCreated(GL10 gl, EGLConfig config) {
        nRendererInit(cPtr());
    }

    public synchronized void onSurfaceChanged(GL10 gl, int width, int height) {
        nRendererResize(cPtr(), width, height);
    }
    
    private long prev = 0;
        
    public synchronized void onDrawFrame(GL10 gl) {
        /*long cur = System.currentTimeMillis();
        Log.i(Utils.LOG_TAG, "time: " + (cur - prev));
        prev = cur;*/

        nRendererPaint(cPtr());
    }
    
    private native void nRendererInit(long ptr);
    private native void nRendererResize(long ptr, int w, int h);
    private native void nRendererPaint(long ptr);

    /**
     * Listener interface for receiving events from the runner.
     * The callbacks are always invoked from within a wrapper
     * method call, and are not allowed to destroy the wrapper.
     */
    public interface Listener {
        void onFlowNeedsRepaint();
        void onFlowError(String msg, String debug_info);
        void onFlowReset(boolean post_destroy);
        boolean onFlowBrowseUrl(String url, String target);
    }
    
    public static class ListenerAdapter implements Listener {
        public void onFlowNeedsRepaint() {}
        public void onFlowError(String msg, String debug_info) {}
        public void onFlowReset(boolean post_destroy) {}
        public boolean onFlowBrowseUrl(String url, String target) { return false; }
    }
    
    private ArrayList<Listener> listeners;

    public synchronized boolean addListener(Listener obj) {
        if (listeners.contains(obj))
            return false;

        listeners.add(obj);
        return true;
    }
    
    public synchronized void removeListener(Listener obj) {
        listeners.remove(obj);
    }

    /* Callbacks for native code. Synchronization already
     * provided by the entries on the call stack. */
    private void cbNeedsRepaint() {
        ArrayList<Listener> to_call = new ArrayList<Listener>(listeners);
        for (Listener listener : to_call)
            listener.onFlowNeedsRepaint();
    }

    private void cbRunnerError() {
        String msg = getRunnerError();
        String info = getRunnerErrorInfo();
        
        ArrayList<Listener> to_call = new ArrayList<Listener>(listeners);
        for (Listener listener : to_call)
            listener.onFlowError(msg, info);
    }
    
    private void cbBrowseUrl(String url, String target) {
        ArrayList<Listener> to_call = new ArrayList<Listener>(listeners);
        for (Listener listener : to_call)
            if (listener.onFlowBrowseUrl(url, target))
                return;
    }

    private void cbRunnerReset() {
        doRunnerReset(false);
    }
    
    private void doRunnerReset(boolean post_destroy) {
        timer_engine.removeCallbacksAndMessages(null);
        
        ArrayList<Listener> to_call = new ArrayList<Listener>(listeners);
        for (Listener listener : to_call)
            listener.onFlowReset(post_destroy);
        
        if (post_destroy)
            listeners.clear();
    }

    private void cbNewTimer(final int id, int delay_ms) {
        if (timer_engine == null) return;
        
        Runnable tt = new Runnable() {
            public void run() {
                deliverTimer(id);
            }
        };

        timer_engine.postDelayed(tt, delay_ms);
    }
    
    private synchronized void deliverTimer(int id) {
        if (c_ptr != 0)
            nDeliverTimer(c_ptr, id);
    }
    
    private native void nDeliverTimer(long ptr, int id);
    
    /* Pictures */
    
    public interface PictureResolver extends ResourceCache.Resolver {
        /**
         * Supply a loaded bitmap to the renderer.
         * @return true if not already resolved. 
         */
        boolean resolveBitmap(Bitmap bmp);
        /**
         * Supply a loaded bitmap to the renderer.
         * @return true if not already resolved. 
         */
        boolean resolveBitmap(byte[] bmp);
    }
    
    public interface PictureLoader {
        /**
         * Load a picture for the flow renderer.
         * 
         * @param url Location of the picture.
         * @param cache Should the picture be aggressively cached.
         * @param callback Interface for supplying the picture back to the renderer.
         *                 May be called either immediately or asynchronously. 
         */
        void load(String url, boolean cache, PictureResolver callback) throws IOException;

        void abortPictureLoad(String url);
    }
    
    @Nullable
    private PictureLoader picture_loader = null;

    public synchronized void setPictureLoader(PictureLoader loader) {
        picture_loader = loader;
    }
    
    private void cbLoadPicture(final String url, boolean cache) {
        if (picture_loader == null) {
            nResolvePictureError(cPtr(), url, "PictureLoader not set");
            return;
        }

        try {
            PictureResolver cb = new PictureResolver() {
                public boolean resolveBitmap(@NonNull Bitmap bmp) {
                    return resolvePictureBitmap(url, bmp, bmp.getWidth(), bmp.getHeight());
                }
                public void resolveFile(String filename) {
                    resolvePictureBitmapFile(url, filename);
                }
                public boolean resolveBitmap(byte[] data) {
                    return resolvePictureBitmapData(url, data);
                }
                public void resolveError(String message) {
                    resolvePictureError(url, message);
                }
            };

            picture_loader.load(url, cache, cb);
        } catch (IOException e) {
            nResolvePictureError(cPtr(), url, "I/O error: " + e.getMessage());
        }
    }

    private void cbAbortPictureLoading(final String url) {
        picture_loader.abortPictureLoad(url);
    }

    private void cbBindTextureBitmap(Bitmap bitmap) {
        GLUtils.texImage2D(GL10.GL_TEXTURE_2D, 0, bitmap, 0);
    }
    
    private synchronized boolean resolvePictureBitmap(String url, Bitmap bmp, int w, int h) {
        if (!isValid()) return false;
        return nResolvePictureBitmap(cPtr(), url, bmp, w, h);
    }

    private synchronized native boolean nResolvePictureBitmap(long ptr, String url, Bitmap bmp, int w, int h);
    
    private synchronized boolean resolvePictureBitmapFile(String url, String filename) {
        if (!isValid()) return false;
        return nResolvePictureBitmapFile(cPtr(), url, filename);
    }

    private synchronized native boolean nResolvePictureBitmapFile(long ptr, String url, String filename);
    
    private synchronized boolean resolvePictureBitmapData(String url, byte[] data) {
        if (!isValid()) return false;
        return nResolvePictureBitmapData(cPtr(), url, data);
    }

    private synchronized native boolean nResolvePictureBitmapData(long ptr, String url, byte[] data);
    
    private synchronized boolean resolvePictureError(String url, String error) {
        if (!isValid()) return false;
        return nResolvePictureError(cPtr(), url, error);
    }

    private synchronized native boolean nResolvePictureError(long ptr, String url, String error);

    /* HTTP Requests */
    public interface HttpResolver {
        /**
         * Report http request finished loading
         */
        void deliverDone(int status, HashMap<String, String> headers);
        /**
         * Supply loaded http response data.
         */
        void deliverData(byte[] bmp, boolean last);
        /**
         * Report a loading error to the flow runner.
         */
        void resolveError(String message);
        /**
         * Report HTTP status code
         */
        void reportStatus(int status);
        /**
         * Report loading progress
         */
        void reportProgress(float loaded, float total);
    }
    
    public interface HttpLoader {
        /**
         * Perform an HTTP request.
         * 
         * @param url Location of the picture.
         * @param method HTTP request method
         * @param callback Interface for supplying the data back to flow code.
         * @param headers A flattened map of HTTP headers to set.
         * @param payload A binary string sent to the server as request body
         */
        void request(String url, String method, String[] headers, byte[] payload, HttpResolver callback) throws IOException;

        /**
         * Preload a media object.
         * @param url Location of the media.
         */
        void preloadMedia(String url, ResourceCache.Resolver callback) throws IOException;
        /**
         * Removes a media from local cache.
         * @param url Location of the media.
         */
        void removeCachedMedia(String url) throws IOException;
    }

    @Nullable
    private HttpLoader http_loader = null;

    public synchronized void setHttpLoader(HttpLoader loader) {
        http_loader = loader;
    }
    
    private void cbStartHttpRequest(final int id, final String url, final String method, String[] headers, final byte[] payload) {
        if (http_loader == null) {
            deliverHttpError(id, "HttpLoader not set".getBytes());
            return;
        }

        try {
            HttpResolver cb = new HttpResolver() {
                public void deliverDone(int status, HashMap<String, String> headers) {
                    deliverHttpResponse(id, status, headers);
                }
                public void deliverData(byte[] bytes, boolean last) {
                    deliverHttpData(id, bytes, last);
                }
                public void resolveError(String message) {
                    deliverHttpError(id, message.getBytes());
                }
                public void reportStatus(int status) {
                    deliverHttpStatus(id, status);                    
                }
                public void reportProgress(float loaded, float total) {
                    deliverHttpProgress(id, loaded, total);                    
                }
            };

            http_loader.request(url, method, headers, payload, cb);
        } catch (IOException e) {
            String message = "I/O error: " + e.getMessage();
            deliverHttpError(id, message.getBytes());
        }
    }

    private void cbStartMediaPreload(final int id, final String url) {
        if (http_loader == null) {
            String message = "HttpLoader not set";
            deliverHttpError(id, message.getBytes());
            return;
        }

        try {
            ResourceCache.Resolver cb = new ResourceCache.Resolver() {
                public void resolveFile(String fn) {
                    deliverHttpData(id, new byte[]{}, true);
                    deliverHttpResponse(id, 200, new HashMap());
                }
                public void resolveError(String message) {
                    deliverHttpError(id, message.getBytes());
                }
            };

            http_loader.preloadMedia(url, cb);
        } catch (IOException e) {
            String message = "I/O error: " + e.getMessage();
            deliverHttpError(id, message.getBytes());
        }
    }
    
    private void cbRemoveUrlFromCache(final String url) {
        if (http_loader != null) {
            try {
                http_loader.removeCachedMedia(url);
            } catch (IOException e) {
                Log.i(Utils.LOG_TAG, "Cannot remove cached media: " + url);
            }
        }
    }
    
    private void cbSystemDownloadFile(final String url) {
        if (widget_host != null)
            Utils.systemDownloadFile(widget_host.getWidgetHostContext(), url);
    }

    private void cbDeleteAppCookies() {
        if (widget_host != null)
            Utils.deleteAppCookies(widget_host.getWidgetHostContext());
    }
    
    private boolean cbUsesNativeVideo() {
        if (widget_host != null) {
            SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(widget_host.getWidgetHostContext());
            return !prefs.getBoolean("opengl_video", true);
        }
        return true;
    }

    private synchronized void deliverHttpError(int id, byte[] error) {
        if (isValid())
            nDeliverHttpError(cPtr(), id, error);
    }
    
    private native void nDeliverHttpError(long ptr, int id, byte[] error);
    
    private synchronized void deliverHttpData(int id, byte[] data, boolean last) {
        if (isValid())
            nDeliverHttpData(cPtr(), id, data, last);
    }
    
    private native void nDeliverHttpResponse(long ptr, int id, int status, String[] headersArray);

    private synchronized void deliverHttpResponse(int id, int status, HashMap<String, String> headers) {
        if (isValid())
            nDeliverHttpResponse(cPtr(), id, status, parseHashMapToArray(headers));
    }

    private native void nDeliverHttpData(long ptr, int id, byte[] data, boolean last);
    
    private synchronized void deliverHttpProgress(final int id, final float loaded, final float total) {
        if (isValid()) {
            nDeliverHttpProgress(cPtr(), id, loaded, total); 
        }
    }
    
    private native void nDeliverHttpProgress(long ptr, int id, float loaded, float totoal);
    
    private synchronized void deliverHttpStatus(int id, int status) {
        if (isValid())
            nDeliverHttpStatus(cPtr(), id, status);
    }
    
    private native void nDeliverHttpStatus(long ptr, int id, int status);
    
    /* Assets */
    @Nullable
    private AssetManager assets = null;
    
    public void setAssets(AssetManager amgr) {
        assets = amgr;
    }
    
    @Nullable
    private byte[] cbLoadAssetData(String name) {
        return Utils.loadAssetData(assets, name);
    }
    
    /**
     * Delivers a mouse event to the flow code.
     */
    public synchronized void deliverMouseEvent(int type, int x, int y) {
        nDeliverMouseEvent(cPtr(), type, x, y);
    }

    public static int EVENT_MOUSE_DOWN = 10;
    public static int EVENT_MOUSE_UP = 11;
    public static int EVENT_MOUSE_MOVE = 12;
    public static int EVENT_MOUSE_CANCEL = 16;

    private native void nDeliverMouseEvent(long ptr, int type, int x, int y);
    
    /**
     * Delivers a gesture event to the flow code.
     */
    public static int EVENT_GESTURE_PAN = 65;
    public static int EVENT_GESTURE_PINCH = 63;

    public static int GESTURE_STATE_BEGIN = 0;
    public static int GESTURE_STATE_PROGRESS = 1;
    public static int GESTURE_STATE_END = 2;
    
    public synchronized boolean deliverGestureEvent(int type, int state, float p1, float p2, float p3, float p4) {
        return nDeliverGestureEvent(cPtr(), type, state, p1, p2, p3, p4);
    }
    
    private native boolean nDeliverGestureEvent(long ptr, int type, int state, float p1, float p2, float p3, float p4);
    
    /**
     * Adjusts stage-level scaling configuration.
     * 
     * @param dx Number of pixels to shift to the right at current scaling.
     * @param dy Number of pixels to shift to the bottom at current scaling.
     * @param cx X coordinate of the incremental scaling pivot point.
     * @param cy Y coordinate of the incremental scaling pivot point.
     * @param fct Incremental scaling factor.
     */
    public synchronized void adjustGlobalScale(float dx, float dy, float cx, float cy, float fct) {
        nAdjustGlobalScale(cPtr(), dx, dy, cx, cy, fct);
    }
    
    private native void nAdjustGlobalScale(long ptr, float dx, float dy, float cx, float cy, float fct);
    
    /*
     * Native widgets
     */

    public interface WidgetHost {
        void onFlowDestroyWidget(long id);
        void onFlowResizeWidget(
            long id, boolean visible, 
            float minx, float miny, float maxx, float maxy,
            float scale, float alpha
        );
        void onFlowCreateTextWidget(
            long id, String text,
            String font_name, float font_size, int font_color,
            boolean multiline, boolean readonly, float line_spacing,
            String text_input_type, String alignment,
            int max_size, int cursor_pos, int sel_start, int sel_end
        );
        void onFlowCreateVideoWidget(long id, String url, boolean playing, boolean looping, int controls, float volume);
        void onFlowCreateVideoWidgetFromMediaStream(long id, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream);
        void onFlowCreateWebWidget(long id, String url);
        void onFlowWebClipHostCall(long id, String js);
        void onFlowSetWebClipZoomable(long id, boolean zoomable);
        void onFlowSetWebClipDomains(long id, String[] domains);
        void onFlowUpdateVideoPlay(long id, boolean playing);
        void onFlowUpdateVideoPosition(long id, long position);
        void onFlowUpdateVideoVolume(long id, float volume);
        
        void onFlowCreateCameraWidget(long id, int camID, int camWidth, int camHeight, int camFps, int recordMode);
        void onFlowUpdateCameraWidget(long id, String filename, boolean record);
        void onFlowSetInterfaceOrientation(String orientation);
        Context getWidgetHostContext();
    }

    @Nullable
    private WidgetHost widget_host = null;

    public void setWidgetHost(WidgetHost host) {
        widget_host = host;
    }

    private void cbDestroyWidget(long id) {
        if (widget_host != null)
            widget_host.onFlowDestroyWidget(id);
    }

    private void cbResizeWidget(
        long id, boolean visible, 
        float minx, float miny, float maxx, float maxy,
        float scale, float alpha
    ) {
        if (widget_host != null)
            widget_host.onFlowResizeWidget(id, visible, minx, miny, maxx, maxy, scale, alpha);
    }

    private void cbCreateTextWidget(
        long id, String text,
        String font_name, float font_size, int font_color,
        boolean multiline, boolean readonly, float line_spacing,
        String text_input_type, String alignment,
        int max_size, int cursor_pos, int sel_start, int sel_end
    ) {
        if (widget_host != null)
            widget_host.onFlowCreateTextWidget(
                id, text, font_name, font_size, font_color, multiline, readonly, line_spacing,
                text_input_type, alignment, max_size, cursor_pos, sel_start, sel_end
            );
    }

    private void cbCreateVideoWidget(long id, String url, boolean playing, boolean looping, int controls, float volume) {
        if (widget_host != null)
            widget_host.onFlowCreateVideoWidget(id, url, playing, looping, controls, volume);
    }
    
    private void cbCreateVideoWidgetFromMediaStream(long id, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream) {
        if (widget_host != null)
            widget_host.onFlowCreateVideoWidgetFromMediaStream(id, flowMediaStream);
    }

    private void cbUpdateVideoPlay(long id, boolean playing) {
        if (widget_host != null)
            widget_host.onFlowUpdateVideoPlay(id, playing);
    }

    private void cbUpdateVideoPosition(long id, long position) {
        if (widget_host != null)
            widget_host.onFlowUpdateVideoPosition(id, position);
    }

    private void cbUpdateVideoVolume(long id, float volume) {
        if (widget_host != null)
            widget_host.onFlowUpdateVideoVolume(id, volume);
    }

    private void cbCreateWebWidget(long id, String url) {
        if (widget_host != null)
            widget_host.onFlowCreateWebWidget(id, url);
    }
    
    private void cbWebClipHostCall(long id, String js) {
        if (widget_host != null)
            widget_host.onFlowWebClipHostCall(id, js);
    }

    private void cbSetWebClipZoomable(long id, boolean zoomable) {
        if (widget_host != null)
            widget_host.onFlowSetWebClipZoomable(id, zoomable);
    }

    private void cbSetWebClipDomains(long id, String[] domains) {
        if (widget_host != null)
            widget_host.onFlowSetWebClipDomains(id, domains);
    }
    
    private native void nCallFlowFromWebView(long ptr, long id, String[] args);

    public synchronized void callFlowFromWebView(long id, String[] args) {
        nCallFlowFromWebView(cPtr(), id, args);
    }

    private void cbCreateCameraWidget(long id, int camID, int camWidth, int camHeight, int camFps, int recordMode) {
        if (widget_host != null)
            widget_host.onFlowCreateCameraWidget(id, camID, camWidth, camHeight, camFps, recordMode);
    }
    
    private void cbUpdateCameraWidget(long id, String filename, boolean record) {
        if (widget_host != null)
            widget_host.onFlowUpdateCameraWidget(id, filename, record);
    }
    
    public synchronized void deliverEditStateUpdate(long id, int cursor, int sel_start, int sel_end, String text) {
        nDeliverEditStateUpdate(cPtr(), id, cursor, sel_start, sel_end, text);
    }
    
    private native void nDeliverEditStateUpdate(long ptr, long id, int cursor, int sel_start, int sel_end, String text);

    @NonNull
    public synchronized String textIsAcceptedByFlowFilters(long id, String text) {
        return nTextIsAcceptedByFlowFilters(cPtr(), id, text);
    }
    
    @NonNull
    private native String nTextIsAcceptedByFlowFilters(long ptr, long id, String text);

    public synchronized boolean keyEventFilteredByFlowFilters
            (long id, int event, String key, boolean ctrl,
             boolean shift, boolean alt, boolean meta, int code) {

        return nKeyEventFilteredByFlowFilters(cPtr(), id, event, key, ctrl, shift, alt, meta, code);
    }

    private native boolean nKeyEventFilteredByFlowFilters
            (long ptr, long id, int event, String key, boolean ctrl,
             boolean shift, boolean alt, boolean meta, int code);

    public synchronized void deliverVideoNotFound(long id) {
        nDeliverVideoNotFound(cPtr(), id);
    }
    
    private native void nDeliverVideoNotFound(long ptr, long id);
    
    public synchronized void deliverVideoSize(long id, int width, int height) {
        nDeliverVideoSize(cPtr(), id, width, height);
    }
    
    private native void nDeliverVideoSize(long ptr, long id, int width, int height);
    
    public synchronized void deliverVideoDuration(long id, long duration) {
        nDeliverVideoDuration(cPtr(), id, duration);
    }
    
    private native void nDeliverVideoDuration(long ptr, long id, long length);
   
    public synchronized void deliverVideoPlayStatus(long id, int event) {
        nDeliverVideoPlayStatus(cPtr(), id, event);
    }
    
    private native void nDeliverVideoPlayStatus(long ptr, long id, int event);

    public synchronized void deliverVideoPosition(long id, long position) {
        nDeliverVideoPosition(cPtr(), id, position);
    }

    private native void nDeliverVideoPosition(long ptr, long id, long position);

    public synchronized void setVideoExternalTextureId(long id, int texture_id) {
        nSetVideoExternalTextureId(cPtr(), id, texture_id);
    }

    private native void nSetVideoExternalTextureId(long ptr, long id, int texture_id);
    
    public synchronized void deliverCameraError(long id) {
        nDeliverCameraError(cPtr(), id);
    }
    
    private native void nDeliverCameraError(long ptr, long id);

    public synchronized void deliverCameraStatus(long id, int event) {
        nDeliverCameraStatus(cPtr(), id, event);
    }
    
    private native void nDeliverCameraStatus(long ptr, long id, int event);

    public synchronized void VirtualKeyboardHeightCallback(double height) {
        if (isValid())
            nVirtualKeyboardHeightCallback(cPtr(), height);
    }

    private native void nVirtualKeyboardHeightCallback(long ptr, double height);

    public synchronized boolean isVirtualKeyboardListenerAttached() {
        return nIsVirtualKeyboardListenerAttached(cPtr());
    }

    private native boolean nIsVirtualKeyboardListenerAttached(long ptr);

    /* Sounds */
    public interface SoundLoadResolver {
        void resolveReady();
        void resolveError(String message);
    }

    public interface SoundPlayer {
        void preloadSound(String url, SoundLoadResolver rsv) throws IOException;
        int getUrlDuration(String url);
        
        void beginPlay(long channel_id, String url, float start_pos, boolean loop);
        void stopPlay(long channel_id);
        void setVolume(long channel_id, float value);
        float getPosition(long channel_id);
        float getLength(long channel_id);
    }

    @Nullable
    private SoundPlayer sound_player = null;
    
    public void setSoundPlayer(SoundPlayer player) {
        sound_player = player;
    }

    private void cbBeginLoadSound(final long sound, String url)
    {
        SoundLoadResolver resolver = new SoundLoadResolver() {
            public void resolveReady() {
                synchronized (FlowRunnerWrapper.this) {
                    if (isValid())
                        nDeliverSoundResolveReady(cPtr(), sound);
                }
            }

            public void resolveError(String message) {
                synchronized (FlowRunnerWrapper.this) {
                    if (isValid())
                        nDeliverSoundResolveError(cPtr(), sound, message);
                }
            }
        };
        
        if (sound_player == null) {
            resolver.resolveError("Sound not implemented");
            return;
        }

        try {
            sound_player.preloadSound(url, resolver);
        } catch (IOException e) {
            resolver.resolveError("IO Error: " + e.getMessage());
        }
    }

    private void cbBeginPlaySound(long channel, String url, float start_pos, boolean loop)
    {
        sound_player.beginPlay(channel, url, start_pos, loop);
    }

    private void cbStopSound(long channel)
    {
        sound_player.stopPlay(channel);
    }

    private void cbSetSoundVolume(long channel, float value)
    {
        sound_player.setVolume(channel, value);
    }

    private float cbGetSoundPosition(long channel)
    {
        return sound_player.getPosition(channel);
    }
    
    private float cbGetSoundLength(String url)
    {
        return sound_player.getUrlDuration(url);
    }

    public synchronized void deliverSoundPlayDone(long channel_id) {
        if (isValid())
            nDeliverSoundNotifyDone(cPtr(), channel_id);
    }

    private native void nDeliverSoundResolveReady(long ptr, long sound);
    private native void nDeliverSoundResolveError(long ptr, long sound, String msg);
    private native void nDeliverSoundNotifyDone(long ptr, long channel);
    
    @Nullable
    private AndroidStorePurchase storePurchaseAPI = null;
    private boolean storePurchaseEnabled = false;
    
    public void setStorePurchaseAPI(AndroidStorePurchase storePurchaseAPI) {
        this.storePurchaseAPI = storePurchaseAPI;
    }
    
    @Nullable
    public AndroidStorePurchase getStorePurchaseAPI() {
        return this.storePurchaseAPI;
    }
    
    public void setStorePurchaseEnabled(boolean enabled) {
        this.storePurchaseEnabled = enabled;
    }
    
    public boolean getStorePurchaseEnabled() {
        return this.storePurchaseEnabled;
    }
    
    public void cbLoadPurchaseProductInfo(@NonNull String[] pids) {
        if (getStorePurchaseEnabled()) {
            ArrayList<String> list = new ArrayList<String>();
            for (int i = 0; i< pids.length; i++)
                list.add(pids[i]);
            
            storePurchaseAPI.loadProductsInfo(list);
        }
    }
    
    public void cbPaymentRequest(String id, int count) {
        if (getStorePurchaseEnabled()) {
            storePurchaseAPI.buyProduct(id, count);
        }
    }
    
    public void cbRestorePaymentRequest() {
        if (getStorePurchaseEnabled()) {
            storePurchaseAPI.restoreProducts();
        }
    }
    
    public synchronized void CallbackPurchaseProduct(String id, String title, String description, double price, String priceLocale) {
        Log.i(Utils.LOG_TAG, "CALLBACK " + id + " is valid " + isValid());
        if (isValid())
            nCallbackPurchaseProduct(cPtr(), id, title, description, price, priceLocale);
    }
    
    public synchronized void CallbackPurchasePayment(String id, String status, String errorMsg) {
        if (isValid())
            nCallbackPurchasePayment(cPtr(), id, status, errorMsg);
    }
    
    public synchronized void CallbackPurchaseRestore(String id, int count, String errorMsg) {
        if (isValid())
            nCallbackPurchaseRestore(cPtr(), id, count, errorMsg);
    }
    
    public native void nCallbackPurchaseProduct(long ptr, String id, String title, String description, double price, String priceLocale);
    public native void nCallbackPurchasePayment(long ptr, String id, String status, String errorMsg);
    public native void nCallbackPurchaseRestore(long ptr, String id, int count, String errorMsg);

    @Nullable
    private FlowNotificationsAPI flowNotificationsAPI = null;
    private boolean localNotificationsEnabled = false;

    public void setFlowNotificationsAPI(FlowNotificationsAPI flowNotificationsAPI) {
        this.flowNotificationsAPI = flowNotificationsAPI;
    }
    
    public void setLocalNotificationsEnabled(boolean value) {
        localNotificationsEnabled = value;
    }
    
    public boolean getLocalNotificationsEnabled() {
        return localNotificationsEnabled;
    }

    public void onFlowLocalNotificationClick(int notificationId, String notificationCallbackArgs) {
        flowNotificationsAPI.onLocalNotificationClick(notificationId, notificationCallbackArgs);
    }

    public boolean cbHasPermissionLocalNotification() {
        return flowNotificationsAPI.hasPermissionLocalNotification();
    }

    public void cbRequestPermissionLocalNotification(int cb_root) {
        flowNotificationsAPI.requestPermissionLocalNotification(cb_root);
    }

    public void cbScheduleLocalNotification(double time, int notificationId, String notificationCallbackArgs, String notificationTitle, String notificationText, boolean withSound, boolean pinNotification) {
        if (getLocalNotificationsEnabled()) {
            flowNotificationsAPI.scheduleLocalNotification(time, notificationId, notificationCallbackArgs, notificationTitle, notificationText, withSound, pinNotification);
        }
    }

    public void cbCancelLocalNotification(int notificationId) {
        if (getLocalNotificationsEnabled()) {
            flowNotificationsAPI.cancelLocalNotification(notificationId, false);
        }
    }

    private void callFirebaseServiceSubscription(boolean doSubscribe, String topic) {
        try {
            Class service = Class.forName("com.google.firebase.messaging.FirebaseMessaging");

            try {
                Method getInstance = service.getMethod("getInstance");
                Object instance = getInstance.invoke(null);

                String methodName;
                if (doSubscribe) {
                    methodName = "subscribeToTopic";
                } else {
                    methodName = "unsubscribeFromTopic";
                }

                Method subscription = service.getMethod(methodName, String.class);
                subscription.invoke(instance, topic);
            } catch (Exception ex) {
                ex.printStackTrace();
            }
        } catch (ClassNotFoundException ex) {
            Log.i(Utils.LOG_TAG, "No Firebase messaging enbled!");
        }
    }

    public void cbGetFBToken(int cb_root) {
        try {
            Class service = Class.forName("com.google.firebase.iid.FirebaseInstanceId");

            try {
                Method getInstance = service.getMethod("getInstance");
                Object instance = getInstance.invoke(null);

                Method subscription = service.getMethod("getToken");
                String token = (String)subscription.invoke(instance);
                nDeliverFBTokenTo(cPtr(), cb_root, token);
            } catch (Exception ex) {
                ex.printStackTrace();
            }
        } catch (ClassNotFoundException ex) {
            Log.i(Utils.LOG_TAG, "No Firebase messaging enbled!");
        }
    }

    public void cbSubscribeToFBTopic(String name) {
        callFirebaseServiceSubscription(true, name);
    }

    public void cbUnsubscribeFromFBTopic(String name) {
        callFirebaseServiceSubscription(false, name);
    }

    public synchronized void RequestPermissionLocalNotificationResult(boolean result, int cb_root) {
        if (isValid())
            nRequestPermissionLocalNotificationResult(cPtr(), result, cb_root);
    }

    public synchronized void ExecuteNotificationCallbacks(int notificationId, String notificationCallbackArgs) {
        if (isValid())
            nExecuteNotificationCallbacks(cPtr(), notificationId, notificationCallbackArgs);
    }

    private native void nRequestPermissionLocalNotificationResult(long ptr, boolean result, int cb_root);
    private native void nExecuteNotificationCallbacks(long ptr, int notificationId, String notificationCallbackArgs);

    private String[] parseHashMapToArray(HashMap<String, String> map) {
        final String[] dataArray = new String[map.size() * 2];

        int i = 0;
        for (Entry<String, String> pair : map.entrySet()) {
            dataArray[i++] = pair.getKey();
            dataArray[i++] = pair.getValue();
        }

        return dataArray;
    }

    public synchronized void DeliverFBMessage(String id, String body, String title, String from, long stamp, @NonNull HashMap<String, String> data) {
        if (isValid()) {

            nDeliverFBMessage(cPtr(), id, body, title, from, stamp, parseHashMapToArray(data));
        }
    }

    public synchronized void DeliverFBToken(String token) {
        if (isValid()) {
            nDeliverFBToken(cPtr(), token);
        }
    }

    private native void nDeliverFBMessage(long ptr, String id, String body, String title, String from, long stamp, String[] data);
    private native void nDeliverFBToken(long ptr, String token);
    private native void nDeliverFBTokenTo(long ptr, int cb_root, String token);
    
    @Nullable
    private FlowGeolocationAPI flowGeolocationAPI = null;
    
    public void setFlowGeolocationAPI(FlowGeolocationAPI flowGeolocationAPI) {
        this.flowGeolocationAPI = flowGeolocationAPI;
    }
    
    public void cbGeolocationGetCurrentPosition(int callbacksRoot, boolean enableHighAccuracy, double timeout, double maximumAge, String turnOnGeolocationMessage, String okButtonText, String cancelButtonText) {
        flowGeolocationAPI.getCurrentPosition(callbacksRoot, enableHighAccuracy, timeout, maximumAge, turnOnGeolocationMessage, okButtonText, cancelButtonText);
    }

    public void cbGeolocationWatchPosition(int callbacksRoot, boolean enableHighAccuracy, double timeout, double maximumAge, String turnOnGeolocationMessage, String okButtonText, String cancelButtonText) {
        flowGeolocationAPI.watchPosition(callbacksRoot, enableHighAccuracy, timeout, maximumAge, turnOnGeolocationMessage, okButtonText, cancelButtonText);
    }
    
    public void cbGeolocationAfterWatchDispose(int callbacksRoot) {
        flowGeolocationAPI.watchDisposed(callbacksRoot);
    }
    
    public synchronized void GeolocationExecuteOnOkCallback(int callbacksRoot, boolean removeAfterCall, double latitude, double longitude, double altitude,
            double accuracy, double altitudeAccuracy, double heading, double speed, double time) {
        if (isValid())
            nGeolocationExecuteOnOkCallback(cPtr(), callbacksRoot, removeAfterCall, latitude, longitude, altitude,
                    accuracy, altitudeAccuracy, heading, speed, time);
    }
    
    public synchronized void GeolocationExecuteOnErrorCallback(int callbacksRoot, boolean removeAfterCall, int code, String message) {
        if (isValid())
            nGeolocationExecuteOnErrorCallback(cPtr(), callbacksRoot, removeAfterCall, code, message);
    }
    
    private native void nGeolocationExecuteOnOkCallback(long ptr, int callbacksRoot, boolean removeAfterCall, double latitude, double longitude, double altitude,
            double accuracy, double altitudeAccuracy, double heading, double speed, double time);
    private native void nGeolocationExecuteOnErrorCallback(long ptr, int callbacksRoot, boolean removeAfterCall, int code, String message);

    @Nullable
    private FlowCameraAPI flowCameraAPI = null;
    @Nullable
    private FlowAudioCaptureAPI flowAudioCaptureAPI = null;
    
    public void setFlowCameraAPI(FlowCameraAPI flowCameraAPI) {
        this.flowCameraAPI = flowCameraAPI;
    }    
    public void setFlowAudioCaptureAPI(FlowAudioCaptureAPI flowAudioCaptureAPI) {
        this.flowAudioCaptureAPI = flowAudioCaptureAPI;
    }

    public int cbGetNumberOfCameras()
    {
        return flowCameraAPI.getNumberOfCameras();
    }

    @NonNull
    public String cbGetCameraInfo(int id)
    {
        return flowCameraAPI.getCameraInfo(id);
    }
    
    public void cbOpenCameraAppPhotoMode(int cameraId, String additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, String fileName, int fitMode)
    {
        flowCameraAPI.openCameraAppPhotoMode(cameraId, additionalInfo, desiredWidth, desiredHeight, compressQuality, fileName, fitMode);
    }

    public void cbOpenCameraAppVideoMode(int cameraId, String additionalInfo, int duration, int size, int quality, String fileName)
    {
        flowCameraAPI.openCameraAppVideoMode(cameraId, additionalInfo, duration, size, quality, fileName);
    }

    public void cbStartRecordAudio(String additionalInfo, String fileName, int duration)
    {
        flowAudioCaptureAPI.startRecordAudio(additionalInfo, fileName, duration);
    }

    public void cbStopRecordAudio()
    {
        flowAudioCaptureAPI.stopRecordAudio();
    }

    public void cbTakeAudioRecord()
    {
        flowAudioCaptureAPI.takeAudioRecord();
    }
    
    public synchronized void NotifyCameraEvent(int code, String message, String additionalInfo, int width, int height)
    {
        if (isValid())
            nNotifyCameraEvent(cPtr(), code, message, additionalInfo, width, height);
    }
    
    private native void nNotifyCameraEvent(long ptr, int code, String message, String additionalInfo, int width, int height);

    public synchronized void NotifyCameraEventVideo(int code, String message, String additionalInfo, int width, int height, int duration, int size)
    {
        if (isValid())
            nNotifyCameraEventVideo(cPtr(), code, message, additionalInfo, width, height, duration, size);
    }
    
    private native void nNotifyCameraEventVideo(long ptr, int code, String message, String additionalInfo, int width, int height, int duration, int size);

    public synchronized void NotifyCameraEventAudio(int code, String message, String additionalInfo, int duration, int size)
    {
        if (isValid())
            nNotifyCameraEventAudio(cPtr(), code, message, additionalInfo, duration, size);
    }
    
    private native void nNotifyCameraEventAudio(long ptr, int code, String message, String additionalInfo, int duration, int size);

    @NonNull
    private HashMap<String,Typeface> fonts = new HashMap<String,Typeface>();

    private boolean cbLoadSystemFont(float[] metrics, String name, int tile_size)
    {
        int mode = Typeface.NORMAL;
        String family = name;
        String suffix = "";

        int dashIndex = family.lastIndexOf("-");
        if (dashIndex > 0) {
            family = name.substring(0, dashIndex);
            suffix = name.substring(dashIndex + 1);
        }


        for (;;) {
            if (suffix.endsWith("Bold")) {
                mode |= Typeface.BOLD;
                suffix = suffix.substring(0, suffix.length() - 4);
            } else if (family.endsWith("Italic")) {
                mode |= Typeface.ITALIC;
                suffix = suffix.substring(0, suffix.length() - 6);
            } else {
                break;
            }
        }

        Typeface font = Typeface.create(family, mode);
        if (font.getStyle() != mode)
            return false;

        fonts.put(name, font);

        Paint paint = new Paint();
        paint.setTypeface(font);

        // em_size
        metrics[0] = tile_size * 0.875f;
        paint.setTextSize((int)metrics[0]);

        // 1/dist_scale
        metrics[1] = tile_size * 0.25f;

        Paint.FontMetrics fm = paint.getFontMetrics();
        metrics[2] = -fm.ascent;
        metrics[3] = -fm.descent;
        metrics[4] = paint.getFontSpacing();
        metrics[5] = paint.measureText("M");

        // underline pos & thickness
        metrics[6] = 0;
        metrics[7] = 1;

        return true;
    }

    private int[] cbLoadSystemGlyph(float[] metrics, String name, @NonNull char[] codes, int tile_size, float em_size)
    {
        Typeface typeface = fonts.get(name);
        if (typeface == null)
            return null;

        int scale = 3;
        int fsize = (int)(em_size * scale);

        TextPaint paint = new TextPaint();
        paint.setTypeface(typeface);
        paint.setTextSize(fsize);

        Rect bounds = new Rect();

        boolean isUtf32Glyph = codes[0] >= 0xD800 && codes[0] < 0xDC00;
        int charLength = isUtf32Glyph ? 2 : 1;

        paint.getTextBounds(codes, 0, charLength, bounds);
        float advance = paint.measureText(codes, 0, charLength);

        if ((bounds.width() <= 0 || bounds.height() <= 0) && !Character.isSpaceChar(codes[0]))
        {
                Log.e(Utils.LOG_TAG, "Character with null bounds: "+codes[0]+" - "+bounds);
                return null;
        }

        int bsize = tile_size * scale;
        int xpos = (bsize - bounds.width()) / 2;
        int ypos = (bsize - bounds.height()) / 2;

        metrics[0] = xpos / scale;
        metrics[1] = ypos / scale;
        metrics[2] = advance / scale;
        metrics[3] = bounds.left / scale;
        metrics[4] = bounds.top / scale;
        metrics[5] = (float)Math.ceil(bounds.width() / scale);
        metrics[6] = (float)Math.ceil(bounds.height() / scale);

        Bitmap bmp = Bitmap.createBitmap(bsize, bsize, Bitmap.Config.ARGB_8888);
        Canvas cvs = new Canvas(bmp);

        paint.setColor(0);
        cvs.drawRect(0, 0, bsize, bsize, paint);
        paint.setColor(0xFFFFFFFF);
        cvs.drawText(codes, 0, charLength, xpos - bounds.left, ypos - bounds.top, paint);

        int[] data = new int[bsize*bsize];
        bmp.getPixels(data, 0, bsize, 0, 0, bsize, bsize);
        return data;
    }
    
    public final int PLATFORM_APPLICATION_SUSPENDED = 1;
    public final int PLATFORM_APPLICATION_RESUMED = 2;
    public final int PLATFORM_NETWORK_OFFLINE = 3;
    public final int PLATFORM_NETWORK_ONLINE = 4;
    public final int PLATFORM_LOW_MEMORY = 5;
    public final int PLATFORM_DEVICE_BACK_BUTTON = 6;

    private native boolean nNotifyPlatformEvent(long ptr, int event);

    /**
     * returns true when at least one listener asks to cancel default action and pretends to handle situation itself
     */
    public synchronized boolean NotifyPlatformEvent(int event_id) {
        return nNotifyPlatformEvent(cPtr(), event_id);
    }
    
    public void cbSetInterfaceOrientation(String orientation)
    {
        widget_host.onFlowSetInterfaceOrientation(orientation);
    }
    
    private native void nNotifyCustomFileTypeOpened(long ptr, String path);
    public synchronized void NotifyCustomFileTypeOpened(@NonNull Uri uri) {
        Context ctx = widget_host.getWidgetHostContext();
        String file_path = Utils.getPath(ctx, uri);
        if (file_path != null && !file_path.isEmpty()) {
            nNotifyCustomFileTypeOpened(cPtr(), file_path);
        } else {
            // Something goes wrong. Copy content locally and notify flow with a copy
            try {
                InputStream in = ctx.getContentResolver().openInputStream(uri);
                final File tempFile = File.createTempFile("associated", ".tmp");
                tempFile.deleteOnExit();
                FileOutputStream out = new FileOutputStream(tempFile);
                Utils.copyData(out, in, null);
                nNotifyCustomFileTypeOpened(cPtr(), tempFile.getAbsolutePath());
            } catch (Exception e) {
                Log.e(Utils.LOG_TAG, "Cannot open associated URL " + e);
            }
            
        }
    }
   
    private native void nNotifyWebViewLoaded(long ptr, long id);
    public synchronized void NotifyWebViewLoaded(long id) {
        nNotifyWebViewLoaded(cPtr(), id);
    }
    
    private native void nNotifyWebViewError(long ptr, long id, String msg);
    public synchronized void NotifyWebViewError(long id, String msg) {
        nNotifyWebViewError(cPtr(), id, msg);
    }
    
    public static final int FLOW_KEYDOWN = 20;
    public static final int FLOW_KEYUP = 22;  
    private native void nDispatchKeyEvent(long ptr, int event, String key, boolean ctrl,
            boolean shift, boolean alt, boolean meta, int code);
    public synchronized void DispatchKeyEvent(int event, String key, boolean ctrl,
            boolean shift, boolean alt, boolean meta, int code) {
        nDispatchKeyEvent(cPtr(), event, key, ctrl, shift, alt, meta, code);
    }
    
    @NonNull
    private native FlowAccessibleClip[] nFetchAccessibleClips(long ptr);
    @NonNull
    public synchronized FlowAccessibleClip[] FetchAccessibleClips() {
        return nFetchAccessibleClips(cPtr());
    }
    
    private void cbTagLocalyticsEventWithAttributes(String event_name, @NonNull String[] attributes) {
        try {            
            HashMap<String, String> attributes_map = new HashMap<String, String>();
            for (int i = 0; i < attributes.length / 2; ++i) {
                attributes_map.put(attributes[i * 2], attributes[ i * 2 + 1 ]);
            }
            
            Class<?> c = Class.forName("com.localytics.android.Localytics");
            Method m = c.getDeclaredMethod("tagEvent", String.class, Map.class);
            m.invoke(null, event_name, attributes_map);
        } catch (Exception e) {
            Log.e(Utils.LOG_TAG, "Were not able to call Localytics.tagEvent.");
        }
    }

    private FlowMediaStreamSupport mediaStreamSupport = null;

    public void setFlowMediaStreamSupport(FlowMediaStreamSupport mediaStreamSupport) {
        this.mediaStreamSupport = mediaStreamSupport;
    }

    private native void nDeviceInfoUpdated(long ptr, int id);

    private synchronized void cbDeviceInfoUpdated(int cb) {
        mediaStreamSupport.initializeDeviceInfo();
        nDeviceInfoUpdated(cPtr(), cb);
    }

    private native void nGetMediaDevices(long ptr, int id, String[] ids, String[] names);

    private void getMediaDevices(int cb, Map<String, String> devices) {
        ArrayList<String> ids = new ArrayList<>();
        ArrayList<String> names = new ArrayList<>();
        for (Entry<String, String> item : devices.entrySet()) {
            ids.add(item.getKey());
            names.add(item.getValue());
        }
        nGetMediaDevices(cPtr(), cb, ids.toArray(new String[0]), names.toArray(new String[0]));
    }

    private synchronized void cbGetAudioDevices(int cb) {
        getMediaDevices(cb, mediaStreamSupport.getAudioDevices());
    }

    private synchronized void cbGetVideoDevices(int cb) {
        getMediaDevices(cb, mediaStreamSupport.getVideoDevices());
    }

    private synchronized void cbMakeMediaStream(boolean recordAudio, boolean recordVideo, String videoDeviceId, String audioDeviceId,
                                            int cbOnReadyRoot, int cbOnErrorRoot) {
        mediaStreamSupport.makeMediaStream(recordAudio, recordVideo, videoDeviceId, audioDeviceId, cbOnReadyRoot, cbOnErrorRoot);
    }

    private synchronized void cbStopMediaStream(FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream) {
        mediaStreamSupport.stopMediaStream(flowMediaStream);
    }

    private native void nOnMediaStreamReady(long ptr, int id, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream);

    synchronized void cbOnMediaStreamReady(int id, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream) {
        nOnMediaStreamReady(cPtr(), id, flowMediaStream);
    }

    private native void nOnMediaStreamError(long ptr, int id, String error);

    synchronized void cbOnMediaStreamError(int id, String error) {
        nOnMediaStreamError(cPtr(), id, error);
    }

    private FlowWebRTCSupport webRTCSupport = null;

    public void setFlowWebRTCSupport(FlowWebRTCSupport webRTCSupport) {
        this.webRTCSupport = webRTCSupport;
    }

    private synchronized void cbMakeMediaSender(String serverUrl, String roomId, String[] stunUrls, String[][] turnServers,
                                                FlowMediaStreamSupport.FlowMediaStreamObject stream,
                                                int onMediaSenderReadyRoot, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot) {
        webRTCSupport.makeMediaSender(serverUrl, roomId, stunUrls, turnServers, stream, onMediaSenderReadyRoot, onNewParticipantRoot, onParticipantLeaveRoot, onErrorRoot);
    }

    private synchronized void cbStopMediaSender(FlowWebRTCSupport.FlowMediaSenderObject mediaSender) {
        webRTCSupport.stopMediaSender(mediaSender);
    }

    private native void nOnMediaSenderReady(long ptr, int id, FlowWebRTCSupport.FlowMediaSenderObject flowMediaSender);

    synchronized void cbOnMediaSenderReady(int id, FlowWebRTCSupport.FlowMediaSenderObject flowMediaSender) {
        nOnMediaSenderReady(cPtr(), id, flowMediaSender);
    }

    private native void nOnMediaSenderNewParticipant(long ptr, int id, String participant_id, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream);

    synchronized void cbOnMediaSenderNewParticipant(int id, String participant_id, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream) {
        nOnMediaSenderNewParticipant(cPtr(), id, participant_id, flowMediaStream);
    }

    private native void nOnMediaSenderParticipantLeave(long ptr, int id, String participant_id);

    synchronized void cbOnMediaSenderParticipantLeave(int id, String participant_id) {
        nOnMediaSenderParticipantLeave(cPtr(), id, participant_id);
    }

    private native void nOnMediaSenderError(long ptr, int id, String error);

    synchronized void cbOnMediaSenderError(int id, String error) {
        nOnMediaStreamError(cPtr(), id, error);
    }

    private FlowMediaRecorderSupport mediaRecorderSupport = null;

    public void setFlowMediaRecorderSupport(FlowMediaRecorderSupport mediaRecorderSupport) {
        this.mediaRecorderSupport = mediaRecorderSupport;
    }

    private native void nOnRecorderReady(long ptr, int id, FlowMediaRecorderSupport.FlowMediaRecorderObject flowRecorder);

    synchronized void cbOnRecorderReady(int id, FlowMediaRecorderSupport.FlowMediaRecorderObject flowRecorder) {
        nOnRecorderReady(cPtr(), id, flowRecorder);
    }

    private native void nOnRecorderError(long ptr, int id, String error);

    synchronized void cbOnRecorderError(int id, String error) {
        nOnRecorderError(cPtr(), id, error);
    }

    private synchronized void cbMakeMediaRecorder(String websocketUri, String filePath, FlowMediaStreamSupport.FlowMediaStreamObject mediaStream, int timeslice, int cbOnReadyRoot, int cbOnErrorRoot) {
        if (Utils.isMediaRecorderSupported)
            mediaRecorderSupport.makeMediaRecorder(websocketUri, filePath, mediaStream, timeslice, cbOnReadyRoot, cbOnErrorRoot);
    }

    private synchronized void cbStartMediaRecorder(FlowMediaRecorderSupport.FlowMediaRecorderObject recorder) {
        if (Utils.isMediaRecorderSupported)
            mediaRecorderSupport.startMediaRecorder(recorder);
    }

    private synchronized void cbResumeMediaRecorder(FlowMediaRecorderSupport.FlowMediaRecorderObject recorder) {
        if (Utils.isMediaRecorderPauseResumeSupported)
            mediaRecorderSupport.resumeMediaRecorder(recorder);
    }

    private synchronized void cbPauseMediaRecorder(FlowMediaRecorderSupport.FlowMediaRecorderObject recorder) {
        if (Utils.isMediaRecorderPauseResumeSupported)
            mediaRecorderSupport.pauseMediaRecorder(recorder);
    }

    private synchronized void cbStopMediaRecorder(FlowMediaRecorderSupport.FlowMediaRecorderObject recorder) {
        if (Utils.isMediaRecorderSupported)
            mediaRecorderSupport.stopMediaRecorder(recorder);
    }

    @Nullable
    private FlowWebSocketSupport webSocketSupport = null;

    public void setFlowWebSocketSupport(FlowWebSocketSupport webSocketSupport) {
        this.webSocketSupport = webSocketSupport;
    }

    public synchronized void deliverWebSocketOnClose(int callbacksKey, int closeCode, String reason, boolean wasClean) {
        nDeliverWebSocketOnClose(cPtr(), callbacksKey, closeCode, reason, wasClean);
    }

    private native void nDeliverWebSocketOnClose(long ptr, int callbacksKey, int closeCode, String reason, boolean wasClean);

    public synchronized void deliverWebSocketOnError(int callbacksKey, String error) {
        nDeliverWebSocketOnError(cPtr(), callbacksKey, error);
    }

    private native void nDeliverWebSocketOnError(long ptr, int callbacksKey, String error);

    public synchronized void deliverWebSocketOnMessage(int callbacksKey, String message) {
        nDeliverWebSocketOnMessage(cPtr(), callbacksKey, message);
    }

    private native void nDeliverWebSocketOnMessage(long ptr, int callbacksKey, String message);

    public synchronized void deliverWebSocketOnOpen(int callbacksKey) {
        nDeliverWebSocketOnOpen(cPtr(), callbacksKey);
    }

    private native void nDeliverWebSocketOnOpen(long ptr, int callbacksKey);

    public synchronized WebSocketClient cbOpenWSClient(String url, int callbacksKey) {
        return webSocketSupport.open(url, callbacksKey);
    }

    public synchronized boolean cbSendMessageWSClient(WebSocketClient webSocketClient, String message) {
        return webSocketSupport.send(webSocketClient, message);
    }

    public synchronized boolean cbHasBufferedDataWSClient(WebSocketClient webSocketClient) {
        return webSocketSupport.hasBufferedData(webSocketClient);
    }

    public synchronized void cbCloseWSClient(WebSocketClient webSocketClient, int code, String reason) {
        webSocketSupport.close(webSocketClient, code, reason);
    }

    private FlowFileSystemInterface fileSystemInterface = null;

    public void setFlowFileSystemInterface(FlowFileSystemInterface fileSystemInterface) {
        this.fileSystemInterface = fileSystemInterface;
    }

    public FlowFileSystemInterface getFlowFileSystemInterface() {
        return this.fileSystemInterface;
    }

    public synchronized void cbOpenFileDialog(int maxFilesCount, String[] fileTypes, int callbackRoot) {
        fileSystemInterface.openFileDialog(maxFilesCount, fileTypes, callbackRoot);
    }

    public synchronized String cbGetFileType(String path) {
        return fileSystemInterface.getFileMimeType(path);
    }

    public synchronized void deliverOpenFileDialogResult(int callbackRoot, String[] filePaths) {
        nDeliverOpenFileDialogResult(cPtr(), callbackRoot, filePaths);
    }

    private native void nDeliverOpenFileDialogResult(long ptr, int callbackRoot, String[] filePaths);

    private FlowPrintingSupport flowPrintingSupport = null;

    public void setFlowPrintingSupport(FlowPrintingSupport flowPrintingSupport) {
        this.flowPrintingSupport = flowPrintingSupport;
    }

    public synchronized void cbPrintHTML(String html) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP)
            flowPrintingSupport.printHTML(html);
    }

    public synchronized void cbPrintURL(String url) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT)
            flowPrintingSupport.printURL(url);
    }

    private SoftKeyboardSupport softKeyboardSupport = null;

    public void setSoftKeyboardSupport(SoftKeyboardSupport softKeyboardSupport) {
        this.softKeyboardSupport = softKeyboardSupport;
    }

    public synchronized void cbShowSoftKeyboard() {
        softKeyboardSupport.showKeyboard();
    }

    public synchronized void cbHideSoftKeyboard() {
        softKeyboardSupport.hideKeyboard();
    }
}
