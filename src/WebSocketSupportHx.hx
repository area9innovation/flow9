import js.html.WebSocket;

class WebSocketSupportHx {

	public static function open(
		url : String,
		onClose : Int -> String -> Bool -> Void,
		onError : String -> Void,
		onMessage : String -> Void,
		onOpen : Void -> Void) : Dynamic {

		var webSocket = new WebSocket(url);
		webSocket.onclose = function (closeEvent) {
			onClose(closeEvent.code, closeEvent.reason, closeEvent.wasClean);
		};
		webSocket.onerror = function (errorEvent) {
			trace(errorEvent);
			onError(
				if (errorEvent.message != null) errorEvent.message
				else "WebSocket unknown error."
			);
		};
		webSocket.onmessage = function (msgEvent) {
			onMessage(msgEvent.data);
		};
		webSocket.onopen = function (openEvent) {
			onOpen();
		};

		return webSocket;
	}

	public static function send(webSocket : Dynamic, msg : String) : Bool {
		var isReady = webSocket.readyState > 0;
		if (isReady)
			webSocket.send(msg);
		return isReady;
	}

	public static function close(webSocket : Dynamic, code : Int, reason : String) : Void {
		webSocket.close(code, reason);
		return;
	}

	public static function hasBufferedData(webSocket : Dynamic) : Bool {
		return webSocket.bufferedAmount > 0;
	}

}