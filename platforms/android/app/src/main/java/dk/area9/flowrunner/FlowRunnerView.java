package dk.area9.flowrunner;

import java.nio.ByteBuffer;
import java.util.ArrayList;

import javax.microedition.khronos.egl.EGL10;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.egl.EGLContext;
import javax.microedition.khronos.egl.EGLDisplay;
import javax.microedition.khronos.opengles.GL10;

import android.graphics.PixelFormat;
import android.opengl.GLSurfaceView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;
import android.view.GestureDetector;
import android.view.GestureDetector.SimpleOnGestureListener;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.ScaleGestureDetector.OnScaleGestureListener;
import android.view.SurfaceHolder;


/**
 * A simple GLSurfaceView sub-class that demonstrate how to perform
 * OpenGL ES 2.0 rendering into a GL Surface. Note the following important
 * details:
 *
 * - The class must use a custom context factory to enable 2.0 rendering.
 *   See ContextFactory class definition below.
 *
 * - The class must use a custom EGLConfigChooser to be able to select
 *   an EGLConfig that supports 2.0. This is done by providing a config
 *   specification to eglChooseConfig() that has the attribute
 *   EGL10.ELG_RENDERABLE_TYPE containing the EGL_OPENGL_ES2_BIT flag
 *   set. See ConfigChooser class definition below.
 *
 * - The class must select the surface's format, then choose an EGLConfig
 *   that matches it exactly (with regards to red/green/blue/alpha channels
 *   bit depths). Failure to do so would result in an EGL_BAD_MATCH error.
 */
class FlowRunnerView extends GLSurfaceView {
    private FlowRunnerWrapper wrapper;
    private FlowWidgetGroup group;
    
    // private static String TAG = "GL2JNIView";
    
    @NonNull
    private final GestureDetector gestureDetector;
    @NonNull
    public final FlowGestureListener gestureListener;

    public FlowRunnerView(FlowWidgetGroup group) {
        super(group.getContext());
        this.wrapper = group.getWrapper();
        this.group = group;
        this.gestureListener = new FlowGestureListener();
        this.gestureDetector = new GestureDetector(group.getContext(), gestureListener);

        init(false, 0, 8);
    }

    @Override
    public void onPause() {
        for(final VideoWidget v : group.getVideoWidgets()) {
            v.onPause();
        }
        super.onPause();
    }

    private void init(boolean translucent, int depth, int stencil) {

        /* By default, GLSurfaceView() creates a RGB_565 opaque surface.
         * If we want a translucent one, we should change the surface's
         * format here, using PixelFormat.TRANSLUCENT for GL Surfaces
         * is interpreted as any 32-bit surface with alpha by SurfaceFlinger.
         */
        if (translucent) {
            this.getHolder().setFormat(PixelFormat.TRANSLUCENT);
        }

        /* Setup the context factory for 2.0 rendering.
         * See ContextFactory class definition below
         */
        setEGLContextFactory(new ContextFactory());

        /* We need to choose an EGLConfig that matches the format of
         * our surface exactly. This is going to be done in our
         * custom config chooser. See ConfigChooser class definition
         * below.
         */
        setEGLConfigChooser( translucent ?
                             new ConfigChooser(8, 8, 8, 8, depth, stencil) :
                             new ConfigChooser(5, 6, 5, 0, depth, stencil) );

        /* Set the renderer responsible for frame rendering */
        setRenderer(renderer);
        setRenderMode(RENDERMODE_WHEN_DIRTY);
        
        wrapper.addListener(wrapper_cb);
    }

    @NonNull
    private FlowRunnerWrapper.Listener wrapper_cb = new FlowRunnerWrapper.ListenerAdapter() {
        public void onFlowNeedsRepaint() {
            requestRender();
        }
    };
    
    @NonNull
    private Renderer renderer = new Renderer() {
        boolean changed = false, created = false;
        int width, height;

        public void onDrawFrame(@NonNull GL10 gl) {
            if (group.getBlockEvents()) {
                gl.glClearColor(1, 1, 1, 1);
                gl.glClear(GL10.GL_COLOR_BUFFER_BIT);
                return;
            }

            if (created)
                wrapper.onSurfaceCreated(gl, null);
            if (changed)
                wrapper.onSurfaceChanged(gl, width, height);

            changed = created = false;
            wrapper.onDrawFrame(gl);

            gl.glReadPixels(0, 0, 1, 1, GL10.GL_RGBA, GL10.GL_UNSIGNED_BYTE, PixelBuffer);
        }

        private ByteBuffer PixelBuffer = ByteBuffer.allocateDirect(4);

        public void onSurfaceChanged(GL10 gl, int width, int height) {
            this.width = width;
            this.height = height;
            changed = true;
        }

        public void onSurfaceCreated(GL10 gl, EGLConfig config) {
            created = changed = true;
            
            ArrayList<VideoWidget> videos = group.getVideoWidgets();
            
            for (final VideoWidget video : videos) {
                video.createSurface();
            }
        }
    };
    
    /* ****************************** *
     *     CONTEXT INITIALIZATION     *
     * ****************************** */
    
    private static class ContextFactory implements GLSurfaceView.EGLContextFactory {
        private static int EGL_CONTEXT_CLIENT_VERSION = 0x3098;
        public EGLContext createContext(@NonNull EGL10 egl, EGLDisplay display, EGLConfig eglConfig) {
            Log.w(Utils.LOG_TAG, "creating OpenGL ES 2.0 context");
            checkEglError("Before eglCreateContext", egl);
            int[] attrib_list = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL10.EGL_NONE };
            EGLContext context = egl.eglCreateContext(display, eglConfig, EGL10.EGL_NO_CONTEXT, attrib_list);
            checkEglError("After eglCreateContext", egl);
            return context;
        }

        public void destroyContext(@NonNull EGL10 egl, EGLDisplay display, EGLContext context) {
            egl.eglDestroyContext(display, context);
        }
    }
    
    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        ArrayList<VideoWidget> videos = group.getVideoWidgets();
        
        for (VideoWidget video : videos) {
            video.destroySurface();
        }
        
        super.surfaceDestroyed(holder);
    }

    private static void checkEglError(String prompt, EGL10 egl) {
        int error;
        while ((error = egl.eglGetError()) != EGL10.EGL_SUCCESS) {
            Log.e(Utils.LOG_TAG, String.format("%s: EGL error: 0x%x", prompt, error));
        }
    }

    private static class ConfigChooser implements GLSurfaceView.EGLConfigChooser {

        public ConfigChooser(int r, int g, int b, int a, int depth, int stencil) {
            mRedSize = r;
            mGreenSize = g;
            mBlueSize = b;
            mAlphaSize = a;
            mDepthSize = depth;
            mStencilSize = stencil;
        }

        /* This EGL config specification is used to specify 2.0 rendering.
         * We use a minimum size of 4 bits for red/green/blue, but will
         * perform actual matching in chooseConfig() below.
         */
        private static int EGL_OPENGL_ES2_BIT = 4;
        @NonNull
        private static int[] s_configAttribs2 =
        {
            EGL10.EGL_RED_SIZE, 4,
            EGL10.EGL_GREEN_SIZE, 4,
            EGL10.EGL_BLUE_SIZE, 4,
            EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
            EGL10.EGL_NONE
        };

        @Nullable
        public EGLConfig chooseConfig(@NonNull EGL10 egl, EGLDisplay display) {

            /* Get the number of minimally matching EGL configurations
             */
            int[] num_config = new int[1];
            egl.eglChooseConfig(display, s_configAttribs2, null, 0, num_config);

            int numConfigs = num_config[0];

            if (numConfigs <= 0) {
                throw new IllegalArgumentException("No configs match configSpec");
            }

            /* Allocate then read the array of minimally matching EGL configs
             */
            EGLConfig[] configs = new EGLConfig[numConfigs];
            egl.eglChooseConfig(display, s_configAttribs2, configs, numConfigs, num_config);

            /* Now return the "best" one
             */
            return chooseConfig(egl, display, configs);
        }

        @Nullable
        public EGLConfig chooseConfig(@NonNull EGL10 egl, EGLDisplay display,
                                      @NonNull EGLConfig[] configs) {
            for(EGLConfig config : configs) {
                int d = findConfigAttrib(egl, display, config,
                        EGL10.EGL_DEPTH_SIZE, 0);
                int s = findConfigAttrib(egl, display, config,
                        EGL10.EGL_STENCIL_SIZE, 0);

                // We need at least mDepthSize and mStencilSize bits
                if (d < mDepthSize || s < mStencilSize)
                    continue;

                // We want an *exact* match for red/green/blue/alpha
                int r = findConfigAttrib(egl, display, config,
                        EGL10.EGL_RED_SIZE, 0);
                int g = findConfigAttrib(egl, display, config,
                            EGL10.EGL_GREEN_SIZE, 0);
                int b = findConfigAttrib(egl, display, config,
                            EGL10.EGL_BLUE_SIZE, 0);
                int a = findConfigAttrib(egl, display, config,
                        EGL10.EGL_ALPHA_SIZE, 0);

                if (r == mRedSize && g == mGreenSize && b == mBlueSize && a == mAlphaSize)
                    return config;
            }
            return null;
        }

        private int findConfigAttrib(EGL10 egl, EGLDisplay display,
                EGLConfig config, int attribute, int defaultValue) {

            if (egl.eglGetConfigAttrib(display, config, attribute, mValue)) {
                return mValue[0];
            }
            return defaultValue;
        }

        // Subclasses can adjust these values:
        protected int mRedSize;
        protected int mGreenSize;
        protected int mBlueSize;
        protected int mAlphaSize;
        protected int mDepthSize;
        protected int mStencilSize;
        @NonNull
        private int[] mValue = new int[1];
    }
    
    /* ****************************** *
     *      TOUCH EVENT HANDLING      *
     * ****************************** */
    
    private int touch_start_x = -1;
    private int touch_start_y = -1;
    private final int TOUCH_MOVE_THRESHOLD = 10;
    
    public boolean onTouchEvent(@NonNull MotionEvent event) {
        int x = Math.round(event.getX());
        int y = Math.round(event.getY());
        
        switch (event.getActionMasked()) {
        case MotionEvent.ACTION_DOWN:
            wrapper.deliverMouseEvent(FlowRunnerWrapper.EVENT_MOUSE_DOWN, x, y);
            touch_start_x = x; touch_start_y = y;
            break;
            
        case MotionEvent.ACTION_MOVE:
            if (touch_start_x >= 0) {
                int dx = Math.abs(x - touch_start_x);
                int dy = Math.abs(y - touch_start_y);
                // Threshold is needed to behave like other targets - don't send Move for simple tap
                if (dx > TOUCH_MOVE_THRESHOLD || dy > TOUCH_MOVE_THRESHOLD) {
                    touch_start_x = touch_start_y = -1;
                    wrapper.deliverMouseEvent(FlowRunnerWrapper.EVENT_MOUSE_MOVE, x, y);
                }
            } else {
                wrapper.deliverMouseEvent(FlowRunnerWrapper.EVENT_MOUSE_MOVE, x, y);
            }
          
            break;
            
        case MotionEvent.ACTION_UP:
            if (!gestureListener.isFlowGestureInProgress()) wrapper.deliverMouseEvent(FlowRunnerWrapper.EVENT_MOUSE_UP, x, y);
            break;
            
        case MotionEvent.ACTION_CANCEL:
            if (!gestureListener.isFlowGestureInProgress()) wrapper.deliverMouseEvent(FlowRunnerWrapper.EVENT_MOUSE_CANCEL, x, y);
            break;
        }
        
        gestureListener.onTouchEvent(event);
        gestureDetector.onTouchEvent(event);

        return true;
    }
    
    class FlowGestureListener extends SimpleOnGestureListener implements OnScaleGestureListener
    {  
        // Triple tap for debug menu
        private int tapCount = 0;
        private float lastTapX = -10.0f;
        private float lastTapY = -10.0f;
        
        private void resetTapCounter(float x, float y) { lastTapX = x; lastTapY = y; tapCount = 0; }
        private void showPopupMenu() {
            final FlowRunnerActivity activity = (FlowRunnerActivity)group.getContext();
            activity.runOnUiThread(new Runnable() {
                public void run() { activity.showPopupMenu(); }
            });
        }
        
        // Pan gesture
        private boolean scrollInProgress = false;
        private boolean scrollHandledByFlow = false;
        
        public boolean isFlowGestureInProgress() { return scrollHandledByFlow || scaleHandledByFlow; }
        
        public void onTouchEvent(@NonNull MotionEvent event) {
            int action = event.getActionMasked();
            
            if (action == MotionEvent.ACTION_CANCEL || action == MotionEvent.ACTION_UP) {
                if (scrollInProgress) {
                    wrapper.deliverGestureEvent(FlowRunnerWrapper.EVENT_GESTURE_PAN, FlowRunnerWrapper.GESTURE_STATE_END, event.getX(), event.getY(), 0.0f, 0.0f);
                    scrollInProgress = false;
                    scrollHandledByFlow = false;
                } else if (action == MotionEvent.ACTION_UP) {
                    float x = event.getX();
                    float y = event.getY();
                    if ( Math.abs(x - lastTapX) < 35.0f && Math.abs(y - lastTapY) < 35.0f ) {
                        if (++tapCount == 2) {
                            resetTapCounter(-10.0f, -10.0f);
                            showPopupMenu();
                        }
                    } else {
                        resetTapCounter(x, y);
                    }
                }
            }
        }
        
        @Override
        public boolean onScroll(@NonNull MotionEvent e1, @NonNull MotionEvent e2, float distanceX, float distanceY)
        {
            if (e2.getPointerCount() == 1) {
                if (!scrollInProgress) {
                    scrollInProgress = true;
                    scrollHandledByFlow = wrapper.deliverGestureEvent(FlowRunnerWrapper.EVENT_GESTURE_PAN, FlowRunnerWrapper.GESTURE_STATE_BEGIN, e1.getX(), e1.getY(), 0.0f, 0.0f);
                } else if (scrollHandledByFlow) {
                    wrapper.deliverGestureEvent(FlowRunnerWrapper.EVENT_GESTURE_PAN, FlowRunnerWrapper.GESTURE_STATE_PROGRESS, e2.getX(), e2.getY(), -distanceX, -distanceY);
                }
            }
            
            return true;
        }
        
        // Pinch gesture
        private boolean scaleHandledByFlow = false;
        private float totalScaleFactor = 1.0f;
        
        public boolean onScaleBegin(@NonNull ScaleGestureDetector d) {
            totalScaleFactor = 1.0f;
            scaleHandledByFlow = wrapper.deliverGestureEvent(FlowRunnerWrapper.EVENT_GESTURE_PINCH, FlowRunnerWrapper.GESTURE_STATE_BEGIN, d.getFocusX(), d.getFocusY(), 1.0f, 0.0f); 
            return scaleHandledByFlow;
        }
        
        public boolean onScale(@NonNull ScaleGestureDetector d) {
            if (scaleHandledByFlow) {
                totalScaleFactor *= d.getScaleFactor();
                wrapper.deliverGestureEvent(FlowRunnerWrapper.EVENT_GESTURE_PINCH, FlowRunnerWrapper.GESTURE_STATE_PROGRESS, d.getFocusX(), d.getFocusY(), totalScaleFactor, 0.0f);
            }
            
            return scaleHandledByFlow;
        }
        public void onScaleEnd(@NonNull ScaleGestureDetector d) {
            wrapper.deliverGestureEvent(FlowRunnerWrapper.EVENT_GESTURE_PINCH, FlowRunnerWrapper.GESTURE_STATE_END, d.getFocusX(), d.getFocusY(), totalScaleFactor, 0.0f);
            scaleHandledByFlow = false;
        }
    }
}
