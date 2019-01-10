import Flow;
import FlowArray;
import MediaRecorderSupportHx;

class MediaRecorderSupport {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}
	
	var interpreter : Interpreter;
	private static var mediaRecorderSupportHx : MediaRecorderSupportHx = new MediaRecorderSupportHx();
}
