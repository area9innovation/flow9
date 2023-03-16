package dk.area9.flowrunner;

import android.media.MediaRecorder;
import android.os.Build;
import androidx.annotation.RequiresApi;

import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;
import org.webrtc.EglBase;
import org.webrtc.EglRenderer;
import org.webrtc.GlRectDrawer;
import org.webrtc.VideoFrame;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.URI;

class FlowMediaRecorderSupport {
    private FlowRunnerWrapper wrapper;

    FlowMediaRecorderSupport(FlowRunnerWrapper wrp) {
        wrapper = wrp;
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    void makeMediaRecorder(String websocketUri, String filePath, FlowMediaStreamSupport.FlowMediaStreamObject mediaStream,
                           int timeslice, int cbOnReadyRoot, int cbOnErrorRoot) {

        MediaRecorder mediaRecorder = new MediaRecorder();
        FlowMediaRecorderObject flowRecorder = new FlowMediaRecorderObject(mediaRecorder, mediaStream, null, websocketUri, cbOnErrorRoot);

        boolean recordAudio = !mediaStream.mediaStream.audioTracks.isEmpty() && mediaStream.isLocalStream;
        boolean recordVideo = !mediaStream.mediaStream.videoTracks.isEmpty();

        try {
            configureDataSource(mediaRecorder, recordAudio, recordVideo);
            configureOutput(flowRecorder, filePath);
            setVideoParams(flowRecorder, mediaStream, recordAudio, recordVideo);

            mediaRecorder.prepare();

            if (recordVideo) {
                captureCameraSurface(flowRecorder, mediaStream);
            }

            wrapper.cbOnRecorderReady(cbOnReadyRoot, flowRecorder);
        } catch (Exception e) {
            wrapper.cbOnRecorderError(cbOnErrorRoot, e.getMessage());
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private void configureDataSource(MediaRecorder mediaRecorder, boolean recordAudio, boolean recordVideo) {
        if (recordAudio)
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.DEFAULT);
        if (recordVideo)
            mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);

        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private void configureOutput(FlowMediaRecorderObject flowRecorder, String filePath) throws Exception {
        File output;
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
    private void setVideoParams(FlowMediaRecorderObject flowRecorder, FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStream, boolean recordAudio, boolean recordVideo) {
        if (recordAudio) {
            flowRecorder.mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.DEFAULT);
        }

        if (recordVideo) {
            flowRecorder.mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264);
            flowRecorder.mediaRecorder.setVideoEncodingBitRate(1000000);
            flowRecorder.mediaRecorder.setVideoFrameRate(flowMediaStream.fps);
            flowRecorder.mediaRecorder.setVideoSize(flowMediaStream.width, flowMediaStream.height);
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    private void captureCameraSurface(FlowMediaRecorderObject flowRecorder, FlowMediaStreamSupport.FlowMediaStreamObject mediaStreamObject) {
        EglRenderer eglRenderer = new EglRenderer("VideoTrackRecorder"){
            @Override
            public void onFrame(VideoFrame frame) {
                if (flowRecorder.initialRotation == -1) {
                   flowRecorder.initialRotation = frame.getRotation();
                }
                VideoFrame rotatedFrame = new VideoFrame(frame.getBuffer(), flowRecorder.initialRotation, frame.getTimestampNs());
                super.onFrame(rotatedFrame);
            }
        };
        eglRenderer.init(FlowMediaStreamSupport.getRootEglBase().getEglBaseContext(), EglBase.CONFIG_RGBA, new GlRectDrawer());

        eglRenderer.createEglSurface(flowRecorder.mediaRecorder.getSurface());
        if (mediaStreamObject.isCameraFrontFacing) {
            eglRenderer.setMirror(true);
        }

        if (!mediaStreamObject.mediaStream.videoTracks.isEmpty()) {
            mediaStreamObject.mediaStream.videoTracks.get(0).addSink(eglRenderer);
        }

        flowRecorder.eglRenderer = eglRenderer;
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
        if (recorder.eglRenderer != null) {
            if (recorder.mediaStreamObject.mediaStream != null && !recorder.mediaStreamObject.mediaStream.videoTracks.isEmpty()) {
                recorder.mediaStreamObject.mediaStream.videoTracks.get(0).removeSink(recorder.eglRenderer);
            }
            recorder.eglRenderer.release();
        }

        recorder.mediaRecorder.stop();
        recorder.mediaRecorder.reset();
        recorder.mediaRecorder.release();

        Runnable onEnd = () -> {};

        if (recorder.deleteOutputFile) {
            onEnd = () -> recorder.outputFile.delete();
        }

        if (!recorder.websocketUri.isEmpty()) {
            sendFileToWSServer(URI.create(recorder.websocketUri), recorder.outputFile, recorder.cbOnError, onEnd);
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
        MediaRecorder mediaRecorder;
        FlowMediaStreamSupport.FlowMediaStreamObject mediaStreamObject;
        File outputFile;
        boolean deleteOutputFile;
        String websocketUri;
        int cbOnError;

        int initialRotation = -1;
        EglRenderer eglRenderer;

        FlowMediaRecorderObject(MediaRecorder mediaRecorder, FlowMediaStreamSupport.FlowMediaStreamObject mediaStreamObject, File outputFile, String websocketUri, int cbOnError) {
            this.mediaRecorder = mediaRecorder;
            this.mediaStreamObject = mediaStreamObject;
            this.outputFile = outputFile;
            this.websocketUri = websocketUri;
            this.cbOnError = cbOnError;
        }
    }

}
