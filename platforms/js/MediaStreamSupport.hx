import js.Browser;
import js.html.URL;
import js.html.MediaRecorder;
import js.html.WebSocket;

class MediaStreamSupport {

	private static var audioDevices : Array<Array<String>> = [];
	private static var videoDevices : Array<Array<String>> = [];

	public static function loadQrLibrary(onLoad : Void -> Void) : Void {
		if (untyped __js__("typeof jsQr === 'undefined'")) {
			var head = Browser.document.getElementsByTagName('head')[0];

			var node = Browser.document.createElement('script');
			node.setAttribute("type","text/javascript");
			node.setAttribute("src", 'js/jsQr.js');
			node.onload = onLoad;
			head.appendChild(node);
		} else {
			onLoad();
		}
	}

	public static function stopMediaStream(mediaStream : FlowMediaStream) : Void {
		for (track in mediaStream.mediaStream.getTracks()) {
			track.stop();
		}
	}

	public static function scanMediaStream(mediaStream : FlowMediaStream, types : Array<String>, onResult : String -> Void) : Void {
		loadQrLibrary(function() {
			mediaStream.on("attached", function () {
				var canvas : Dynamic = Browser.document.createElement('canvas');
				var ctx = canvas.getContext('2d');
				
				var scanVideoFrame = function () {
					var video = mediaStream.videoClip.videoWidget;
					
					if (video.readyState != video.HAVE_ENOUGH_DATA) {
						return;
					}

					canvas.width = video.videoWidth;
					canvas.height = video.videoHeight;

					ctx.drawImage(video, 0, 0);

					var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

					var code = untyped __js__("jsQR(imageData.data, imageData.width, imageData.height, {
						inversionAttempts: 'dontInvert',
					});");

					if (code != null && code.binaryData.length > 0) {
						onResult(code.data);
					}
				}

				RenderSupport.on("drawframe", scanVideoFrame);
				
				mediaStream.videoClip.on("removed", function () {
					RenderSupport.off("drawframe", scanVideoFrame);
				});
			});

			if (mediaStream.videoClip != null) {
				mediaStream.emit("attached");
			}
		});
	}

	public static function initDeviceInfo(
		onDeviceInfoReady : Void->Void
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
						audioDevices.push([device.deviceId, device.label]);
					} else if (device.kind == 'videoinput') {
						videoDevices.push([device.deviceId, device.label]);
					}
				});

				stopMediaStream(new FlowMediaStream(mediaStream));

				onDeviceInfoReady();
			}, function() {});
		}, function() {});
	#end
	}

	public static function requestAudioInputDevices(onDeviceInfoReady : Array<Array<String>>->Void) : Void {
		onDeviceInfoReady(audioDevices);
	}

	public static function requestVideoInputDevices(onDeviceInfoReady : Array<Array<String>>->Void) : Void {
		onDeviceInfoReady(videoDevices);
	}

	public static function makeMediaStream(
		recordAudio : Bool,
		recordVideo : Bool,
		videoDeviceId : String,
		audioDeviceId : String,
		onMediaStreamReady : Dynamic->Void,
		onMediaStreamError : String->Void
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
			onMediaStreamReady(new FlowMediaStream(mediaStream));
		}, function(error) {
			onMediaStreamError(error.message);
		});
	#end
	}

}
