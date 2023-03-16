class MediaStreamSupport {
	public static function loadQrLibrary(onLoad : Void -> Void) : Void {
	}

	public static function stopMediaStream(mediaStream : Dynamic) : Void {
	}

	public static function scanMediaStream(mediaStream : Dynamic, types : Array<String>, onResult : String -> Void) : Void {
	}

	public static function initDeviceInfo(
		onDeviceInfoReady : Void->Void
	) : Void {
	}

	public static function requestAudioInputDevices(onDeviceInfoReady : Array<Array<String>>->Void) : Void {
	}

	public static function requestVideoInputDevices(onDeviceInfoReady : Array<Array<String>>->Void) : Void {
	}

	public static function makeMediaStream(
		recordAudio : Bool,
		recordVideo : Bool,
		videoDeviceId : String,
		audioDeviceId : String,
		onMediaStreamReady : Dynamic->Void,
		onMediaStreamError : String->Void
	) : Void {
	}
}
