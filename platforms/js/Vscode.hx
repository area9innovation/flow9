import HaxeRuntime;

class Vscode {
	#if js
	private static var api : Dynamic = null;
	#end

	public static function sendMessage(message : String) : Void {
		initApi();
		#if js
		Vscode.api.postMessage(message);
		#end
	}
	
	public static function getState() : String {
		initApi();
		#if js
		return Vscode.api.getState();
		#else
		return "";
		#end
	}

	public static function setState(state : String) : Void {
		initApi();
		#if js
		Vscode.api.setState(state);
		#end
	}

	private static function initApi() : Void {
		#if js
		if (!Vscode.api) {
			Vscode.api = untyped __js__("acquireVsCodeApi()");
		}
		#end
	}
}
