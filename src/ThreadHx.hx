
class ThreadHx {
	public static function hasThreads() : Bool {
		#if js
			return untyped __js__("typeof Worker != 'undefined'");
		#else
			return false;
		#end
	}

	public static function isThread() : Bool {
		#if js
			return untyped __js__("typeof window == 'undefined'" );
		#else
			return false;
		#end
	}

	public static function makeThread(receiveFn : Dynamic -> String -> Void) : Dynamic {
		try {
			var w = untyped __js__("new Worker('thread.js')");
			w.addEventListener('message', function(e) {
				trace(e.data);
				receiveFn(w, e.data);
			}, false);
			// Start the worker
			w.postMessage();
			return w;
		} catch (e : Dynamic) {
			trace("Something is wrong");
			return null;
		}
	}

	public static function sendThreadMessage(thread : Dynamic, message : String) : Void {
		// native  : io (thread : native, message : string) -> bool = Thread.sendThreadMessage;
	}

	public static function postThreadMessage(message : String) : Void {
		// native  : io (thread : native, message : string) -> bool = Thread.sendThreadMessage;
		untyped __js__("self.postMessage(message)");
	}


}

/*
	// Start a thread. Give a function that will receive messages from the thread
	native makeThread : io (receiveMessage : (native, string) -> void) -> native = Thread.makeThread;

	// Send this message to the thread.
	native sendThreadMessage : io (thread : native, message : string) -> bool = Thread.sendThreadMessage;

	// Shut down a thread
	native terminateThread : io (native) -> void = Thread.terminateThread;

*/