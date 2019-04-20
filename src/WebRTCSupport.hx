import js.Browser;
import js.Promise;

class WebRTCSupport {

	private static function loadJSFilePromise(url : String) : Promise<Dynamic> {
		return new Promise<Dynamic>(function(resolve, reject) {
			var script : Dynamic = Browser.document.createElement('script');
			script.addEventListener('load', resolve);
			script.addEventListener('error', reject);
			script.addEventListener('abort', reject);
			script.src = url;
			Browser.document.head.appendChild(script);
		});
	}

	public static function initWebRTC(
			onReady : Void->Void
		) : Void {
	#if (js && !flow_nodejs)
		var adapterPromise = loadJSFilePromise("js/webrtc/adapter.js");
		var socketioPromise = loadJSFilePromise("js/socket.io/socket.io.js");
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
				iceServers: [],
				iceTransportPolicy: 'relay'
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
			var peerConnections : Map<String, PeerConnection> = new Map<String, PeerConnection>();

			if (roomId != '') {
				socket.emit('join', roomId);
			}

			socket.on('message', function(m) {
				var clientId : String = m.clientId;
				var message : Dynamic = m.content;
				if (message.type == 'new_user') {
					peerConnections[clientId] = new PeerConnection(socket, pcConfig, clientId, localStream, onNewParticipant, onParticipantLeave);
					peerConnections[clientId].createOffer(onError);
				} else if (message.type == 'offer') {
					if (peerConnections[clientId] == null) {
						peerConnections[clientId] = new PeerConnection(socket, pcConfig, clientId, localStream, onNewParticipant, onParticipantLeave);
						peerConnections[clientId].setRemoteDescription(message);
						peerConnections[clientId].createAnswer(onError);
					}
				} else if (message.type == 'answer') {
					peerConnections[clientId].setRemoteDescription(message);
				} else if (message.type == 'candidate') {
					var candidate = {
						sdpMLineIndex: message.label,
						candidate: message.candidate
					};
					peerConnections[clientId].addIceCandidate(candidate);
				} else if (message.type == 'disconnect') {
					peerConnections[clientId].stop();
				}
			});

			socket.emit("message", {
				content : {
					type : "new_user"
				}
			});

			var mediaSender = {
				socket : socket,
				peerConnections : peerConnections
			};

			Browser.window.addEventListener("beforeunload", function() {
				stopMediaSender(mediaSender);
			});
			onMediaSenderReady(mediaSender);
		}
	#end
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
			var peerConnections : Map<String, PeerConnection> = mediaSender.peerConnections;
			for (peerConnection in peerConnections) {
				peerConnection.stop();
			}
			mediaSender = null;
		}
	#end
	}
}

class PeerConnection {
	private var clientId : String = "";
	private var connection : Dynamic = null;
	private var onNewParticipant: String->Dynamic->Void;
	private var onParticipantLeave: String->Void;
	private var socket : Dynamic;

	public function new(socket : Dynamic, pcConfig : Dynamic, clientId : String, localStream : Dynamic,
		onNewParticipant : String->Dynamic->Void,
		onParticipantLeave : String -> Void) {
		if (localStream) {
			this.socket = socket;
			this.clientId = clientId;
			this.onNewParticipant = onNewParticipant;
			this.onParticipantLeave = onParticipantLeave;

			this.connection = untyped __js__("new RTCPeerConnection(pcConfig)");
			this.connection.onicecandidate = handleIceCandidate;
			this.connection.onaddstream = handleRemoteStreamAdded;
			this.connection.addStream(localStream);
		}
	}

	private function sendMessageTo(to : String, content : Dynamic) {
		this.socket.emit("message", {
			to : to,
			content: content
		});
	}

	private function updateLocalDescription(sessionDescription : Dynamic) {
		this.connection.setLocalDescription(sessionDescription);
		sendMessageTo(this.clientId, sessionDescription);
	}

	public function createOffer(onError : String -> Void) {
		this.connection.createOffer().then(
			updateLocalDescription,
			function(error) {
				onError(error.message);
			}
		);
	}

	public function createAnswer(onError : String -> Void) {
		this.connection.createAnswer().then(
			updateLocalDescription,
			function(error) {
				onError(error.message);
			}
		);
	}

	public function setLocalDescription(description : Dynamic) {
		this.connection.setLocalDescription(untyped __js__("new RTCSessionDescription(description)"));
	}

	public function setRemoteDescription(description : Dynamic) {
		this.connection.setRemoteDescription(untyped __js__("new RTCSessionDescription(description)"));
	}

	public function addIceCandidate(candidate : Dynamic) {
		this.connection.addIceCandidate(untyped __js__("new RTCIceCandidate(candidate)"));
	}

	public function handleIceCandidate(event : Dynamic) {
		if (event.candidate) {
			sendMessageTo(this.clientId, {
				type: 'candidate',
				label: event.candidate.sdpMLineIndex,
				id: event.candidate.sdpMid,
				candidate: event.candidate.candidate,
			});
		}
	}

	public function handleRemoteStreamAdded(event : Dynamic) {
		this.onNewParticipant(this.clientId, event.stream);
	}

	public function stop() {
		this.onParticipantLeave(this.clientId);
		if (this.connection) {
			this.connection.close();
			this.connection = null;
		}
	}
}
