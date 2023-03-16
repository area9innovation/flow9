package dk.area9.flowrunner;

import android.content.Context;
import android.os.Handler;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;
import android.view.View;
import android.widget.RelativeLayout;

class CameraWidget extends NativeWidget {
    static final int RecordReady = 0; // Ready for recording
    static final int RecordStart = 1;   // Record start
    static final int RecordStop = 2;   // Record stop

    public CameraWidget(FlowWidgetGroup group, long id, Handler uiHandler) {
        super(group, id);
        this.uiHandler = uiHandler;
    }
    
    @NonNull
    protected View createView() {
        Log.d(Utils.LOG_TAG, "CameraWidget.createView start");
        context = group.getContext();
        camera = new CameraPreview(context, this, camID);
        camera.setZOrderMediaOverlay(true);
        
        int fill = RelativeLayout.LayoutParams.FILL_PARENT;
        final RelativeLayout grp = new RelativeLayout(context);

        RelativeLayout.LayoutParams vparams = new RelativeLayout.LayoutParams(fill,fill);
        vparams.addRule(RelativeLayout.ALIGN_PARENT_TOP,-1);
        vparams.addRule(RelativeLayout.ALIGN_PARENT_LEFT,-1);
        grp.addView(camera, vparams);
        
        Log.d(Utils.LOG_TAG, "CameraWidget.createView end");
        return grp;
    }

    private String filename;
    private Handler uiHandler;
    private Context context;
    private boolean record;
    private int camID, camWidth, camHeight, camFps, recordMode;
    private CameraPreview camera;
    
    public void layout() {
        super.layout();

        Log.d(Utils.LOG_TAG, "CAMERA LAYOUT " + (maxx-minx) + "x" + (maxy-miny));
    }
    
    public void resize(boolean nvisible, int nminx, int nminy, int nmaxx, int nmaxy, float nscale, float nalpha)
    {
        if (nmaxx <= nminx || nmaxy <= nminy)
        {
            nminx++; nminy++;
            nmaxx = Math.max(nminx+1,nmaxx);
            nmaxy = Math.max(nminy+1,nmaxy);
        }

        int dx = nmaxx - nminx;
        int dy = nmaxy - nminy;
        if (dx != dy)
        {
            nmaxx = nminx + Math.min(dx,dy);
            nmaxy = nminy + Math.min(dx,dy);
        }

        Log.d(Utils.LOG_TAG, "CAMERA RESIZE " + (nmaxx-nminx) + "x" + (nmaxy-nminy));
        Log.d(Utils.LOG_TAG, "CAMERA RESIZE(" + nminx + "," + nminy + "," + nmaxx + "," + nmaxy + "," + nscale + "," + nalpha + ")");
        super.resize(nvisible, nminx, nminy, nmaxx, nmaxy, nscale, nalpha);
        if (camera != null) {
            camera.updateRotation();
        } else {
            Log.d(Utils.LOG_TAG, "CameraWidget.resize camera == null");
        }
    }
    
    private void updateStateFlags(@NonNull CameraPreview camera) {
        if (record) 
            camera.startRecord(filename, camWidth, camHeight, camFps, recordMode);
        else
            camera.stopRecord();
    }
    
    @NonNull
    private Runnable create_cb = new Runnable() {
        public void run() {
            Log.d(Utils.LOG_TAG, "create_cb");
            getOrCreateView();
        }
    };

    @NonNull
    private Runnable update_cb = new Runnable() {
        public void run() {
            Log.d(Utils.LOG_TAG, "update_cb");
            if (camera == null) {
                Log.d(Utils.LOG_TAG, "camera == null");
                return;
            }
            updateStateFlags(camera);
        }
    };

    private long getReportId()
    {
        Log.d(Utils.LOG_TAG, "CameraWidget.getReportId: start, id =" + id);
        if (id == 0) return 0;
        Log.d(Utils.LOG_TAG, "CameraWidget.getReportId:" + id);
        return id;
    }
    
    public void reportFailure()
    {
        long idv = getReportId();
        Log.d(Utils.LOG_TAG, "CameraWidget.reportFailure:" + idv);
        if (idv != 0)
            group.getWrapper().deliverCameraError(idv);
    }

    public void reportStatusEvent(int event)
    {
        Log.d(Utils.LOG_TAG, "CameraWidget.reportStatusEvent:" + event);
        long idv = getReportId();
        if (idv != 0)
            group.getWrapper().deliverCameraStatus(idv, event);
    }
    
    public void init(int camID, int camWidth, int camHeight, int camFps, int recordMode)
    {
        Log.d(Utils.LOG_TAG, "CameraWidget.init");
        this.record = false;
        this.camID = camID;
        this.camWidth = camWidth;
        this.camHeight = camHeight;
        this.camFps = camFps;
        this.recordMode = recordMode;
        Log.d(Utils.LOG_TAG, "CameraWidget.init group.post(create_cb)");
        uiHandler.post(create_cb);
        //((Activity) context).runOnUiThread(create_cb);
        
    }

    public void configure(final String filename, boolean record)
    {
        Log.d(Utils.LOG_TAG, "CameraWidget.configure;" + filename + ";" + record);
        this.record = record;
        this.filename = filename;
        
        group.post(update_cb);
    }
    
    public void destroy() {
        // Ensure the resources are immediately released
        camera.destroy();
        super.destroy();
    }
}
