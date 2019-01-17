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
import android.media.CamcorderProfile;
import android.media.MediaRecorder;
import android.os.Build;
import android.support.annotation.NonNull;
import android.support.annotation.RequiresApi;
import android.support.v4.app.ActivityCompat;
import android.util.Size;
import android.util.SparseIntArray;
import android.view.Surface;

import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.URI;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class FlowMediaRecorderSupport {

    static boolean isCamera2Supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP;
    static boolean isPauseResumeSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N;
    private static final SparseIntArray ORIENTATIONS = new SparseIntArray();

    private Map<String, String> videoDevices = new HashMap<>();
    private Map<String, String> audioDevices = new HashMap<>();
    private FlowRunnerActivity flowRunnerActivity;
    private FlowRunnerWrapper wrapper;

    static {
        ORIENTATIONS.append(Surface.ROTATION_0, 90);
        ORIENTATIONS.append(Surface.ROTATION_90, 0);
        ORIENTATIONS.append(Surface.ROTATION_180, 270);
        ORIENTATIONS.append(Surface.ROTATION_270, 180);
    }

    FlowMediaRecorderSupport(FlowRunnerActivity ctx, FlowRunnerWrapper wrp) {
        flowRunnerActivity = ctx;
        wrapper = wrp;
    }

    static int getOrientation(boolean isFacingFront, int sensorOrientation, int rotation) {
        if (isFacingFront)
            return (sensorOrientation + rotation * 90) % 360;
        // Sensor orientation of CameraMetadata.LENS_FACING_BACK is 90 for most devices, or 270 for some devices (eg. Nexus 5X)
        // We have to take that into account and rotate JPEG properly.
        // For devices with orientation of 90, we simply return our mapping from ORIENTATIONS.
        // For devices with orientation of 270, we need to rotate the JPEG 180 degrees.
        return (ORIENTATIONS.get(rotation) + sensorOrientation + 270) % 360;
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    void initializeDeviceInfo() {
        videoDevices.clear();
        audioDevices.clear();
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
        } catch (Exception e) {
            e.printStackTrace();
        }

        audioDevices.put(String.valueOf(MediaRecorder.AudioSource.DEFAULT), "Default");
    }

    Map<String, String> getVideoDevices() {
        return videoDevices;
    }

    Map<String, String> getAudioDevices() {
        return audioDevices;
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    void recordMedia(String websocketUri, String filePath, int timeslice, String videoMimeType,
                     boolean recordAudio, boolean recordVideo, String videoDeviceId,
                     String audioDeviceId, int cbOnWebsocketErrorRoot, final int cbOnRecorderReadyRoot,
                     int cbOnMediaStreamReadyRoot, int cbOnRecorderErrorRoot) {

        MediaRecorder mediaRecorder = new MediaRecorder();
        FlowMediaRecorderObject flowRecorder = new FlowMediaRecorderObject(mediaRecorder, null, null, websocketUri, cbOnWebsocketErrorRoot);
        FlowMediaStreamObject flowMediaStream = new FlowMediaStreamObject();

        if (audioDeviceId.isEmpty())
            audioDeviceId = "0";
        if (videoDeviceId.isEmpty())
            videoDeviceId = "0";

        try {
            configureDataSource(mediaRecorder, recordAudio, recordVideo, audioDeviceId);
            configureOutput(flowRecorder, filePath);
            setVideoParams(flowRecorder, flowMediaStream, recordAudio, recordVideo, videoDeviceId);

            mediaRecorder.prepare();

            if (recordVideo) {
                captureCamera(flowRecorder, flowMediaStream, videoDeviceId, cbOnRecorderReadyRoot, cbOnRecorderErrorRoot, cbOnMediaStreamReadyRoot);
            } else {
                wrapper.cbOnRecorderReady(cbOnRecorderReadyRoot, flowRecorder);
            }
        } catch (Exception e) {
            wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, e.getMessage());
        }

    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private void configureDataSource(MediaRecorder mediaRecorder, boolean recordAudio, boolean recordVideo, String audioDeviceId) {
        if (recordAudio)
            mediaRecorder.setAudioSource(Integer.parseInt(audioDeviceId));
        if (recordVideo)
            mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);

        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
    }

    private void configureOutput(FlowMediaRecorderObject flowRecorder, String filePath) throws Exception {
        File output = null;
        if (!filePath.isEmpty()) {
            output = new File(filePath);
            flowRecorder.deleteOutputFile = false;
            File parentDir = output.getParentFile();

            if (!parentDir.exists() && !parentDir.mkdirs()) {
                throw new Exception("MediaRecorder: Wrong output file path.");
            }
        } else {
            output = File.createTempFile("record", null);
            flowRecorder.deleteOutputFile = true;
        }
        flowRecorder.outputFile = output;
        flowRecorder.mediaRecorder.setOutputFile(output.getPath());

    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private void setVideoParams(FlowMediaRecorderObject flowRecorder, FlowMediaStreamObject flowMediaStream, boolean recordAudio, boolean recordVideo, String videoDeviceId) throws Exception {
        if (recordAudio) {
            flowRecorder.mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.DEFAULT);
        }

        if (recordVideo) {
            flowRecorder.mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);

            CamcorderProfile profile = CamcorderProfile.get(Integer.parseInt(videoDeviceId), CamcorderProfile.QUALITY_HIGH);
            flowRecorder.mediaRecorder.setVideoEncodingBitRate(profile.videoBitRate);
            flowRecorder.mediaRecorder.setVideoFrameRate(profile.videoFrameRate);

            CameraManager manager = (CameraManager) flowRunnerActivity.getSystemService(Context.CAMERA_SERVICE);

            CameraCharacteristics characteristics = manager.getCameraCharacteristics(videoDeviceId);
            StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);

            Size[] resolutions = map.getOutputSizes(SurfaceTexture.class);
            Size maxSize = resolutions[0];
            for (Size s : resolutions) {
                if (maxSize.getWidth() * maxSize.getHeight() <= s.getWidth() * s.getHeight()) {
                    maxSize = s;
                }
            }
            flowMediaStream.width = maxSize.getWidth();
            flowMediaStream.height = maxSize.getHeight();
            flowRecorder.mediaRecorder.setVideoSize(flowMediaStream.width, flowMediaStream.height);

            flowMediaStream.isFacingFront = characteristics.get(CameraCharacteristics.LENS_FACING) == CameraMetadata.LENS_FACING_FRONT;
            flowMediaStream.sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
            int displayRotation = flowRunnerActivity.getWindowManager().getDefaultDisplay().getRotation();
            flowRecorder.mediaRecorder.setOrientationHint(getOrientation(flowMediaStream.isFacingFront, flowMediaStream.sensorOrientation, displayRotation));
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private void captureCamera(final FlowMediaRecorderObject flowRecorder, final FlowMediaStreamObject flowMediaStream, String videoDeviceId,
                               final int cbOnRecorderReadyRoot, final int cbOnRecorderErrorRoot, final int cbOnMediaStreamReadyRoot) throws Exception {
        if (ActivityCompat.checkSelfPermission(flowRunnerActivity, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, "MediaRecorder: 'Manifest.permission.CAMERA' is not granted");
            return;
        }
        CameraManager manager = (CameraManager) flowRunnerActivity.getSystemService(Context.CAMERA_SERVICE);
        manager.openCamera(videoDeviceId, new CameraDevice.StateCallback() {
            @Override
            public void onOpened(@NonNull CameraDevice camera) {
                flowMediaStream.surfaceTexture = new SurfaceTexture(0);
                flowMediaStream.surfaceTexture.detachFromGLContext();
                flowMediaStream.surfaceTexture.setDefaultBufferSize(flowMediaStream.width, flowMediaStream.height);

                Surface previewSurface = new Surface(flowMediaStream.surfaceTexture);
                Surface recorderSurface = flowRecorder.mediaRecorder.getSurface();

                List<Surface> surfaceList = new ArrayList<>();
                surfaceList.add(recorderSurface);
                surfaceList.add(previewSurface);

                startCaptureSession(flowRecorder, flowMediaStream, cbOnRecorderReadyRoot, cbOnRecorderErrorRoot, cbOnMediaStreamReadyRoot, camera, surfaceList);
            }

            @Override
            public void onClosed(@NonNull CameraDevice camera) {
                super.onClosed(camera);
            }

            @Override
            public void onDisconnected(@NonNull CameraDevice camera) {
                camera.close();
            }

            @Override
            public void onError(@NonNull CameraDevice camera, int error) {
                camera.close();
                wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, "CameraDevice error " + error);
            }
        }, null);
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private void startCaptureSession(final FlowMediaRecorderObject flowRecorder, final FlowMediaStreamObject flowMediaStream,
                                     final int cbOnRecorderReadyRoot, final int cbOnRecorderErrorRoot, final int cbOnMediaStreamReadyRoot,
                                     CameraDevice camera, List<Surface> surfaceList) {
        try {
            final CaptureRequest.Builder captureRequest = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD);
            for (Surface surface : surfaceList)
                captureRequest.addTarget(surface);

            camera.createCaptureSession(surfaceList, new CameraCaptureSession.StateCallback() {
                @Override
                public void onConfigured(@NonNull CameraCaptureSession session) {
                    captureRequest.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO);
                    try {
                        session.setRepeatingRequest(captureRequest.build(), null, null);
                    } catch (CameraAccessException e) {
                        wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, e.getMessage());
                    }

                    flowRecorder.session = session;
                    wrapper.cbOnRecorderReady(cbOnRecorderReadyRoot, flowRecorder);
                    wrapper.cbOnMediaStreamReady(cbOnMediaStreamReadyRoot, flowMediaStream);
                }

                @Override
                public void onConfigureFailed(@NonNull CameraCaptureSession session) {
                    wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, "MediaRecorder: CameraCaptureSession configuration failed");
                    session.getDevice().close();
                }

                @Override
                public void onClosed(@NonNull final CameraCaptureSession session) {
                    super.onClosed(session);
                    session.getDevice().close();
                }
            }, null);
        } catch (Exception e) {
            wrapper.cbOnRecorderError(cbOnRecorderErrorRoot, e.getMessage());
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    void startMediaRecorder(FlowMediaRecorderObject recorder) {
        recorder.mediaRecorder.start();
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    void resumeMediaRecorder(FlowMediaRecorderObject recorder) {
        recorder.mediaRecorder.resume();
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    void pauseMediaRecorder(FlowMediaRecorderObject recorder) {
        recorder.mediaRecorder.pause();
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    void stopMediaRecorder(final FlowMediaRecorderObject recorder) {
        if (recorder.session != null) {
            try {
                recorder.session.abortCaptures();
            } catch (CameraAccessException e) {
                e.printStackTrace();
            }
            recorder.session.close();
        }

        recorder.mediaRecorder.stop();
        recorder.mediaRecorder.reset();
        recorder.mediaRecorder.release();

        Runnable onEnd = () -> {};

        if (recorder.deleteOutputFile) {
            onEnd = () -> recorder.outputFile.delete();
        }

        if (!recorder.websocketUri.isEmpty()) {
            sendFileToWSServer(URI.create(recorder.websocketUri), recorder.outputFile, recorder.cbOnWebSocketError, onEnd);
        } else {
            onEnd.run();
        }
    }

    private void sendFileToWSServer(URI uri, final File file, final int cbOnWebSocketError, final Runnable onEnd) {
        WebSocketClient client = new FlowWebSocketClient(uri) {
            @Override
            public void onOpen(ServerHandshake serverHandshake) {
                InputStream inputStream = null;
                try {
                    inputStream = new FileInputStream(file);
                    byte[] buffer = new byte[1024 * 1024];
                    while (inputStream.read(buffer) > 0) {
                        send(buffer);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    try {
                        inputStream.close();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                close();
            }

            @Override
            public void onClose(int code, String reason, boolean remote) {
                onEnd.run();
            }

            @Override
            public void onError(Exception e) {
                wrapper.cbOnRecorderError(cbOnWebSocketError, e.getMessage());
                onEnd.run();
            }
        };
        client.connect();
    }

    class FlowMediaRecorderObject {
        CameraCaptureSession session;
        MediaRecorder mediaRecorder;
        File outputFile;
        boolean deleteOutputFile;
        String websocketUri;
        int cbOnWebSocketError;

        FlowMediaRecorderObject(MediaRecorder mediaRecorder, CameraCaptureSession session, File outputFile, String websocketUri, int cbOnWebSocketError) {
            this.mediaRecorder = mediaRecorder;
            this.session = session;
            this.outputFile = outputFile;
            this.websocketUri = websocketUri;
            this.cbOnWebSocketError = cbOnWebSocketError;
        }
    }

    class FlowMediaStreamObject {
        int width;
        int height;
        SurfaceTexture surfaceTexture;
        int sensorOrientation;
        boolean isFacingFront;

        FlowMediaStreamObject() {
        }
    }

}
