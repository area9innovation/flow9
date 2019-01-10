import js.html.URL;
import js.html.MediaRecorder;
import js.html.MediaStream;
import js.html.WebSocket;

class MediaRecorderSupportHx {

	private static var audioDevices = {
		deviceIds : [],
		labels : []
	};
	private static var videoDevices =  {
		deviceIds : [],
		labels : []
	};

	private static function stopMediaStreamTracks(mediaStream : MediaStream) : Void {		
		for (track in mediaStream.getTracks()) {
			track.stop();
		}
	}

	public static function initDeviceInfo(
			OnDeviceInfoReady : Void->Void
		) : Void {
	#if (js && !flow_nodejs)
		untyped navigator.mediaDevices.getUserMedia({audio: true, video : true})
		.then(function(mediaStream) {
			untyped navigator.mediaDevices.enumerateDevices()
			.then(function(devices) {
				audioDevices.deviceIds = [];
				audioDevices.labels = [];

				videoDevices.deviceIds = [];
				videoDevices.labels = [];

				devices.forEach(function(device) {
					if (device.kind == 'audioinput') {
						audioDevices.deviceIds.push(device.deviceId);
						audioDevices.labels.push(device.label);
					} else if (device.kind == 'videoinput') {
						videoDevices.deviceIds.push(device.deviceId);
						videoDevices.labels.push(device.label);
					}
				});

				stopMediaStreamTracks(mediaStream);
				
				OnDeviceInfoReady();
			}, function() {});
		}, function() {});
	#end
	}

	public static function requestAudioInputDevices(
			OnDeviceInfoReady : Array<String>->Array<String>->Void
		) : Void {
		OnDeviceInfoReady(audioDevices.deviceIds, audioDevices.labels);		
	}

	public static function requestVideoInputDevices(
			OnDeviceInfoReady : Array<String>->Array<String>->Void
		) : Void {
		OnDeviceInfoReady(videoDevices.deviceIds, videoDevices.labels);
	}

	public static function startRecording(recorder : Dynamic, timeslice : Int) : Void {
	#if (js && !flow_nodejs)
		recorder.mediaRecorder.start(timeslice);
	#end
	}

	public static function resumeRecording(recorder : Dynamic) : Void {
	#if (js && !flow_nodejs)
		recorder.mediaRecorder.resume();
	#end
	}

	public static function pauseRecording(recorder : Dynamic) : Void {
	#if (js && !flow_nodejs)
		recorder.mediaRecorder.pause();
	#end
	}

	public static function stopRecording(recorder : Dynamic) : Void {
	#if (js && !flow_nodejs)
		recorder.mediaRecorder.onstop = function(){			
			recorder.socket.close();
			stopMediaStreamTracks(recorder.mediaRecorder.stream);
		}
		recorder.mediaRecorder.stop();
	#end
	}

	public static function makeMediaRecorder(
		websocketUri : String,
		filePath : String,
		timeslice : Int,
		videoMimeType : String,
		recordAudio : Bool,
		recordVideo : Bool,
		videoDeviceId : String,
		audioDeviceId : String,
		OnWebSocketError : String -> Void,
		OnRecorderReady : Dynamic->Void,
		OnMediaStreamReady : Dynamic->Void,
		OnRecorderError : String -> Void
	) : Void {
	#if (js && !flow_nodejs)
		if (websocketUri != "") {
			var socket = new WebSocket(websocketUri);
			socket.addEventListener("error", function(error) {
				OnWebSocketError(error.message);
			});
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
				var mediaRecorder;
				if (untyped MediaRecorder.isTypeSupported(videoMimeType)) {
					mediaRecorder = new MediaRecorder(mediaStream, {
						mimeType : videoMimeType
					});	
				} else {
					mediaRecorder = new MediaRecorder(mediaStream);
				}
				mediaRecorder.addEventListener("dataavailable", function(event : Dynamic) {
					if (event.data.size != 0) {
						socket.send(event.data);
					}
				});

				OnRecorderReady({
					mediaRecorder : mediaRecorder, 
					socket: socket
				});

			}, function(error) {
				OnRecorderError(error.message);
			});
		}
	#end
	}

}
