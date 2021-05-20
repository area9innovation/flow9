class MediaRecorderSupport {

	public static function loadPolyFill(cb : Void -> Void) {
	}

	public static function startRecording(recorder : Dynamic, timeslice : Int) : Void {
	}

	public static function resumeRecording(recorder : Dynamic) : Void {
	}

	public static function pauseRecording(recorder : Dynamic) : Void {
	}

	public static function stopRecording(recorder : Dynamic) : Void {
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
	}

}
