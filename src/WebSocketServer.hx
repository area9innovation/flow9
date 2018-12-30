import js.node.events.EventEmitter;
import js.node.http.Server;
import haxe.extern.EitherType;
import haxe.Constraints.Function;

@:jsRequire("ws", "WebSocket")
extern class WebSocket extends EventEmitter<WebSocket> {

	public var bufferedAmount : Int;

	/**
		Create a `WebSocketServer` instance.

		Arguments
			address - The URL to which to connect
			protocols - The subprotocols
			options - Connection options
	**/
	public function new(
		address : String,
		?protocols : EitherType<String, Array<String>>,
		?options : ConnectionOptions);

	/**
			Pause the socket stream.
	**/
	public function pause() : Void;

	/**
			Resume the socket stream.
	**/
	public function resume() : Void;

	/**
			Start a closing handshake.
			Arguments
				code - Status code explaining why the connection is closing
				data - A string explaining why the connection is closing
	**/
	public function close(code : Int, data : String) : Void;

	/**
			Send a ping message.
			Arguments
				data - The message to send
				mask - Indicates whether or not to mask `data`
				failSilently - Indicates whether or not to throw if `readyState` isn't `OPEN`
	**/
	public function ping(
		data : Dynamic,
		?mask : Bool,
		?failSilently : Bool) : Void;

	/**
			Send a pong message.
			Arguments
				data - The message to send
				mask - Indicates whether or not to mask `data`
				failSilently - Indicates whether or not to throw if `readyState` isn't `OPEN`
	**/
	public function pong(
		data : Dynamic,
		?mask : Bool,
		?failSilently : Bool) : Void;

	/**
			Send a data message.
			Arguments
				data - The message to send
				options - Options record
				callback - Callback which is executed when data is written out
	**/
	public function send(
		data : Dynamic,
		?options : SendOptions,
		?callback : Void -> Void) : Void;
}

typedef SendOptions = {
	/**
			Specifies whether or not to compress `data`
	**/
	@:optional var compress : Bool;

	/**
			Specifies whether `data` is binary or text
	**/
	@:optional var binary : Bool;

	/**
			Specifies whether the fragment is the last one
	**/
	@:optional var fin : Bool;

	/**
			Specifies whether or not to mask `data`
	**/
	@:optional var mask : Bool;
}

@:jsRequire("ws", "Server")
extern class Server extends EventEmitter<Server> {
	/**
		Create a `WebSocketServer` instance.
		Arguments
			options - Configuration options
			callback - A listener for the `listening` event
	**/
	public function new(
		?options : ConnectionOptions,
		?callback : Void -> Void);

	/**
			Close the server.
			Arguments
				callback - Callback
	**/
	public function close(?callback : Void -> Void) : Void;
}

typedef ConnectionOptions = {
	/**
			The hostname where to bind the server.
	**/
	@:optional var host : String;

	/**
			The port where to bind the server.
	**/
	@:optional var port : Int;

	/**
			A pre-created HTTP/S server to use.
	**/
	@:optional var server : js.node.net.Server;

	/**
			An hook to reject connections.
	**/
	@:optional var verifyClient : Function;

	/**
			An hook to handle protocols.
	**/
	@:optional var handleProtocols : Function;

	/**
			Accept only connections matching this path.
	**/
	@:optional var path : String;

	/**
			Enable no server mode.
	**/
	@:optional var noServer : Bool;

	/**
			Specifies whether or not to track clients.
	**/
	@:optional var clientTracking : Bool;

	/**
			Enable/disable permessage-deflate.
	**/
	@:optional var perMessageDeflate : EitherType<Bool, Dynamic>;

	/**
			The maximum allowed message size.
	**/
	@:optional var maxPayload : Int;
}
