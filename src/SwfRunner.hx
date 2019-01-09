import HaxeRuntime;
import haxe.Json;

class SwfRunner {
	public static function sendError(e:Dynamic) {
		var msg = "Url params:\n\n";
		msg += Json.stringify(flash.Lib.current.loaderInfo.parameters);
		msg += "\nException: " + e + "\n\n";
		msg += "Stack trace:\n";
		msg += Assert.callStackToString(haxe.CallStack.exceptionStack());

		var http = new haxe.Http("php/debug.php");
		http.setParameter("operation", "save_log");
		http.setParameter("value", msg);
		http.request(true);
	}

	public static function main() {
		try {
			var swfClass = Type.resolveClass("Swf");
			var swf = Type.createInstance(swfClass, []);
			
			// Initialize all globals
			Reflect.callMethod(swf, Reflect.field(swf, "_init_flow_globals"), []);
			
			// Then run main!
			Reflect.callMethod(swf, Reflect.field(swf, "main"), []);
		} catch (e : Dynamic) {
			var cs = Assert.callStackToString(haxe.CallStack.exceptionStack());
			// TODO: Register some native that we can call and complain
			NativeHx.println("FATAL ERROR: main reported: " + e);
			trace(cs);
			NativeHx.callFlowCrashHandlers("[main]: " + e);
			#if flash
		 	sendError(e);
			#end
		}
	}
}
