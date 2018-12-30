import Flow;
import FlowArray;
import NativeTime;

/**
 * Bridge class for invoking native haXe functions from flow.
 * Each function should take a flow array, and return flow if it returns anything
 */
class Native {
	public function new(interpreter : Interpreter) {
		this.interpreter = interpreter;
	}
	
	var interpreter : Interpreter;
	
	public function println(args : FlowArray<Flow>, pos : Position) : Flow {
		for (c in args) {
			#if sys
			switch (c) {
				case ConstantString(s, pos): {
					Sys.println(s);
					return ConstantVoid(pos);
				}
				default:
			}
			#end
			
			var s = interpreter.toString(c);
			#if flash
				try {
					var qoute = StringTools.replace(s, '\\', '');
					flash.external.ExternalInterface.call("console.log", qoute);
				} catch (e : Dynamic) {
					trace(s);
				}
			#else
				Errors.print(s);
			#end
		}
		return ConstantVoid(pos);
	}

	public function debugStopExecution(args : FlowArray<Flow>, pos : Position) : Flow {
		#if js
			//If dev tools are available stops execution at this line
			js.Lib.debug();
		#end
		return ConstantVoid(pos);
	}
	
	public function hostCall(args: FlowArray<Flow>, pos: Position) : Flow {
		var result = ConstantVoid(pos);
		
		var flowToDynamic = function(value: Flow): Dynamic {
			var res: Dynamic = value;
		
			switch (value) {
				case ConstantBool(v, pos): res = v;
				case ConstantI32(v, pos): res = v;
				case ConstantDouble(v, pos): res = v;
				case ConstantString(v, pos): res = v;
				case ConstantArray(v, pos): res = v;
				case ConstantNative(v, pos): res = v;
				default: {}
			}
			
			return res;
		};
		
		#if flash
			try {
				var name: String = interpreter.toString(args[0]);
				
				// Remove extra quotes
				name = name.substr(1, name.length - 2);

				// args[1] should be an array, let's check it here
				var argsArray: FlowArray<Flow> = null;
				
				switch (args[1]) {
					case ConstantArray(value, p): argsArray = value;
					default: trace("Invalid arguments when calling hostCall");
				}
				
				var arguments = new Array<Dynamic>();
				for (i in 0...4) {
					if (Std.int(argsArray.length) > i) {
						arguments.push(flowToDynamic(argsArray[i]));
					}
					else
						arguments.push(null);
				}
				
				var res = flash.external.ExternalInterface.call(name, 
					arguments[0], 
					arguments[1], 
					arguments[2], 
					arguments[3], 
					arguments[4]
				);
				
				result = if (res == null) {
					ConstantVoid(pos);
				}
				else {	// TODO: See if we can return here ConstantString, ConstantI32, etc. instead
					ConstantNative(res, pos);
				}				
			} catch (e: Dynamic) {
				trace(e);
			}
		#end
		
		return result;
	}
	
	public function hostAddCallback(args: FlowArray<Flow>, pos: Position) : Flow {
		#if flash
			try {
				var name: String = interpreter.toString(args[0]);
				
				// Remove extra quotes
				name = name.substr(1, name.length - 2);
				
				var cb = interpreter.registerRoot(args[1]);
				
				flash.external.ExternalInterface.addCallback(name, cb);				
			} catch (e: Dynamic) {
				trace(e);
			}
		#end
		
		return ConstantVoid(pos);
	}
	
	public function setClipboard(args: FlowArray<Flow>, pos: Position) : Flow {
		#if flash
			flash.system.System.setClipboard(FlowUtil.getString(args[0]));
		#end
		
		return ConstantVoid(pos);
	}

	public function getClipboard(args: FlowArray<Flow>, pos: Position) : Flow {
		return ConstantString("", pos);
	}

	public function getClipboardFormat(args: FlowArray<Flow>, pos: Position) : Flow {
		return ConstantString("", pos);
	}

	public function setCurrentDirectory(args: FlowArray<Flow>, pos: Position) : Flow {
		return ConstantVoid(pos);
	}

	public function getCurrentDirectory(args: FlowArray<Flow>, pos: Position) : Flow {
		return ConstantString("", pos);
	}

	public function getApplicationPath(args : FlowArray<Flow>, pos: Position) : Flow {
		return ConstantString("", pos);
	}
	
	public function toString(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantString(interpreter.toString(args[0]), pos);
	}

	public function makeStructValue(args : FlowArray<Flow>, pos : Position) : Flow {
		var c = FlowUtil.getString(args[0]);
		var args = FlowUtil.getArray(args[1]);
		return ConstantStruct(c, args, pos);
	}

	public function isArray(args : FlowArray<Flow>, pos : Position) : Flow {
		switch(args[0]) {
			case ConstantArray(values, pos2):
				return ConstantBool(true, pos);
			default:
				return ConstantBool(false, pos);
		}
	}

	public function isSameStructType(args : FlowArray<Flow>, pos : Position) : Flow {
		var name1 = null;
		switch(args[0]) {
			case ConstantStruct(name, values, pos): name1 = name;
			default: return ConstantBool(false, pos);
		}
		var name2 = null;
		switch(args[1]) {
			case ConstantStruct(name, values, pos): name2 = name;
			default: return ConstantBool(false, pos);
		}
		return ConstantBool(name1 == name2, pos);
	}

	public function isSameObj(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(FlowInterpreter.isSameObj(args[0], args[1], pos), pos);
	}

	public function gc(args : FlowArray<Flow>, pos : Position) : Flow {
		interpreter.gc();
		return ConstantVoid(pos);
	}
	
	public function addHttpHeader(args : FlowArray<Flow>, pos : Position) : Flow {
		// CGI only. Here to avoid compile errors
		return ConstantVoid(pos);
	}
	
	public function subrange(args : FlowArray<Flow>, pos : Position) : Flow {
		var a = FlowUtil.getArray(args[0]);
		var i = FlowUtil.getInt(args[1]);
		var l = FlowUtil.getInt(args[2]);
		return ConstantArray(a.slice(i, i + l), pos);
	}
	
	public function length(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantI32((FlowUtil.getArray(args[0]).length), pos);
	}

	public function strlen(args : FlowArray<Flow>, pos : Position) : Flow {
		// Unicode clean
		var s = FlowUtil.getString(args[0]);
		var l = haxe.Utf8.length(s);
		return ConstantI32((l), pos);
	}
	
	public function strIndexOf(args : FlowArray<Flow>, pos : Position) : Flow {
		var s1 = FlowUtil.getString(args[0]);
		var s2 = FlowUtil.getString(args[1]);
		// First, do a quick byte-based check
		var bi = s1.indexOf(s2);
		if (bi > 0) {
			var l2 = haxe.Utf8.length(s2);
			// OK, we have to check and do the check with unicode
			for (i in 0...bi) {
				var sub = haxe.Utf8.sub(s1, i, l2);
				if (sub == s2) {
					bi = i;
					break;
				}
			}
		}

		// This is wrong in the face of 8-bit characters!
		return ConstantI32((bi), pos);
	}

	public function substring(args : FlowArray<Flow>, pos : Position) : Flow {
		// Unicode clean
		var s = FlowUtil.getString(args[0]);
		var i1 = FlowUtil.getInt(args[1]);
		var i2 = FlowUtil.getInt(args[2]);
		var s2 = haxe.Utf8.sub(s, i1, i2);
		return ConstantString(s2, pos);
	}

	public function toLowerCase(args : FlowArray<Flow>, pos : Position) : Flow {
		// Unicode clean, although only ASCII characters are supported
		return ConstantString(FlowUtil.getString(args[0]).toLowerCase(), pos);
	}

	public function toUpperCase(args : FlowArray<Flow>, pos : Position) : Flow {
		// Unicode clean, although only ASCII characters are supported
		return ConstantString(FlowUtil.getString(args[0]).toUpperCase(), pos);
	}

	public function s2a(args : FlowArray<Flow>, pos : Position) : Flow {
		// Unicode clean
		var s = FlowUtil.getString(args[0]);
		var a = new FlowArray();
		haxe.Utf8.iter(s, function(c) {
			a.push(ConstantI32((c), pos));
		});
		return ConstantArray(a, pos);
	}
	
	public function string2utf8(args : FlowArray<Flow>, pos : Position) : Flow {
		// Unicode clean
		var s = FlowUtil.getString(args[0]);

		var buf = new haxe.io.BytesOutput();
		buf.writeString(s);
		
		var bytes = buf.getBytes();
		
		var a = new FlowArray();
		for (i in 0...bytes.length) {
			a.push(ConstantI32((bytes.get(i)), pos));
		}
		return ConstantArray(a, pos);
	}
	
	public function getCharCodeAt(args : FlowArray<Flow>, pos : Position) : Flow {
		// Unicode clean
		var s = FlowUtil.getString(args[0]);
		var i = FlowUtil.getInt(args[1]);
		var c = haxe.Utf8.charCodeAt(s, i);
		return ConstantI32((c), pos);
	}
	
	public function fromCharCode(args : FlowArray<Flow>, pos : Position) : Flow {
		var code = FlowUtil.getInt(args[0]);
		var s = Util.fromCharCode(code);
		return ConstantString(s, pos);
	}

	public function list2string(args : FlowArray<Flow>, pos : Position) : Flow {
		var result = "";
		var h = args[0];
		while (true) {
			switch(h) {
				case ConstantStruct(name, values, pos): {
					if (name == "Cons") {
						result = FlowUtil.getString(values[0]) + result;
						h = values[1];
					} else if (name == "EmptyList") {
						break;
					}
				}
				case VarRef(name, pos): {    // fixes neko runner crash on EmptyList struct written without braces
					if (name == "EmptyList") {
						break;
					} else {
						throw "list2string wants a List struct";
					}
				}
				default: throw "list2string wants a struct";
			}
		}
		return ConstantString(result, pos);
	}

	public function list2array(args : FlowArray<Flow>, pos : Position) : Flow {
		var result = new FlowArray();
		var h = args[0];
		while (true) {
			switch(h) {
				case ConstantStruct(name, values, pos): {
					if (name == "Cons") {
						result.unshift(values[0]);
						h = values[1];
					} else if (name == "EmptyList") {
						break;
					}
				}
				case VarRef(name, pos): {   // fixes neko runner crash on EmptyList struct written without braces
					if (name == "EmptyList") {
						break;
					} else {
						throw "list2array wants a List struct";
					}
				}
				default: throw "list2array wants a struct";
			}
		}
		return ConstantArray(result, pos);
	}
	
	public function bitXor(args : FlowArray<Flow>, pos : Position) : Flow {
		var i1 = FlowUtil.getI32(args[0]);
		var i2 = FlowUtil.getI32(args[1]);
		return ConstantI32((i1 ^ i2), pos);
	}
	public function bitAnd(args : FlowArray<Flow>, pos : Position) : Flow {
		var i1 = FlowUtil.getI32(args[0]);
		var i2 = FlowUtil.getI32(args[1]);
		return ConstantI32((i1 & i2), pos);
	}
	public function bitOr(args : FlowArray<Flow>, pos : Position) : Flow {
		var i1 = FlowUtil.getI32(args[0]);
		var i2 = FlowUtil.getI32(args[1]);
		return ConstantI32((i1 | i2), pos);
	}
	public function bitUshr(args : FlowArray<Flow>, pos : Position) : Flow {
		var i1 = FlowUtil.getI32(args[0]);
		var i2 = FlowUtil.getInt(args[1]);
		return ConstantI32((i1 >>> i2), pos);
	}
	public function bitShl(args : FlowArray<Flow>, pos : Position) : Flow {
		var i1 = FlowUtil.getI32(args[0]);
		var i2 = FlowUtil.getInt(args[1]);
		return ConstantI32((i1 << i2), pos);
	}
	public function bitNot(args : FlowArray<Flow>, pos : Position) : Flow {
		var i1 = FlowUtil.getI32(args[0]);
		return ConstantI32((~i1), pos);
	}
	
	public function concat(args : FlowArray<Flow>, pos : Position) : Flow {
		var a1 = FlowUtil.getArray(args[0]);
		var a2 = FlowUtil.getArray(args[1]);
		return ConstantArray(a1.concat(a2), pos);
	}	

	public function replace(args : FlowArray<Flow>, pos : Position) : Flow {
		if (args[0] == null) {
			return ConstantArray(new FlowArray(), pos);
		}
		var a = FlowUtil.getArray(args[0]);
		var i = FlowUtil.getInt(args[1]);
		if (i < 0) {
			return ConstantArray(new FlowArray(), pos);
		}
		var v = args[2];
		var newArray = new FlowArray();
		for (e in a) {
			newArray.push(e);
		}
		newArray[i] = v;
		return ConstantArray(newArray, pos);
	}
	
	public function map(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var clos = args[1];
		var result = new FlowArray();
		for (v in values) {
			result.push(interpreter.eval(Call(clos, FlowArrayUtil.one(v), pos)));
		}
		return ConstantArray(result, pos);
	}

	public function iter(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var clos = args[1];
		for (v in values) {
			interpreter.eval(Call(clos, FlowArrayUtil.one(v), pos));
		}
		return ConstantVoid(pos);
	}
	
	public function mapi(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var clos = args[1];
		// Common small cases
		if (values.length == 1) {
			var r = interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((0), pos), values[0]), pos));
			return ConstantArray(FlowArrayUtil.one(r), pos);
		} else if (values.length == 2) {
			var r1 = interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((0), pos), values[0]), pos));
			var r2 = interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((1), pos), values[1]), pos));
			return ConstantArray(FlowArrayUtil.two(r1, r2), pos);
		}
		var i = 0;
		var result = new FlowArray();
		for (v in values) {
			result.push(interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((i), pos), v), pos)));
			++i;
		}
		return ConstantArray(result, pos);
	}

	public function iteri(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var clos = args[1];
		// Common small cases
		if (values.length == 1) {
			interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((0), pos), values[0]), pos));
		} else if (values.length == 2) {
			interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((0), pos), values[0]), pos));
			interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((1), pos), values[1]), pos));
		} else {
			var i = 0;
			for (v in values) {
				interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((i), pos), v), pos));
				++i;
			}
		}
		return ConstantVoid(pos);
	}
	
	public function iteriUntil(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var clos = args[1];

		var i = 0;
		var result;
		for (v in values) {
			result = interpreter.eval(Call(clos, FlowArrayUtil.two(ConstantI32((i), pos), v), pos));
			if (FlowUtil.getBool(result)) {
				break;
			}
			++i;
		}

		return ConstantI32((i), pos);
	}
	
	public function fold(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var init = args[1];
		var fn = args[2];
		for (v in values) {
			init = interpreter.eval(Call(fn, FlowArrayUtil.two(init, v), pos));
		}
		return init;
	}

	public function foldi(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var init = args[1];
		var fn = args[2];
		var i = 0;
		for (v in values) {
			var iv = ConstantI32((i), pos);
			init = interpreter.eval(Call(fn, FlowArrayUtil.three(iv, init, v), pos));
			i++;
		}
		return init;
	}

	public function filter(args : FlowArray<Flow>, pos : Position) : Flow {
		var values = FlowUtil.getArray(args[0]);
		var clos = args[1];
		var result = new FlowArray();
		for (v in values) {
			var rv = interpreter.eval(Call(clos, FlowArrayUtil.one(v), pos));
			if (FlowUtil.getBool(rv))
				result.push(v);
		}
		return ConstantArray(result, pos);
	}

	// Get a random number between 0 and 1.
	// native random : () -> double = Native.random;
	public function random(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.random(), pos);
	}

	// Seed the random generator
/*
	public function srand(args : FlowArray<Flow>, pos : Position) : Flow {
		var seed = FlowUtil.getInt(args[0]);
		something.
	}
*/

	// Get the current time, in milliseconds since epoch 1970
	// native timestamp : () -> double = Native.timestamp;
	public function timestamp(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(/*if you want this, add "-lib nme" to the hxml
								 #if neko
								  1000.0 * nme.Timer.stamp()
  							     #else*/
									NativeTime.timestamp()
							   /*#end*/
							  , pos);
	}

	// native getCurrentDate : () -> [Date] = Native.getCurrentDate;
	public function getCurrentDate(args : FlowArray<Flow>, pos : Position) : Flow  {
		
		var date = Date.now();			
		var a1 = new FlowArray<Flow>();
		var a2 = new FlowArray<Flow>();

		a2.push(ConstantI32((date.getFullYear()), pos));
		a2.push(ConstantI32((date.getMonth() + 1), pos));		
		a2.push(ConstantI32((date.getDate()), pos));

		a1.push(ConstantString("Date", pos));
		a1.push(ConstantArray(a2, pos));
		return makeStructValue(a1, pos);

	}

	public function addCrashHandler(args : FlowArray<Flow>, pos : Position) : Flow {
		return NativeClosure(0, function(flow, pos) {
			return ConstantVoid(pos);
		}, pos);
	}

	public function utc2local(args : FlowArray<Flow>, pos : Position) : Flow {
		var stamp = FlowUtil.getDouble(args[0]);
		return ConstantDouble(NativeTime.utc2local(stamp), pos);
	}

	public function local2utc(args : FlowArray<Flow>, pos : Position) : Flow {
		var stamp = FlowUtil.getDouble(args[0]);
		return ConstantDouble(NativeTime.local2utc(stamp), pos);
	}

	// Converts string time representation to time in milliseconds since epoch 1970
	public function string2time(args : FlowArray<Flow>, pos : Position) : Flow {
		var date = FlowUtil.getString(args[0]);
		return ConstantDouble(NativeTime.string2time(date), pos);
	}

	// Returns a string representation for the time (time is given in milliseconds since epoch 1970)
	public function time2string(args : FlowArray<Flow>, pos : Position) : Flow {
		var date = FlowUtil.getDouble(args[0]);
		return ConstantString(NativeTime.time2string(date), pos);
	}

	public function dayOfWeek(args: FlowArray<Flow>, pos: Position) : Flow {
		var year = FlowUtil.getInt(args[0]);
		var month = FlowUtil.getInt(args[1]);
		var day = FlowUtil.getInt(args[2]);
		return ConstantI32((NativeTime.dayOfWeek(year, month, day)), pos);
	}

	// Get a callback in x ms
	// native timer(ms : int, callback : () -> void) -> void = Native.timer;
	public function timer(args : FlowArray<Flow>, pos : Position) : Flow {
		var ms = FlowUtil.getInt(args[0]);
		var cb = interpreter.registerRoot(args[1]);
		var me = this;
		#if !sys
		haxe.Timer.delay(function() {
			var c = me.interpreter.lookupRoot(cb);
			me.interpreter.releaseRoot(cb);
			me.interpreter.eval(Call(c, new FlowArray(), pos));
		}, ms);
		#else 
			var c = me.interpreter.lookupRoot(cb);
			me.interpreter.eval(Call(c, new FlowArray(), pos));
			me.interpreter.releaseRoot(cb);
		#end
		return ConstantVoid(pos);
	}

	public function sin(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.sin(FlowUtil.getDouble(args[0])), pos);
	}

	public function asin(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.asin(FlowUtil.getDouble(args[0])), pos);
	}

	public function acos(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.acos(FlowUtil.getDouble(args[0])), pos);
	}

	public function atan(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.atan(FlowUtil.getDouble(args[0])), pos);
	}
	
	public function atan2(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.atan2(FlowUtil.getDouble(args[0]), FlowUtil.getDouble(args[1])), pos);
	}	

	public function exp(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.exp(FlowUtil.getDouble(args[0])), pos);
	}

	public function log(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantDouble(Math.log(FlowUtil.getDouble(args[0])), pos);
	}

	public function enumFromTo(args : FlowArray<Flow>, pos : Position) : Flow {
		var from = FlowUtil.getInt(args[0]);
		var to = FlowUtil.getInt(args[1]);

		var newArray = new FlowArray();
		for (i in from...(to+1)) {
			newArray.push(ConstantI32((i), pos));
		}
		return ConstantArray(newArray, pos);
	}

	public function getAllUrlParameters(args : FlowArray<Flow>, pos : Position) : Flow {
		var parameters : Map<String, String> = new Map();
		
		#if flash
		var raw = flash.Lib.current.loaderInfo.parameters;
		var keys = Reflect.fields(raw);
		for (key in keys) {
			parameters.set(key, Reflect.field(raw, key));
		}
		#elseif neko
		if (neko.Web.isModNeko) {
			parameters = neko.Web.getParams();
		}
		#end

		var i = 0;
		var result : FlowArray<Flow> = new FlowArray<Flow>();
		for (key in parameters.keys()) {
			var keyvalue = new FlowArray<Flow>();
			keyvalue[0] = ConstantString(key, pos);
			keyvalue[1] = ConstantString(parameters.get(key), pos);

			result[i] = ConstantArray(keyvalue, pos);
			i++;
		}

		return ConstantArray(result, pos);
	}

	public function getUrlParameter(args : FlowArray<Flow>, pos : Position) : Flow {
		var name = FlowUtil.getString(args[0]);
		var value = null;
		#if flash
		var parameters = flash.Lib.current.loaderInfo.parameters;
		value = Reflect.field(parameters, name);
		#elseif neko
		if (neko.Web.isModNeko) {
			value = neko.Web.getParams().get(name);
		} else {
			var foundDivider = false;
			for (a in Sys.args()) {
				if (foundDivider) {
					if (StringTools.startsWith(a, name)) {
						value = a.substr(a.indexOf("=") +1 );
						break;
					}
				} else {
					foundDivider = a == "--";
				}
			}
		}
		#end
		if (value != null) {
			return ConstantString(value, pos);
		} else {
			return ConstantString("", pos);
		}
	}
	
	public function loaderUrl(args : FlowArray<Flow>, pos : Position) : Flow {
		var value = null;
		#if flash
		value = flash.Lib.current.loaderInfo.loaderURL;
		#end
		if (value != null) {
			return ConstantString(value, pos);
		} else {
			return ConstantString("", pos);
		}
	}
	
	public function getUrl(args : FlowArray<Flow>, pos : Position) : Void {
		#if flash
		var url = FlowUtil.getString(args[0]);
		var target = FlowUtil.getString(args[1]);
		flash.Lib.getURL(new flash.net.URLRequest(url), target);
		#end
	}

	public function quit(args : FlowArray<Flow>, pos : Position) : Flow {
		var code = FlowUtil.getInt(args[0]);
		#if (neko||cpp)
		Sys.exit(code);
		#else
		Errors.print("quit called: " + code);
		#end
		
		return ConstantVoid(pos);
	}

	public function getFileContent(args : FlowArray<Flow>, pos : Position) : Flow {
		#if (neko||cpp)
		var path = FlowUtil.getString(args[0]);
		var content = sys.FileSystem.exists(path) ? 
			sys.io.File.getContent(path) : "";
		return ConstantString(content, pos);
		#else
		throw "Not implemented for this target: getFileContent";
		return ConstantString("", pos);
		#end
	}

	public function getFileContentBinary(args : FlowArray<Flow>, pos : Position) : Flow {
		throw "Not implemented for this target: getFileContentBinary";
		return ConstantString("", pos);
	}

	public function setFileContent(args : FlowArray<Flow>, pos : Position) : Flow {
		#if (flash || js || neko)
			throw "Use setFileContentUTF16 via QtByteRunner: setFileContent";
			return ConstantBool(false, pos);
		#else
			var path = FlowUtil.getString(args[0]);
			var content = FlowUtil.getString(args[1]);
			try {
				sys.io.File.saveContent(path, content);
			} catch (e : Dynamic) {
				Errors.print(e);
				return ConstantBool(false, pos);
			}
			return ConstantBool(true, pos);
		#end
	}

	public function setFileContentUTF16(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}

	public function setFileContentBinary(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}

	public function setFileContentBytes(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}
	
	public function writeProcessStdin(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}

	public function killProcess(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}

	public function startProcess(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}

	public function runProcess(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}

	public function startDetachedProcess(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantBool(false, pos);
	}

	public function getTargetName(args : FlowArray<Flow>, pos : Position) : Flow {
		return ConstantString(
			#if flash
			"flash"
			#elseif neko
			"neko"
			#elseif hl
			"hashlink"
			#elseif js
			"js"
			#elseif cpp
			"cpp"
			#elseif java
			"java"
			#end
		, pos);
	}

	// Save a key/value pair. Persistent on the client.
	public function setKeyValue(args : FlowArray<Flow>, pos : Position) : Flow {
		var key = FlowUtil.getString(args[0]);
		var value = FlowUtil.getString(args[1]);
		#if flash
			if (!HaxeRuntime.wideStringSafe(value)) {
				// OK, we can not encode this! So better to fail early
				Errors.print("Unsafe string, can not save key: " + key);
				return ConstantBool(false, pos);
			}
			return ConstantBool(setValue(key, value), pos);
		#elseif neko
			var output = sys.io.File.write(key, false);
			output.writeString(value);
			output.close();
			return ConstantBool(false, pos);
		#else
			// TODO: Implement this for other targets
			return ConstantBool(false, pos);
		#end
	}

	// Get a stored key/value pair. Persistent on the client
	public function getKeyValue(args : FlowArray<Flow>, pos : Position) : Flow {
		var key = FlowUtil.getString(args[0]);
		var defaultValue = FlowUtil.getString(args[1]);
		var value = defaultValue;
		#if flash
		value = getValue(key);
		if (value == null) {
			value = defaultValue;
		}
		#end
		return ConstantString(value, pos);
	}

	public function removeKeyValue(args : FlowArray<Flow>, pos : Position) : Flow {
		var key = FlowUtil.getString(args[0]);
		throw "removeKeyValue: This operation is not supported on this target";
		return ConstantVoid(pos);
	}

	public function setSessionKeyValue(args : FlowArray<Flow>, pos : Position) : Flow {
		var key = FlowUtil.getString(args[0]);
		var value = FlowUtil.getString(args[1]);
		throw "setSessionKeyValue: This operation is not supported on this target";
		return ConstantBool(false, pos);
	}

	public function getSessionKeyValue(args : FlowArray<Flow>, pos : Position) : Flow {
		var key = FlowUtil.getString(args[0]);
		var defaultValue = FlowUtil.getString(args[1]);
		var value = defaultValue;
		throw "getSessionKeyValue: This operation is not supported on this target";
		return ConstantString(value, pos);
	}

	public function removeSessionKeyValue(args : FlowArray<Flow>, pos : Position) : Flow {
		var key = FlowUtil.getString(args[0]);
		throw "removeSessionKeyValue: This operation is not supported on this target";
		return ConstantVoid(pos);
	}

	public function clearTrace(args : FlowArray<Flow>, pos : Position) : Flow {
		//haxe.Log.clear();
		return ConstantVoid(pos);
	}
	public function printCallstack(args : FlowArray<Flow>, pos : Position) : Flow {
		interpreter.printCallstack();
		return ConstantVoid(pos);
	}
    public function captureCallstack(args : FlowArray<Flow>, pos : Position) : Flow {
        // stub
        return ConstantVoid(pos);
    }
    public function captureCallstackItem(args : FlowArray<Flow>, pos : Position) : Flow {
        // stub
        return ConstantVoid(pos);
    }
    public function impersonateCallstackItem(args : FlowArray<Flow>, pos : Position) : Flow {
        // stub
        return ConstantVoid(pos);
    }
    public function impersonateCallstackFn(args : FlowArray<Flow>, pos : Position) : Flow {
        // stub
        return ConstantVoid(pos);
    }
    public function impersonateCallstackNone(args : FlowArray<Flow>, pos : Position) : Flow {
        // stub
        return ConstantVoid(pos);
    }

	public function failWithError(args : FlowArray<Flow>, pos : Position) : Flow {
		throw ("Runtime failure: " + FlowUtil.getString(args[0]));
		return ConstantVoid(pos);
	}
	
	public function number2double(args : FlowArray<Flow>, pos : Position) : Flow {
		var number : Flow = args[0];
		switch (number) {
		case ConstantI32(value, pos): return ConstantDouble(I2i.toInt(value), pos);
		case ConstantDouble(value, pos): return number;
		default: throw "Not a number:" + Prettyprint.print(number);
		}		
	}

	public function fromBinary(args : FlowArray<Flow>, pos : Position) : Flow {
		return args[0];
	}

	public function toBinary(args : FlowArray<Flow>, pos : Position) : Flow {
		// This target has only one byte per one char for strings
		// so toBinary cannot work for now
		throw "toBinary: This operation is not supported on this target";
		return ConstantVoid(pos);
	}

	public function stringbytes2double(args : FlowArray<Flow>, pos : Position) : Flow {
		throw "toBinary: This operation is not supported on this target";
		return ConstantVoid(pos);
	}

	public function stringbytes2int(args : FlowArray<Flow>, pos : Position) : Flow {
		throw "toBinary: This operation is not supported on this target";
		return ConstantVoid(pos);
	}

	public function getTotalMemoryUsed(args : FlowArray<Flow>, pos : Position) : Flow {
		#if flash
		return ConstantDouble(flash.system.System.totalMemory, pos);
		#end
		return ConstantDouble(0.0, pos);
	}

	public function addPlatformEventListener(args : FlowArray<Flow>, pos : Position) : Flow {
		//NOP
		return NativeClosure(0, function(flow, pos) {
			return ConstantVoid(pos);
		}, pos);
	}

	public function addCameraPhotoEventListener(args : FlowArray<Flow>, pos : Position) : Flow {
		// not implemented yet for js/flash
		return NativeClosure(0, function(flow, pos) {
			return ConstantVoid(pos);
		}, pos);
	}
	public function addCameraVideoEventListener(args : FlowArray<Flow>, pos : Position) : Flow {
		// not implemented yet for js/flash
		return NativeClosure(0, function(flow, pos) {
			return ConstantVoid(pos);
		}, pos);
	}

	public function md5(args : FlowArray<Flow>, pos : Position) : Flow {
		var b = new StringBuf();
		var c = string2utf8(args, pos);
		switch(c) {
			case ConstantArray(value, pos1) : {
			for (i in value)
				switch(i) {
					case ConstantI32(value, pos2) : b.addChar(value);
					default : throw "md5 array convert error";
				}
			}
			default : throw "md5 string convert error";
		}
		return ConstantString(Md5.encode(b.toString()), pos);
	}

	#if flash
	static function getValue<T>(n : String) : T {
		var v : T = null;
		var cookie = getState();
		if (cookie != null) {
			v = Reflect.field(cookie.data, n);
		}
		return v;
	}

	static function setValue<T>(n : String, v : T) : Bool {
		try {
			var cookie = getState();
			if (cookie == null) {
				return false;
			}
			Reflect.setField(cookie.data, n, v);
			if (cookie.flush() != flash.net.SharedObjectFlushStatus.PENDING) {
				return true;
			}
			return false;
		} catch (e : Dynamic) {
			return false;
		}
	}

	static var state : flash.net.SharedObject;

	static function getState() : flash.net.SharedObject {
		if (state != null) {
			return state;
		}
		try {
			state = flash.net.SharedObject.getLocal("flow", "/");
			return state;
		} catch (e : Dynamic) {
			return null;
		}
	}
	#end
	}
