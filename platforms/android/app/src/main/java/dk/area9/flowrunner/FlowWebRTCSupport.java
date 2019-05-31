package dk.area9.flowrunner;

import org.json.JSONException;
import org.json.JSONObject;
import org.webrtc.DataChannel;
import org.webrtc.IceCandidate;
import org.webrtc.MediaConstraints;
import org.webrtc.MediaStream;
import org.webrtc.PeerConnection;
import org.webrtc.PeerConnectionFactory;
import org.webrtc.RtpReceiver;
import org.webrtc.SdpObserver;
import org.webrtc.SessionDescription;

import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.net.ssl.SSLContext;
import javax.net.ssl.X509TrustManager;

import io.socket.client.IO;
import io.socket.client.Socket;
import okhttp3.OkHttpClient;
import okhttp3.internal.platform.Platform;

class FlowWebRTCSupport {

    private FlowRunnerWrapper wrapper;

    FlowWebRTCSupport(FlowRunnerWrapper wrp) {
        wrapper = wrp;

        try {
            SSLContext sslContext = SSLContext.getDefault();
            X509TrustManager trustManager = Platform.get().trustManager(sslContext.getSocketFactory());
            OkHttpClient okHttpClient = new OkHttpClient.Builder()
                    .sslSocketFactory(sslContext.getSocketFactory(), trustManager)
                    .build();

            IO.setDefaultOkHttpWebSocketFactory(okHttpClient);
            IO.setDefaultOkHttpCallFactory(okHttpClient);
        } catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
        }
    }

    void makeMediaSender(String serverUrl, String roomId, String[] stunUrls, String[][] turnServers,
                         FlowMediaStreamSupport.FlowMediaStreamObject stream,
                         int onMediaSenderReadyRoot, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot) {
        try {
            FlowMediaSenderObject mediaSenderObject = new FlowMediaSenderObject();

            PeerConnection.RTCConfiguration configuration = createRTCConfiguration(stunUrls, turnServers);

            Socket serverSocket = IO.socket(serverUrl);

            PeerConnectionManager peerConnectionManager = new PeerConnectionManager(stream.peerConnectionFactory, configuration, stream.mediaStream, serverSocket, onNewParticipantRoot, onParticipantLeaveRoot, onErrorRoot);

            serverSocket.on("message", args -> {
                JSONObject data = (JSONObject) args[0];
                try {
                    String clientId = data.getString("clientId");
                    JSONObject message = data.getJSONObject("content");
                    String type = message.getString("type");
                    switch (type) {
                        case "new_user":
                            peerConnectionManager.createPeerConnection(clientId);
                            peerConnectionManager.createOffer(clientId);
                            break;
                        case "offer":
                            peerConnectionManager.createPeerConnection(clientId);
                            peerConnectionManager.setRemoteDescription(clientId, new SessionDescription(SessionDescription.Type.OFFER, message.getString("sdp")));
                            peerConnectionManager.createAnswer(clientId);
                            break;
                        case "answer":
                            peerConnectionManager
                                    .setRemoteDescription(clientId, new SessionDescription(SessionDescription.Type.ANSWER, message.getString("sdp")));
                            break;
                        case "candidate":
                            peerConnectionManager
                                    .addIceCandidate(clientId, new IceCandidate(message.getString("id"), message.getInt("label"), message.getString("candidate")));
                            break;
                        case "disconnect":
                            wrapper.cbOnMediaSenderParticipantLeave(onParticipantLeaveRoot, clientId);
                            peerConnectionManager.close(clientId);
                            break;
                    }
                } catch (JSONException e) {
                    wrapper.cbOnMediaSenderError(onErrorRoot, e.getLocalizedMessage());
                }
            });

            serverSocket.connect();

            serverSocket.emit("join", roomId);
            serverSocket.emit("message", new JSONObject()
                    .put("content", new JSONObject()
                            .put("type", "new_user")
                    )
            );

            mediaSenderObject.peerConnectionManager = peerConnectionManager;
            mediaSenderObject.serverSocket = serverSocket;
            wrapper.cbOnMediaSenderReady(onMediaSenderReadyRoot, mediaSenderObject);

        } catch (Exception e) {
            wrapper.cbOnMediaSenderError(onErrorRoot, e.getLocalizedMessage());
        }
    }

    void stopMediaSender(FlowMediaSenderObject mediaSender) {
        try {
            mediaSender.serverSocket.emit("message", new JSONObject()
                    .put("content", new JSONObject()
                            .put("type", "disconnect")
                    )
            );
        } catch (JSONException e) {
            e.printStackTrace();
        }
        mediaSender.peerConnectionManager.close();
        mediaSender.serverSocket.close();
    }

    private PeerConnection.RTCConfiguration createRTCConfiguration(String[] stunUrls, String[][] turnServers) {
        List<PeerConnection.IceServer> iceServers = new ArrayList<>();
        for (String stunServer : stunUrls) {
            iceServers.add(PeerConnection.IceServer.builder(stunServer).createIceServer());
        }
        for (String[] turnServer : turnServers) {
            iceServers.add(PeerConnection.IceServer.builder(turnServer[0])
                    .setUsername(turnServer[1])
                    .setPassword(turnServer[2])
                    .createIceServer());
        }

        return new PeerConnection.RTCConfiguration(iceServers);
    }


    class PeerConnectionManager {
        PeerConnectionFactory peerConnectionFactory;
        PeerConnection.RTCConfiguration peerConnectionConfiguration;
        MediaConstraints sdpConstraints;
        MediaStream localStream;

        Socket serverSocket;

        int onNewParticipantRoot;
        int onParticipantLeaveRoot;
        int onErrorRoot;

        Map<String, PeerConnectionWrapper> peerConnections = new HashMap<>();

        class PeerConnectionWrapper {
            PeerConnection peerConnection;
            SdpObserver updateLocalDescriptionObserver;
        }

        PeerConnectionManager(PeerConnectionFactory peerConnectionFactory, PeerConnection.RTCConfiguration configuration, MediaStream localStream, Socket serverSocket, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot) {
            this.peerConnectionFactory = peerConnectionFactory;
            this.peerConnectionConfiguration = configuration;

            this.sdpConstraints = new MediaConstraints();
            this.sdpConstraints.mandatory.add(new MediaConstraints.KeyValuePair("OfferToReceiveAudio", Boolean.toString(!localStream.audioTracks.isEmpty())));
            this.sdpConstraints.mandatory.add(new MediaConstraints.KeyValuePair("OfferToReceiveVideo", Boolean.toString(!localStream.videoTracks.isEmpty())));

            this.localStream = localStream;

            this.serverSocket = serverSocket;

            this.onNewParticipantRoot = onNewParticipantRoot;
            this.onParticipantLeaveRoot = onParticipantLeaveRoot;
            this.onErrorRoot = onErrorRoot;
        }

        void createPeerConnection(final String clientId) {
            PeerConnectionWrapper connectionWrapper = new PeerConnectionWrapper();
            connectionWrapper.peerConnection = peerConnectionFactory.createPeerConnection(peerConnectionConfiguration, new CustomPeerConnectionObserver() {
                @Override
                public void onIceCandidate(IceCandidate iceCandidate) {
                    sendMessage(clientId, iceCandidate2JSON(iceCandidate));
                }

                @Override
                public void onAddStream(MediaStream mediaStream) {
                    FlowMediaStreamSupport.FlowMediaStreamObject flowMediaStreamObject = new FlowMediaStreamSupport.FlowMediaStreamObject();
                    flowMediaStreamObject.mediaStream = mediaStream;

                    wrapper.cbOnMediaSenderNewParticipant(onNewParticipantRoot, clientId, flowMediaStreamObject);
                }

                @Override
                public void onRemoveStream(MediaStream mediaStream) {
                    wrapper.cbOnMediaSenderParticipantLeave(onParticipantLeaveRoot, clientId);
                }
            });
            connectionWrapper.peerConnection.addStream(localStream);
            connectionWrapper.updateLocalDescriptionObserver = new CustomSdpObserver() {
                @Override
                public void onCreateSuccess(SessionDescription sessionDescription) {
                    connectionWrapper.peerConnection.setLocalDescription(new CustomSdpObserver(), sessionDescription);
                    sendMessage(clientId, sessionDescription2JSON(sessionDescription));
                }
            };
            peerConnections.put(clientId, connectionWrapper);
        }

        void setRemoteDescription(String clientId, SessionDescription sessionDescription) {
            peerConnections.get(clientId).peerConnection.setRemoteDescription(new CustomSdpObserver(), sessionDescription);
        }

        void createOffer(String clientId) {
            PeerConnectionWrapper connectionWrapper = peerConnections.get(clientId);
            connectionWrapper.peerConnection.createOffer(connectionWrapper.updateLocalDescriptionObserver, sdpConstraints);
        }

        void createAnswer(String clientId) {
            PeerConnectionWrapper connectionWrapper = peerConnections.get(clientId);
            connectionWrapper.peerConnection.createAnswer(connectionWrapper.updateLocalDescriptionObserver, sdpConstraints);
        }

        void addIceCandidate(String clientId, IceCandidate iceCandidate) {
            peerConnections.get(clientId).peerConnection.addIceCandidate(iceCandidate);
        }

        public void close(String clientId) {
            wrapper.cbOnMediaSenderParticipantLeave(onParticipantLeaveRoot, clientId);
            peerConnections.get(clientId).peerConnection.close();
        }

        public void close() {
            for (Map.Entry<String, PeerConnectionWrapper> entry : peerConnections.entrySet()) {
                close(entry.getKey());
            }
        }

        private void sendMessage(String clientId, JSONObject content) {
            try {
                serverSocket.emit("message", new JSONObject()
                        .put("to", clientId)
                        .put("content", content));
            } catch (JSONException e) {
                wrapper.cbOnMediaSenderError(onErrorRoot, e.getLocalizedMessage());
            }
        }

        private JSONObject sessionDescription2JSON(SessionDescription sessionDescription) {
            JSONObject obj = new JSONObject();
            try {
                obj.put("type", sessionDescription.type.canonicalForm());
                obj.put("sdp", sessionDescription.description);
            } catch (JSONException e) {
                wrapper.cbOnMediaSenderError(onErrorRoot, e.getLocalizedMessage());
            }
            return obj;
        }

        private JSONObject iceCandidate2JSON(IceCandidate iceCandidate) {
            JSONObject object = new JSONObject();
            try {
                object.put("type", "candidate");
                object.put("label", iceCandidate.sdpMLineIndex);
                object.put("id", iceCandidate.sdpMid);
                object.put("candidate", iceCandidate.sdp);
            } catch (Exception e) {
                wrapper.cbOnMediaSenderError(onErrorRoot, e.getLocalizedMessage());
            }
            return object;
        }
    }

    class FlowMediaSenderObject {
        PeerConnectionManager peerConnectionManager;
        Socket serverSocket;

        FlowMediaSenderObject() {
        }
    }

    class CustomPeerConnectionObserver implements PeerConnection.Observer {
        @Override
        public void onSignalingChange(PeerConnection.SignalingState signalingState) {
        }

        @Override
        public void onIceConnectionChange(PeerConnection.IceConnectionState iceConnectionState) {
        }

        @Override
        public void onIceConnectionReceivingChange(boolean b) {
        }

        @Override
        public void onIceGatheringChange(PeerConnection.IceGatheringState iceGatheringState) {
        }

        @Override
        public void onIceCandidate(IceCandidate iceCandidate) {
        }

        @Override
        public void onIceCandidatesRemoved(IceCandidate[] iceCandidates) {
        }

        @Override
        public void onAddStream(MediaStream mediaStream) {
        }

        @Override
        public void onRemoveStream(MediaStream mediaStream) {
        }

        @Override
        public void onDataChannel(DataChannel dataChannel) {
        }

        @Override
        public void onRenegotiationNeeded() {
        }

        @Override
        public void onAddTrack(RtpReceiver rtpReceiver, MediaStream[] mediaStreams) {
        }
    }

    class CustomSdpObserver implements SdpObserver {
        @Override
        public void onCreateSuccess(SessionDescription sessionDescription) {
        }

        @Override
        public void onSetSuccess() {
        }

        @Override
        public void onCreateFailure(String s) {
        }

        @Override
        public void onSetFailure(String s) {
        }
    }

}
