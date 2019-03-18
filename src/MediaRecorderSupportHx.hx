import js.html.URL;
import js.html.MediaRecorder;
import js.html.MediaStream;
import js.html.WebSocket;

class MediaRecorderSupportHx {

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
				makeMediaRecorderFromStream(websocketUri, filePath, mediaStream, timeslice, videoMimeType, OnWebSocketError, OnRecorderReady, OnRecorderError);
			}, function(error) {
				OnRecorderError(error.message);
			});
		}
	#end
	}

	public static function makeMediaRecorderFromStream(
		websocketUri : String,
		filePath : String,
		mediaStream : Dynamic,
		timeslice : Int,
		videoMimeType : String,
		OnWebSocketError : String -> Void,
		OnRecorderReady : Dynamic->Void,
		OnRecorderError : String -> Void
	) : Void {
	#if (js && !flow_nodejs)
		if (websocketUri != "") {
			var socket = new WebSocket(websocketUri);
			socket.addEventListener("error", function(error) {
				OnWebSocketError(error.message);
			});

			var mediaRecorder;
			if (untyped MediaRecorder.isTypeSupported(videoMimeType)) {
				mediaRecorder = new MediaRecorder(mediaStream, {
					mimeType : videoMimeType
				});	
			} else {
				mediaRecorder = new MediaRecorder(mediaStream);
			}
			mediaRecorder.onerror = function(event : Dynamic) {
				OnRecorderError(event.error.name);
			}
			mediaRecorder.onstop = function(){			
				socket.close();
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
		}
	#end
	}

}
