class Errors {
	static var instance : Errors;
	static public var dontlog : Bool;
	static public function get() {
		if (instance == null) {
			instance = new Errors();
		}
		return instance;
	}
	public function new() {
		callBack = null;
		doTrace = true;
		count = 0;
	}
	static public function report(text : String) {
		get().add(text);
		get().count++;
		#if js
		untyped console.error("Error: " + text);
		#else
		print(text);
		#end
		addToLog(text);
	}

	static public function warning(text : String) {
		get().add(text);
		#if js
		untyped console.warn("Warning: " + text);
		#else
		print(text);
		#end
	}

	static public function print(text : String) {
		if (!Errors.get().doTrace) {
		  return;
		}
		#if flash
		try {
			var esc = StringTools.replace(text, "\\", '/');
			flash.external.ExternalInterface.call("console.log", esc);
		} catch (e :Dynamic) {
			trace(text);
		}
		#elseif (js && (flow_nodejs || nwjs))
			Util.println(text);
		#elseif js
			untyped console.log(text);
		#else
			Sys.println(text);
		#end
	}
	function add(text : String) {
		if (callBack != null) {
			// To prevent infinite recursion, we block out recursive callbacks
			callBack(text);
		}
	}

	static public function getCount() : Int {
		return get().count;
	}
	
	static public function resetCount() : Void {
		get().count = 0;
	}
	
	static function addToLog(m : String) {
		if (dontlog) return;
		#if sys
		if (logFile == null) {
			logFile = sys.io.File.append(".compile-errors");
			logFile.writeString(Date.now().toString() + "\n");
			logFile.writeString('neko flow.n  ' + Sys.args().join(' ') + "\n");
		}
		logFile.writeString(m + "\n");
		#end
	}
	static public function closeErrorLog() {
		#if sys
		if (logFile != null) {
			logFile.writeString("\n");
			logFile.close();
		}
		#end
	}
	#if sys
	static var logFile : sys.io.FileOutput;
	#end

	public var callBack : String -> Void;
	public var doTrace : Bool;
	private var count : Int;
}
