package dk.area9.flowrunner;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.hardware.display.DisplayManager;
import android.media.CamcorderProfile;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.support.v4.app.ActivityCompat;
import android.util.Size;
import android.util.SparseIntArray;
import android.view.Surface;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class FlowMediaRecorderSupport {

    public static boolean isCamera2Supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP;
    public static boolean isPauseResumeSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N;

    private static final SparseIntArray ORIENTATIONS = new SparseIntArray();

    static {
        ORIENTATIONS.append(Surface.ROTATION_0, 90);
        ORIENTATIONS.append(Surface.ROTATION_90, 0);
        ORIENTATIONS.append(Surface.ROTATION_180, 270);
        ORIENTATIONS.append(Surface.ROTATION_270, 180);
    }

    class FlowMediaRecorderObject {
        public MediaRecorder mediaRecorder;
        public CameraCaptureSession session;
        public File tempFile;
        public String filePath;
        public String websocketUri;

        public FlowMediaRecorderObject(MediaRecorder mediaRecorder, CameraCaptureSession session, File tempFile, String filePath, String websocketUri) {
            this.mediaRecorder = mediaRecorder;
            this.session = session;
            this.tempFile = tempFile;
            this.filePath = filePath;
            this.websocketUri = websocketUri;
        }
    }

    class FlowMediaStreamObject {
        public SurfaceTexture surfaceTexture;
        public int width;
        public int height;
        public int sensorOrientation;

        public FlowMediaStreamObject(SurfaceTexture surfaceTexture, int width, int height, int sensorOrientation) {
            this.surfaceTexture = surfaceTexture;
            this.width = width;
            this.height = height;
            this.sensorOrientation = sensorOrientation;
        }
    }

    private Map<String, String> videoDevices = new HashMap<String, String>();
    private Map<String, String> audioDevices = new HashMap<String, String>();

    private FlowRunnerActivity flowRunnerActivity;
    private FlowRunnerWrapper wrapper;

    FlowMediaRecorderSupport(FlowRunnerActivity ctx, FlowRunnerWrapper wrp) {
        flowRunnerActivity = ctx;
        wrapper = wrp;
    }

    public static int getOrientation(int sensorOrientation, int rotation) {
        // Sensor orientation is 90 for most devices, or 270 for some devices (eg. Nexus 5X)
        // We have to take that into account and rotate JPEG properly.
        // For devices with orientation of 90, we simply return our mapping from ORIENTATIONS.
        // For devices with orientation of 270, we need to rotate the JPEG 180 degrees.
        return (ORIENTATIONS.get(rotation) + sensorOrientation + 270) % 360;
    }

    public void initializeDeviceInfo() {
        videoDevices.clear();
        audioDevices.clear();
        if (isCamera2Supported) {
            CameraManager manager = (CameraManager) flowRunnerActivity.getSystemService(Context.CAMERA_SERVICE);
            try {
                String[] cameras = manager.getCameraIdList();
                for (String camera : cameras) {
                    CameraCharacteristics characteristics = manager.getCameraCharacteristics(camera);
                    String cameraName;

                    switch (characteristics.get(CameraCharacteristics.LENS_FACING)) {
                        case CameraMetadata.LENS_FACING_FRONT:
                            cameraName = "Front camera";
                            break;
                        case CameraMetadata.LENS_FACING_BACK:
                            cameraName = "Back camera";
                            break;
                        case CameraMetadata.LENS_FACING_EXTERNAL:
                            cameraName = "External camera";
                            break;
                        default:
                            cameraName = "";
                    }

                    videoDevices.put(camera, cameraName);
                }
            } catch (CameraAccessException e) {
            }
        }

        audioDevices.put(String.valueOf(MediaRecorder.AudioSource.DEFAULT), "Default");
    }

    public Map<String, String> getVideoDevices() {
        return videoDevices;
    }

    public Map<String, String> getAudioDevices() {
        return audioDevices;
    }

    public void recordMedia(String websocketUri, String filePath, int timeslice, String videoMimeType,
                            boolean recordAudio, boolean recordVideo, String videoDeviceId,
                            String audioDeviceId, int cbOnWebsocketErrorRoot, final int cbOnRecorderReadyRoot,
                            final int cbOnMediaStreamReadyRoot, final int cbOnRecorderErrorRoot) {
        if (FlowMediaRecorderSupport.isCamera2Supported) {
            CameraManager manager = (CameraManager) flowRunnerActivity.getSystemService(Context.CAMERA_SERVICE);
            if (ActivityCompat.checkSelfPermission(flowRunnerActivity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                final MediaRecorder mediaRecorder = new MediaRecorder();

                if (recordAudio) {
                    Integer audioSource = MediaRecorder.AudioSource.DEFAULT;
                    if (!audioDeviceId.isEmpty()) {
                        audioSource = Integer.parseInt(audioDeviceId);
                    }
                    mediaRecorder.setAudioSource(audioSource);
                }

                if (recordVideo) {
                    mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);
                }
                mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
                if (recordAudio) {
                    mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.DEFAULT);
                }
                if (recordVideo) {
                    mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);

                    if (videoDeviceId.isEmpty())
                        videoDeviceId = "0";

                    CamcorderProfile profile = CamcorderProfile.get(Integer.parseInt(videoDeviceId), CamcorderProfile.QUALITY_HIGH);

                    mediaRecorder.setVideoEncodingBitRate(profile.videoBitRate);
                    mediaRecorder.setVideoFrameRate(profile.videoFrameRate);
                }

                final FlowMediaRecorderObject flowRecorder = new FlowMediaRecorderObject(mediaRecorder, null, null, filePath, websocketUri);

                try {
                    File outputFile = File.createTempFile("record", null);
                    mediaRecorder.setOutputFile(outputFile.getAbsolutePath());
                    flowRecorder.tempFile = outputFile;
                } catch (IOException e) {
                    if (!filePath.isEmpty())
                        mediaRecorder.setOutputFile(filePath);
                    wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, e.getMessage());
                }

                mediaRecorder.setOutputFile(filePath);
                if (recordVideo) {
                    try {
                        CameraCharacteristics characteristics = manager.getCameraCharacteristics(videoDeviceId);

                        StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
                        Size[] resolutions = map.getOutputSizes(SurfaceTexture.class);
                        Size maxSize = resolutions[0];
                        for (Size s : resolutions) {
                            if (maxSize.getWidth() * maxSize.getHeight() <= s.getWidth() * s.getHeight()) {
                                maxSize = s;
                            }
                        }

                        int sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);

                        final FlowMediaStreamObject flowMediaStream = new FlowMediaStreamObject(null, maxSize.getWidth(), maxSize.getHeight(), sensorOrientation);

                        mediaRecorder.setVideoSize(flowMediaStream.width, flowMediaStream.height);

                        mediaRecorder.setOrientationHint(getOrientation(sensorOrientation, flowRunnerActivity.getWindowManager().getDefaultDisplay().getRotation()));

                        manager.openCamera(videoDeviceId, new CameraDevice.StateCallback() {
                            @Override
                            public void onOpened(CameraDevice camera) {
                                try {
                                    flowMediaStream.surfaceTexture = new SurfaceTexture(0);
                                    flowMediaStream.surfaceTexture.setDefaultBufferSize(flowMediaStream.width, flowMediaStream.height);
                                    Surface surface = new Surface(flowMediaStream.surfaceTexture);

                                    mediaRecorder.prepare();
                                    List<Surface> list = new ArrayList<>();

                                    final CaptureRequest.Builder captureRequest = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD);
                                    Surface recorderSurface = mediaRecorder.getSurface();

                                    list.add(recorderSurface);
                                    list.add(surface);
                                    captureRequest.addTarget(recorderSurface);
                                    captureRequest.addTarget(surface);

                                    camera.createCaptureSession(list, new CameraCaptureSession.StateCallback() {
                                        @Override
                                        public void onConfigured(CameraCaptureSession session) {
                                            captureRequest.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO);
                                            try {
                                                session.setRepeatingRequest(captureRequest.build(), null, null);
                                            } catch (CameraAccessException e) {
                                                e.printStackTrace();
                                            }

                                            flowRecorder.session = session;
                                            wrapper.cbOnRecorderReady(cbOnRecorderReadyRoot, flowRecorder);
                                            wrapper.cbOnMediaStreamReady(cbOnMediaStreamReadyRoot, flowMediaStream);
                                        }

                                        @Override
                                        public void onConfigureFailed(CameraCaptureSession session) {
                                        }
                                    }, null);
                                } catch (Exception e) {
                                    wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, e.getMessage());
                                }
                            }

                            @Override
                            public void onDisconnected(CameraDevice camera) {
                            }

                            @Override
                            public void onError(CameraDevice camera, int error) {
                                wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, "CameraDevice error " + error);
                            }
                        }, null);
                    } catch (CameraAccessException e) {
                        wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, e.getMessage());
                    }
                } else {
                    try {
                        mediaRecorder.prepare();
                    } catch (IOException e) {
                        wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, e.getMessage());
                    }
                    wrapper.cbOnRecorderReady(cbOnRecorderReadyRoot, flowRecorder);
                }
            }
        }
    }

}
