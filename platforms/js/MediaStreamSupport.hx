import js.html.URL;
import js.html.MediaRecorder;
import js.html.MediaStream;
import js.html.WebSocket;

class MediaStreamSupport {

	private static var audioDevices : Array<Array<String>> = [];
	private static var videoDevices : Array<Array<String>> = [];

	public static function stopMediaStream(mediaStream : MediaStream) : Void {
		for (track in mediaStream.getTracks()) {
			track.stop();
		}
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

				stopMediaStream(mediaStream);

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
			onMediaStreamReady(mediaStream);
		}, function(error) {
			onMediaStreamError(error.message);
		});
	#end
	}

}
