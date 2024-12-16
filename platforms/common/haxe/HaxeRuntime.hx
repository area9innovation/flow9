enum RuntimeType {
	RTVoid();
	RTBool();
	RTInt();
	RTDouble();
	RTString();
	RTArray(type : RuntimeType);
	RTStruct(name : String); // "" for unknown struct
	RTRefTo(type : RuntimeType);
	RTUnknown();
}

class FlowRefObject {
	public var __v : Dynamic;
	public function new(v : Dynamic) {
		__v = v;
	}
}

class HaxeRuntime {
	static public var _structnames_ : haxe.ds.IntMap<String>;
	static public var _structargs_ : haxe.ds.IntMap<Array<String>>;
	static public var _structargtypes_ : haxe.ds.IntMap<Array<RuntimeType>>;
	static public var _structids_ : haxe.ds.StringMap<Int>;
	static public var _structtemplates_ : haxe.ds.IntMap<Dynamic>;
#if (js)
	static var regexCharsToReplaceForString : Dynamic = untyped __js__ ("/[\\\\\\\"\\n\\t]/g");
	static var regexCharsToReplaceForJson : Dynamic = untyped __js__ ("/[\\\\\\\"\\n\\t\\x00-\\x08\\x0B-\\x1F]/g");
#end
	static public inline function ref__<T>(val : T) : Dynamic { return new FlowRefObject(val); }
	static public inline function deref__<T>(val : Dynamic) : T { return val.__v; }
	static public inline function setref__<T>(r : Dynamic, v : T) : Void { r.__v = v; }
	static public inline function _s_(v : Dynamic) : Dynamic { return v; }
	static public function initStruct(id : Int, name : String, args : Array<String>, atypes: Array<RuntimeType>) {
#if (js)
	untyped __js__("var j='0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';var l=j.length;function f(i){var c=j[i%l|0];var r=i/l|0;return r>0?c+f(r-1):c;}");

	// Do not use 'eval' directly here: https://esbuild.github.io/content-types/#direct-eval
	// Using 'new Function('arg', 'code')' instead
#if (readable)
	untyped __js__ ("if(args!=[]){var a='';for(var i=0;i<args.length;i++)a+=(args[i]+':'+args[i]+ ','); a=a.substring(0, a.length -1);(new Function('g', 'g.c$'+f(id) + '=function(' + args.join(',') +'){return {name:\"'+ name+'\",' + a + '};}'))($global)}");
#else
	untyped __js__ ("if(args!=[]){var a='';for(var i=0;i<args.length;i++)a+=(args[i]+':'+args[i]+ ','); a=a.substring(0, a.length -1);(new Function('g', 'g.c$'+f(id) + '=function(' + args.join(',') + '){return {_id:'+id.toString()+',' + a + '};}'))($global)}");
#end
#end
		_structnames_.set(id, name);
		_structids_.set(name, id);
		_structargs_.set(id, args);
		_structargtypes_.set(id, atypes);
	}

  static public function compareEqual(a : Dynamic, b : Dynamic) : Bool {
	// Modelled after https://github.com/epoberezkin/fast-deep-equal/blob/master/index.js
#if (js)
	untyped __js__("
if (a === b) return true;

	var isArray = Array.isArray;
	var keyList = Object.keys;
	var hasProp = Object.prototype.hasOwnProperty;

	if (a && b && typeof a == 'object' && typeof b == 'object') {
		var arrA = isArray(a)
		  , arrB = isArray(b)
		  , i
		  , length
		  , key;

	if (arrA && arrB) {
	  length = a.length;
	  if (length != b.length) return false;
	  for (i = length; i-- !== 0;)
		if (!HaxeRuntime.compareEqual(a[i], b[i])) return false;
	  return true;
	}

	if (arrA != arrB) return false;

	var result = false;
");
#if (readable)
	untyped __js__("
	if (hasProp.call(a, '_name') && hasProp.call(b, '_name')) {
		if (a._name !== b._name) {
			return false;
		} else {
			result = true;
		}
");
#else
	untyped __js__("
	if (hasProp.call(a, '_id') && hasProp.call(b, '_id')) {
		if (a._id !== b._id) {
			return false;
		} else {
			result = true;
		}
");
#end
	untyped __js__("
		var keys = keyList(a);
		length = keys.length;

		for (i = 1; i < length; i++) {
			key = keys[i];
			if (!HaxeRuntime.compareEqual(a[key], b[key])) return false;
		}
	}

	if (hasProp.call(a, '__v') && hasProp.call(b, '__v')) {
		return false;
	}

	return result;
}
");
	return false;
#else
	return compareByValue(a, b) == 0;
#end
  }
	static public function compareByValue(o1 : Dynamic, o2 : Dynamic) : Int {
		#if (js && !readable)
			untyped __js__("if (o1 === o2) return 0;
			if(o1 == null || o2 == null) {
				return 1;
			}
			if(Array.isArray(o1)) {
				if(!Array.isArray(o2)) {
					return 1;
				}
				var l1 = o1.length;
				var l2 = o2.length;
				var l = l1 < l2 ? l1 : l2;
				var _g = 0;
				var _g1 = l;
				while(_g < _g1) {
					var i = _g++;
					var c = HaxeRuntime.compareByValue(o1[i],o2[i]);
					if(c != 0) {
						return c;
					}
				}
				if(l1 == l2) {
					return 0;
				} else if(l1 < l2) {
					return -1;
				} else {
					return 1;
				}
			}
			var i1 = o1._id;
			if(i1 !== undefined) {
				var i2 = o2._id;
				if(i2 === undefined) {
					return 1;
				}
				if(i1 < i2) {
					return -1;
				}
				if(i1 > i2) {
					return 1;
				}
				var args = HaxeRuntime._structargs_.h[i1];
				var _g = 0;
				while(_g < args.length) {
					var f = args[_g];
					++_g;
					var c = HaxeRuntime.compareByValue(o1[f],o2[f]);
					if(c != 0) {
						return c;
					}
				}
				return 0;
			}
			if(o1 < o2) {
				return -1;
			} else {
				return 1;
			}
			");
			return 0;
		#else
			#if (js)
				untyped __js__("if (o1 === o2) return 0;");
			#else
				if (o1 == o2) return 0;
			#end
			if (o1 == null || o2 == null) return 1;

			#if flash
			// Possible return values of the getQualifiedClassName:
			//   "Array"
			//   "int" for ints (or defacto doubles that are ints)
			//   "Number" for doubles
			//   "Boolean" for bools
			//   "String"
			//   "FS_Foo" for structs
			//   "FlowRefObject" for references
			//   "builtin.as$0::MethodClosure"  for functions
			// See the results with this:
			// flash.external.ExternalInterface.call("console.log", qname1);
			var qname1 = untyped __global__["flash.utils.getQualifiedClassName"](o1);
			if (qname1 == "Array") {
			#else
			if ( isArray(o1) ) {
			#end
				if (!isArray(o2)) return 1;
				var l1 : Int = o1.length;
				var l2 : Int = o2.length;
				var l : Int =  l1 < l2 ? l1 : l2;
				for (i in 0...l ) {
					var c = compareByValue(o1[i], o2[i]);
					if (c != 0) return c;
				}
				return (l1 == l2) ? 0 : (l1 < l2 ? -1 : 1);
			}
			#if flash
			if (untyped o1.hasOwnProperty("_id")) {
			#else
				#if (js && readable)
					if (Reflect.hasField(o1, "_name")) {
				#else
					if (Reflect.hasField(o1, "_id")) {
				#end
			#end
			#if (js && readable)
				if (!Reflect.hasField(o2, "_name")) return 1;
				var n1 = o1._name;
				var n2 = o2._name;
				var i1 = _structids_.get(n1);
				var i2 = _structids_.get(n2);
			#else
				if (!Reflect.hasField(o2, "_id")) return 1;
				var i1 = o1._id;
				var i2 = o2._id;
			#end
				if (i1 < i2) return -1;
				if (i1 > i2) return 1;

				// We need to remember the order of the fields
				var args = _structargs_.get(i1);
				for (f in args) {
					var c = compareByValue(Reflect.field(o1, f), Reflect.field(o2, f));
					if (c != 0) return c;
				}
				return 0;
			}

			return (o1 < o2 ? -1 : 1);
		#end
	}


	public static function extractStructArguments(value : Dynamic) :  Array<Dynamic> {
		#if (js && readable)
			if (!Reflect.hasField(value, "_name")) return [];
			var i = _structids_.get(value._name);
		#else
			if (!Reflect.hasField(value, "_id")) return [];
			var i = value._id;
		#end

		var sargs = _structargs_.get(i);
		var n = sargs.length;
		var result = untyped Array(n);
		for (i in 0...n) {
			result[i] = Reflect.field(value, sargs[i]);
		}
		return result;
	}

	public static inline function isArray(o1 : Dynamic) : Bool {
		#if js
		return untyped __js__ ("Array").isArray(o1);
		#elseif flash
		return untyped __global__["flash.utils.getQualifiedClassName"](o1) == "Array";
		#else
		return Type.getClassName(Type.getClass(o1)) == "Array";
		#end
	}

	public static inline function nop___() : Void {
	}

	public static inline function isSameStructType(o1 : Dynamic, o2 : Dynamic) : Bool {
		#if (js && readable)
			return !isArray(o1) && !isArray(o2) &&
				Reflect.hasField(o1, "_name") &&
				Reflect.hasField(o2, "_name") &&
				o1._name == o2._name;
		#else
			return !isArray(o1) && !isArray(o2) &&
				Reflect.hasField(o1, "_id") &&
				Reflect.hasField(o2, "_id") &&
				o1._id == o2._id;
		#end
	}

	static function toStringCommon(value : Dynamic, ?keepStringEscapes : Bool = false, additionalEscapingFn : Dynamic->String->String) : String {
		if (value == null) return "{}";

/*
		#if flash
			// Possible return values of the getQualifiedClassName:
			//   "Array"
			//   "int" for ints (or defacto doubles that are ints)
			//   "Number" for doubles
			//   "Boolean" for bools
			//   "String"
			//   "FS_Foo" for structs
			//   "FlowRefObject" for references
			//   "builtin.as$0::MethodClosure"  for functions
			// See the results with this:
			// flash.external.ExternalInterface.call("console.log", qname1);
			var qname1 = untyped __global__["flash.utils.getQualifiedClassName"](value);
			if (qname1 == "int" || qname1 == "Number" || qname1 == "Boolean") {
				return Std.string(value);
			}
		#else*/
		if (!Reflect.isObject(value)) {
			return Std.string(value);
		}
		//#end
		if (isArray(value)) {
			var a : Array<Dynamic> = value;
			var r = "[";
			var s = "";
			for (v in a) {
				var vc = toStringCommon(v, false, additionalEscapingFn);
				r += s + vc;
				s = ", ";
			}
			return r + "]";
		}
		if (Reflect.hasField(value, "__v")) {
			// Reference
			return "ref " + toStringCommon(value.__v, false, additionalEscapingFn);
		}
		#if (js && readable)
		if (Reflect.hasField(value, "_name")) {
			var name = value._name;
			var structname = name;
			var id = _structids_.get(name);
		#else
		if (Reflect.hasField(value, "_id")) {
			var id = value._id;
			var structname = _structnames_.get(id);
		#end
			var r = structname + "(";

			if (structname == "DLink") {
				return r + "...)";
			}

			var s = "";
			var args = _structargs_.get(id);
			var argTypes = _structargtypes_.get(id);
			// We need to remember the order of the fields
			for (i in 0...args.length) {
				var f = args[i];
				var t = argTypes[i];
				var v : Dynamic = Reflect.field(value, f);
				switch (t) {
					case RTDouble: {
						r += s + v + ( (Std.int(v) == v) ? ".0" : "" );
					}
					case RTArray(arrtype): {
						if (!isArray(v) || arrtype != RTDouble) r += s + toStringCommon(v, false, additionalEscapingFn);
						else {
							r += s + "[";
							for (j in 0...v.length)
								r += ((j > 0) ? ", " : "") + v[j] + ((Std.int(v[j]) == v[j]) ? ".0" : "" );
							r += "]";
						}
					}
					default:
						r += s + toStringCommon(v, false, additionalEscapingFn);
				}
				s = ", ";
			}
			r += ")";
			return r;
		}
		if (Reflect.isFunction(value)) {
			return "<function>";
		}

		try {
			// OK, it is a string
			var s : String = value;

			if (!keepStringEscapes) {
				return additionalEscapingFn(value, s);
			} else {
				StringTools.replace(s, "\\", "\\\\"); // Check if really a string

				return s;
			}
		} catch(e : Dynamic) {
			return "<native>";//haxe.Json.stringify(value);
		}
		// #end
	}

	public static function toString(value : Dynamic, ?keepStringEscapes : Bool = false) : String {
		return toStringCommon(value, keepStringEscapes, function(val, s){
			#if js
				untyped __js__("
					return '\"' + val.replace(HaxeRuntime.regexCharsToReplaceForString, function (c) {
						if (c==='\\\\') {
							return '\\\\\\\\';
						} else if (c==='\\\"') {
							return '\\\\\"';
						} else if (c === '\\n') {
							return '\\\\n';
						} else if (c==='\\t') {
							return '\\\\t';
						} else {
							return c;
						}
					}) + '\"';
				");
			#else
				s = StringTools.replace(s, "\\", "\\\\");
				s = StringTools.replace(s, "\"", "\\\"");
				s = StringTools.replace(s, "\n", "\\n");
				s = StringTools.replace(s, "\t", "\\t");
			#end

			return "\"" + s + "\"";
		});
	}

	public static function toStringForJson(value : String) : String {
		return toStringCommon(value, false, function(val, s){
			#if js
				untyped __js__("
					return '\"' + val.replace(HaxeRuntime.regexCharsToReplaceForJson, function (c) {
						if (c==='\\\\') {
							return '\\\\\\\\';
						} else if (c==='\\\"') {
							return '\\\\\"';
						} else if (c === '\\n') {
							return '\\\\n';
						} else if (c==='\\t') {
							return '\\\\t';
						} else if (c.length===1 && c.charCodeAt(0)<0x20) {
							return \"\\\\u\" + c.charCodeAt(0).toString(16).padStart(4, \"0\");
						} else {
							return c;
						}
					}) + '\"';
				");
			#else
				s = StringTools.replace(s, "\\", "\\\\");
				s = StringTools.replace(s, "\"", "\\\"");
				s = StringTools.replace(s, "\n", "\\n");
				s = StringTools.replace(s, "\t", "\\t");
			#end

			return "\"" + s + "\"";
		});
	}

	#if (!neko && !cpp)
	private static function isValueFitInType(type : RuntimeType, value : Dynamic) {
		switch (type) {
			case RTArray(arrtype): {
				if (!isArray(value)) return false;
				if (arrtype != RTUnknown) { // Typed array
					for (i in 0...value.length)
						if (!isValueFitInType(arrtype, value[i])) return false;
				}
				return true;
			}
			case RTInt: return typeOf(value) == RTDouble; // There are only numbers for JS and Flash runtime. Check if integer?
			case RTRefTo(reftype): switch (typeOf(value)) {case RTRefTo(t): return isValueFitInType(reftype, value.__v); default: return false; };
			case RTUnknown: return true;
			case RTStruct(name): switch (typeOf(value)) { case RTStruct(n): return name == "" || n == name; default: return false; };
			default: return typeOf(value) == type;
		}
	}
	#end

	public static function makeStructValue(name : String, args : Array<Dynamic>, default_value : Dynamic) : Dynamic {
		try {
			var sid = _structids_.get(name);
			if (sid == null)
				return default_value;

			#if (!neko && !cpp)
			// Check fields types
			var types = _structargtypes_.get(sid);
			if (types.length != args.length) return default_value;
			for (i in 0...args.length) {
				if (! isValueFitInType(types[i], args[i] ) )
					return default_value;
			}
			#end

			var sargs = _structargs_.get(sid);
			var o : Dynamic = makeEmptyStruct(sid);
			for (i in 0...args.length) {
				Reflect.setField(o, sargs[i], args[i]);
			}
			return o;
		} catch(e : Dynamic) {
			return default_value;
		}
	}


	#if js
	// Use these when sure args types and count is correct and struct exists
	public static inline function fastMakeStructValue(n : String, a1 : Dynamic) : Dynamic {
		var sid  = _structids_.get(n);
		var o = {
		#if readable
			name : n
		#else
			_id : sid
		#end
		};
		untyped o[_structargs_.get(sid)[0]] = a1;
		return o;
	}

	public static inline function fastMakeStructValue2(n : String, a1 : Dynamic, a2 : Dynamic) : Dynamic {
		var sid  = _structids_.get(n);
		var o = {
		#if readable
			name : n
		#else
			_id : sid
		#end
		};
		untyped o[_structargs_.get(sid)[0]] = a1;
		untyped o[_structargs_.get(sid)[1]] = a2;
		return o;
	}
	#end

	public static function makeEmptyStruct(sid : Int) : Dynamic {
		if (_structtemplates_ != null) {
			var ff = _structtemplates_.get(sid);
			if (ff != null)
				return ff._copy();
		}
	#if (js && readable)
		var name = _structnames_.get(sid);
		return { _name : name }
	#else
		return { _id: sid };
	#end
	}

	#if (!neko && !cpp)
	public static function typeOf(value : Dynamic) : RuntimeType {
		if (value == null)
			return RTVoid;
		var t : String;

		#if flash
		t = untyped JSHaxeSupport.typeof(value);
		#elseif js
		t = untyped __js__("typeof")(value);
		#else
		t = value;
		#end

		switch (t) {
			case "string":
				return RTString;
			case "number":
				return RTDouble;
			case "boolean":
				return RTBool;
			case "object":
			{
				if ( isArray(value) )
					return RTArray(RTUnknown);
			#if (js && readable)
				if (Reflect.hasField(value, "_name"))
					return RTStruct(value._name);
			#else
				if (Reflect.hasField(value, "_id"))
					return RTStruct(_structnames_.get(value._id));
			#end
				if (Reflect.hasField(value, "__v"))
					return RTRefTo(typeOf(value.__v));
			}
			default:
		}

		return RTUnknown;
	}
	#end

	#if js
	public static function mul_32(a, b) {
		var ah = (a >> 16) & 0xffff, al = a & 0xffff;
		var bh = (b >> 16) & 0xffff, bl = b & 0xffff;
		var high = ((ah * bl) + (al * bh)) & 0xffff;
		return 0xffffffff & ((high << 16) + (al * bl));
	}
	#end

	public static function getStructName(id : Int) : String {
		return _structnames_.get(id);
	}

	// Some characters can NOT be represented in UTF-16, believe it or not!
	public static function wideStringSafe(str : String) : Bool {
		#if (flash || js)
		for (i in 0...str.length) {
			var c = str.charCodeAt(i);
			if (0xd800 <= c && c < 0xe000) {
				return false;
			}
		}
		return true;
		#else
		var safe = true;
		try {
			haxe.Utf8.iter(str, function(c : Int) {
				if (0xd800 <= c && c < 0xe000) {
					safe = false;
				}
			});
		} catch (e : Dynamic) {
			safe = false;
		}
		return safe;
		#end
	}

	public static function instanceof(v1 : Dynamic, v2 : Dynamic) : Bool {
		#if (haxe_ver >= "4.0.0")
			#if js
				return js.Syntax.instanceof(v1, v2);
			#else
				return Std.downcast(v1, v2) != null;
			#end
		#else
			return untyped __instanceof__(v1, v2);
		#end
	}

	public static function typeof(v : Dynamic) : Dynamic {
		#if (haxe_ver >= "4.0.0")
			#if js
				return js.Syntax.typeof(v);
			#else
				// TODO: Not sure this is correct
				return Type.getClass(v);
			#end
		#else
			return untyped __typeof__(v);
		#end
	}

	public static function strictEq(v1 : Dynamic, v2 : Dynamic) : Bool {
		#if (haxe_ver >= "4.0.0")
			#if js
				return js.Syntax.strictEq(v1, v2);
			#else
				return v1 == v2;
			#end
		#else
			return untyped __strict_eq__(v1, v2);
		#end
	}

	// Getter with bounds check
	static public inline function getArray<T>(a : Array<T>, i : Int) : T {
		if (i < 0 || i >= a.length) {
			if (a.length == 0) {
				throw "array index " + i + " is out of bounds: array is empty " + haxe.CallStack.toString(haxe.CallStack.callStack());
			} else {
				throw "array index " + i + " is out of bounds: 0 <= i < " + a.length+" "+haxe.CallStack.toString(haxe.CallStack.callStack());
			}
		}
		return a[i];
	}
}
