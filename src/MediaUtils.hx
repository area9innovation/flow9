import js.html.URL;
import js.html.MediaRecorder;
import js.html.MediaStream;
import js.html.WebSocket;

class MediaUtils {

	private static var audioDevices = {
		deviceIds : [],
		labels : []
	};
	private static var videoDevices = {
		deviceIds : [],
		labels : []
	};

	public static function stopMediaStream(mediaStream : MediaStream) : Void {
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

				stopMediaStream(mediaStream);
				
				OnDeviceInfoReady();
			}, function() {});
		}, function() {});
	#end
	}

	public static function requestAudioInputDevices(OnDeviceInfoReady : Array<String>->Array<String>->Void) : Void {
		OnDeviceInfoReady(audioDevices.deviceIds, audioDevices.labels);
	}

	public static function requestVideoInputDevices(OnDeviceInfoReady : Array<String>->Array<String>->Void) : Void {
		OnDeviceInfoReady(videoDevices.deviceIds, videoDevices.labels);
	}

	public static function makeMediaStream(
		recordAudio : Bool,
		recordVideo : Bool,
		videoDeviceId : String,
		audioDeviceId : String,
		OnMediaStreamReady : Dynamic->Void,
		OnMediaStreamError : String->Void
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
		}, function(error) {
			OnMediaStreamError(error.message);
		});
	#end
	}

}
