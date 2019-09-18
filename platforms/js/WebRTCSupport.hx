import js.Browser;
import js.Promise;

class WebRTCSupport {

	public static function initWebRTC(
			onReady : Void->Void
		) : Void {
	#if (js && !flow_nodejs)
		var adapterPromise = Util.loadJS("js/webrtc/adapter.js");
		var socketioPromise = Util.loadJS("js/socket.io/socket.io.js");
		Promise.all([adapterPromise, socketioPromise]).then(function(res) {
			onReady();
		}, function(e) {});
	#end
	}

	public static function makeMediaSenderFromStream(
		serverUrl : String,
		roomId : String,
		stunUrls : Array<String>,
		turnServers : Array<Array<String>>,
		mediaStream : Dynamic,
		onMediaSenderReady : Dynamic->Void,
		onNewParticipant : String->Dynamic->Void,
		onParticipantLeave : String -> Void,
		onError : String -> Void
	) : Void {
	#if (js && !flow_nodejs)
		if (serverUrl != "") {
			var pcConfig : Dynamic = {
				iceServers: []
			};
			for (url in stunUrls) {
				pcConfig.iceServers.push({
					'urls':url
				});
			}
			for (server in turnServers) {
				pcConfig.iceServers.push({
					'urls': server[0],
					'username': server[1],
					'credential': server[2]
				});
			}

			var localStream = mediaStream;
			var socket : Dynamic = untyped io(serverUrl).connect();
			var peerConnectionManager : PeerConnectionManager = new PeerConnectionManager(pcConfig, localStream, sendMessageTo.bind(socket), onNewParticipant, onParticipantLeave, onError);

			if (roomId != '') {
				socket.emit('join', roomId);
			}

			socket.on('message', function(m) {
				var clientId : String = m.clientId;
				var message : Dynamic = m.content;
				if (message.type == 'new_user') {
					peerConnectionManager.createPeerConnection(clientId);
					peerConnectionManager.createOffer(clientId);
				} else if (message.type == 'offer') {
					peerConnectionManager.createPeerConnection(clientId);
					peerConnectionManager.setRemoteDescription(clientId, message);
					peerConnectionManager.createAnswer(clientId);
				} else if (message.type == 'answer') {
					peerConnectionManager.setRemoteDescription(clientId, message);
				} else if (message.type == 'candidate') {
					var candidate = {
						sdpMLineIndex: message.label,
						candidate: message.candidate
					};
					peerConnectionManager.addIceCandidate(clientId, candidate);
				} else if (message.type == 'disconnect') {
					peerConnectionManager.stop(clientId);
				}
			});

			socket.emit("message", {
				content : {
					type : "new_user"
				}
			});

			var mediaSender = {
				socket : socket,
				peerConnectionManager : peerConnectionManager
			};

			Browser.window.addEventListener("beforeunload", function() {
				stopMediaSender(mediaSender);
			});
			onMediaSenderReady(mediaSender);
		}
	#end
	}

	private static function sendMessageTo(socket : Dynamic, to : String, content : Dynamic) : Void {
		socket.emit("message", {
			to : to,
			content: content
		});
	}

	public static function stopMediaSender(mediaSender : Dynamic) : Void {
	#if (js && !flow_nodejs)
		if (mediaSender) {
			if (mediaSender.socket) {
				mediaSender.socket.emit("message", {
					content: {
						type : "disconnect"
					}
				});
				mediaSender.socket.close();
				mediaSender.socket = null;
			}
			mediaSender.peerConnectionManager.close();
			mediaSender = null;
		}
	#end
	}
}

class PeerConnectionManager {
	private var peerConnections : Map<String, Dynamic>;

	private var pcConfig : Dynamic;
	private var localStream : Dynamic;
	private var onNewParticipant: String->Dynamic->Void;
	private var onParticipantLeave: String->Void;
	private var onError: String->Void;
	private var sendHandshakeMessage : String->Dynamic->Void;

	public function new(pcConfig : Dynamic, localStream : Dynamic,
		sendHandshakeMessage : String->Dynamic->Void,
		onNewParticipant : String->Dynamic->Void,
		onParticipantLeave : String -> Void,
		onError: String->Void) {
		if (localStream) {
			this.peerConnections = new Map<String, Dynamic>();
			this.pcConfig = pcConfig;
			this.localStream = localStream;
			this.sendHandshakeMessage = sendHandshakeMessage;
			this.onNewParticipant = onNewParticipant;
			this.onParticipantLeave = onParticipantLeave;
			this.onError = onError;
		}
	}

	public function createPeerConnection(clientId : String) {
		var connection : Dynamic = untyped __js__("new RTCPeerConnection(this.pcConfig)");
		connection.onicecandidate = handleIceCandidate.bind(clientId);
		connection.onaddstream = handleRemoteStreamAdded.bind(clientId);
		connection.addStream(this.localStream);

		peerConnections[clientId] = connection;
	}

	private function updateLocalDescription(clientId : String, sessionDescription : Dynamic) {
		setLocalDescription(clientId, sessionDescription);
		this.sendHandshakeMessage(clientId, sessionDescription);
	}

	public function createOffer(clientId : String) {
		peerConnections[clientId].createOffer().then(
			updateLocalDescription.bind(clientId),
			function(error) {
				this.onError(error.message);
			}
		);
	}

	public function createAnswer(clientId : String) {
		peerConnections[clientId].createAnswer().then(
			updateLocalDescription.bind(clientId),
			function(error) {
				this.onError(error.message);
			}
		);
	}

	public function setLocalDescription(clientId : String, description : Dynamic) {
		peerConnections[clientId].setLocalDescription(untyped __js__("new RTCSessionDescription(description)"));
	}

	public function setRemoteDescription(clientId : String, description : Dynamic) {
		peerConnections[clientId].setRemoteDescription(untyped __js__("new RTCSessionDescription(description)"));
	}

	public function addIceCandidate(clientId : String, candidate : Dynamic) {
		peerConnections[clientId].addIceCandidate(untyped __js__("new RTCIceCandidate(candidate)"));
	}

	public function handleIceCandidate(clientId : String, event : Dynamic) {
		if (event.candidate) {
			this.sendHandshakeMessage(clientId, {
				type: 'candidate',
				label: event.candidate.sdpMLineIndex,
				id: event.candidate.sdpMid,
				candidate: event.candidate.candidate,
			});
		}
	}

	public function handleRemoteStreamAdded(clientId : String, event : Dynamic) {
		this.onNewParticipant(clientId, event.stream);
	}

	public function stop(clientId : String) {
		this.onParticipantLeave(clientId);
		if (peerConnections[clientId]) {
			peerConnections[clientId].close();
			peerConnections[clientId] = null;
		}
	}

	public function close() {
		for(clientId in this.peerConnections.keys()) {
			stop(clientId);
		}
	}
}
