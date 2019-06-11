package dk.area9.flowrunner;

import android.Manifest;

import org.webrtc.AudioSource;
import org.webrtc.AudioTrack;
import org.webrtc.Camera1Enumerator;
import org.webrtc.Camera2Enumerator;
import org.webrtc.CameraEnumerator;
import org.webrtc.DefaultVideoDecoderFactory;
import org.webrtc.DefaultVideoEncoderFactory;
import org.webrtc.EglBase;
import org.webrtc.MediaConstraints;
import org.webrtc.MediaStream;
import org.webrtc.PeerConnectionFactory;
import org.webrtc.SurfaceTextureHelper;
import org.webrtc.VideoCapturer;
import org.webrtc.VideoSource;
import org.webrtc.VideoTrack;

import java.util.HashMap;
import java.util.Map;

class FlowMediaStreamSupport {
    private static EglBase rootEglBase = EglBase.create();

    private CameraEnumerator cameraEnumerator;

    private Map<String, String> videoDevices = new HashMap<>();
    private Map<String, String> audioDevices = new HashMap<>();
    private FlowRunnerActivity flowRunnerActivity;
    private FlowRunnerWrapper wrapper;

    FlowMediaStreamSupport(FlowRunnerActivity ctx, FlowRunnerWrapper wrp) {
        flowRunnerActivity = ctx;
        wrapper = wrp;

        PeerConnectionFactory.initialize(
                PeerConnectionFactory.InitializationOptions.builder(ctx)
                        .createInitializationOptions()
        );
        if (Utils.isCamera2Supported) {
            cameraEnumerator = new Camera2Enumerator(ctx);
        } else {
            cameraEnumerator = new Camera1Enumerator(false);
        }
    }

    void initializeDeviceInfo() {
        videoDevices.clear();
        audioDevices.clear();
        String[] cameras = cameraEnumerator.getDeviceNames();
        for (String camera : cameras) {
            if (cameraEnumerator.isFrontFacing(camera)) {
                videoDevices.put(camera, "Front camera");
            } else {
                videoDevices.put(camera, "Back camera");
            }
        }

        audioDevices.put("", "Default");
    }

    Map<String, String> getVideoDevices() {
        return videoDevices;
    }

    Map<String, String> getAudioDevices() {
        return audioDevices;
    }

    void makeMediaStream(boolean recordAudio, boolean recordVideo, String videoDeviceId, String audioDeviceId,
                         int cbOnReadyRoot, int cbOnErrorRoot) {
        if (Utils.isRequestPermissionsSupported) {
            Utils.checkAndRequestPermissions(flowRunnerActivity, new String[]{
                    Manifest.permission.CAMERA,
                    Manifest.permission.RECORD_AUDIO
            }, -1);
        }
        final FlowMediaStreamObject mediaStreamObject = new FlowMediaStreamObject();
        mediaStreamObject.isLocalStream = true;

        PeerConnectionFactory.Options options = new PeerConnectionFactory.Options();
        DefaultVideoEncoderFactory defaultVideoEncoderFactory = new DefaultVideoEncoderFactory(
                rootEglBase.getEglBaseContext(), true, true);
        DefaultVideoDecoderFactory defaultVideoDecoderFactory = new DefaultVideoDecoderFactory(rootEglBase.getEglBaseContext());

        PeerConnectionFactory peerConnectionFactory = PeerConnectionFactory.builder()
                .setVideoEncoderFactory(defaultVideoEncoderFactory)
                .setVideoDecoderFactory(defaultVideoDecoderFactory)
                .setOptions(options)
                .createPeerConnectionFactory();

        MediaStream mediaStream = peerConnectionFactory.createLocalMediaStream("LocalStream");

        if (recordAudio) {
            AudioSource audioSource = peerConnectionFactory.createAudioSource(new MediaConstraints());
            AudioTrack audioTrack = peerConnectionFactory.createAudioTrack("Audio1", audioSource);
            mediaStream.addTrack(audioTrack);
            audioTrack.setEnabled(true);
        }

        if (recordVideo) {
            if (videoDeviceId.isEmpty()) {
                videoDeviceId = cameraEnumerator.getDeviceNames()[0];
            }
            VideoCapturer videoCapturer = cameraEnumerator.createCapturer(videoDeviceId, null);
            VideoSource videoSource = peerConnectionFactory.createVideoSource(false);
            VideoTrack videoTrack = peerConnectionFactory.createVideoTrack("Video1", videoSource);
            mediaStream.addTrack(videoTrack);
            videoTrack.setEnabled(true);

            SurfaceTextureHelper videoSourceTextureHelper = SurfaceTextureHelper.create("VideoSourceTextureHelper", rootEglBase.getEglBaseContext());
            videoCapturer.initialize(videoSourceTextureHelper, flowRunnerActivity, videoSource.getCapturerObserver());
            videoCapturer.startCapture(mediaStreamObject.width, mediaStreamObject.height, mediaStreamObject.fps);

            mediaStreamObject.videoCapturer = videoCapturer;
        }

        mediaStreamObject.peerConnectionFactory = peerConnectionFactory;
        mediaStreamObject.mediaStream = mediaStream;

        wrapper.cbOnMediaStreamReady(cbOnReadyRoot, mediaStreamObject);
    }

    void stopMediaStream(FlowMediaStreamObject flowMediaStream) {
        if (flowMediaStream.mediaStream != null) {
            for (AudioTrack track : flowMediaStream.mediaStream.audioTracks) {
                flowMediaStream.mediaStream.removeTrack(track);
                track.dispose();
            }

            for (VideoTrack track : flowMediaStream.mediaStream.videoTracks) {
                flowMediaStream.mediaStream.removeTrack(track);
                track.dispose();
            }
        }

        if (flowMediaStream.videoCapturer != null) {
            flowMediaStream.videoCapturer.dispose();
        }
    }

    static EglBase getRootEglBase(){
        return rootEglBase;
    }

    static class FlowMediaStreamObject {
        PeerConnectionFactory peerConnectionFactory;
        MediaStream mediaStream;
        boolean isCameraFrontFacing;
        VideoCapturer videoCapturer;
        boolean isLocalStream;

        int width = 800;
        int height = 600;
        int fps = 20;

        FlowMediaStreamObject() {
        }
    }

}
