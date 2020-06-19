import js.html.URL;
import js.html.MediaRecorder;
import js.html.MediaStream;
import js.html.WebSocket;

class MediaRecorderSupport {

	public static function startRecording(recorder : Dynamic, timeslice : Int) : Void {
	#if (js && !flow_nodejs)
		recorder.start(timeslice);
	#end
	}

	public static function resumeRecording(recorder : Dynamic) : Void {
	#if (js && !flow_nodejs)
		recorder.resume();
	#end
	}

	public static function pauseRecording(recorder : Dynamic) : Void {
	#if (js && !flow_nodejs)
		recorder.pause();
	#end
	}

	public static function stopRecording(recorder : Dynamic) : Void {
	#if (js && !flow_nodejs)
		recorder.stop();
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
		var mediaRecorder = new MediaRecorder(mediaStream);
		mediaRecorder.onerror = function(event : Dynamic) {
			onError(event.error.name);
		}
		if (websocketUri != "") {
			var socket = new WebSocket(websocketUri);
			socket.addEventListener("error", function(error) {
				onError(error.message);
			});

			mediaRecorder.addEventListener("stop", function(){
				socket.close();
			});
			mediaRecorder.addEventListener("dataavailable", function(event : Dynamic) {
				if (event.data.size != 0) {
					socket.send(event.data);
				}
			});
		}
		if (filePath != "") {
			var videoParts = [];

			mediaRecorder.addEventListener("stop", function(){
				FlowFileSystem.saveFileClient(filePath, videoParts, "video/webm");
				videoParts = null;
			});

			mediaRecorder.addEventListener("dataavailable", function(event : Dynamic) {
				if (event.data.size != 0) {
					videoParts.push(event.data);
				}
			});

		}
		onReady(mediaRecorder);
	#end
	}

}
