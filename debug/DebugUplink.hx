package debug;

import flash.display.Loader;
import flash.events.DataEvent;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.Lib;
import flash.net.URLRequest;
import flash.net.XMLSocket;
import flash.events.IOErrorEvent;
import flash.system.Security;
import flash.utils.ByteArray;
import flash.utils.Timer;
import flash.events.TimerEvent;

import haxe.xml.Fast;
import haxe.Stack;

class DebugUplink {
	var sock : XMLSocket;
	var runner : BytecodeRunner;
	var recv_id : Int;
	var svr_id : String;
	
	public function new(_runner : BytecodeRunner) {
		runner = _runner;
		recv_id = 0;
		//		haxe.Log.trace = TraceCB;
		connect();
    }

	public inline function isConnected() : Bool {
		return sock != null && svr_id != null;
	}

	private function connect() {
		Security.loadPolicyFile("xmlsocket://localhost:17777");
		sock = new XMLSocket();
		sock.addEventListener(Event.CONNECT, connectHandler);
		sock.addEventListener(IOErrorEvent.IO_ERROR, socketIOErrorHandler);
		sock.addEventListener(DataEvent.DATA, commandHandler);
		sock.connect("localhost", 17777);
	}

	private function connectHandler(e : Event) {
		trace("connected");
		sock.send("<runner-connect/>");
	}
	
	private function commandHandler(e : DataEvent) {
		var xmlStr: String = e.data;
		if (xmlStr != null) {
			if (xmlStr.indexOf("cross-domain-policy") != -1)
				return;

			var xmlData : Xml = Xml.parse(xmlStr);
			
			var commandElem = xmlData.elementsNamed("command");
			if (commandElem == null) {
				trace("No commands: " + xmlStr);
				return;
			}
			
			var command: Xml = commandElem.next();
			if (command == null)
				return;

			var id = command.get("id");
			if (id == null) {
				trace("Command without ID: " + xmlStr);
				return;
			}
			var iid = Std.parseInt(id);
			if (iid == null || iid == 0) {
				trace("Invalid command ID: " + xmlStr);
				return;
			}

			recv_id = iid;

			var reply = Xml.createElement("command-reply");
			reply.set("id", id);
			
			try {
				var name = command.get("name");
				if (name == null)
					throw "Command name not specified.";

				evaluateCommand(name, command, reply);
			} catch (e : Dynamic) {
				reply = Xml.createElement("command-error");
				reply.set("id", id);
				reply.addChild(Xml.createCData(""+e));
			}

			sock.send(reply.toString());
		}
	}

	private function getIntAttr(node : Xml, name : String, ?def : Null<Int> = null) : Int {
		var s = node.get(name);
		var v = (s == null ? null : Std.parseInt(s));
		if (v != null) return v;
		if (def == null)
			throw "Attribute " + name + " must be an int.";
		else
			return def;
	}
	
	private function evaluateCommand(name : String, info : Xml, reply : Xml) {
		switch (name) {
			case "init-link":
				svr_id = info.get('link-id');
				if (svr_id == null)
					throw "Link ID is NULL";
			case "query-values":
				var addr = getIntAttr(info, 'address');
				var count = getIntAttr(info, 'count', 1);
				var depth = getIntAttr(info, 'depth', 1);
				for (i in 0...count)
					reply.addChild(runner.memoryToXml(addr + BytecodeRunner.stackslot*i, depth));
			case "query-state":
				var stack_cnt = getIntAttr(info, 'stack-cnt', 0);
				var stack_bias = getIntAttr(info, 'stack-bias', 0);
				reply.addChild(runner.exportState(stack_cnt, stack_bias));
			case "query-function":
				var name = info.get('function-name');
				var ptr = -1;
				if (name != null) {
					ptr = runner.functionToAddress(name);
					if (ptr < 0)
						throw "Unknown function: "+name;
				} else {
					ptr = getIntAttr(info, 'address');
				}
				reply.addChild(runner.addressToFunctionXml(ptr));
				var fn = runner.findFnInfoByAddress(ptr);
				if (fn != null)
					reply.addChild(runner.disassembleToXml(fn.start, fn.end));
			default:
				throw "Unknown command '"+name+"'";
		}
	}

	public function reportEvent(type : String, ?text : String = null, ?info : Array<Xml> = null) {
		if (!isConnected())
			return;
		
		try {
			var event = Xml.createElement("event");
			event.set("type", type);
			if (text != null && text != '')
				event.set("text", text);
			if (info != null)
				for (c in info)
					event.addChild(c);
			sock.send(event);
		} catch (e : Dynamic) {
			trace("Error in reportEvent: " + e);
		}
	}
	
	private function socketIOErrorHandler(e:IOErrorEvent) {
		sock.removeEventListener(IOErrorEvent.IO_ERROR, socketIOErrorHandler);
		sock.close();
		sock = null;
		trace("Socket error: " + e);
	}

	private static function exportHaxeStackItem(item : Null<StackItem>) : Null<Xml> {
		if (item == null)
			return null;

		switch(item) {
		case FilePos(rec, file, line):
			var node = exportHaxeStackItem(rec);
			if (node == null)
				node = Xml.createElement('source');
			node.set('file', file);
			node.set('line', ""+line);
			return node;
		case CFunction:
			return Xml.createElement('c-function');
		case Module(m):
			var node = Xml.createElement('module');
			node.set('name', m);
			return node;
		case Method(cname, meth):
			var node = Xml.createElement('method');
			node.set('class', cname);
			node.set('name', meth);
			return node;
		case Lambda(n):
			var node = Xml.createElement('lambda');
			node.set('id', ""+n);
			return node;
		}
	}

	public static function exportHaxeStack(?exception : Dynamic = null) : Xml {
		var list = Xml.createElement('haxe-stack');

		// Scan the exception stack
		if (exception != null) {
			list.set('in-catch', '1');
			for (item in Stack.exceptionStack())
				list.addChild(exportHaxeStackItem(item));
			var cnode = Xml.createElement('try-catch');
			cnode.addChild(Xml.createCData(""+exception));
			list.addChild(cnode);
		}

		for (item in Stack.callStack())
			list.addChild(exportHaxeStackItem(item));

		return list;
	}
}
