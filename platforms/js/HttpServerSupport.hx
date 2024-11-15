import Errors;

import js.node.Http;
import js.node.Https;
import js.node.net.Server;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
import js.node.Fs;
import haxe.extern.EitherType;

class HttpServerSupport {

	public static function createHttpServerNative(
		port : Int,
		isHttps : Bool,
		pfxPath : String,
		pfxPassword : String,
		?onOpen : Void -> Void,
		?onOpenError : String -> Void,
		?onMessage : String ->
					String ->
					String ->
					Array<Array<String>> ->
					(String->String->Null<Void->Void>->Void) ->
					(String->EitherType<String, Array<String>>->Void) ->
					(Int->Void) ->
					Void
	) : Server {

		#if flow_nodejs
			var onRequest : IncomingMessage->ServerResponse->Void =
				function (request, response) {
					var requestData = request.read();
					var setResponseCode = function (status) {
						response.statusCode = status;
					}
					onMessage(
						request.url,
						if (requestData != null)
							requestData
						else
							"",
						request.method,
						split(request.rawHeaders, 2),
						response.end,
						response.setHeader,
						setResponseCode
					);
				}

			var server = if (isHttps) {
				Https.createServer(
					{
						pfx: Fs.readFileSync(pfxPath),
						passphrase: pfxPassword
					},
					onRequest
				);
			} else {
				Http.createServer(onRequest);
			}

			server.listen(port, onOpen);

			return server;
		#else
			reportInvalidInvocation();
			return null;
		#end
	}

	public static function closeHttpServerNative(server : Server) : Void {
		server.close;
	}

	static function reportInvalidInvocation() : Void {
		Errors.report("WebSocket server is not supported on this platform.");
	}

	static function split<T>(a : Array<T>, n : Int) : Array<Array<T>> {
		var l = a.length;
		if (l <= n || n <= 0) {
			return [a];
		} else {
			return [a.slice(0, n)].concat(split(a.slice(n), n));
		}
	}
}
