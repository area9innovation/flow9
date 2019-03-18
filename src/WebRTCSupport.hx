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
			OnReady : Void->Void
		) : Void {
	#if (js && !flow_nodejs)
		var adapterPromise = loadJSFilePromise("js/webrtc/adapter.js");
		var socketioPromise = loadJSFilePromise("js/socket.io/socket.io.js");
		Promise.all([adapterPromise, socketioPromise]).then(function(res){
			OnReady();
		}, function(e){});
	#end
	}

	public static function makeMediaSender(
		serverUrl : String,
		roomId : String,
		stunUrls : Array<String>,
		turnUrls : Array<String>,		
		turnUsernames : Array<String>,
		turnPasswords : Array<String>,
		recordAudio : Bool,
		recordVideo : Bool,
		audioDeviceId : String,
		videoDeviceId : String,
		OnMediaSenderReady : Dynamic->Void,
		OnNewParticipant : String->Dynamic->Void,
		OnParticipantLeave : String -> Void,
		OnMediaStreamReady : Dynamic->Void,
		OnError : String -> Void
	) : Void {
	#if (js && !flow_nodejs)
		var constraints = {
			audio : recordAudio,
			video : recordVideo
		};
		if (recordVideo && videoDeviceId != "") {
			constraints.video = untyped { deviceId : videoDeviceId };
		}
		if (recordAudio && audioDeviceId != "") {
			constraints.audio = untyped { deviceId : audioDeviceId };
		}
		untyped navigator.mediaDevices.getUserMedia(constraints)
		.then(function(mediaStream) {
			OnMediaStreamReady(mediaStream);
			makeMediaSenderFromStream(serverUrl, roomId, stunUrls, turnUrls, turnUsernames, turnPasswords, mediaStream, OnMediaSenderReady, OnNewParticipant, OnParticipantLeave, OnError);
		}, function(error) {
			OnError(error.message);
		});
	#end
	}


	public static function makeMediaSenderFromStream(
		serverUrl : String,
		roomId : String,
		stunUrls : Array<String>,
		turnUrls : Array<String>,		
		turnUsernames : Array<String>,
		turnPasswords : Array<String>,
		mediaStream : Dynamic,
		OnMediaSenderReady : Dynamic->Void,
		OnNewParticipant : String->Dynamic->Void,
		OnParticipantLeave : String -> Void,
		OnError : String -> Void
	) : Void {
	#if (js && !flow_nodejs)
		if (serverUrl != "") {
			var pcConfig : Dynamic = {
				iceServers: [],
				iceTransportPolicy: 'relay'
			};
			for(url in stunUrls) {
				pcConfig.iceServers.push({
					'urls':url
				});
			}
			for(i in 0...turnUrls.length) {
				pcConfig.iceServers.push({
					'urls': turnUrls[i],
					'username': turnUsernames[i],
					'credential': turnPasswords[i]
				});
			}

			var localStream = mediaStream;
			var socket : Dynamic = untyped io(serverUrl).connect();
			var peerConnections : Map<String, PeerConnection> = new Map<String, PeerConnection>();

			if (roomId != '') {
				socket.emit('create or join', roomId);
			}

			socket.on('message', function(m) {
				var clientId : String = m.clientId;
				var message : Dynamic = m.message;
				if (message == 'got user media') {
					peerConnections[clientId] = new PeerConnection(socket, pcConfig, clientId, localStream, OnNewParticipant, OnParticipantLeave);
					peerConnections[clientId].createOffer().then(
						function(sessionDescription) {
							peerConnections[clientId].setLocalDescription(sessionDescription);
							socket.emit("message", {
								to : clientId,
								content : sessionDescription
							});
						},
						function(e){}
					);
				} else if (message.type == 'offer') {
					if(peerConnections[clientId] == null) { 
						peerConnections[clientId] = new PeerConnection(socket, pcConfig, clientId, localStream, OnNewParticipant, OnParticipantLeave);
						peerConnections[clientId].setRemoteDescription(message);
						peerConnections[clientId].createAnswer().then(
							function(sessionDescription) {
								peerConnections[clientId].setLocalDescription(sessionDescription);
								socket.emit("message", {
									to : clientId,
									content : sessionDescription
								});
							},
							function(e){}
						);
					}
				} else if (message.type == 'answer') {
					peerConnections[clientId].setRemoteDescription(message);
				} else if (message.type == 'candidate') {
					var candidate = {
						sdpMLineIndex: message.label,
						candidate: message.candidate
					};
					peerConnections[clientId].addIceCandidate(candidate);
				} else if (message == 'bye') {
					peerConnections[clientId].stop();
				}
			});

			socket.emit("message", {
				content : "got user media"
			});

			var mediaSender = {
				socket : socket,
				peerConnections : peerConnections
			};

			Browser.window.addEventListener("beforeunload", function(){
				stopMediaSender(mediaSender);
			});
			OnMediaSenderReady(mediaSender);
		}
	#end
	}
	public static function stopMediaSender(mediaSender : Dynamic) : Void {
	#if (js && !flow_nodejs)
		if (mediaSender) {
			var socket : Dynamic = mediaSender.socket;
			socket.emit("message", {
				content: "bye"
			});
			socket.close();

			var peerConnections : Map<String, PeerConnection> = mediaSender.peerConnections;
			for(peerConnection in peerConnections) {
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
	private var OnNewParticipant: String->Dynamic->Void;
	private var OnParticipantLeave: String->Void;
	private var socket : Dynamic;
	
	public function new(socket : Dynamic, pcConfig : Dynamic, clientId : String, localStream : Dynamic,
		OnNewParticipant : String->Dynamic->Void,
		OnParticipantLeave : String -> Void) {
		if (localStream) {
			this.socket = socket;
			this.clientId = clientId;
			this.OnNewParticipant = OnNewParticipant;
			this.OnParticipantLeave = OnParticipantLeave;

			this.connection = untyped __js__("new RTCPeerConnection(pcConfig)");
			this.connection.onicecandidate = handleIceCandidate;
			this.connection.onaddstream = handleRemoteStreamAdded;
			this.connection.addStream(localStream);
		}
	}

	public function createOffer() : Promise<Dynamic> {
		return this.connection.createOffer();
	}

	public function createAnswer() : Promise<Dynamic> {
		return this.connection.createAnswer();
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
			socket.emit("message", {
				to: this.clientId, 
				content: {
					type: 'candidate',
					label: event.candidate.sdpMLineIndex,
					id: event.candidate.sdpMid,
					candidate: event.candidate.candidate,
				}
			});
		}
	}

	public function handleRemoteStreamAdded(event : Dynamic) {
		this.OnNewParticipant(this.clientId, event.stream);
	}

	public function stop() {
		this.OnParticipantLeave(this.clientId);
		connection.close();
		connection = null;
	}
}
