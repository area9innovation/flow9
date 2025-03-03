package dk.area9.flowrunner;

import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map.Entry;
import java.util.Timer;
import java.util.TimerTask;

import android.app.Activity;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.graphics.Rect;
import android.graphics.Region;
import android.graphics.SurfaceTexture;
import android.os.Build;
import android.os.Handler;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import android.view.View.AccessibilityDelegate;
import android.view.ViewGroup;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.inputmethod.InputMethodManager;

public class FlowWidgetGroup extends ViewGroup implements FlowRunnerWrapper.WidgetHost {    
    private FlowRunnerWrapper wrapper;
    private FlowRunnerView surface;
    private Handler uiHandler;
    
    URI resource_uri;
    
    public FlowWidgetGroup(Context context, FlowRunnerWrapper wrapper, Handler uiHandler) {
        super(context);
        
        this.uiHandler = uiHandler;
        this.wrapper = wrapper;
        this.surface = new FlowRunnerView(this);
        
        this.scale_detector = new ScaleGestureDetector(context, scale_listener);
    
        wrapper.addListener(wrapper_cb);
        wrapper.setWidgetHost(this);

        addView(surface);  
    }
    
    public FlowRunnerView getFlowRunnerView() { return surface; }
    
    public Context getWidgetHostContext() {
        return getContext();
    }
    
    @Nullable
    private Timer accessibilityTimer;
    private void startAccessibilityTimer() {
        // Schedule an updating of elements for accessibility tools.
        // 1 s looks frequent enough
        final Activity a = (Activity)getContext();
        if ((a.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0 && accessibilityTimer == null) {
            accessibilityTimer = new Timer();
            accessibilityTimer.schedule(new TimerTask() {
                @Override
                public void run() {
                    a.runOnUiThread(new Runnable() {
                        @Override public void run() { updateFlowAccessibleClips(); }
                    });
                }
            }, 1000, 1000);   
        }
    }
    
    private void stopAccessibilityTimer() {
        if (accessibilityTimer != null) {
            accessibilityTimer.cancel();
            accessibilityTimer = null;
        }
    }

    private FlowAccessibleClip[] accessibleClips = {};
    public void updateFlowAccessibleClips() {
        //Log.i(Utils.LOG_TAG, "updateFlowAccessibleClips");
        for (FlowAccessibleClip c : accessibleClips) c.destroyView();
        accessibleClips = wrapper.FetchAccessibleClips();
        for (final FlowAccessibleClip c : accessibleClips) {
            c.createView(this); c.layoutView();
        }
    }
    
    public void setResourceURI(URI uri) {
        resource_uri = uri;
    }
    
    @NonNull
    public ArrayList<VideoWidget> getVideoWidgets() {
        return new ArrayList<VideoWidget>(videoWidgets.values());
    }
        
    public void onPause() {
        stopAccessibilityTimer();
        surface.onPause();
    }

    public void onResume() {
        surface.onResume();
        startAccessibilityTimer();
    }
    
    public FlowRunnerWrapper getWrapper() {
        return wrapper;
    }

    @NonNull
    private FlowRunnerWrapper.Listener wrapper_cb = new FlowRunnerWrapper.ListenerAdapter() {
        public void onFlowReset(boolean post_destroy) {
            setBlockEvents(true);
            destroyAllWidgets();
        }
    };

    /* ****************************** *
     *    NATIVE WIDGET MANAGEMENT    *
     * ****************************** */

    final HashMap<Long, NativeWidget> widgets = new HashMap<Long, NativeWidget>();
    final HashMap<Long, VideoWidget> videoWidgets = new HashMap<Long, VideoWidget>();
    
    public void onFlowDestroyWidget(long id) {
        NativeWidget widget = widgets.get(id);
        if (widget == null) return;

        removeWidgets(Collections.singletonList(widget));
        widgets.remove(id);

        VideoWidget video = videoWidgets.get(id);
        if (video != null) {
            videoWidgets.remove(id);
        }
    }

    private void destroyAllWidgets() {
        if (widgets.isEmpty()) return;

        removeWidgets(new ArrayList<NativeWidget>(widgets.values()));
        widgets.clear();
        videoWidgets.clear();
    }

    private void removeWidgets(final Collection<NativeWidget> to_delete) {
        for (NativeWidget widget : to_delete)
            widget.preDestroy();

        post(new Runnable() {
            public void run() {
                for (NativeWidget widget : to_delete) {
                    if (widget.view != null)
                        widget.destroy();
                }
            }
        });
    }

    public void onFlowResizeWidget(long id, boolean visible, float minx,
            float miny, float maxx, float maxy, float scale, float alpha)
    {
        final NativeWidget widget = widgets.get(id);
        if (widget == null) return;

        widget.resize(visible, (int)Math.floor(minx), (int)Math.floor(miny),
                      (int)Math.ceil(maxx), (int)Math.ceil(maxy), scale, alpha);
    }

    @Nullable
    InputMethodManager getIMM() {
        return (InputMethodManager)getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
    }

    @Nullable
    private EditWidget focused_edit = null;

    public void setFocus(EditWidget editWidget) {
        focused_edit = editWidget;
    }

    public void dropFocus() {
        focused_edit = null;
    }

    public boolean isInFocus(EditWidget editWidget) {
        return focused_edit == editWidget;
    }

    public void onFlowCreateTextWidget(long id, @NonNull String text,
                                       String font_name, float font_size, int font_color,
                                       boolean multiline, boolean readonly, float line_spacing,
                                       @NonNull String text_input_type, String alignment,
                                       int max_size, int cursor_pos, int sel_start, int sel_end)
    {
        EditWidget widget = (EditWidget)widgets.get(id);
        if (widget == null) {
            widgets.put(id, widget = new EditWidget(this, id));
        }

        widget.configure(
            text, font_size, font_color,
            multiline, readonly, line_spacing, text_input_type, alignment,
            max_size, cursor_pos, sel_start, sel_end
        );     
    }
    
    public void onFlowCreateVideoWidget(
            long id, @NonNull String url, @NonNull String[] headers,
            boolean playing, boolean looping, int controls, float volume) {

        HashMap<String, String> headers_map = new HashMap<String, String>();
        for (int i = 0; i < headers.length / 2; ++i) {
            headers_map.put(headers[i * 2], headers[ i * 2 + 1 ]);
        }

        VideoWidget widget = (VideoWidget)widgets.get(id);
        if (widget == null) {
            widgets.put(id, widget = new VideoWidget(this, id));
            videoWidgets.put(id, widget);
            widget.init( resource_uri.resolve(url).toString(), headers_map, playing, looping, controls, volume );
        }
    }

    public void onFlowCreateVideoWidgetFromMediaStream(
            long id, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream) {

        VideoWidget widget = (VideoWidget)widgets.get(id);
        if (widget == null) {
            widgets.put(id, widget = new VideoWidget(this, id));
            videoWidgets.put(id, widget);
            widget.init(flowMediaStream);
        }
    }

    public void onFlowUpdateVideoPlay(long id, boolean playing) {
        VideoWidget widget = (VideoWidget)widgets.get(id);
        if (widget == null) return;
        widget.setPlaying(playing);
    }

    public void onFlowUpdateVideoPosition(long id, long position) {
        VideoWidget widget = (VideoWidget)widgets.get(id);
        if (widget == null) return;
        widget.setPosition(position);
    }

    public void onFlowUpdateVideoVolume(long id, float volume) {
        VideoWidget widget = (VideoWidget)widgets.get(id);
        if (widget == null) return;
        widget.setVolume(volume);
    }

    public void onFlowCreateWebWidget(long id, String url) {
        WebWidget widget = (WebWidget)widgets.get(id);
        if (widget == null) {
            widgets.put(id, widget = new WebWidget(this, id));
            widget.configure(url);
        }
    }

    public void onFlowWebClipHostCall(long id, String js) {
        WebWidget widget = (WebWidget)widgets.get(id);
        if (widget != null) {
            widget.evalJS(js);
        }
    }

    public void onFlowSetWebClipZoomable(long id, boolean zoomable) {
        WebWidget widget = (WebWidget) widgets.get(id);
        if (widget != null) {
            widget.setZoomable(zoomable);
        }
    }

    public void onFlowSetWebClipDomains(long id, String[] domains) {
        WebWidget widget = (WebWidget) widgets.get(id);
        if (widget != null) {
            widget.setWhiteListDomains(domains);
        }
    }

    public void onFlowCreateCameraWidget(
        long id, int camID,
        int camWidth, int camHeight, int camFps, int recordMode) {

        CameraWidget widget = (CameraWidget)widgets.get(id);
        Log.d(Utils.LOG_TAG, "onFlowCreateCameraWidget, id=" + id);
        if (widget == null) {
            Log.d(Utils.LOG_TAG, "widget == null, start create widget");
            widgets.put(id, widget = new CameraWidget(this, id, uiHandler));
            widget.init(camID, camWidth, camHeight, camFps, recordMode);
            Log.d(Utils.LOG_TAG, "widget == null, stop create widget");
        }
    }

    public void onFlowUpdateCameraWidget(long id, String filename, boolean record) {
        CameraWidget widget = (CameraWidget)widgets.get(id);
        if (widget == null) return;
        widget.configure(filename, record);
    }

    public void onFlowSetInterfaceOrientation(@NonNull String orientation) {
        Log.i(Utils.LOG_TAG, "onFlowSetInterfaceOrientation: " + orientation);
        Activity activity = (Activity)getContext();
        if (orientation.equals("landscape")) {
            activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
        } else if (orientation.equals("portrait")) {
            activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        } else {
            activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
        }
    }

    protected void onMeasure(int xspec, int yspec) {
        surface.measure(xspec, yspec);
        setMeasuredDimension(surface.getMeasuredWidth(), surface.getMeasuredHeight());

        for (Entry<Long, NativeWidget> item : widgets.entrySet()) {
            NativeWidget widget = item.getValue();

            if (widget != null)
                widget.measure();
        }
    }

    protected void onLayout(boolean new_val, int l, int t, int r, int b) {
        surface.layout(l, t, r, b);

        for (Entry<Long, NativeWidget> item : widgets.entrySet()) {
            NativeWidget widget = item.getValue();

            if (widget != null)
                widget.layout();
        }
    }

    @NonNull
    private int[] mLocation = new int[2];

    public boolean gatherTransparentRegion(@NonNull Region region) {
        boolean opaque = super.gatherTransparentRegion(region);

        /* Work around a somewhat known bug in adjustPan.
         *
         * Namely, when ViewRoot is scrolling the contents to make
         * the focused area visible, it does not properly adjust the
         * transparent region.
         *
         * This tweak removes the whole vertical strip containing
         * the widget from the region, thus allowing it to be freely
         * scrolled without adjustments.
         */
        if (widgets.isEmpty())
            return opaque;

        getLocationInWindow(mLocation);
        int height = getHeight();
        int ymin = Math.min(mLocation[1], 0);
        int ymax = Math.max(mLocation[1] + height, height);

        for (Entry<Long, NativeWidget> item : widgets.entrySet()) {
            NativeWidget widget = item.getValue();
            if (widget == null || !widget.visible)
                continue;

            region.op(mLocation[0] + widget.minx, ymin,
                      mLocation[0] + widget.maxx, ymax,
                      Region.Op.DIFFERENCE);
        }
        
        return opaque;
    }
    
    /* ****************************** *
     *      TOUCH EVENT HANDLING      *
     * ****************************** */
    
    @NonNull
    private ScaleGestureDetector.OnScaleGestureListener scale_listener
        = new ScaleGestureDetector.OnScaleGestureListener() 
    {
        private static final float STEP = 0.005f;
        private static final float STEP1 = 0.05f;
        private static final float PRECISION = 0.2f;
        private static final float THRESHOLD = 0.15f;
    
        private float fx, fy;
        private boolean scaling;
        private boolean first;
    
        public boolean onScale(@NonNull ScaleGestureDetector detector) {
            // First event: remember focus center.
            // The one in onScaleBegin is wrong if
            // finger enters from the border.
            if (first) {
                fx = detector.getFocusX();
                fy = detector.getFocusY();
                first = false;
                return false;
            }

            // Focus center movement
            int dx = Math.round(detector.getFocusX() - fx);
            int dy = Math.round(detector.getFocusY() - fy);
            fx += dx; fy += dy;

            // Scaling
            float sf = detector.getScaleFactor();
            boolean accept = false;

            if (scaling) {
                if (Math.abs(sf-1.0f) >= STEP)
                    accept = true;
                else if (detector.getTimeDelta() > 1500)
                    scaling = false;
            } else {
                float pixel_size = 2.5f/wrapper.getDPI();
                float pspan = detector.getPreviousSpan() * pixel_size;
                float cspan = detector.getCurrentSpan() * pixel_size;
                float threshold = THRESHOLD * PRECISION / (pspan * STEP1);

                if (Math.abs(cspan - pspan) > threshold) {
                    scaling = true;
                    accept = true;
                    sf = Math.max(Math.min(sf, 1.0f+STEP1), 1.0f-STEP1);
                }
            }                
            
            // If anything changed, apply:
            if (accept || dx != 0 || dy != 0) {
                //Log.i(Utils.LOG_TAG, "x " + dx + " y " + dy + " f " + sf + " " + accept);
                if (!surface.gestureListener.onScale(detector)) // Can Flow code handle?
                    wrapper.adjustGlobalScale(dx, dy, fx, fy, accept ? sf : 1.0f);
            }

            return accept;
        }

        public boolean onScaleBegin(@NonNull ScaleGestureDetector detector) {
            inScaleMode = true;
            scaling = false;
            first = true;
            surface.gestureListener.onScaleBegin(detector);
            return true;
        }

        public void onScaleEnd(@NonNull ScaleGestureDetector detector) {
            surface.gestureListener.onScaleEnd(detector);
        }
    };

    private ScaleGestureDetector scale_detector;
    private boolean inScaleMode = false;
    private boolean blockEvents = true;
    
    public void setBlockEvents(boolean block) {
        blockEvents = block;
        inScaleMode = false;
        if (!block)
            surface.requestRender();
    }
    
    public boolean getBlockEvents() {
        return blockEvents;
    }
    
    public boolean onInterceptTouchEvent (MotionEvent event) {
        if (blockEvents)
            return true;

        scale_detector.onTouchEvent(event);
        return inScaleMode;
    }
    
    public boolean onTouchEvent(@NonNull MotionEvent event) {
        if (blockEvents)
            return true;

        scale_detector.onTouchEvent(event);
        
        switch (event.getActionMasked()) {
        case MotionEvent.ACTION_UP:
        case MotionEvent.ACTION_CANCEL:
            inScaleMode = false;
            break;
        }
        
        return true;
    }
}

class FlowAccessibleClip {
    private String role;
    private String description;
    private Rect bounds;
    @Nullable
    private View view; // Fake view to provide description and bounds for accessibility tools
    private ViewGroup group;
    
    public FlowAccessibleClip(String _role, String _description, int l, int t, int r, int b) {
        role = _role;
        description = _description;
        bounds = new Rect(l, t, r, b);
        view = null;
    }

    public void createView(ViewGroup _group) {
        group = _group;
        view = new View(group.getContext());
        group.addView(view);
        
        if (Build.VERSION.SDK_INT >= 14) {
            view.setAccessibilityDelegate(new AccessibilityDelegate() {
                @Override
                public void onInitializeAccessibilityNodeInfo(View host, @NonNull AccessibilityNodeInfo info) {
                    super.onInitializeAccessibilityNodeInfo(host, info);
                    info.setText(role + ":" + description);
                }
            } );
        }
    }
    
    public void destroyView() {
        group.removeView(view);
        view = null;
    }
    
    public void layoutView() {
        view.layout(bounds.left, bounds.top, bounds.right, bounds.bottom);
    }
}
