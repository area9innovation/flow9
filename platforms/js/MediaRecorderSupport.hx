import js.html.URL;
import js.html.MediaRecorder;
import js.html.MediaStream;
import js.html.WebSocket;
import js.html.Int16Array;
import js.html.Blob;

class MediaRecorderSupport {

	public static function loadPolyFill(cb : Void -> Void) {
		if (untyped __js__("typeof window['MediaRecorder'] === 'undefined'")) {
			Util.loadJS('js/audio/polyfill.js').then(function (d) {
				untyped window.MediaRecorder = untyped window.AudioRecorder;
				cb();
			});
		} else {
			cb();
		}
	}

	public static function startRecording(recorder : Dynamic, timeslice : Int) : Void {
	#if (js && !flow_nodejs)
	if (timeslice == -1)
		recorder.start();
	else
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
		if (recorder.state != "inactive")
			recorder.stop();
	#end
	}

	public static function makeMediaRecorderFromStream(
		websocketUri : String,
		filePath : String,
		dataCb : String -> Void,
		mediaStream : Dynamic,
		timeslice : Int,
		onReady : Dynamic->Void,
		onError : String -> Void
	) : Void {
	#if (js && !flow_nodejs)
		loadPolyFill(function () {
			var mediaRecorder = new MediaRecorder(mediaStream.mediaStream);
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

			var videoParts = [];

			mediaRecorder.addEventListener("stop", function() {
				if (filePath != "")
					FlowFileSystem.saveFileClient(filePath, videoParts, mediaRecorder.mimeType);

				untyped __js__("
					var blob = new Blob(videoParts, {type: mediaRecorder.mimeType});
					dataCb(URL.createObjectURL(blob));
				");
				videoParts = null;
			});

			mediaRecorder.addEventListener("dataavailable", function(event : Dynamic) {
				if (event.data.size != 0) {
					videoParts.push(event.data);
				}
			});

			onReady(mediaRecorder);
		});
	#end
	}

}
