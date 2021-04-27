package dk.area9.flowrunner;

import java.io.IOException;

import android.annotation.TargetApi;
import android.app.Activity;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.graphics.Point;
import android.hardware.Camera;
import android.hardware.Camera.CameraInfo;
import android.media.MediaRecorder;
import android.media.CamcorderProfile;
import android.os.Build;
import android.os.Environment;
import androidx.annotation.NonNull;
import android.util.Log;
import android.view.Display;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.WindowManager;


public class CameraPreview extends SurfaceView implements SurfaceHolder.Callback {
    private SurfaceHolder mHolder;
    private Camera mCamera;
    private int camID = 0;
    private MediaRecorder recorder;
    private Context context;
    private CameraWidget owner;
    private boolean failed = false;
    private boolean recordRunning = false;
    private FlowCameraAPI flowCameraAPI = FlowCameraAPI.getInstance();

	public CameraPreview(Context context, @NonNull CameraWidget owner, int camID) {
        super(context);
        this.context = context;
        this.owner = owner;
        this.camID = camID;
        mCamera = flowCameraAPI.openCamera(camID);
        if (mCamera == null) {
            failed = true;
            Log.d(Utils.LOG_TAG, "CameraPreview.FAILED");
            owner.reportFailure();
            return;
        }
        recorder = new MediaRecorder();
        // Install a SurfaceHolder.Callback so we get notified when the
        // underlying surface is created and destroyed.
        mHolder = getHolder();
        mHolder.addCallback(this);
        // deprecated setting, but required on Android versions prior to 3.0
        mHolder.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS);
    }

    private void prepareRecorder(String filename, int camWidth, int camHeight, int camFps, int recordMode) {
        if (failed) return;
        mCamera.unlock();
        recorder.setCamera(mCamera);
        try {
            recorder.setAudioSource(MediaRecorder.AudioSource.DEFAULT);
            recorder.setVideoSource(MediaRecorder.VideoSource.DEFAULT);
            CamcorderProfile ccProfile = CamcorderProfile.get(CamcorderProfile.QUALITY_HIGH);
            recorder.setProfile(ccProfile);
            recorder.setOutputFile(Environment.getExternalStorageDirectory().getPath() + "/" + filename);
            recorder.setVideoSize(camWidth, camHeight);
            recorder.setVideoFrameRate(camFps);
            recorder.setPreviewDisplay(mHolder.getSurface());
            recorder.prepare();
            recorder.start();
            recordRunning = true;
        } catch (IllegalStateException e) {
            Log.v(Utils.LOG_TAG,"Couldn't set MPEG-4 as output format");
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void startRecord(String filename, int camWidth, int camHeight, int camFps, int recordMode) {
        if (failed) return;
        if (!recordRunning) {
            lockOrientation();
            prepareRecorder(filename, camWidth, camHeight, camFps, recordMode);
            recordRunning = true;
            owner.reportStatusEvent(CameraWidget.RecordStart);
        }
    }

    public void stopRecord() {
        if (failed) return;
        if (recordRunning) {
            ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
            try {
                recorder.stop();
                recordRunning = false;
                owner.reportStatusEvent(CameraWidget.RecordStop);
            } catch (IllegalStateException e) {
                e.printStackTrace();
            }
        }
    }
    
    public int getVideoWidth() {
        int width = 0;
        if (mCamera != null) {
            width = 1280;
        }
        return width;  
    }
    
    public int getVideoHeight() {
        int height = 0;
        if (mCamera != null) {
            height = 720;
        }
        return height;  
    }

    private void lockOrientation() {
        if (failed) return;
        Display display = ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay();
        int rotation = display.getRotation();
        Point size = new Point();
        display.getSize(size);
        int height = size.y;
        int width = size.x;
        switch (rotation) {
        case Surface.ROTATION_90:
            if (width > height)
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
            else
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT);
            break;
        case Surface.ROTATION_180:
            if (height > width)
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT);
            else
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE);
            break;          
        case Surface.ROTATION_270:
            if (width > height)
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE);
            else
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
            break;
        case Surface.ROTATION_0:
            if (height > width)
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
            else
                ((Activity) context).setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        }
    }
    
    public void updateRotation() {
        if (failed) return;
        CameraInfo info = new Camera.CameraInfo();
        Camera.getCameraInfo(camID, info);
        int rotation = ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay().getRotation();
        int degrees = 0;
        switch (rotation) {
            case Surface.ROTATION_0: degrees = 0; break;
            case Surface.ROTATION_90: degrees = 90; break;
            case Surface.ROTATION_180: degrees = 180; break;
            case Surface.ROTATION_270: degrees = 270; break;
        }
        int result;
        if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {
            result = (info.orientation + degrees) % 360;
            result = (360 - result) % 360;  // compensate the mirror
        } else {  // back-facing
            result = (info.orientation - degrees + 360) % 360;
        }
        int orientationHint = (360 - result) % 360;
        Log.d(Utils.LOG_TAG, "info.orientation=" + info.orientation + ";rotation=" + rotation + "(" + degrees + ");result=" + result + ";orientationHint=" + orientationHint);        
        flowCameraAPI.setDisplayOrientation(camID, result);
        recorder.setOrientationHint(orientationHint);
    }

    public void surfaceCreated(SurfaceHolder holder) {
        if (failed) return;
        // The Surface has been created, now tell the camera where to draw the preview.
        try {
            flowCameraAPI.setPreviewDisplay(camID, mHolder);
            flowCameraAPI.startPreview(camID);
            owner.reportStatusEvent(CameraWidget.RecordReady);
            
        } catch (Exception e) {
            Log.d(Utils.LOG_TAG, "Error setting camera preview: " + e.getMessage());
        }
    }

    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        
    }
   
    public void surfaceDestroyed(SurfaceHolder holder) {
        if (failed) return;
        flowCameraAPI.stopPreview(camID);
        stopRecord();
    }
    
    public void destroy() {
        // Ensure the resources are immediately released
        flowCameraAPI.closeCamera(camID);
    }
}
