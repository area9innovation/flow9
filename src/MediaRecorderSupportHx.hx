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

	public static function makeMediaRecorderFromStream(
		websocketUri : String,
		filePath : String,
		mediaStream : Dynamic,
		timeslice : Int,
		onReady : Dynamic->Void,
		onError : String -> Void
	) : Void {
	#if (js && !flow_nodejs)
		if (websocketUri != "") {
			var socket = new WebSocket(websocketUri);
			socket.addEventListener("error", function(error) {
				onError(error.message);
			});

			var mediaRecorder = new MediaRecorder(mediaStream);
			mediaRecorder.onerror = function(event : Dynamic) {
				onError(event.error.name);
			}
			mediaRecorder.onstop = function(){
				socket.close();
			}
			mediaRecorder.addEventListener("dataavailable", function(event : Dynamic) {
				if (event.data.size != 0) {
					socket.send(event.data);
				}
			});

			onReady({
				mediaRecorder : mediaRecorder,
				socket: socket
			});
		}
	#end
	}

}
