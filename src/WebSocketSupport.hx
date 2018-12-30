import Flow;
import FlowArray;
import FlowArrayUtil;
import WebSocketSupportHx;

class WebSocketSupport {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}
	
	var interpreter : Interpreter;

	public function open(args : FlowArray<Flow>, pos : Position) : Flow {
		url = FlowUtil.getString(args[0]);
		protocols = FlowUtil.getArray(args[1]);
		onClose = interpreter.registerRoot(args[2]);
		onError = interpreter.registerRoot(args[3]);
		onMessage = interpreter.registerRoot(args[4]);
		onOpen = interpreter.registerRoot(args[5]);

		onCloseInterpret = function(code, reason, wasClean) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onClose), FlowArrayUtil.fromArray([
				ConstantInt32(code, pos),
				ConstantString(reason, pos),
				ConstantBool(wasClean, pos)
			]), pos));
			me.interpreter.releaseRoot(onClose);
			me.interpreter.releaseRoot(onError);
			me.interpreter.releaseRoot(onMessage);
			me.interpreter.releaseRoot(onOpen);
		};

		onErrorInterpret = function(error) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onError), FlowArrayUtil.fromArray([
				ConstantString(error, pos)
			]), pos));
		};

		onMessageInterpret = function(msgn) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onMessage), FlowArrayUtil.fromArray([
				ConstantString(msg, pos)
			]), pos));
		};

		onOpenInterpret = function(protocol) {
			me.interpreter.eval(Call(me.interpreter.lookupRoot(onOpen), FlowArrayUtil.fromArray([
				ConstantString(protocol, pos)
			]), pos));
		};

		return ConstantNative(
			WebSocketSupportHx(
				url,
				protocols,
				onCloseInterpret,
				onErrorInterpret,
				onMessageInterpret,
				onOpenInterpret
			),
			pos
		);
	}

	public function send(args : FlowArray<Flow>, pos : Position) : Flow {
		webSocket = FlowUtil.getNative(args[0]);
		msg = FlowUtil.getString(args[1]);

		WebSocketSupportHx.send(webSocket, msg);
		return ConstantVoid(pos);
	}

	public function close(args : FlowArray<Flow>, pos : Position) : Flow {
		webSocket = FlowUtil.getNative(args[0]);
		code = FlowUtil.getInt(args[1]);
		reason = FlowUtil.getString(args[2]);

		return ConstantBool(WebSocketSupportHx.close(webSocket, msg), pos);
	}

	public function getBufferedAmount(args : FlowArray<Flow>, pos : Position) : Flow {
		webSocket = FlowUtil.getNative(args[0]);

		return ConstantI32(WebSocketSupportHx.getBufferedAmount(webSocket));
	}

}