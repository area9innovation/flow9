import HaxeRuntime;
import NativeTime;
import haxe.ds.Vector;
import haxe.CallStack;

#if js
import js.Browser;
import js.BinaryParser;
import JSBinflowBuffer;
import JsMd5;
#end

#if (flow_nodejs || nwjs)
import js.Node.process;
import js.node.Fs;
import js.node.ChildProcess;
import js.node.Buffer;

#if flow_webmodule
import node.express.Request;
import node.express.Response;
#end
#end

#if flash
import flash.utils.ByteArray;
#end

class Native {
	public static var isNew : Bool = Util.getParameter("new") == "1";
#if (js && flow_nodejs && flow_webmodule)
	static var webModuleResponseText = "";
#end
	public static function println(arg : Dynamic) : Dynamic {
		var s = toString(arg, true);
		#if flash
			try {
				var qoute = StringTools.replace(s, '\\', '');
				flash.external.ExternalInterface.call("console.log", qoute);
			} catch (e : Dynamic) {
				trace(s);
			}
		#elseif neko
			Sys.println(s);
		#elseif (js && ((flow_nodejs && !flow_webmodule) || nwjs))
			Util.println(arg);
		#elseif (js && flow_nodejs && flow_webmodule)
			webModuleResponseText += arg + "\n";
		#elseif js
			untyped console.log(s);
		#else
			Errors.report(s);
		#end
		return null;
	}

	public static inline function debugStopExecution() : Void {
		#if js
			//If dev tools are available stops execution at this line
			js.Lib.debug();
		#end
	}

	public static function genericCompare(a : Dynamic, b : Dynamic) : Int {
		return HaxeRuntime.compareByValue(a, b);
	}

	public static function hostCall(name : String, args: Array<Dynamic>) : Dynamic {
		var result = null;

		#if flash
			if (flash.external.ExternalInterface.available) {
				try {
					result = flash.external.ExternalInterface.call(name,
						args[0],
						args[1],
						args[2],
						args[3],
						args[4]
					);
				} catch (e: Dynamic) {
					trace(e);
				}
			} else {
				if (!complainedMissingExternal) {
					complainedMissingExternal = true;
					trace("No external interface available");
				}
				// Not much to do, dude
			}
		#elseif (js && !flow_nodejs)
			try {
				// Handle namespaces
				var name_parts = name.split(".");
				var fun : Dynamic = untyped Browser.window;
				var fun_nested_object : Dynamic = fun;
				for (i in 0...name_parts.length) {
					fun_nested_object = fun;
					fun = untyped fun[name_parts[i]];
				}
				result = fun.call(fun_nested_object, args[0], args[1], args[2], args[3], args[4]);
			} catch( e : Dynamic) {
				Errors.report(e);
			}
		#end

		return result;
	}

	public static function importJSModule(arg : Dynamic, cb : Dynamic -> Void) : Void {
		#if (js && !flow_nodejs)
			try {
				var module = untyped __js__("arg + encodeURI('\\nconst importJSModuleVersion =' + Math.random())");
				//untyped __js__("eval(\"import(module).then((v) => { return v && v.default ? v.default : v; }).then((v) => { cb(v); }).catch((e) => { Errors.report(e); cb(null); })\")");
				untyped __js__("(new Function(\"import(module).then((v) => { return v && v.default ? v.default : v; }).then((v) => { cb(v); }).catch((e) => { Errors.report(e); cb(null); })\"))()");
			} catch( e : Dynamic) {
				Errors.report(e);
				cb(null);
			}
		#else
			cb(null);
		#end
	}

	static var complainedMissingExternal : Bool = false;

	public static function hostAddCallback(name : String, cb : Void -> Dynamic) : Dynamic {
		#if flash
			try {
				flash.external.ExternalInterface.addCallback(name, cb);
			} catch (e: Dynamic) {
				trace(e);
			}
		#elseif (js && !flow_nodejs)
			untyped Browser.window[name] = cb;
		#end

		return null;
	}

#if (js && !flow_nodejs)
	private static function createInvisibleTextArea() {
		var textArea = Browser.document.createElement("textarea");
		// Place in top-left corner of screen regardless of scroll position.
		// Ensure it has a small width and height. Setting to 1px / 1em
		// doesn't work as this gives a negative w/h on some browsers.
		// We don't need padding, reducing the size if it does flash render.
		// Clean up any borders.
		// Avoid flash of white box if rendered for any reason.
		textArea.style.cssText = "position:fixed;top:0px;left:0px;width:2em;height:2em;padding:0px;border:none;outline:none;boxShadow:none;background:transparent;";
		Browser.document.body.appendChild(textArea);
		return textArea;
	}

	public static function evaluateObjectSize(object : Dynamic) : Int {
		var bytes = 0;
		untyped __js__("
			var objectList = [];
			var stack = [object];

			while (stack.length) {
				var value = stack.pop();

				if (typeof value === 'boolean') {
					bytes += 4;
				}
				else if ( typeof value === 'string' ) {
					bytes += value.length * 2;
				}
				else if ( typeof value === 'number' ) {
					bytes += 8;
				}
				else if
				(
					typeof value === 'object'
					&& objectList.indexOf( value ) === -1
				)
				{
					objectList.push( value );

					if (Object.prototype.toString.call(value) != '[object Array]'){
					   for(var key in value) bytes += 2 * key.length;
					}

					for( var i in value ) {
						stack.push( value[ i ] );
					}
				}
			}
		");
		return bytes;
	}

	public static function usedJSHeapSize() : Int {
		try {
			return untyped Browser.window.performance.memory.usedJSHeapSize;
		} catch (e : Dynamic) {
			untyped console.log("Warning! performance.memory.usedJSHeapSize is not implemented in this target");
			return 0;
		}
	}

	public static function totalJSHeapSize() : Int {
		try {
			return untyped Browser.window.performance.memory.totalJSHeapSize;
		} catch (e : Dynamic) {
			untyped console.log("Warning! performance.memory.totalJSHeapSize is not implemented in this target");
			return 0;
		}
	}

	// TODO : Implement native for performance.measureUserAgentSpecificMemory() as well, when it will be supported by browsers.
#end

	private static function copyAction(textArea : Dynamic) {
		#if (js && !flow_nodejs)
			try {
				untyped textArea.select();
				var successful = Browser.document.execCommand('copy');
				if (!successful) Errors.warning('Browser "copy" command execution was unsuccessful');
			} catch (err : Dynamic) {
				Errors.report('Oops, unable to copy');
			}
		#end
	}

	public static function setClipboard(text: String) : Void {
		#if flash
			flash.system.System.setClipboard(text);
		#elseif (js && !flow_nodejs)
			// save current focus
			var focusedElement = Browser.document.activeElement;

			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.setData) { // IE
				untyped Browser.window.clipboardData.setData('Text', text);
			} else if (untyped Browser.navigator.clipboard && untyped Browser.navigator.clipboard.writeText) { // Chrome Async Clipboard API
				untyped Browser.navigator.clipboard.writeText(text);
			} else {
				var textArea = createInvisibleTextArea();
				untyped textArea.value = text;

				// see https://trello.com/c/rBuXiyWM/194-text-form-content-copypaste-doesnt-work-in-some-cases
				if (text.length < 10000 ) {
					copyAction(textArea);
					Browser.document.body.removeChild(textArea);
				} else {
					untyped setTimeout(function () {
						copyAction(textArea);
						Browser.document.body.removeChild(textArea);
					}, 0);
				}
			}

			// restore focus to the previous state
			focusedElement.focus();

			// If paste command fails in getClipboard()
			// we still have consistent value from here
			clipboardData = text;
		#end
	}

	public static var clipboardData = "";
	public static var clipboardDataHtml = "";

	public static function getClipboard() : String {
		#if (js && !flow_nodejs)
			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.getData) { // IE
				return untyped Browser.window.clipboardData.getData("Text");
			}

			if (isNew) {
				return clipboardData;
			}

			// save current focus
			var focusedElement = Browser.document.activeElement;

			var result = clipboardData;

			var textArea = createInvisibleTextArea();
			untyped textArea.value = '';
			untyped textArea.select();

			try {
				#if js
				untyped __js__("
					if (typeof RenderSupport !== 'undefined') {
						RenderSupport.disablePasteEventListener();
					}
				");
				#end

				var successful = Browser.document.execCommand('paste');

				if (successful) {
					result = untyped textArea.value;
				} else {
					Errors.warning('Browser "paste" command execution was unsuccessful');
				}
			} catch (err : Dynamic) {
				Errors.report('Oops, unable to paste');
			}

			#if js
			untyped __js__("
				if (typeof RenderSupport !== 'undefined') {
					RenderSupport.enablePasteEventListener();
				}
			");
			#end

			Browser.document.body.removeChild(textArea);

			// restore focus to the previous state
			untyped __js__("
				if (typeof RenderSupport !== 'undefined') {
					RenderSupport.deferUntilRender(function() {
						focusedElement.focus();
					});
				} else {
					focusedElement.focus();
				}
			");
			return result;
		#else
			return "";
		#end
	}

	public static function getClipboardToCB(callback : String->Void) : Void {
		#if (js && !flow_nodejs)
			if (untyped Browser.window.clipboardData && untyped Browser.window.clipboardData.getData) { // IE
				callback(untyped Browser.window.clipboardData.getData("Text"));
			} else if (untyped navigator.clipboard && untyped navigator.clipboard.readText) {
				untyped navigator.clipboard.readText().then(callback, function(e){
					Errors.print(e);
				});
			} else {
				callback(clipboardData);
			}
		#else
			callback("");
		#end
	}

	public static function setCurrentDirectory(path : String) : Void {
		// do nothing
	}

	public static function getCurrentDirectory() : String {
		return "";
	}

	public static function getClipboardFormat(mimetype: String) : String {
		if (mimetype == "html" || mimetype == "text/html") return clipboardDataHtml;
		else return "";
	}

	public static function getApplicationPath() : String {
		return "";
	}

	public static inline function toString(value : Dynamic, ?keepStringEscapes : Bool = false) : String {
		return HaxeRuntime.toString(value, keepStringEscapes);
	}

	public static function toStringForJson(value : String) : String {
		return HaxeRuntime.toStringForJson(value);
	}

	public static inline function gc() : Void {
		#if flash
			// unsupported technique that seems to force garbage collection
			// try {
			//	new flash.net.LocalConnection().connect('foo');
			//	new flash.net.LocalConnection().connect('foo');
			// } catch (e:Dynamic) {}
			flash.system.System.pauseForGCIfCollectionImminent(0.1);
		#end
		// NOP
	}

	public static inline function addHttpHeader(data: String) : Void {
		#if (flow_nodejs && flow_webmodule)
		var headerParts  = data.split(": ");
		if (headerParts.length == 2) {
			untyped response.set(headerParts[0], headerParts[1]);
		}
		#end
	}

	public static inline function getCgiParameter(name: String) : String {
		// NOP
		return "";
	}

	public static inline function subrange<T>(arr : Array<T>, start : Int, len : Int) : Array<T> {
		if (start < 0 || len < 1)
			return [];
		else
			return arr.slice(start, start + len);
	}

	public static inline function removeIndex<T>(src : Vector<T>, index : Int) : Vector<T> {
		if (index >= 0 && index < src.length) {
			var dst = new Vector(src.length - 1);
			var i = 0;

			while (i < index) {
				dst[i] = src[i];
				i++;
			}
			while (i < dst.length) {
				dst[i] = src[i + 1];
				i++;
			}

			return dst;
		} else {
			return src;
		}
	}

	public static function isArray(a : Dynamic) : Bool {
		return HaxeRuntime.isArray(a);
	}

	public static function isSameStructType(a : Dynamic, b : Dynamic) : Bool {
		return HaxeRuntime.isSameStructType(a,b);
	}

	public static function isSameObj(a : Dynamic, b : Dynamic) : Bool {
	#if js
		if (a == b)
			return true;
		// TODO: fix js generator so that fieldless structs have only one instance
		#if (readable)
		if (a != null && b != null &&
			Reflect.hasField(a, "_name") && a._name == b._name &&
			HaxeRuntime._structargs_.get(HaxeRuntime._structids_.get(a._name)).length == 0)
			return true;
		#else
		if (a != null && b != null &&
			Reflect.hasField(a, "_id") && a._id == b._id &&
			HaxeRuntime._structargs_.get(a._id).length == 0)
			return true;
		#end
		return false;
	#else
		return a == b;
	#end
	}

	#if !js
	public static inline function length<T>(arr : Array<T>) : Int {
		return arr.length;
	}
	#else
	// Notice: We have to rename because .length is a reserved property on functions! This is a haXe bug
	public static inline function length__<T>(arr : Array<T>) : Int {
		return arr.length;
	}
	#end

	public static inline function strlen(s : String) : Int {
		return s.length;
	}

	public static inline function strIndexOf(str : String, substr : String) : Int {
		return str.indexOf(substr, 0);
	}

	public static inline function strRangeIndexOf(str : String, substr : String, start : Int, end : Int) : Int {
		/*
		  Searching within a range suggest that we can stop searching inside long string after end position.
		  This makes searching a bit faster. But JavaScript has no means for this.
		  We have only way to do this - make a copy of string within the range and search there.
		  It is significantly faster for a long string comparing to simple `indexOf()` for whole string.
		  But copying is not free. Since copy is linear in general and search is linear in general too,
		  we can select method depending on source string length and range width.
		*/

		if (str == "" || start < 0)
			return -1;

		var s = start;
		var e = (end > str.length || end < 0) ? str.length : end;

		if (substr.length == 0) {
			return 0;
		} else if (substr.length > e - s) {
			return -1;
		}
		if (2*(e-s) < str.length - s) {
			if (end >= str.length) return str.indexOf(substr, start);
			var rv = str.substr(start, end-start).indexOf(substr, 0);
			return (rv < 0) ? rv : start+rv;
		} else {
			var pos = str.indexOf(substr, s);
			var finish = pos + substr.length - 1;
			return (pos < 0) ? -1 : (finish < e ? pos : -1);
		}
	}

	public static inline function substring(str : String, start : Int, end : Int) : String {
		var s = str.substr((start), (end));
		#if js
		// It turns out that Chrome does NOT copy strings out when doing substring,
		// and thus we never free the original string
		if (2 * s.length < str.length) {
			// So if our slice is "small", we explicitly force a copy like this
			return untyped (' ' + s).slice(1);
		} else {
			return s;
		}
		#else
		return s;
		#end
	}

	public static inline function cloneString(str : String) : String {
		#if js
		return untyped (' ' + str).slice(1);
		#else
		return str;
		#end
	}

	public static inline function toLowerCase(str : String) : String {
		return str.toLowerCase();
	}

	public static inline function toUpperCase(str : String) : String {
		return str.toUpperCase();
	}

	#if js
	public static inline function strReplace(str : String, find : String, replace : String) : String {
		return StringTools.replace(str, find, replace);
	}
	#end

	public static function string2utf8(str : String) : Array<Int> {
		var bytes = haxe.io.Bytes.ofString(str);
		var a : Array<Int> = [for (i in 0...bytes.length) bytes.get(i)];
		return a;
	}

	public static function s2a(str : String) : Array<Int> {
		var arr : Array<Int> = new Array();
		for (i in 0...str.length)
			arr.push((str.charCodeAt(i)));

		return arr;
	}

	public static function list2string(h : Dynamic) : String {
		var res : String = "";
		while (Reflect.hasField(h, "head")) {
			var s : String = Std.string(h.head);
			res = s + res;
			h = h.tail;
		}
		return res;
	}

	public static function list2array(h : Dynamic) : Array<Dynamic> {
		var cnt = 0;
		var p: Dynamic = h;
		while (Reflect.hasField(p, "head")) {
			cnt += 1;
			p = p.tail;
		}
		if (cnt == 0) {
		  return untyped Array(0);
		}
		var result = untyped Array(cnt);

		p = h;
		cnt -= 1;
		while (Reflect.hasField(p, "head")) {
			result[cnt] = p.head;
			cnt -= 1;
			p = p.tail;
		}
		return result;
	}

	public static inline function bitXor(a : Int, b : Int) : Int {
		return a ^ b;
	}

	public static inline function bitAnd(a : Int, b : Int) : Int {
		return a & b;
	}

	public static inline function bitOr(a : Int, b : Int) : Int {
		return a | b;
	}

	public static inline function bitUshr(a : Int, b : Int) : Int {
		return a >>> b;
	}

	public static inline function bitShl(a : Int, b : Int) : Int {
		return a << b;
	}


	public static inline function bitNot(a : Int) : Int {
		return ~a;
	}

	public static inline function concat<T>(arr1 : Array<T>, arr2 : Array<T>) : Array<T> {
		return arr1.concat(arr2);
	}

	// Some browsers want concat for arrayPush. Testing shows that IE, Edge & Firefox prefer the slice,
	public static var useConcatForPush : Bool = #if js Platform.isChrome || Platform.isSafari; #else false; #end

	public static function replace<T>(arr : Array<T>, i : Int, v : T) : Array<T> {
		if (arr == null) {
			return new Array();
		} else if (i < 0 || i > arr.length) {
			println("replace: array index is out of bounds: " + toString(i) + " of " + toString(arr.length));
			println(CallStack.toString(CallStack.callStack()));
			return arr;
		} else if (i == arr.length && useConcatForPush) {
			return arr.concat([v]);
		} else {
			var new_arr = arr.slice(0, arr.length);
			new_arr[i] = v;
			return new_arr;
		}
	}

	public static function map<T, U>(values : Array<T>, clos : T -> U) : Array<U> {
		var n = values.length;
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = clos(values[i]);
		}
		return result;
	}

	public static function iter<T>(values : Array<T>, clos : T -> Void) : Void {
		for (v in values) {
			clos(v);
		}
	}

	public static function mapi<T, U>(values : Array<T>, clos : Int -> T -> U) : Array<U> {
		var n = values.length;
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = clos(i, values[i]);
		}
		return result;
	}

	public static function iteri<T>(values : Array<T>, clos : Int -> T -> Void) : Void {
		var i : Int = 0;
		for (v in values) {
			clos(i, v);
			i++;
		}
	}

	public static function iteriUntil<T>(values : Array<T>, clos : Int -> T -> Bool) : Int {
		var i : Int = 0;
		for (v in values) {
			if (clos(i, v)) {
				return i;
			}
			i++;
		}
		return i;
	}

	public static function fold<T, U>(values : Array<T>, init : U, fn : U -> T -> U) : U {
		for (v in values) {
			init = fn(init, v);
		}
		return init;
	}

	public static function foldi<T, U>(values : Array<T>, init : U, fn : Int -> U -> T -> U) : U {
		var i = 0;
		for (v in values) {
			init = fn(i, init, v);
			i++;
		}
		return init;
	}

	public static function filter<T>(values : Array<T>, clos : T -> Bool) : Array<T> {
		var result = new Array();
		for (v in values) {
			if (clos(v))
				result.push(v);
		}
		return result;
	}

	public static function filtermapi<T>(values : Array<T>, clos : Int -> T -> Dynamic) : Array<T> {
		var result = new Array();
		var n = values.length;
		for (i in 0...n) {
			var v = values[i];
			var maybe = clos(i, v);
			var fields = Reflect.fields(maybe);
			// Check if there is both an _id and a value field of some kind: Then it is some
			if (fields.length == 2) {
				for (f in fields) {
					// The ID field of a struct is named _id, so skip that one
					if (f != "_id") {
						var val = Reflect.field(maybe, f);
						result.push(val);
					}
				}
			}
		}
		return result;
	}

	public static function mapiM<T>(values : Array<T>, clos : Int -> T -> Dynamic) : Dynamic {
		var result = new Array();
		var n = values.length;
		for (i in 0...n) {
			var v = values[i];
			var maybe = clos(i, v);
			var fields = Reflect.fields(maybe);
			// Check if there is both an _id and a value field of some kind: Then it is Some
			if (fields.length == 2) {
				for (f in fields) {
					// The ID field of a struct is named _id, so skip that one
					if (f != "_id") {
						var val = Reflect.field(maybe, f);
						result.push(val);
					}
				}
			} else {
				return maybe;
			}
		}
		return makeStructValue("Some", [ result ], makeStructValue("IllegalStruct", [], null));
	}

	public static inline function random() : Float {
		return Math.random();
	}

	public static inline function deleteNative(clip : Dynamic) : Void {
		if (untyped clip != null && !clip.destroyed) {
			if (clip.destroy != null) {
				untyped clip.destroy({children: true, texture: true, baseTexture: true});
			}

			if (clip.parent != null && clip.parent.removeChild != null) {
				clip.parent.removeChild(clip);
			}

			if (!Platform.isIE && untyped clip.nativeWidget != null) {
				untyped clip.nativeWidget.style.display = 'none';
			}

			#if js
			untyped __js__("
				if (typeof RenderSupport !== 'undefined' && (clip.nativeWidget != null || clip.accessWidget != null)) {
					RenderSupport.once('drawframe', function() {
						DisplayObjectHelper.deleteNativeWidget(clip);
					});
				}
			");
			#end

			untyped clip.destroyed = true;
		}
	}

	public static function timestamp() : Float {
		return NativeTime.timestamp();
	}

	// native getCurrentDate : () -> [Date] = Native.getCurrentDate;
	public static function getCurrentDate() : Dynamic {
		var date = Date.now();
		return makeStructValue("Date", [ date.getFullYear(), date.getMonth() + 1, date.getDate() ], makeStructValue("IllegalStruct", [], null));
	}

	#if js
	private static var DeferQueue : Array< Void -> Void > = new Array();
	private static var deferTolerance : Int = 250;
	private static var deferActive : Bool = false;
	public static function defer(cb : Void -> Void) : Void {
		var fn = function() {
			var t0 = NativeTime.timestamp();

			// we shouldn't block the thread in JS for long time because it freeze UI
			while (NativeTime.timestamp() - t0 < Native.deferTolerance && DeferQueue.length > 0) {
				var f = DeferQueue.shift();
				f();
			}
			if (DeferQueue.length > 0) {
				untyped __js__("setTimeout(fn, 42);");
			} else {
				Native.deferActive = false;
			}
		}

		if (Native.deferActive) {
			DeferQueue.push(cb);
		} else {
			Native.deferActive = true;
			DeferQueue.push(cb);
			untyped __js__("setTimeout(fn, 0);");
		}
	}
	#end

	public static function setInterval(ms : Int, cb : Void -> Void) : Void -> Void {
		#if !neko
		#if flash
		var cs = haxe.CallStack.callStack();
		#end
		var fn = function() {
			try {
				cb();
			} catch (e : Dynamic) {
				var stackAsString = "n/a";
				#if flash
					stackAsString = Assert.callStackToString(cs);
				#end
				var actualStack = Assert.callStackToString(haxe.CallStack.callStack());
				var crashInfo = e + "\nStack at timer creation:\n" + stackAsString + "\nStack:\n" + actualStack;
				println("FATAL ERROR: timer callback: " + crashInfo);
				Assert.printStack(e);
				Native.callFlowCrashHandlers("[Timer Handler]: " + crashInfo);
			}
		};

		var t = untyped __js__("setInterval(fn, ms);");
		return function() { untyped __js__("clearInterval(t);"); };
		#else
		cb();
		return function() {};
		#end
	}

	public static function interruptibleTimer(ms : Int, cb : Void -> Void) : Void -> Void {
		#if !neko
		#if flash
		var cs = haxe.CallStack.callStack();
		#end
		var fn = function() {
			try {
				cb();
			} catch (e : Dynamic) {
				var stackAsString = "n/a";
				#if flash
					stackAsString = Assert.callStackToString(cs);
				#end
				var actualStack = Assert.callStackToString(haxe.CallStack.callStack());
				var crashInfo = e + "\nStack at timer creation:\n" + stackAsString + "\nStack:\n" + actualStack;
				println("FATAL ERROR: timer callback: " + crashInfo);
				Assert.printStack(e);
				Native.callFlowCrashHandlers("[Timer Handler]: " + crashInfo);
			}
		};

		#if js
		// TO DO : may be the same for all short timers
		if (ms == 0) {
			var alive = true;
			defer(function () {if (alive) fn(); });
			return function() { alive = false; };
		}
		#end

		var t = untyped __js__("setTimeout(fn, ms);");
		return function() { untyped __js__("clearTimeout(t);"); };
		#else
		cb();
		return function() {};
		#end
	}

	public static function timer(ms : Int, cb : Void -> Void) : Void {
		interruptibleTimer(ms, cb);
	}

	public static inline function sin(a : Float) : Float {
		return Math.sin(a);
	}

	public static inline function asin(a : Float) : Float {
		return Math.asin(a);
	}

	public static inline function acos(a : Float) : Float {
		return Math.acos(a);
	}

	public static inline function atan(a : Float) : Float {
		return Math.atan(a);
	}

	public static inline function atan2(a : Float, b : Float) : Float {
		return Math.atan2(a, b);
	}

	public static inline function exp(a : Float) : Float {
		return Math.exp(a);
	}

	public static inline function log(a : Float) : Float {
		return Math.log(a);
	}

	public static function enumFromTo(from : Int, to : Int) : Array<Int> {
		var n = to - from + 1;
		if (n <= 0) {
			return untyped Array(0);
		}
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = i + from;
		}
		return result;
	}

	public static function getAllUrlParameters() : Array<Array<String>> {
		var parameters : Map<String, String> = new Map();

		#if flash
		var raw = flash.Lib.current.loaderInfo.parameters;
		var keys = Reflect.fields(raw);
		for (key in keys) {
			parameters.set(key, Reflect.field(raw, key));
		}
		#elseif js
			#if (flow_nodejs && flow_webmodule)
			var params : Array<String> = [];
			var parametersMap = {};
			if (untyped request.method == "GET") {
				parametersMap = untyped request.query;
			} else {
				parametersMap = untyped request.body;
			}
			untyped Object.keys(untyped parametersMap).map(function(key, index) {
				params.push(key + "=" + untyped parametersMap[key]);
			});
			#elseif (flow_nodejs)
			var params = process.argv.slice(2);
			#elseif (nwjs)

			// Command line parameters
			var params1 = nw.Gui.app.argv;

			// Query string parameters from url query string (e.g., from the app manifest file - package.json)
			// (first character in search string is "?", so we skip it)
			var paramString2 = js.Browser.window.location.search.substring(1);
			var params2 : Array<String> = paramString2.split("#")[0].split("&");

			var params = params1.concat(params2);

			#else
			var paramString = js.Browser.window.location.search.substring(1);
			var params : Array<String> = paramString.split("&");
			#end
			for (keyvalue in params) {
				var pair = keyvalue.split("=");
				parameters.set(pair[0], (pair.length > 1)? StringTools.urlDecode(pair[1]) : "");
			}
		#end

		var i = 0;
		var result : Array<Array<String>> = new Array<Array<String>>();
		for (key in parameters.keys()) {
			var keyvalue = new Array<String>();
			keyvalue[0] = key;
			keyvalue[1] = parameters.get(key);

			result[i] = keyvalue;
			i++;
		}
		#if (js)
		untyped __js__("if (typeof predefinedBundleParams != 'undefined') {result = mergePredefinedParams(result, predefinedBundleParams);}");
		#end
		  return result;
	}

	public static function getUrlParameter(name : String) : String {
		var value = "";

	#if (js && flow_nodejs && flow_webmodule)
		if (untyped request.method == "GET") {
			value = untyped request.query[name];
		} else if (untyped request.method == "POST") {
			value = untyped request.body[name];
		}
	#else
		value = Util.getParameter(name);
	#end

		return value != null ? value : "";
	}

	#if js
	public static function isTouchScreen() : Bool {
		#if (flow_nodejs || nwjs)
		return false;
		#else
		return Platform.isMobile || untyped __js__("(('ontouchstart' in window) || (window.DocumentTouch && document instanceof DocumentTouch) || window.matchMedia('(pointer: coarse)').matches)");
		#end
	}
	#end

	public static inline function getTargetName() : String {
		#if flash
			return "flash";
		#elseif neko
			return "neko";
		#elseif js
			#if (flow_nodejs && flow_webmodule)
			return "js,nodejs,webmodule";
			#elseif (flow_nodejs && jslibrary)
			return "js,nodejs,jslibrary";
			#elseif flow_nodejs
			return "js,nodejs";
			#elseif nwjs
			return "js,nwjs";
			#elseif jslibrary
			return "js,jslibrary";
			#else
			var testdiv = Browser.document.createElement("div");
			testdiv.style.height = "1in";
			testdiv.style.width = "1in";
			testdiv.style.left = "-100%";
			testdiv.style.top = "-100%";
			testdiv.style.position = "absolute";
			Browser.document.body.appendChild(testdiv);
			var dpi = testdiv.offsetHeight * js.Browser.window.devicePixelRatio;
			Browser.document.body.removeChild(testdiv);
			if (!Platform.isMobile) {
				return "js,pixi,dpi=" + dpi;
			} else {
				return "js,pixi,mobile,dpi=" + dpi;
			}
			#end
		#else
			return "unknown";
		#end
	}

	#if js
	private static function isIE() : Bool {
	#if (flow_nodejs || nwjs)
		return false;
		#else
		return js.Browser.window.navigator.userAgent.indexOf("MSIE") >= 0;
		#end
	}
	#end

	// Save a key/value pair. Persistent on the client.
	public static function setKeyValue(k : String, v : String) : Bool {
		#if js
		return setKeyValueJS(k, v, false);
		#elseif flash
		return setValue(k, v);
		#else
		return false;
		#end
	}

	// Get a stored key/value pair. Persistent on the client
	public static function getKeyValue(key : String, def : String) : String {
		#if js
		return getKeyValueJS(key, def, false);
		#elseif flash
		var value = getValue(key);
		if (value == null) {
			value = def;
		}
		return value;
		#else
		return def;
		#end
	}

	// Removes a stored key/value pair.
	public static function removeKeyValue(key : String) : Void {
		var useMask = StringTools.endsWith(key, "*");
		var mask = "";
		if (useMask) mask = key.substr(0, key.length-1);

		#if js
		removeKeyValueJS(key, false);
		#elseif flash
		try {
			var cookie = getState();
			if (cookie == null) return;
			if (useMask) {
				var arr = Reflect.fields(cookie.data);
				for (i in 0...arr.length)
					if (StringTools.startsWith(arr[i], mask))
						Reflect.deleteField(cookie.data, arr[i]);
			} else {
				Reflect.deleteField(cookie.data, key);
			}
			cookie.flush();
		} catch (e : Dynamic) {}

		#else
		#end
	}

	// Remove all stored key/value pairs.
	public static function removeAllKeyValues() : Void {
		#if js
		removeAllKeyValuesJS(false);
		#else
		return;
		#end
	}

	// Get list of stored keys.
	public static function getKeysList() : Array<String> {
		#if js
		return getKeysListJS(false);
		#else
		return [];
		#end
	}

	// Save a session key/value pair. Persistent on the client for the duration of the session
	public static function setSessionKeyValue(k : String, v : String) : Bool {
		#if js
		return setKeyValueJS(k, v, true);
		#else
		return false;
		#end
	}

	// Save a session key/value pair.
	public static function getSessionKeyValue(key : String, def : String) : String {
		#if js
		return getKeyValueJS(key, def, true);
		#else
		return def;
		#end
	}

	// Removes a session key/value pair.
	public static function removeSessionKeyValue(key : String) : Void {
		#if js
		removeKeyValueJS(key, true);
		#end
	}

	#if flash
	static function getValue(n : String) : String {
		var v : String = null;
		var cookie = getState();
		if (cookie != null) {
			v = Reflect.field(cookie.data, n);
		}
		return v;
	}

	static function setValue(n : String, v : String) : Bool {
		try {
			var cookie = getState();
			if (cookie == null) {
				return false;
			}
			if (!HaxeRuntime.wideStringSafe(v)) {
				// OK, we can not encode this! So better to fail early
				Errors.print("Unsafe string, can not save key: " + n);
				Reflect.deleteField(cookie.data, n);
				return false;
			}
			// Errors.print("Saving " + v.length + " characters");
			Reflect.setField(cookie.data, n, v);
			if (cookie.flush() != flash.net.SharedObjectFlushStatus.PENDING) {
				return true;
			}
			return false;
		} catch (e : Dynamic) {
			return false;
		}
	}

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

	static var state : flash.net.SharedObject;
	#end

	#if js
	public static function setKeyValueJS(k : String, v : String, session : Bool) : Bool {
		#if flow_nodejs
//			Errors.report("Cannot set value for key \"" + k + "\"");
			return false;
		#else
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			if (isIE())
				untyped storage.setItem(k, StringTools.urlEncode(v));
			else
				untyped storage.setItem(k, v);
			return true;
		} catch (e : Dynamic) {
			Errors.report("Cannot set value for key \"" + k + "\": " + e);
			return false;
		}
		#end
	}

	public static function getKeyValueJS(key : String, def : String, session : Bool) : String {
		#if flow_nodejs
			// Errors.report("Cannot get value for key \"" + key + "\"");
			return def;
		#else
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			var value = untyped storage.getItem(key);

			if (null == value) return def;

			if (isIE())
				return StringTools.urlDecode(value);
			else
				return value;
		} catch (e : Dynamic) {
			Errors.report("Cannot get value for key \"" + key + "\": " + e);
			return def;
		}
		#end
	}

	public static function removeKeyValueJS(key : String, session : Bool) : Void {
		#if flow_nodejs
//			Errors.report("Cannot get remove key \"" + key + "\"");
		#else
		var useMask = StringTools.endsWith(key, "*");
		var mask = "";
		if (useMask) mask = key.substr(0, key.length-1);
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			if (storage.length == 0) return;
			if (useMask) {
				var nextKey : String;
				for (i in 0...storage.length) {
					nextKey = storage.key(i);
					if (StringTools.startsWith(nextKey, mask))
						storage.removeItem(nextKey);
				}
			} else storage.removeItem(key);
		} catch (e : Dynamic) {
			Errors.report("Cannot remove key \"" + key + "\": " + e);
		}
		#end
	}

	public static function removeAllKeyValuesJS(session : Bool) : Void {
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			storage.clear();
		} catch (e : Dynamic) {
			Errors.report("Cannot clear storage: " + e);
		}
	}

	public static function getKeysListJS(session : Bool) : Array<String> {
		try {
			var storage = session? untyped sessionStorage : untyped localStorage;
			return untyped Object.keys(storage);
		} catch (e : Dynamic) {
			Errors.report("Cannot get keys list: " + e);
			return [];
		}
	}
	#end

	public static function clearTrace() : Void {
		// haxe.Log.clear();
	}

	public static function printCallstack() : Void {
		#if js
		untyped __js__("console.trace()");
		#else
		println(Assert.callStackToString(haxe.CallStack.callStack()));
		#end
	}
	public static function captureCallstack() : Dynamic {
		// This is expensive use captureStringCallstack if you really need it
		// return haxe.CallStack.callStack();
		return null;
	}
	public static function callstack2string(c : Dynamic) : String {
		// return Assert.callStackToString(c);
		return "";
	}
	public static function captureStringCallstack() : Dynamic {
		#if js
		return StringTools.replace(StringTools.replace(untyped __js__("new Error().stack"), "    at ", ""), "Error\n", "");
		#else
		return Assert.callStackToString(haxe.CallStack.callStack());
		#end
	}
	public static function captureCallstackItem(index : Int) : Dynamic {
		return null;
	}
	public static function impersonateCallstackItem(item : Dynamic, index : Int) : Void {
		// stub
	}
	public static function impersonateCallstackFn(fn : Dynamic, index : Int) : Void {
		// stub
	}
	public static function impersonateCallstackNone(index : Int) : Void {
		// stub
	}

	public static function failWithError(e : String) : Void {
		throw ("Runtime failure: " + e);
	}

	public static inline function makeStructValue(name : String, args : Array<Dynamic>, default_value : Dynamic) : Dynamic {
		return HaxeRuntime.makeStructValue(name, args, default_value);
	}

	public static function extractStructArguments(value : Dynamic) :  Array<Dynamic> {
		return HaxeRuntime.extractStructArguments(value);
	}

	public static function quit(c : Int) : Void {
#if js
#if ((flow_nodejs && !flow_webmodule) || nwjs)
		process.exit(c);
#elseif (flow_nodejs && flow_webmodule)
		if (untyped response.headersSent == false)
			untyped response.send(webModuleResponseText);
#else
		Browser.window.open("", "_top").close();
#end
#elseif (neko || cpp)
		Sys.exit(c);
#else
		Errors.print("quit called: " + c);
#end
	}

	public static function getFileContent(file : String) : String {
		#if (flash)
		return "";
		#elseif (js && (flow_nodejs || nwjs))
		try {
			var stat = Fs.statSync(file);
			return stat.isFile() ? Fs.readFileSync(file, 'utf8') : "";
		} catch (error : Dynamic) {
			return "";
		}
		#elseif (js)
		return "";
		#else
		return sys.FileSystem.exists(file) ? sys.io.File.getContent(file) : "";
		#end
	}

	public static function getFileContentBinary(file : String) : String {
		throw "Not implemented for this target: getFileContentBinary";
		return "";
	}

	public static function setFileContent(file : String, content : String) : Bool {
		#if (flash || neko)
			Errors.print("setFileContent '" + file + "' does not work in this target. Use the C++ runner");
			return false;
		#elseif (js && (flow_nodejs || nwjs))
			try {
				Fs.writeFileSync(file, content, 'utf8');
			} catch (error : Dynamic) {
				return false;
			}
			return true;
		#elseif js
			Errors.print("setFileContent '" + file + "' does not work in this target. Use the C++ runner");
			return false;
		#else
			try {
				sys.io.File.saveContent(file, content);
			} catch (error : Dynamic) {
				return false;
			}
			return true;
		#end
	}

	public static function setFileContentUTF16(file : String, content : String) : Bool {
		// throw "Not implemented for this target: setFileContentUTF16";
		return false;
	}

	public static function setFileContentBinaryConvertToUTF8(file : String, content : String) : Bool {
		return setFileContentBinaryCommon(file, content, true);
	}

	public static function setFileContentBinary(file : String, content : Dynamic) : Bool {
		return setFileContentBinaryCommon(file, content, false);
	}

	public static function setFileContentBinaryCommon(file : String, content : Dynamic, convertToUTF8 : Bool) : Bool {
		#if (js && (flow_nodejs || nwjs))
			try {
				Fs.writeFileSync(file, new Buffer(content), 'binary');
			} catch (error : Dynamic) {
				return false;
			}
			return true;
		#elseif (js)
			try {
				var a : Dynamic = js.Browser.document.createElement("a");
				a.download = file;
				js.Browser.document.body.appendChild(a);

				if (convertToUTF8 || Util.getParameter("save_file_utf8") == "1") { // Old implementation, Blob converts to UTF-8
					var fileBlob = new js.html.Blob([content], {type : 'application/octet-stream'});
					var url = js.html.URL.createObjectURL(fileBlob);
					a.href = url;
					a.click();

					Native.defer(function() {
						js.html.URL.revokeObjectURL(url);
					});
				} else {
					if (content.startsWith(Util.fromCharCode(0xFEFF))) {
						content = content.substr(1);
					}
					var base64data = Browser.window.btoa(content);
					a.href = 'data:application/octet-stream;base64,' + base64data;
					a.click();
				}
				Native.defer(function() {
					js.Browser.document.body.removeChild(a);
				});

				return true;
			} catch (error : Dynamic) {
				if (convertToUTF8) {
					return false;
				} else {
					return setFileContentBinaryCommon(file, content, true);
				}
			}

		#else
			// throw "Not implemented for this target: setFileContentBinary";
			return false;
		#end
	}

	public static function setFileContentBytes(file : String, content : Dynamic) : Bool {
		return setFileContentBinary(file, content);
	}

	public static function startProcess(command : String, args : Array<String>, cwd : String, stdIn : String, onExit : Int -> String -> String -> Void) : Bool {
		#if (js && (flow_nodejs || nwjs))
			// TODO: Handle stdIn
			ChildProcess.exec(command + " " + args.join(" "), {cwd:cwd}, function(error, stdout:Dynamic, stderr:Dynamic) {
				onExit(error.code, stdout, stderr);
			});
		#else
		// throw "Not implemented for this target: startProcess";
		#end
		return false;
	}

	public static function runProcess(command : String, args : Array<String>, cwd : String, onstdout : String -> Void, onstderr : String -> Void, onExit : Int -> Void) : Bool {
		return false;
	}

	public static function startDetachedProcess(command : String, args : Array<String>, cwd : String) : Bool {
		return false;
	}

	public static function writeProcessStdin(process : Dynamic, arg : String) : Bool {
		return false;
	}

	public static function killProcess(process : Dynamic) : Bool {
		return false;
	}

	// Convert a UTF-32/UCS-4 unicode character code to a string
	//native fromCharCode : (int) -> string = Native.fromCharCode;
	public static inline function fromCharCode(c : Int) : String {
		return Util.fromCharCode((c));
	}

	public static function utc2local(stamp : Float) : Float {
		return NativeTime.utc2local(stamp);
	}

	public static function local2utc(stamp : Float) : Float {
		return NativeTime.local2utc(stamp);
	}

	// Converts string local time representation to time in milliseconds since epoch 1970 in UTC
	public static function string2time(date : String) : Float {
		return NativeTime.string2time(date);
	}

	public static function dayOfWeek(year: Int, month: Int, day: Int) : Int {
		return NativeTime.dayOfWeek(year, month, day);
	}

	// Returns a string representation for the time (time is given in milliseconds since epoch 1970)
	public static function time2string(date : Float) : String {
		return NativeTime.time2string(date);
	}

	public static function getUrl(u : String, t : String) : Void {
		getUrlBasic(u, t);
	}

	public static function getUrlAutoclose(u : String, t : String, delay : Int) : Void {
		getUrlBasic(u, t, delay);
	}

	public static function getUrlBasic(u : String, t : String, ?autoCloseDelay : Int = -1) : Void {
		#if (js && !flow_nodejs)
		try {
			var openedWindow = Browser.window.open(u, t);
			if (autoCloseDelay >= 0) {
				openedWindow.addEventListener('pageshow', function() {
					timer(autoCloseDelay, function() { openedWindow.close(); });
				});
			}
		} catch (e:Dynamic) {
			// Catch exception that tells that window wasn't opened after user chose to stay on page
			if (e != null && e.number != -2147467259) throw e;
		}
		#end
	}

	public static function getUrl2(u : String, t : String) : Bool {
		#if (js && !flow_nodejs)
		try {
			return Browser.window.open(u, t) != null;
		} catch (e:Dynamic) {
			// Catch exception that tells that window wasn't opened after user chose to stay on page
			if (e != null && e.number != -2147467259) throw e;
			else Errors.report(e);
			return false;
		}
		#elseif flash
		flash.Lib.getURL(new flash.net.URLRequest(u), t);
		return true;
		#else
		return false;
		#end
	}

	public static inline function getCharCodeAt(s : String, i : Int) : Int {
		return (s.charCodeAt((i)));
	}

	public static function loaderUrl() : String {
		#if js
		#if (flow_nodejs && flow_webmodule)
		return untyped request.protocol + "://" + untyped request.hostname + untyped request.originalUrl;
		#elseif flow_nodejs
		return "";
		#else
		return Browser.window.location.href;
		#end
		#elseif flash
		return flash.Lib.current.loaderInfo.loaderURL;
		#else
		return "";
		#end
	}

	public static inline function number2double(n : Dynamic) : Float {
		// NOP for this target
		return n;
	}

	// Binary serialization
	#if flash
	private static var doubleBytes : ByteArray;
	#end

	#if js
	private static var doubleToString : Dynamic;
	private static var stringToDouble : Dynamic;
	#end

	public static function stringbytes2double(s : String) : Float {
		#if flash
		doubleBytes.writeShort(s.charCodeAt(0)); doubleBytes.writeShort(s.charCodeAt(1));
		doubleBytes.writeShort(s.charCodeAt(2)); doubleBytes.writeShort(s.charCodeAt(3));
		doubleBytes.position = 0;
		var ret = doubleBytes.readDouble();
		doubleBytes.position = 0;
		return ret;
		#elseif js
		return stringToDouble(s);
		#else
		return 0.0;
		#end
	}

	public static function stringbytes2int(s : String) : Int {
		return s.charCodeAt(0) | (s.charCodeAt(1) << 16);
	}

	private static function initBinarySerialization() : Void {
		#if flash
		// Buffer for serialization of doubles
		doubleBytes = new ByteArray();
		doubleBytes.endian = flash.utils.Endian.LITTLE_ENDIAN;
		#elseif js
		if (untyped __js__("typeof")(ArrayBuffer) == "undefined" ||
				untyped __js__("typeof")(Float64Array) == "undefined") {
			var binaryParser = new BinaryParser(false, false);
			doubleToString = function(value : Float) : String {
				return packDoubleBytes(binaryParser.fromDouble(value));
			}
			stringToDouble = function(str : String) : Float {
				return binaryParser.toDouble(unpackDoubleBytes(str));
			}
		} else {
			var arrayBuffer = untyped __js__ ("new ArrayBuffer(16)");
			var uint16Array = untyped __js__ ("new Uint16Array(arrayBuffer)");
			var float64Array = untyped __js__ ("new Float64Array(arrayBuffer)");
			doubleToString = function(value : Float) : String {
				float64Array[0] = value;
				var ret : StringBuf = new StringBuf();
				ret.addChar(uint16Array[0]); ret.addChar(uint16Array[1]);
				ret.addChar(uint16Array[2]); ret.addChar(uint16Array[3]);
				return ret.toString();
			}
			stringToDouble = function(str : String) : Float {
				uint16Array[0] = str.charCodeAt(0); uint16Array[1] = str.charCodeAt(1);
				uint16Array[2] = str.charCodeAt(2); uint16Array[3] = str.charCodeAt(3);
				return float64Array[0];
			}
		}
		#end
	}

	#if js
	private static function packDoubleBytes(s : String) : String {
		var ret : StringBuf = new StringBuf();
		for ( i in 0...cast( s.length / 2 ) ) {
			ret.addChar(s.charCodeAt(i * 2) | (s.charCodeAt(i * 2 + 1) << 8));
		}
		return ret.toString();
	}

	private static function unpackDoubleBytes(s : String) : String {
		var ret : StringBuf = new StringBuf();
		for (i in 0...s.length) {
			ret.addChar(s.charCodeAt(i) & 0xFF);
			ret.addChar(s.charCodeAt(i) >> 8);
		}
		return ret.toString();
	}
	#end

	public static function __init__() : Void {
		initBinarySerialization();
	}

	private static inline function writeBinaryInt32( value : Int, buf : StringBuf) : Void {
		buf.addChar(value & 0xFFFF);
		buf.addChar(value >> 16);
	}

	public static inline function writeInt(value : Int, buf : StringBuf) : Void {
		if (value & 0xFFFF8000 != 0) {
			buf.addChar(0xFFF5);
			writeBinaryInt32(value, buf);
		} else {
			buf.addChar(value);
		}
	}

	static var structIdxs : Map<Int,Int>; // struct id -> idx in the struct def table in the footer
	static var structDefs : Array< Array<Dynamic> >; // [ [fields count, structname] ]

	private static function writeStructDefs(buf : StringBuf) : Void {
		writeArrayLength(structDefs.length, buf);
		for (struct_def in structDefs) {
			buf.addChar(0xFFF8); buf.addChar(0x0002);
			buf.addChar(struct_def[0]);
			buf.addChar(0xFFFA);
			buf.addChar(struct_def[1].length);
			buf.addSub(struct_def[1], 0);
		}
	}

	private static function writeArrayLength(arr_len: Int, buf: StringBuf) : Void {
		if (arr_len == 0) {
			buf.addChar(0xFFF7);
		} else {
			if ( arr_len > 65535 ) {
				buf.addChar(0xFFF9);
				writeBinaryInt32(arr_len, buf);
			} else {
				buf.addChar(0xFFF8);
				buf.addChar(arr_len);
			}
		}
	}
	private static function writeBinaryValue(value : Dynamic, buf : StringBuf) : Void {
		switch ( HaxeRuntime.typeOf(value) ) {
			case RTVoid:
				buf.addChar(0xFFFF);
			case RTBool:
				buf.addChar( value ? 0xFFFE : 0xFFFD );
			case RTDouble:
				buf.addChar(0xFFFC);
				#if flash
				doubleBytes.writeDouble(value);
				doubleBytes.position = 0;
				buf.addChar(doubleBytes.readShort()); buf.addChar(doubleBytes.readShort());
				buf.addChar(doubleBytes.readShort()); buf.addChar(doubleBytes.readShort());
				doubleBytes.position = 0;
				#elseif js
				buf.addSub(doubleToString(value), 0);
				#end
			case RTString:
				var str_len : Int = value.length;
				if (value.length > 65535) {
					buf.addChar(0xFFFB);
					writeBinaryInt32(str_len, buf);
				} else {
					buf.addChar(0xFFFA);
					buf.addChar(str_len);
				}
				buf.addSub(value, 0);
			case RTArray(t):
				var arr_len = value.length;
				writeArrayLength(arr_len, buf);
				for (i in 0...arr_len ) {
					writeBinaryValue(value[i], buf);
				}
			case RTStruct(n):
			#if (js && readable)
				var struct_id = HaxeRuntime._structids_.get(value._name);
			#else
				var struct_id = value._id;
			#end
				var struct_fields = HaxeRuntime._structargs_.get(struct_id);
				var field_types = HaxeRuntime._structargtypes_.get(struct_id);
				var fields_count = struct_fields.length;

				var struct_idx = 0;
				if ( structIdxs.exists(struct_id) ) {
					struct_idx = structIdxs.get(struct_id);
				} else {
					struct_idx = structDefs.length;
					structIdxs.set(struct_id, struct_idx);
					structDefs.push([fields_count, HaxeRuntime._structnames_.get(struct_id)]);
				}

				buf.addChar(0xFFF4);
				buf.addChar(struct_idx);

				for (i in 0...fields_count) {
					var field : Dynamic = Reflect.field(value, struct_fields[i]);
					if (field_types[i] == RTInt) {
						writeInt(field, buf);
					} else {
						writeBinaryValue(field, buf);
					}
				}
			case RTRefTo(t):
				buf.addChar(0xFFF6);
				writeBinaryValue( value.__v, buf );
			default:
				throw "Cannot serialize " + value;
		}
	}

	public static function toBinary(value : Dynamic) : String {
		var buf : StringBuf = new StringBuf();
		// Init struct def table
		structIdxs = new Map<Int,Int>();
		structDefs = new Array< Array<Dynamic> >();

		writeBinaryValue(value, buf);
		var str = buf.toString();

		var struct_defs_buf = new StringBuf();
		writeStructDefs(struct_defs_buf);

		var ret = String.fromCharCode((str.length + 2) & 0xFFFF) + String.fromCharCode((str.length + 2) >> 16) + // Offset of structdefs
			str + struct_defs_buf.toString();

		return ret;
	}

	public static function fromBinary(string : Dynamic, defvalue : Dynamic, fixups : Dynamic) : Dynamic {
		#if js
		if (Type.getClass(string) == JSBinflowBuffer) {
			return string.deserialise(defvalue, fixups);
		} else
		#end
		{
			return string;
		}
	}

	public static function getTotalMemoryUsed() : Float {
		#if flash
		return flash.system.System.totalMemory;
		#elseif (js && (flow_nodejs || nwjs))
		return process.memoryUsage().heapUsed;
		#else
		return 0.0;
		#end
	}

	public static function detectDedicatedGPU() : Bool {
		try {
			var canvas = Browser.document.createElement('canvas');
			var gl = untyped __js__("canvas.getContext('webgl') || canvas.getContext('experimental-webgl')");

			if (gl == null) {
				return false;
			}

			var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
			var vendor = gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL);
			var renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);

			return renderer.toLowerCase().indexOf("nvidia") >= 0 || renderer.toLowerCase().indexOf("ati") >= 0 || renderer.toLowerCase().indexOf("radeon") >= 0;
		} catch (e : Dynamic) {
			return false;
		}
	}

	public static function domCompleteTiming() : Float {
		try {
			return untyped __js__("window.performance.timing.domComplete - window.performance.timing.domLoading");
		} catch (e : Dynamic) {
			return -1;
		}
	}

	public static function estimateCPUSpeed() : Float {
		#if js
		untyped __js__("
			var _speedconstant = 1.15600e-8;
			var d = new Date();
			var amount = 150000000;
			var estprocessor = 1.7;
			for (var i = amount; i > 0; i--) {}
			var newd = new Date();
			di = (newd.getTime() - d.getTime()) / 1000;
			spd = ((_speedconstant * amount) / di);
			return Math.round(spd * 1000) / 1000;
		");
		#end

		return -1;
	}

	public static function getDeviceMemory() : Float {
		try {
			return untyped __js__("window.navigator.deviceMemory || -1");
		} catch (e : Dynamic) {
			return -1;
		}
	}

	public static function getDevicePlatform() : Float {
		try {
			return untyped __js__("window.navigator.platform || ''");
		} catch (e : Dynamic) {
			return -1;
		}
	}

	private static var FlowCrashHandlers : Array< String -> Void > = new Array< String -> Void>();

	public static function addCrashHandler(cb : String -> Void) : Void -> Void {
		FlowCrashHandlers.push(cb);
		return function() { FlowCrashHandlers.remove(cb); };
	}

	public static function callFlowCrashHandlers(msg : String) : Void {
		msg += "Call stack: " + Assert.callStackToString(haxe.CallStack.exceptionStack());
		for ( hdlr in FlowCrashHandlers.slice(0, FlowCrashHandlers.length) ) hdlr(msg);
	}

	private static var PlatformEventListeners : Map< String, Array<Void -> Bool> > = new Map();
	private static var LastUserAction : Float = -1;
	private static var IdleLimit : Float = 1000.0 * 60.0; // 1 min
	public static function addPlatformEventListener(event : String, cb : Void -> Bool) : Void -> Void {
		#if (js && !flow_nodejs)
			if (event == "online" || event == "offline") {
				var w = Browser.window;
				if (w.addEventListener != null) {
					w.addEventListener(event, cb, false);
					return function() {
						var w = Browser.window;
						if (w.removeEventListener != null) {
							w.removeEventListener(event, cb);
						}
					}
				}
			} else if (event == "suspend") {
				Browser.window.addEventListener("blur", cb);
				Browser.window.addEventListener("pagehide", cb);
				return function() {
					Browser.window.removeEventListener("blur", cb);
					Browser.window.removeEventListener("pagehide", cb);
				};
			} else if (event == "resume") {
				Browser.window.addEventListener("focus", cb);
				Browser.window.addEventListener("pageshow", cb);
				return function() {
					Browser.window.removeEventListener("focus", cb);
					Browser.window.removeEventListener("pageshow", cb);
				};
			} else if (event == "active") {
				var timeoutActiveId = -1;
				var setTimeoutActiveFn = function () {};
				var activeCalled = false;

				setTimeoutActiveFn = function () {
					var timePassedActive = Date.now().getTime() - LastUserAction;

					if (timePassedActive >= IdleLimit) {
						timeoutActiveId = -1;
						activeCalled = false;
					} else {
						timeoutActiveId = untyped __js__("setTimeout(setTimeoutActiveFn, Native.IdleLimit - timePassedActive)");
						if (!activeCalled) {
							activeCalled = true;
							cb();
						}
					}
				};

				var mouseMoveActiveFn = function () {
					LastUserAction = Date.now().getTime();

					if (timeoutActiveId == -1) {
						setTimeoutActiveFn();
					}
				};

				Browser.window.addEventListener("pointermove", mouseMoveActiveFn);
				Browser.window.addEventListener("videoplaying", mouseMoveActiveFn);
				Browser.window.addEventListener("focus", mouseMoveActiveFn);
				Browser.window.addEventListener("blur", mouseMoveActiveFn);

				mouseMoveActiveFn();

				return function() {
					untyped __js__("clearTimeout(timeoutActiveId)");
					Browser.window.removeEventListener("pointermove", mouseMoveActiveFn);
					Browser.window.removeEventListener("videoplaying", mouseMoveActiveFn);
					Browser.window.removeEventListener("focus", mouseMoveActiveFn);
					Browser.window.removeEventListener("blur", mouseMoveActiveFn);
				};
			} else if (event == "idle") {
				var timeoutIdleId = -1;
				var setTimeoutIdleFn = function () {};
				var idleCalled = false;

				setTimeoutIdleFn = function () {
					var timePassedIdle = Date.now().getTime() - LastUserAction;

					if (timePassedIdle >= IdleLimit) {
						timeoutIdleId = -1;
						if (!idleCalled) {
							idleCalled = true;
							cb();
						}
					} else {
						timeoutIdleId = untyped __js__("setTimeout(setTimeoutIdleFn, Native.IdleLimit - timePassedIdle)");
						idleCalled = false;
					}
				};

				var mouseMoveIdleFn = function () {
					LastUserAction = Date.now().getTime();

					if (timeoutIdleId == -1) {
						setTimeoutIdleFn();
					}
				};

				Browser.window.addEventListener("pointermove", mouseMoveIdleFn);
				Browser.window.addEventListener("videoplaying", mouseMoveIdleFn);
				Browser.window.addEventListener("focus", mouseMoveIdleFn);
				Browser.window.addEventListener("blur", mouseMoveIdleFn);

				return function() {
					untyped __js__("clearTimeout(timeoutIdleId)");
					Browser.window.removeEventListener("pointermove", mouseMoveIdleFn);
					Browser.window.removeEventListener("videoplaying", mouseMoveIdleFn);
					Browser.window.removeEventListener("focus", mouseMoveIdleFn);
					Browser.window.removeEventListener("blur", mouseMoveIdleFn);
				};
			}
		#end

		if (!PlatformEventListeners.exists(event)) PlatformEventListeners.set(event, new Array());
		PlatformEventListeners[event].push(cb);
		return function() { PlatformEventListeners[event].remove(cb); };
	}

	public static function setUserIdleLimit(ms : Int) : Void {
		IdleLimit = ms;
	}

	public static function notifyPlatformEvent(event : String) : Bool {
		var cancelled = false;
		if (PlatformEventListeners.exists(event))
			for (cb in PlatformEventListeners[event])
				cancelled = cb() || cancelled;
		return cancelled;
	}

	public static function addCameraPhotoEventListener(cb : Int -> String -> String -> Int -> Int -> Void) : Void -> Void {
		// not implemented yet for js/flash
		return function() { };
	}
	public static function addCameraVideoEventListener(cb : Int -> String -> String -> Int -> Int -> Int -> Int -> Void) : Void -> Void {
		// not implemented yet for js/flash
		return function() { };
	}

	public static function md5(content : String) : String {
		return JsMd5.encode(content);
	}

	public static function getCharAt(s : String, i : Int) : String {
		return s.charAt(i);
	}

	#if js
	// we will create flow objects using several "sid"
	// they obtained from HaxeRuntime._structids_ / HaxeRuntime._structargs_
	// so we cache them in order to not make local vars (they would increase load on GC)
	static var sidJsonArray : Int;
	static var sidJsonArrayVal : String;
	static var sidJsonString : Int;
	static var sidJsonStringVal : String;
	static var sidJsonDouble : Int;
	static var sidJsonDoubleVal : String;

	static var jsonBoolTrue : Dynamic;
	static var jsonBoolFalse : Dynamic;
	static var jsonNull : Dynamic;

	static var sidPair : Int;
	static var sidPairFirst : String;
	static var sidPairSecond : String;
	static var sidJsonObject : Int;
	static var sidJsonObjectFields : String;

	static var jsonDoubleZero : Dynamic;
	static var jsonStringEmpty : Dynamic;

	// Chrome and maybe other browsers faster with for(var f in o) that with Object.getOwnPropertyNames
	private static function object2JsonStructsCompacting(o : Dynamic, sDict : Dynamic, jsDict : Dynamic, nDict : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var n = o.length;
			var a1 = Array(n);
			for (var i=0; i<n; i++) {
				a1[i] = Native.object2JsonStructs(o[i], sDict, jsDict, nDict);
			}
			var obj = { _id : Native.sidJsonArray };
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					if (o === '') return Native.jsonStringEmpty;
					var obj = jsDict[o];
					if (obj == undefined) {
						var s = sDict[o];
						if (s === undefined) {
							s = o;
							sDict[o] = s;
						}
						obj = { _id : Native.sidJsonString };
						obj[Native.sidJsonStringVal] = s;
						jsDict[o] = obj;
					}
					return obj;
				case 'number':
					if (o === 0.0) return Native.jsonDoubleZero;
					var obj = nDict[o];
					if (obj === undefined) {
						obj = { _id : Native.sidJsonDouble };
						obj[Native.sidJsonDoubleVal] = o;
						nDict[o] = obj;
					}
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = [];
						for(var f in o) {
							var a2 = Native.object2JsonStructs(o[f], sDict, jsDict, nDict);
							var obj = { _id : Native.sidPair };
							var cf = sDict[f];
							if (cf === undefined) {
								cf = f;
								sDict[f] = cf;
							}
							obj[Native.sidPairFirst] = cf;
							obj[Native.sidPairSecond] = a2;
							mappedFields.push(obj);
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	// Firefox and maybe other browsers faster with Object.getOwnPropertyNames that with for(var f in o)
	private static function object2JsonStructsCompacting_FF(o : Dynamic, sDict : Dynamic, jsDict : Dynamic, nDict : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var n = o.length;
			var a1 = Array(n);
			for (var i=0; i<n; i++) {
				a1[i] = Native.object2JsonStructs_FF(o[i], sDict, jsDict, nDict);
			}
			var obj = { _id : Native.sidJsonArray };
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					if (o === '') return Native.jsonStringEmpty;
					var obj = jsDict[o];
					if (obj == undefined) {
						var s = sDict[o];
						if (s === undefined) {
							s = o;
							sDict[o] = s;
						}
						obj = { _id : Native.sidJsonString };
						obj[Native.sidJsonStringVal] = s;
						jsDict[o] = obj;
					}
					return obj;
				case 'number':
					if (o === 0.0) return Native.jsonDoubleZero;
					var obj = nDict[o];
					if (obj === undefined) {
						obj = { _id : Native.sidJsonDouble };
						obj[Native.sidJsonDoubleVal] = o;
						nDict[o] = obj;
					}
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = Object.getOwnPropertyNames(o);
						for(var i=0; i< mappedFields.length; i++) {
							var f = mappedFields[i];
							var cf = sDict[f];
							if (cf === undefined) {
								cf = f;
								sDict[f] = cf;
							}

							var a2 = Native.object2JsonStructs_FF(o[f], sDict, jsDict, nDict);
							var obj = { _id : Native.sidPair };
							obj[Native.sidPairFirst] = cf;
							obj[Native.sidPairSecond] = a2;
							mappedFields[i] = obj;
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	private static function object2JsonStructs(o : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var a1 = Native.map(o,Native.object2JsonStructs);
			var obj = { _id : Native.sidJsonArray };
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					var obj = { _id : Native.sidJsonString };
					obj[Native.sidJsonStringVal] = o;
					return obj;
				case 'number':
					var obj = { _id : Native.sidJsonDouble };
					obj[Native.sidJsonDoubleVal] = o;
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = [];
						for(var f in o) {
							var a2 = Native.object2JsonStructs(o[f]);
							var obj = { _id : Native.sidPair };
							obj[Native.sidPairFirst] = f;
							obj[Native.sidPairSecond] = a2;
							mappedFields.push(obj);
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	// Firefox and maybe other browsers faster with Object.getOwnPropertyNames that with for(var f in o)
	private static function object2JsonStructs_FF(o : Dynamic) : Dynamic {
		untyped __js__("
		if (Array.isArray(o)) {
			var a1 = Native.map(o,Native.object2JsonStructs_FF);
			var obj = { _id : Native.sidJsonArray};
			obj[Native.sidJsonArrayVal] = a1;
			return obj;
		} else {
			var t = typeof o;
			switch (t) {
				case 'string':
					var obj = { _id : Native.sidJsonString };
					obj[Native.sidJsonStringVal] = o;
					return obj;
				case 'number':
					var obj = { _id : Native.sidJsonDouble };
					obj[Native.sidJsonDoubleVal] = o;
					return obj;
				case 'boolean': return o ? Native.jsonBoolTrue : Native.jsonBoolFalse;
				default:
					if(o == null) {
						return Native.jsonNull;
					} else {
						var mappedFields = Object.getOwnPropertyNames(o);
						for(var i=0; i< mappedFields.length; i++) {
							var f = mappedFields[i];
							var a2 = Native.object2JsonStructs_FF(o[f]);
							var obj = { _id : Native.sidPair };
							obj[Native.sidPairFirst] = f;
							obj[Native.sidPairSecond] = a2;
							mappedFields[i] = obj;
						}
						var obj = { _id : Native.sidJsonObject};
						obj[Native.sidJsonObjectFields] = mappedFields;
						return obj;
					}
			}
		}");

		return "";
	}

	private static var parseJsonFirstCall = true;
	public static function parseJson(json : String) : Dynamic {
		if (parseJsonFirstCall) {
			Native.sidJsonArray = HaxeRuntime._structids_.get("JsonArray");
			Native.sidJsonArrayVal = HaxeRuntime._structargs_.get(Native.sidJsonArray)[0];

			Native.sidJsonString = HaxeRuntime._structids_.get("JsonString");
			Native.sidJsonStringVal = HaxeRuntime._structargs_.get(Native.sidJsonString)[0];

			Native.sidJsonDouble = HaxeRuntime._structids_.get("JsonDouble");
			Native.sidJsonDoubleVal = HaxeRuntime._structargs_.get(Native.sidJsonDouble)[0];

			Native.jsonBoolTrue = HaxeRuntime.fastMakeStructValue("JsonBool", true);
			Native.jsonBoolFalse = HaxeRuntime.fastMakeStructValue("JsonBool", false);

			Native.sidPair = HaxeRuntime._structids_.get("Pair");
			Native.sidPairFirst = HaxeRuntime._structargs_.get(Native.sidPair)[0];
			Native.sidPairSecond = HaxeRuntime._structargs_.get(Native.sidPair)[1];

			Native.sidJsonObject = HaxeRuntime._structids_.get("JsonObject");
			Native.sidJsonObjectFields = HaxeRuntime._structargs_.get(Native.sidJsonObject)[0];

			Native.jsonNull = HaxeRuntime.makeStructValue("JsonNull",[],null);

			Native.jsonDoubleZero =  HaxeRuntime.makeStructValue("JsonDouble", [0.0], null);
			Native.jsonStringEmpty = HaxeRuntime.makeStructValue("JsonString", [""], null);
			parseJsonFirstCall = false;
		}
		if (json == "") return Native.jsonDoubleZero;

		untyped __js__("
			try {
				if (Platform.isIOS && json.length > 1024) {
					// on IOS memory restriction is very tight so we try to not create duplicate strings if possible
					// it might have advantages for quite long parsed string only
					return Platform.isFirefox ?
					Native.object2JsonStructsCompacting_FF(JSON.parse(json), {}, {}, {}) :
					Native.object2JsonStructsCompacting(JSON.parse(json), {}, {}, {});
				} else {
					return Platform.isFirefox ?
					Native.object2JsonStructs_FF(JSON.parse(json)) :
					Native.object2JsonStructs(JSON.parse(json));
				}
			} catch (e) {
				return Native.jsonDoubleZero;
			}
		");
		return Native.jsonDoubleZero;
	}
	#end

	public static function concurrentAsync(fine : Bool, tasks : Array < Void -> Dynamic >, cb : Array < Dynamic >) : Void {
		#if js
		untyped __js__("
var fns = tasks.map(function(c, i, a) {
	var v = function v (callback) {
		var r = c.call();
		callback(null, r);
	}
	return v;
});

async.parallel(fns, function(err, results) { cb(results) });");
		#end
	}

	public static function preloadStaticResource(href : String, as : String) : Void {
		#if (js && !flow_nodejs)
			var tag : Dynamic = js.Browser.document.createElement("link");
			tag.rel = "preload";
			tag.href = href;
			tag.as = as;
			js.Browser.document.head.appendChild(tag);
		#end
	}
}
