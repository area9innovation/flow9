package dk.area9.flowrunner;

import android.Manifest;
import android.annotation.TargetApi;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.hardware.Camera;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.util.Log;
import android.view.SurfaceHolder;

import java.io.File;
import java.util.List;

@TargetApi(Build.VERSION_CODES.GINGERBREAD)
public class FlowCameraAPI {

    public static final String CAMERA_PHOTO_PATH = "FLOW_CAMERA_PHOTO_PATH";
    public static final String CAMERA_VIDEO_PATH = "FLOW_CAMERA_VIDEO_PATH";
    public static final String CAMERA_APP_CALLBACK_ADDITIONAL_INFO = "FLOW_CAMERA_APP_CALLBACK_ADDITIONAL_INFO";
    public static final String CAMERA_APP_DESIRED_WIDTH = "FLOW_CAMERA_APP_DESIRED_WIDTH";
    public static final String CAMERA_APP_DESIRED_HEIGHT = "FLOW_CAMERA_APP_DESIRED_HEIGHT";
    public static final String CAMERA_APP_COMPRESS_QUALITY = "FLOW_CAMERA_APP_COMPRESS_QUALITY";
    public static final String CAMERA_APP_DESIRED_FILENAME = "FLOW_CAMERA_APP_DESIRED_FILENAME";
    public static final String CAMERA_APP_FIT_MODE = "FLOW_CAMERA_APP_FIT_MODE";
    public static final String CAMERA_APP_DURATION = "FLOW_CAMERA_APP_DURATION";
    public static final String CAMERA_APP_SIZE = "FLOW_CAMERA_APP_SIZE";
    public static final String CAMERA_APP_VIDEO_QUALITY = "FLOW_CAMERA_APP_VIDEO_QUALITY";


    @Nullable
    public static String cameraAppCallbackAdditionalInfo = "";
    @Nullable
    public static String cameraAppDesiredFilename = "";
    // Settings for photo mode only
    @Nullable
    public static String cameraAppPhotoFilePath = "";
    public static int cameraAppDesiredWidth = 1024;
    public static int cameraAppDesiredHeight = 1024;
    public static int cameraAppCompressQuality = 80;
    public static int cameraAppFitMode = BitmapUtils.FIT_CONTAIN;
    // Settings for video mode only
    @Nullable
    public static String cameraAppVideoFilePath = "";
    public static int cameraAppDuration = 15;
    public static int cameraAppSize = 15728640;
    public static int cameraAppVideoQuality = 1;

    @Nullable
    public static Runnable cameraAppOpenPhotoRunnable = null;
    @Nullable
    public static Runnable cameraAppOpenVideoRunnable = null;

    private static final int DIALOG_FROM_CAMERA_ITEM = 0;
    private static final int DIALOG_FROM_GALLERY_ITEM = 1;
    private static final int DIALOG_CANCEL_ITEM = 2;

    private Context context;
    @Nullable
    private Camera camera = null;
    private volatile static FlowCameraAPI uniqueInstance;
    private boolean isCameraFree = true;
    private int curCameraID = 0;

    private FlowCameraAPI() {}

    public void setContext(Context context) {
        this.context = context;
    }

    public int getNumberOfCameras() {
        return Camera.getNumberOfCameras();
    }

    @NonNull
    public String getCameraInfo(int id) {
        String res = "";
        int n = Camera.getNumberOfCameras();
        if ((0 <= id) && (id < n)) {
            String facing = "";
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.FROYO) {
                facing = "FRONT";
            }else{
                Camera.CameraInfo info=new Camera.CameraInfo();
                Camera.getCameraInfo(id, info);
                if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {
                    facing = "FRONT";
                } else {
                    facing = "BACK";
                }
            }
            Camera.Parameters cameraParameters;
            camera = Camera.open(id);
            cameraParameters = camera.getParameters();
            camera.release();
            // Current settings for camera
            //Camera.Size pictureSize = cameraParameters.getPictureSize();
            // Maximum resolution for camera
            List<Camera.Size> supportedPictureSizes =cameraParameters.getSupportedPictureSizes();
            int l = supportedPictureSizes.size();
            Camera.Size pictureSize = supportedPictureSizes.get(l-1);
            res = facing+";"+Integer.toString(pictureSize.width)+";"+Integer.toString(pictureSize.height)+"\n";

        }
        return res;
    }

    public static FlowCameraAPI getInstance() {
        if (uniqueInstance == null) {
            uniqueInstance = new FlowCameraAPI();
        }
        return uniqueInstance;
    }

    @Nullable
    public Camera openCamera(int id) {
        if (!isCameraFree) return null;
        try {
            if (camera != null) camera.release();
            camera = Camera.open(id);
            curCameraID = id;
            isCameraFree = false;
        } catch(RuntimeException e) {
            Log.e(Utils.LOG_TAG, "Error while opening camera", e);
        }
        return camera;
    }

    public void closeCamera(int id) {
        if (id != curCameraID) return;
        camera.release();
        isCameraFree = true;
    }

    public void setDisplayOrientation(int id, int result) {
        if (id != curCameraID) return;
        camera.setDisplayOrientation(result);
    }

    public void setPreviewDisplay(int id, SurfaceHolder mHolder) throws Exception {
        if (id != curCameraID) return;
        camera.setPreviewDisplay(mHolder);
    }

    public void startPreview(int id) {
        if (id != curCameraID) return;
        camera.startPreview();
    }

    public void stopPreview(int id) {
        if (id != curCameraID) return;
        camera.stopPreview();
    }

    private void createTakePhotoDialog(final int cameraId, final String additionalInfo, final int desiredWidth, final int desiredHeight, final int compressQuality, final String fileName) {
        // TODO: This dialog ignores translation! Pass titles via arguments.
        final String[] dialogButtons = {"Take Photo", "Choose photo from Library", "Cancel"};
        AlertDialog.Builder dialogBuilder = new AlertDialog.Builder(context);
        dialogBuilder.setTitle("Take a photo");
        dialogBuilder.setItems(dialogButtons, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(@NonNull DialogInterface dialog, int item) {
                if (item == DIALOG_FROM_CAMERA_ITEM) {
                    openCameraAppPhoto(cameraId, additionalInfo, desiredWidth, desiredHeight, compressQuality, fileName);
                } else if (item == DIALOG_FROM_GALLERY_ITEM) {
                    openImageGalleryPicker(additionalInfo, desiredWidth, desiredHeight, compressQuality, fileName);
                } else if (item == DIALOG_CANCEL_ITEM) {
                    dialog.dismiss();
                }
            }
        });
        dialogBuilder.show();
    }

    private void createTakeVideoDialog(final int cameraId, final String additionalInfo, final int duration, final int size, final int quality, final String fileName) {
        // TODO: This dialog ignores translation! Pass titles via arguments.
        final String[] dialogButtons = {"Take Video", "Choose video from Library", "Cancel"};
        AlertDialog.Builder dialogBuilder = new AlertDialog.Builder(context);
        dialogBuilder.setTitle("Take a video");
        dialogBuilder.setItems(dialogButtons, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(@NonNull DialogInterface dialog, int item) {
                if (item == DIALOG_FROM_CAMERA_ITEM) {
                    openCameraAppVideo(cameraId, additionalInfo, duration, size, quality, fileName);
                } else if (item == DIALOG_FROM_GALLERY_ITEM) {
                    openVideoGalleryPicker(additionalInfo, duration, size, quality, fileName);
                } else if (item == DIALOG_CANCEL_ITEM) {
                    dialog.dismiss();
                }
            }
        });
        dialogBuilder.show();
    }

    private void openImageGalleryPicker(String additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, String fileName) {
        Intent intent = new Intent(Intent.ACTION_PICK, android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        intent.setType("image/*");
        cameraAppPhotoFilePath = "";
        ((FlowRunnerActivity)context).startActivityForResult(Intent.createChooser(intent, "Select File"), Utils.GALLERY_PHOTO_PICKER_MODE);
    }

    private void openVideoGalleryPicker(String additionalInfo, int duration, int size, int quality, String fileName) {
        Intent intent = new Intent(Intent.ACTION_PICK, android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI);
        intent.setType("video/*");

        cameraAppVideoFilePath = "";
        ((FlowRunnerActivity)context).startActivityForResult(Intent.createChooser(intent, "Select File"), Utils.GALLERY_VIDEO_PICKER_MODE);
    }

    private void openCameraAppPhoto(int cameraId, String additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, final String fileName) {
        cameraAppOpenPhotoRunnable = new Runnable() {
            @Override
            public void run() {
                Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                if (takePictureIntent.resolveActivity(context.getPackageManager()) != null) {
                    String imageFileName = fileName + ".jpg";
                    File storageDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
                    if (!storageDir.exists()) {
                        storageDir.mkdirs();
                    }
                    File image = new File(storageDir, imageFileName);

                    cameraAppPhotoFilePath = image.getAbsolutePath();

                    takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, Utils.fileUriToContentUri(context, image));
                    takePictureIntent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);

                    ((FlowRunnerActivity) context).startActivityForResult(takePictureIntent, Utils.CAMERA_APP_PHOTO_MODE);
                }
            }
        };

        if (Utils.isRequestPermissionsSupported &&
            !Utils.checkAndRequestPermissions((FlowRunnerActivity)context, new String[] {
                    Manifest.permission.CAMERA,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
            }, FlowRunnerActivity.FlowCameraAPIPermissionCode))
            return;

        cameraAppOpenPhotoRunnable.run();
        cameraAppOpenPhotoRunnable = null;
    }

    private void openCameraAppVideo(int cameraId, String additionalInfo, final int duration, final int size, final int quality, final String fileName) {
        cameraAppOpenVideoRunnable = new Runnable() {
            @Override
            public void run() {
                Intent takeVideoIntent = new Intent(MediaStore.ACTION_VIDEO_CAPTURE);
                if (takeVideoIntent.resolveActivity(context.getPackageManager()) != null) {
                    String videoFileName = fileName + ".mp4";
                    File storageDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES);
                    if (!storageDir.exists()) {
                        storageDir.mkdirs();
                    }
                    File video = new File(storageDir, videoFileName);

                    cameraAppVideoFilePath = video.getAbsolutePath();

                    takeVideoIntent.putExtra(MediaStore.EXTRA_DURATION_LIMIT, duration);
                    takeVideoIntent.putExtra(MediaStore.EXTRA_SIZE_LIMIT, size);
                    takeVideoIntent.putExtra(MediaStore.EXTRA_VIDEO_QUALITY, quality);
                    takeVideoIntent.putExtra(MediaStore.EXTRA_OUTPUT, Utils.fileUriToContentUri(context, video));
                    takeVideoIntent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);

                    ((FlowRunnerActivity) context).startActivityForResult(takeVideoIntent, Utils.CAMERA_APP_VIDEO_MODE);
                }
            }
        };

        if (Utils.isRequestPermissionsSupported &&
                !Utils.checkAndRequestPermissions((FlowRunnerActivity)context, new String[] {
                        Manifest.permission.CAMERA,
                        Manifest.permission.RECORD_AUDIO,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                }, FlowRunnerActivity.FlowCameraAPIPermissionCode))
            return;
        cameraAppOpenVideoRunnable.run();
        cameraAppOpenVideoRunnable = null;
    }

    public void openCameraAppPhotoMode(int cameraId, String additionalInfo, int desiredWidth, int desiredHeight, int compressQuality, String fileName, int fitMode) {
        cameraAppCallbackAdditionalInfo = additionalInfo;
        cameraAppDesiredWidth = desiredWidth;
        cameraAppDesiredHeight = desiredHeight;
        cameraAppCompressQuality = Math.max(0, Math.min(100, compressQuality));
        cameraAppDesiredFilename = fileName;
        cameraAppFitMode = fitMode;

        createTakePhotoDialog(cameraId, additionalInfo, desiredWidth, desiredHeight, compressQuality, fileName);
    }

    public void openCameraAppVideoMode(int cameraId, String additionalInfo, int duration, int size, int quality, String fileName) {
        cameraAppCallbackAdditionalInfo = additionalInfo;
        cameraAppDuration = duration;
        cameraAppSize = size;
        cameraAppVideoQuality = Math.max(0, Math.min(1, quality));
        cameraAppDesiredFilename = fileName;

        createTakeVideoDialog(cameraId, additionalInfo, duration, size, quality, fileName);
    }

}
