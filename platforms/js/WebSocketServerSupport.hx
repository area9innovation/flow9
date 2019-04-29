import Errors;
import WebSocketServer;
import HttpServerSupport;

class WebSocketServerSupport {
	public static function createWsServerNative(
		port : Int,
		isHttp : Bool,
		key : String,
		cert : String,
		passphrase : String,
		onOpen : WebSocket -> Void) : Bool {

		#if flow_nodejs
			var server =
				HttpServerSupport.createHttpServerNative(
					port,
					isHttp,
					key,
					cert,
					passphrase
				);
			var webSocketServer =
				new WebSocketServer.Server({ server: server });

			if (webSocketServer != null) {
				webSocketServer.on('connection', onOpen);
				return true;
			} else {
				return false;
			}
		#else
			reportInvalidInvocation();
			return null;
		#end
	}

	public static function embedListeners(
		webSocket : WebSocket,
		onClose : Int -> Void,
	 	onError : Int -> Void,
	 	onMessage : String -> Void) : Void {

		webSocket.on('message', onMessage);
		webSocket.on('close', onClose);
		webSocket.on('error', onError);
	}

	public static function send(webSocket : WebSocket, msg : String) : Bool {
		#if flow_nodejs
			var isReady = webSocket != null;
			if (isReady)
				webSocket.send(msg);
			return isReady;
		#else
			reportInvalidInvocation();
		#end
	}

	public static function close(
		webSocket : WebSocket,
		code : Int,
		reason : String) : Void {

		#if flow_nodejs
			if (webSocket != null) {
				webSocket.close(code, reason);
			}
		#end
	}

	public static function getBufferedAmount(webSocket : WebSocket) : Int {
		#if flow_nodejs
			return webSocket.bufferedAmount;
		#else
			reportInvalidInvocation();
			return 0;
		#end
	}

	public static function reportInvalidInvocation() : Void {
		Errors.report("WebSocket server is not supported on this platform.");
	}
}
