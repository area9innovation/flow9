var $global = typeof window != "undefined" ? window : typeof global != "undefined" ? global : typeof self != "undefined" ? self : this;
var console = $global.console || {log:function(){}};
var $estr = function() { return js_Boot.__string_rec(this,''); };
function $extend(from, fields) {
	function Inherit() {} Inherit.prototype = from; var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var Assert = function() { };
Assert.__name__ = true;
Assert.check = function(cond,message) {
	if(!cond) Assert.fail("Assertion" + (message != null?": " + message:""));
};
Assert.fail = function(message) {
	Assert.printStack("Failure: " + message);
	throw new js__$Boot_HaxeError(message);
};
Assert.printStack = function(message) {
	if(message != null) Errors.print(message);
	Assert.println(Assert.callStackToString(haxe_CallStack.callStack()));
};
Assert.printExnStack = function(message) {
	if(message != null) Errors.print(message);
	Assert.println(Assert.callStackToString(haxe_CallStack.exceptionStack()));
};
Assert.callStackToString = function(stack) {
	return haxe_CallStack.toString(stack);
};
Assert.trace = function(s) {
	var stack = haxe_CallStack.callStack();
	var loc = "<unknown>";
	var i = 2;
	var _g = 0;
	try {
		while(_g < stack.length) {
			var s1 = stack[_g];
			++_g;
			switch(s1[1]) {
			case 2:
				var pos = s1[4];
				var file = s1[3];
				var item = s1[2];
				if(--i == 0) {
					loc = file + ": " + pos;
					throw "__break__";
				}
				break;
			default:
			}
		}
	} catch( e ) { if( e != "__break__" ) throw e; }
	Errors.print("TRACE: at " + loc + ": " + s);
};
Assert.memStat = function(message) {
	var msg;
	if(message != null) msg = message + ": "; else msg = "";
};
Assert.println = function(message) {
	Errors.print(message);
};
var DateTools = function() { };
DateTools.__name__ = true;
DateTools.delta = function(d,t) {
	var t1 = d.getTime() + t;
	var d1 = new Date();
	d1.setTime(t1);
	return d1;
};
var EReg = function(r,opt) {
	opt = opt.split("u").join("");
	this.r = new RegExp(r,opt);
};
EReg.__name__ = true;
EReg.prototype = {
	match: function(s) {
		if(this.r.global) this.r.lastIndex = 0;
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) return this.r.m[n]; else throw new js__$Boot_HaxeError("EReg::matched");
	}
	,split: function(s) {
		var d = "#__delim__#";
		return s.replace(this.r,d).split(d);
	}
	,__class__: EReg
};
var Errors = function() {
	this.callBack = null;
	this.doTrace = true;
	this.count = 0;
};
Errors.__name__ = true;
Errors.get = function() {
	if(Errors.instance == null) Errors.instance = new Errors();
	return Errors.instance;
};
Errors.report = function(text) {
	Errors.get().add(text);
	Errors.get().count++;
	console.error("Error: " + text);
	Errors.addToLog(text);
};
Errors.warning = function(text) {
	Errors.get().add(text);
	console.warn("Warning: " + text);
};
Errors.print = function(text) {
	if(!Errors.get().doTrace) return;
	console.log(text);
};
Errors.getCount = function() {
	return Errors.get().count;
};
Errors.resetCount = function() {
	Errors.get().count = 0;
};
Errors.addToLog = function(m) {
	if(Errors.dontlog) return;
};
Errors.closeErrorLog = function() {
};
Errors.prototype = {
	add: function(text) {
		if(this.callBack != null) this.callBack(text);
	}
	,__class__: Errors
};
var RuntimeType = { __ename__ : true, __constructs__ : ["RTVoid","RTBool","RTInt","RTDouble","RTString","RTArray","RTStruct","RTRefTo","RTUnknown"] };
RuntimeType.RTVoid = ["RTVoid",0];
RuntimeType.RTVoid.toString = $estr;
RuntimeType.RTVoid.__enum__ = RuntimeType;
RuntimeType.RTBool = ["RTBool",1];
RuntimeType.RTBool.toString = $estr;
RuntimeType.RTBool.__enum__ = RuntimeType;
RuntimeType.RTInt = ["RTInt",2];
RuntimeType.RTInt.toString = $estr;
RuntimeType.RTInt.__enum__ = RuntimeType;
RuntimeType.RTDouble = ["RTDouble",3];
RuntimeType.RTDouble.toString = $estr;
RuntimeType.RTDouble.__enum__ = RuntimeType;
RuntimeType.RTString = ["RTString",4];
RuntimeType.RTString.toString = $estr;
RuntimeType.RTString.__enum__ = RuntimeType;
RuntimeType.RTArray = function(type) { var $x = ["RTArray",5,type]; $x.__enum__ = RuntimeType; $x.toString = $estr; return $x; };
RuntimeType.RTStruct = function(name) { var $x = ["RTStruct",6,name]; $x.__enum__ = RuntimeType; $x.toString = $estr; return $x; };
RuntimeType.RTRefTo = function(type) { var $x = ["RTRefTo",7,type]; $x.__enum__ = RuntimeType; $x.toString = $estr; return $x; };
RuntimeType.RTUnknown = ["RTUnknown",8];
RuntimeType.RTUnknown.toString = $estr;
RuntimeType.RTUnknown.__enum__ = RuntimeType;
var FlowRefObject = function(v) {
	this.__v = v;
};
FlowRefObject.__name__ = true;
FlowRefObject.prototype = {
	__class__: FlowRefObject
};
var HaxeRuntime = function() { };
HaxeRuntime.__name__ = true;
HaxeRuntime.ref__ = function(val) {
	return new FlowRefObject(val);
};
HaxeRuntime.deref__ = function(val) {
	return val.__v;
};
HaxeRuntime.setref__ = function(r,v) {
	r.__v = v;
};
HaxeRuntime._s_ = function(v) {
	return v;
};
HaxeRuntime.initStruct = function(id,name,args,atypes) {
	HaxeRuntime._structnames_.h[id] = name;
	HaxeRuntime._structids_.set(name,id);
	HaxeRuntime._structargs_.h[id] = args;
	HaxeRuntime._structargtypes_.h[id] = atypes;
};
HaxeRuntime.compareByValue = function(o1,o2) {
	if(o1 == o2) return 0;
	if(o1 == null || o2 == null) return 1;
	if(Array.isArray(o1)) {
		if(!Array.isArray(o2)) return 1;
		var l1 = o1.length;
		var l2 = o2.length;
		var l;
		if(l1 < l2) l = l1; else l = l2;
		var _g = 0;
		while(_g < l) {
			var i = _g++;
			var c = HaxeRuntime.compareByValue(o1[i],o2[i]);
			if(c != 0) return c;
		}
		if(l1 == l2) return 0; else if(l1 < l2) return -1; else return 1;
	}
	if(Object.prototype.hasOwnProperty.call(o1,"_id")) {
		if(!Object.prototype.hasOwnProperty.call(o2,"_id")) return 1;
		var i1 = o1._id;
		var i2 = o2._id;
		if(i1 < i2) return -1;
		if(i1 > i2) return 1;
		var args = HaxeRuntime._structargs_.h[i1];
		var _g1 = 0;
		while(_g1 < args.length) {
			var f = args[_g1];
			++_g1;
			var c1 = HaxeRuntime.compareByValue(Reflect.field(o1,f),Reflect.field(o2,f));
			if(c1 != 0) return c1;
		}
		return 0;
	}
	if(o1 < o2) return -1; else return 1;
};
HaxeRuntime.isArray = function(o1) {
	return Array.isArray(o1);
};
HaxeRuntime.nop___ = function() {
};
HaxeRuntime.isSameStructType = function(o1,o2) {
	return !Array.isArray(o1) && !Array.isArray(o2) && Object.prototype.hasOwnProperty.call(o1,"_id") && Object.prototype.hasOwnProperty.call(o2,"_id") && o1._id == o2._id;
};
HaxeRuntime.toString = function(value) {
	if(value == null) return "{}";
	if(!Reflect.isObject(value)) return Std.string(value);
	if(Array.isArray(value)) {
		var a = value;
		var r = "[";
		var s1 = "";
		var _g = 0;
		while(_g < a.length) {
			var v = a[_g];
			++_g;
			var vc = HaxeRuntime.toString(v);
			r += s1 + vc;
			s1 = ", ";
		}
		return r + "]";
	}
	if(Object.prototype.hasOwnProperty.call(value,"__v")) return "ref " + HaxeRuntime.toString(value.__v);
	if(Object.prototype.hasOwnProperty.call(value,"_id")) {
		var id = value._id;
		var structname = HaxeRuntime._structnames_.h[id];
		var r1 = structname + "(";
		if(structname == "DLink") return r1 + "...)";
		var s2 = "";
		var args = HaxeRuntime._structargs_.h[id];
		var argTypes = HaxeRuntime._structargtypes_.h[id];
		var _g1 = 0;
		var _g2 = args.length;
		while(_g1 < _g2) {
			var i = _g1++;
			var f = args[i];
			var t = argTypes[i];
			var v1 = Reflect.field(value,f);
			switch(t[1]) {
			case 3:
				r1 += s2 + Std.string(v1) + (Std["int"](v1) == v1?".0":"");
				break;
			case 5:
				var arrtype = t[2];
				if(!Array.isArray(v1) || arrtype != RuntimeType.RTDouble) r1 += s2 + HaxeRuntime.toString(v1); else {
					r1 += s2 + "[";
					var _g3 = 0;
					var _g21 = v1.length;
					while(_g3 < _g21) {
						var j = _g3++;
						r1 += (j > 0?", ":"") + v1[j] + ((v1[j] | 0) == v1[j]?".0":"");
					}
					r1 += "]";
				}
				break;
			default:
				r1 += s2 + HaxeRuntime.toString(v1);
			}
			s2 = ", ";
		}
		r1 += ")";
		return r1;
	}
	if(Reflect.isFunction(value)) return "<function>";
	var s = value;
	s = StringTools.replace(s,"\\","\\\\");
	s = StringTools.replace(s,"\"","\\\"");
	s = StringTools.replace(s,"\n","\\n");
	s = StringTools.replace(s,"\t","\\t");
	return "\"" + s + "\"";
};
HaxeRuntime.isValueFitInType = function(type,value) {
	switch(type[1]) {
	case 5:
		var arrtype = type[2];
		if(!Array.isArray(value)) return false;
		if(arrtype != RuntimeType.RTUnknown) {
			var _g1 = 0;
			var _g = value.length;
			while(_g1 < _g) {
				var i = _g1++;
				if(!HaxeRuntime.isValueFitInType(arrtype,value[i])) return false;
			}
		}
		return true;
	case 2:
		return HaxeRuntime.typeOf(value) == RuntimeType.RTDouble;
	case 7:
		var reftype = type[2];
		{
			var _g2 = HaxeRuntime.typeOf(value);
			switch(_g2[1]) {
			case 7:
				var t = _g2[2];
				return HaxeRuntime.isValueFitInType(reftype,value.__v);
			default:
				return false;
			}
		}
		break;
	case 8:
		return true;
	case 6:
		var name = type[2];
		{
			var _g3 = HaxeRuntime.typeOf(value);
			switch(_g3[1]) {
			case 6:
				var n = _g3[2];
				return name == "" || n == name;
			default:
				return false;
			}
		}
		break;
	default:
		return HaxeRuntime.typeOf(value) == type;
	}
};
HaxeRuntime.makeStructValue = function(name,args,default_value) {
	try {
		var sid = HaxeRuntime._structids_.get(name);
		if(sid == null) return default_value;
		var types = HaxeRuntime._structargtypes_.h[sid];
		if(types.length != args.length) return default_value;
		var _g1 = 0;
		var _g = args.length;
		while(_g1 < _g) {
			var i = _g1++;
			if(!HaxeRuntime.isValueFitInType(types[i],args[i])) return default_value;
		}
		var sargs = HaxeRuntime._structargs_.h[sid];
		var o = HaxeRuntime.makeEmptyStruct(sid);
		var _g11 = 0;
		var _g2 = args.length;
		while(_g11 < _g2) {
			var i1 = _g11++;
			o[sargs[i1]] = args[i1];
		}
		return o;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return default_value;
	}
};
HaxeRuntime.makeEmptyStruct = function(sid) {
	if(HaxeRuntime._structtemplates_ != null) {
		var ff = HaxeRuntime._structtemplates_.h[sid];
		if(ff != null) return ff._copy();
	}
	return { _id : sid};
};
HaxeRuntime.typeOf = function(value) {
	if(value == null) return RuntimeType.RTVoid;
	var t;
	t = typeof(value);
	switch(t) {
	case "string":
		return RuntimeType.RTString;
	case "number":
		return RuntimeType.RTDouble;
	case "boolean":
		return RuntimeType.RTBool;
	case "object":
		if(Array.isArray(value)) return RuntimeType.RTArray(RuntimeType.RTUnknown);
		if(Object.prototype.hasOwnProperty.call(value,"_id")) return RuntimeType.RTStruct(HaxeRuntime._structnames_.get(value._id));
		if(Object.prototype.hasOwnProperty.call(value,"__v")) return RuntimeType.RTRefTo(HaxeRuntime.typeOf(value.__v));
		break;
	default:
	}
	return RuntimeType.RTUnknown;
};
HaxeRuntime.mul_32 = function(a,b) {
	var ah = a >> 16 & 65535;
	var al = a & 65535;
	var bh = b >> 16 & 65535;
	var bl = b & 65535;
	var high = ah * bl + al * bh & 65535;
	return -1 & (high << 16) + al * bl;
};
HaxeRuntime.wideStringSafe = function(str) {
	var _g1 = 0;
	var _g = str.length;
	while(_g1 < _g) {
		var i = _g1++;
		var c = HxOverrides.cca(str,i);
		if(55296 <= c && c < 57344) return false;
	}
	return true;
};
var HxOverrides = function() { };
HxOverrides.__name__ = true;
HxOverrides.dateStr = function(date) {
	var m = date.getMonth() + 1;
	var d = date.getDate();
	var h = date.getHours();
	var mi = date.getMinutes();
	var s = date.getSeconds();
	return date.getFullYear() + "-" + (m < 10?"0" + m:"" + m) + "-" + (d < 10?"0" + d:"" + d) + " " + (h < 10?"0" + h:"" + h) + ":" + (mi < 10?"0" + mi:"" + mi) + ":" + (s < 10?"0" + s:"" + s);
};
HxOverrides.strDate = function(s) {
	var _g = s.length;
	switch(_g) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d.setTime(0);
		d.setUTCHours(k[0]);
		d.setUTCMinutes(k[1]);
		d.setUTCSeconds(k[2]);
		return d;
	case 10:
		var k1 = s.split("-");
		return new Date(k1[0],k1[1] - 1,k1[2],0,0,0);
	case 19:
		var k2 = s.split(" ");
		var y = k2[0].split("-");
		var t = k2[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw new js__$Boot_HaxeError("Invalid date format : " + s);
	}
};
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) return undefined;
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(pos != null && pos != 0 && len != null && len < 0) return "";
	if(len == null) len = s.length;
	if(pos < 0) {
		pos = s.length + pos;
		if(pos < 0) pos = 0;
	} else if(len < 0) len = s.length + len - pos;
	return s.substr(pos,len);
};
HxOverrides.indexOf = function(a,obj,i) {
	var len = a.length;
	if(i < 0) {
		i += len;
		if(i < 0) i = 0;
	}
	while(i < len) {
		if(a[i] === obj) return i;
		i++;
	}
	return -1;
};
HxOverrides.remove = function(a,obj) {
	var i = HxOverrides.indexOf(a,obj,0);
	if(i == -1) return false;
	a.splice(i,1);
	return true;
};
HxOverrides.iter = function(a) {
	return { cur : 0, arr : a, hasNext : function() {
		return this.cur < this.arr.length;
	}, next : function() {
		return this.arr[this.cur++];
	}};
};
var JSBinflowBuffer = function(buffer,byte_offset,byte_length,little_endian) {
	this.StructFixupCache = new haxe_ds_StringMap();
	this.StructDefs = [];
	this.arrayBuffer = buffer;
	this.byteOffset = byte_offset;
	this.byteLength = byte_length;
	this.littleEndian = little_endian;
	this.dataView = new DataView(buffer,this.byteOffset,this.byteLength);
	this.length = this.byteLength / 2 | 0;
};
JSBinflowBuffer.__name__ = true;
JSBinflowBuffer.prototype = {
	getWord: function(idx) {
		return this.dataView.getUint16(idx * 2,this.littleEndian);
	}
	,getInt: function(idx) {
		return this.dataView.getUint16(idx * 2,this.littleEndian) | this.dataView.getUint16((idx + 1) * 2,this.littleEndian) << 16;
	}
	,getDouble: function(idx) {
		if(this.littleEndian) return this.dataView.getFloat64(idx * 2,true); else {
			JSBinflowBuffer.DoubleSwapBuffer.setUint16(0,this.dataView.getUint16(idx * 2,this.littleEndian),true);
			JSBinflowBuffer.DoubleSwapBuffer.setUint16(2,this.dataView.getUint16((idx + 1) * 2,this.littleEndian),true);
			JSBinflowBuffer.DoubleSwapBuffer.setUint16(4,this.dataView.getUint16((idx + 2) * 2,this.littleEndian),true);
			JSBinflowBuffer.DoubleSwapBuffer.setUint16(6,this.dataView.getUint16((idx + 3) * 2,this.littleEndian),true);
			return JSBinflowBuffer.DoubleSwapBuffer.getFloat64(0,true);
		}
	}
	,substr: function(idx,l) {
		var s = new StringBuf();
		var _g1 = idx;
		var _g = idx + l;
		while(_g1 < _g) {
			var i = _g1++;
			s.addChar(this.dataView.getUint16(i * 2,this.littleEndian));
		}
		return s.b;
	}
	,getFooterOffset: function() {
		var footer_offset = this.dataView.getUint16(0,this.littleEndian) | this.dataView.getUint16(2,this.littleEndian) << 16;
		if(footer_offset != 1) return [footer_offset,2]; else return [this.dataView.getUint16(4,this.littleEndian) | this.dataView.getUint16(6,this.littleEndian) << 16 | (this.dataView.getUint16(8,this.littleEndian) | this.dataView.getUint16(10,this.littleEndian) << 16),6];
	}
	,getFixup: function(name) {
		var chached_fixup = this.StructFixupCache.get(name);
		if(chached_fixup === undefined) {
			var fixup = this.Fixups(name);
			if(HaxeRuntime._structnames_.h[fixup._id] == "None") chached_fixup = null; else chached_fixup = Reflect.field(fixup,HaxeRuntime._structargs_.h[fixup._id][0]);
			var value = chached_fixup;
			this.StructFixupCache.set(name,value);
		}
		return chached_fixup;
	}
	,doArray: function(index,n) {
		var ni = index;
		var ar = [];
		var _g = 0;
		while(_g < n) {
			var i = _g++;
			var v = this.doBinary(ni);
			ni = v[1];
			ar.push(v[0]);
		}
		return [ar,ni];
	}
	,doBinary: function(index) {
		if(index < this.endIndex) {
			var word = this.dataView.getUint16(index * 2,this.littleEndian);
			var ni = index + 1;
			if(word == 65524) {
				var def = this.StructDefs[this.dataView.getUint16(ni * 2,this.littleEndian)];
				var name = def[1];
				var args = this.doArray(ni + 1,def[0]);
				var fixup = this.getFixup(name);
				var val;
				if(fixup == null) val = HaxeRuntime.makeStructValue(name,args[0],JSBinflowBuffer.FlowIllegalStruct); else val = fixup(args[0]);
				return [val,args[1]];
			} else if(word == 65526) {
				var v = this.doBinary(ni);
				return [new FlowRefObject(v[0]),v[1]];
			} else if(word == 65530) {
				var l = this.dataView.getUint16(ni * 2,this.littleEndian);
				return [this.substr(ni + 1,l),ni + 1 + l];
			} else if(word == 65532) {
				var d;
				if(this.littleEndian) d = this.dataView.getFloat64(ni * 2,true); else {
					JSBinflowBuffer.DoubleSwapBuffer.setUint16(0,this.dataView.getUint16(ni * 2,this.littleEndian),true);
					JSBinflowBuffer.DoubleSwapBuffer.setUint16(2,this.dataView.getUint16((ni + 1) * 2,this.littleEndian),true);
					JSBinflowBuffer.DoubleSwapBuffer.setUint16(4,this.dataView.getUint16((ni + 2) * 2,this.littleEndian),true);
					JSBinflowBuffer.DoubleSwapBuffer.setUint16(6,this.dataView.getUint16((ni + 3) * 2,this.littleEndian),true);
					d = JSBinflowBuffer.DoubleSwapBuffer.getFloat64(0,true);
				}
				return [d,ni + 4];
			} else if(word == 65525) {
				var i = this.dataView.getUint16(ni * 2,this.littleEndian) | this.dataView.getUint16((ni + 1) * 2,this.littleEndian) << 16;
				return [i,ni + 2];
			} else if(word < 65523) return [word,ni]; else if(word == 65523) return [this.dataView.getUint16(ni * 2,this.littleEndian) | this.dataView.getUint16((ni + 1) * 2,this.littleEndian) << 16 | this.getInt(ni + 2),ni + 4]; else if(word == 65533) return [false,ni]; else if(word == 65534) return [true,ni]; else if(word == 65528) {
				var l1 = this.dataView.getUint16(ni * 2,this.littleEndian);
				var result = this.doArray(ni + 1,l1);
				return result;
			} else if(word == 65527) return [[],ni]; else if(word == 65531) {
				var l2 = this.dataView.getUint16(ni * 2,this.littleEndian) | this.dataView.getUint16((ni + 1) * 2,this.littleEndian) << 16;
				return [this.substr(ni + 2,l2),ni + 2 + l2];
			} else if(word == 65529) {
				var l3 = this.dataView.getUint16(ni * 2,this.littleEndian) | this.dataView.getUint16((ni + 1) * 2,this.littleEndian) << 16;
				var result1 = this.doArray(ni + 2,l3);
				return result1;
			} else if(word == 65535) return [null,ni]; else return [word,ni];
		} else return [this.DefValue,index];
	}
	,deserialise: function(defvalue,fixups) {
		if(JSBinflowBuffer.FlowIllegalStruct == null) JSBinflowBuffer.FlowIllegalStruct = HaxeRuntime.makeStructValue("IllegalStruct",[],null);
		var footer_offset = this.getFooterOffset();
		this.endIndex = this.length;
		this.StructDefs = this.doBinary(footer_offset[0])[0];
		this.DefValue = defvalue;
		this.Fixups = fixups;
		this.endIndex = footer_offset[0];
		var r = this.doBinary(footer_offset[1]);
		if(r[1] < footer_offset[0]) Errors.print("Did not understand all!");
		return r[0];
	}
	,__class__: JSBinflowBuffer
};
var Lambda = function() { };
Lambda.__name__ = true;
Lambda.exists = function(it,f) {
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var x = $it0.next();
		if(f(x)) return true;
	}
	return false;
};
Lambda.count = function(it,pred) {
	var n = 0;
	if(pred == null) {
		var $it0 = $iterator(it)();
		while( $it0.hasNext() ) {
			var _ = $it0.next();
			n++;
		}
	} else {
		var $it1 = $iterator(it)();
		while( $it1.hasNext() ) {
			var x = $it1.next();
			if(pred(x)) n++;
		}
	}
	return n;
};
Lambda.find = function(it,f) {
	var $it0 = $iterator(it)();
	while( $it0.hasNext() ) {
		var v = $it0.next();
		if(f(v)) return v;
	}
	return null;
};
var MacroUtils = function() { };
MacroUtils.__name__ = true;
Math.__name__ = true;
var Md5 = function() {
};
Md5.__name__ = true;
Md5.encode = function(s) {
	return Md5.inst.doEncode(s);
};
Md5.bitOR = function(a,b) {
	var lsb = a & 1 | b & 1;
	var msb31 = a >>> 1 | b >>> 1;
	return msb31 << 1 | lsb;
};
Md5.bitXOR = function(a,b) {
	var lsb = a & 1 ^ b & 1;
	var msb31 = a >>> 1 ^ b >>> 1;
	return msb31 << 1 | lsb;
};
Md5.bitAND = function(a,b) {
	var lsb = a & 1 & (b & 1);
	var msb31 = a >>> 1 & b >>> 1;
	return msb31 << 1 | lsb;
};
Md5.addme = function(x,y) {
	var lsw = (x & 65535) + (y & 65535);
	var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
	return msw << 16 | lsw & 65535;
};
Md5.rhex = function(num) {
	var str = "";
	var hex_chr = "0123456789abcdef";
	var _g = 0;
	while(_g < 4) {
		var j = _g++;
		str += hex_chr.charAt(num >> j * 8 + 4 & 15) + hex_chr.charAt(num >> j * 8 & 15);
	}
	return str;
};
Md5.rol = function(num,cnt) {
	return num << cnt | num >>> 32 - cnt;
};
Md5.cmn = function(q,a,b,x,s,t) {
	return Md5.addme(Md5.rol(Md5.addme(Md5.addme(a,q),Md5.addme(x,t)),s),b);
};
Md5.ff = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x,s,t);
};
Md5.gg = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x,s,t);
};
Md5.hh = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x,s,t);
};
Md5.ii = function(a,b,c,d,x,s,t) {
	return Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x,s,t);
};
Md5.prototype = {
	str2blks: function(str) {
		var nblk = (str.length + 8 >> 6) + 1;
		var blks = [];
		var _g1 = 0;
		var _g = nblk * 16;
		while(_g1 < _g) {
			var i1 = _g1++;
			blks[i1] = 0;
		}
		var i = 0;
		while(i < str.length) {
			blks[i >> 2] |= HxOverrides.cca(str,i) << (str.length * 8 + i) % 4 * 8;
			i++;
		}
		blks[i >> 2] |= 128 << (str.length * 8 + i) % 4 * 8;
		var l = str.length * 8;
		var k = nblk * 16 - 2;
		blks[k] = l & 255;
		blks[k] |= (l >>> 8 & 255) << 8;
		blks[k] |= (l >>> 16 & 255) << 16;
		blks[k] |= (l >>> 24 & 255) << 24;
		return blks;
	}
	,charCodeAt: function(str,i) {
		return HxOverrides.cca(str,i);
	}
	,doEncode: function(str) {
		var x = this.str2blks(str);
		var a = 1732584193;
		var b = -271733879;
		var c = -1732584194;
		var d = 271733878;
		var step;
		var i = 0;
		while(i < x.length) {
			var olda = a;
			var oldb = b;
			var oldc = c;
			var oldd = d;
			step = 0;
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i],7,-680876936);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 1],12,-389564586);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 2],17,606105819);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 3],22,-1044525330);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i + 4],7,-176418897);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 5],12,1200080426);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 6],17,-1473231341);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 7],22,-45705983);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i + 8],7,1770035416);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 9],12,-1958414417);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 10],17,-42063);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 11],22,-1990404162);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,c),Md5.bitAND(~b,d)),a,b,x[i + 12],7,1804603682);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,b),Md5.bitAND(~a,c)),d,a,x[i + 13],12,-40341101);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,a),Md5.bitAND(~d,b)),c,d,x[i + 14],17,-1502002290);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,d),Md5.bitAND(~c,a)),b,c,x[i + 15],22,1236535329);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 1],5,-165796510);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 6],9,-1069501632);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 11],14,643717713);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i],20,-373897302);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 5],5,-701558691);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 10],9,38016083);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 15],14,-660478335);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i + 4],20,-405537848);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 9],5,568446438);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 14],9,-1019803690);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 3],14,-187363961);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i + 8],20,1163531501);
			a = Md5.cmn(Md5.bitOR(Md5.bitAND(b,d),Md5.bitAND(c,~d)),a,b,x[i + 13],5,-1444681467);
			d = Md5.cmn(Md5.bitOR(Md5.bitAND(a,c),Md5.bitAND(b,~c)),d,a,x[i + 2],9,-51403784);
			c = Md5.cmn(Md5.bitOR(Md5.bitAND(d,b),Md5.bitAND(a,~b)),c,d,x[i + 7],14,1735328473);
			b = Md5.cmn(Md5.bitOR(Md5.bitAND(c,a),Md5.bitAND(d,~a)),b,c,x[i + 12],20,-1926607734);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 5],4,-378558);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i + 8],11,-2022574463);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 11],16,1839030562);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 14],23,-35309556);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 1],4,-1530992060);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i + 4],11,1272893353);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 7],16,-155497632);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 10],23,-1094730640);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 13],4,681279174);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i],11,-358537222);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 3],16,-722521979);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 6],23,76029189);
			a = Md5.cmn(Md5.bitXOR(Md5.bitXOR(b,c),d),a,b,x[i + 9],4,-640364487);
			d = Md5.cmn(Md5.bitXOR(Md5.bitXOR(a,b),c),d,a,x[i + 12],11,-421815835);
			c = Md5.cmn(Md5.bitXOR(Md5.bitXOR(d,a),b),c,d,x[i + 15],16,530742520);
			b = Md5.cmn(Md5.bitXOR(Md5.bitXOR(c,d),a),b,c,x[i + 2],23,-995338651);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i],6,-198630844);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 7],10,1126891415);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 14],15,-1416354905);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 5],21,-57434055);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i + 12],6,1700485571);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 3],10,-1894986606);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 10],15,-1051523);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 1],21,-2054922799);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i + 8],6,1873313359);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 15],10,-30611744);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 6],15,-1560198380);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 13],21,1309151649);
			a = Md5.cmn(Md5.bitXOR(c,Md5.bitOR(b,~d)),a,b,x[i + 4],6,-145523070);
			d = Md5.cmn(Md5.bitXOR(b,Md5.bitOR(a,~c)),d,a,x[i + 11],10,-1120210379);
			c = Md5.cmn(Md5.bitXOR(a,Md5.bitOR(d,~b)),c,d,x[i + 2],15,718787259);
			b = Md5.cmn(Md5.bitXOR(d,Md5.bitOR(c,~a)),b,c,x[i + 9],21,-343485551);
			a = Md5.addme(a,olda);
			b = Md5.addme(b,oldb);
			c = Md5.addme(c,oldc);
			d = Md5.addme(d,oldd);
			i += 16;
		}
		return Md5.rhex(a) + Md5.rhex(b) + Md5.rhex(c) + Md5.rhex(d);
	}
	,__class__: Md5
};
var js_BinaryParser = function(bigEndian,allowExceptions) {
	this.bigEndian = bigEndian;
	this.allowExceptions = allowExceptions;
};
js_BinaryParser.__name__ = true;
js_BinaryParser.prototype = {
	encodeFloat: function(number,precisionBits,exponentBits) {
		
			var bias = Math.pow(2, exponentBits - 1) - 1, minExp = -bias + 1, maxExp = bias, minUnnormExp = minExp - precisionBits,
			status = isNaN(n = parseFloat(number)) || n == -Infinity || n == +Infinity ? n : 0,
			exp = 0, len = 2 * bias + 1 + precisionBits + 3, bin = new Array(len),
			signal = (n = status !== 0 ? 0 : n) < 0, n = Math.abs(n), intPart = Math.floor(n), floatPart = n - intPart,
			i, lastBit, rounded, j, result;
			for(i = len; i; bin[--i] = 0);
			for(i = bias + 2; intPart && i; bin[--i] = intPart % 2, intPart = Math.floor(intPart / 2));
			for(i = bias + 1; floatPart > 0 && i; (bin[++i] = ((floatPart *= 2) >= 1) - 0) && --floatPart);
			for(i = -1; ++i < len && !bin[i];);
			if(bin[(lastBit = precisionBits - 1 + (i = (exp = bias + 1 - i) >= minExp && exp <= maxExp ? i + 1 : bias + 1 - (exp = minExp - 1))) + 1]){
			    if(!(rounded = bin[lastBit]))
				for(j = lastBit + 2; !rounded && j < len; rounded = bin[j++]);
			    for(j = lastBit + 1; rounded && --j >= 0; (bin[j] = !bin[j] - 0) && (rounded = 0));
			}
			for(i = i - 2 < 0 ? -1 : i - 3; ++i < len && !bin[i];);

			(exp = bias + 1 - i) >= minExp && exp <= maxExp ? ++i : exp < minExp &&
			    (exp != bias + 1 - len && exp < minUnnormExp && this.warn("encodeFloat::float underflow"), i = bias + 1 - (exp = minExp - 1));
			(intPart || status !== 0) && (this.warn(intPart ? "encodeFloat::float overflow" : "encodeFloat::" + status),
			    exp = maxExp + 1, i = bias + 2, status == -Infinity ? signal = 1 : isNaN(status) && (bin[i] = 1));
			for(n = Math.abs(exp + bias), j = exponentBits + 1, result = ""; --j; result = (n % 2) + result, n = n >>= 1);
			for(var n = 0, j = 0, i = (result = (signal ? "1" : "0") + result + bin.slice(i, i + precisionBits).join("")).length, r = [];
			    i; n += (1 << j) * result.charAt(--i), j == 7 && (r[r.length] = String.fromCharCode(n), n = 0), j = (j + 1) % 8);
			r[r.length] = n ? String.fromCharCode(n) : "";
			return (this.bigEndian ? r.reverse() : r).join("");
	}
	,decodeFloat: function(data,precisionBits,exponentBits) {
		
			var b = (((typeof js !== 'undefined' && js) ?
                                (b = new js.BinaryBuffer(this.bigEndian, data)) :
                                (b = new js_BinaryBuffer(this.bigEndian, data))).checkBuffer(precisionBits + exponentBits + 1), b),
			    bias = Math.pow(2, exponentBits - 1) - 1, signal = b.readBits(precisionBits + exponentBits, 1),
			    exponent = b.readBits(precisionBits, exponentBits), significand = 0,
			    divisor = 2, curByte = b.buffer.length + (-precisionBits >> 3) - 1,
			    byteValue, startBit, mask;
			do
			    for(byteValue = b.buffer[ ++curByte ], startBit = precisionBits % 8 || 8, mask = 1 << startBit;
				mask >>= 1; (byteValue & mask) && (significand += 1 / divisor), divisor *= 2);
			while(precisionBits -= startBit);
			return exponent == (bias << 1) + 1 ? significand ? NaN : signal ? -Infinity : +Infinity
			    : (1 + signal * -2) * (exponent || significand ? !exponent ? Math.pow(2, -bias + 1) * significand
			    : Math.pow(2, exponent - bias) * (1 + significand) : 0);
	}
	,warn: function(msg) {
		if(this.allowExceptions) {
			throw new Error(msg);;
		}
		return 1;
	}
	,toDouble: function(data) {
		return this.decodeFloat(data,52,11);
	}
	,fromDouble: function(number) {
		return this.encodeFloat(number,52,11);
	}
	,__class__: js_BinaryParser
};
var StringBuf = function() {
	this.b = "";
};
StringBuf.__name__ = true;
StringBuf.prototype = {
	addChar: function(c) {
		this.b += String.fromCharCode(c);
	}
	,addSub: function(s,pos,len) {
		if(len == null) this.b += HxOverrides.substr(s,pos,null); else this.b += HxOverrides.substr(s,pos,len);
	}
	,__class__: StringBuf
};
var Platform = function() { };
Platform.__name__ = true;
var NativeHx = function() { };
NativeHx.__name__ = true;
NativeHx.println = function(arg) {
	var s = HaxeRuntime.toString(arg);
	console.log(s);
	return null;
};
NativeHx.debugStopExecution = function() {
	debugger;
};
NativeHx.hostCall = function(name,args) {
	var result = null;
	try {
		var name_parts = name.split(".");
		var fun = window;
		var fun_nested_object = fun;
		var _g1 = 0;
		var _g = name_parts.length;
		while(_g1 < _g) {
			var i = _g1++;
			fun_nested_object = fun;
			fun = fun[name_parts[i]];
		}
		result = fun.call(fun_nested_object,args[0],args[1],args[2],args[3],args[4]);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report(e);
	}
	return result;
};
NativeHx.hostAddCallback = function(name,cb) {
	window[name] = cb;
	return null;
};
NativeHx.createInvisibleTextArea = function() {
	var textArea = window.document.createElement("textarea");
	textArea.style.cssText = "position:fixed;top:0px;left:0px;width:2em;height:2em;padding:0px;border:none;outline:none;boxShadow:none;background:transparent;";
	window.document.body.appendChild(textArea);
	return textArea;
};
NativeHx.copyAction = function(textArea) {
	try {
		textArea.select();
		var successful = window.document.execCommand("copy");
		if(!successful) Errors.warning("Browser \"copy\" command execution was unsuccessful");
	} catch( err ) {
		haxe_CallStack.lastException = err;
		if (err instanceof js__$Boot_HaxeError) err = err.val;
		Errors.report("Oops, unable to copy");
	}
};
NativeHx.setClipboard = function(text) {
	var focusedElement = window.document.activeElement;
	if(window.clipboardData && window.clipboardData.setData) window.clipboardData.setData("Text",text); else {
		var textArea = NativeHx.createInvisibleTextArea();
		textArea.value = text;
		if(text.length < 10000) {
			NativeHx.copyAction(textArea);
			window.document.body.removeChild(textArea);
		} else setTimeout(function() {
			NativeHx.copyAction(textArea);
			window.document.body.removeChild(textArea);
		},0);
	}
	focusedElement.focus();
	NativeHx.clipboardData = text;
};
NativeHx.getClipboard = function() {
	if(window.clipboardData && window.clipboardData.getData) return window.clipboardData.getData("Text");
	var focusedElement = window.document.activeElement;
	var result = NativeHx.clipboardData;
	var textArea = NativeHx.createInvisibleTextArea();
	textArea.value = "";
	textArea.select();
	try {
		var successful = window.document.execCommand("paste");
		if(successful) result = textArea.value; else Errors.warning("Browser \"paste\" command execution was unsuccessful");
	} catch( err ) {
		haxe_CallStack.lastException = err;
		if (err instanceof js__$Boot_HaxeError) err = err.val;
		Errors.report("Oops, unable to paste");
	}
	window.document.body.removeChild(textArea);
	focusedElement.focus();
	return result;
};
NativeHx.setCurrentDirectory = function(path) {
};
NativeHx.getCurrentDirectory = function() {
	return "";
};
NativeHx.getClipboardFormat = function(mimetype) {
	if(mimetype == "html" || mimetype == "text/html") return NativeHx.clipboardDataHtml; else return "";
};
NativeHx.getApplicationPath = function() {
	return "";
};
NativeHx.toString = function(value) {
	return HaxeRuntime.toString(value);
};
NativeHx.gc = function() {
};
NativeHx.addHttpHeader = function(data) {
};
NativeHx.getCgiParameter = function(name) {
	return "";
};
NativeHx.subrange = function(arr,start,len) {
	if(start < 0 || len < 1) return []; else return arr.slice(start,start + len);
};
NativeHx.isArray = function(a) {
	return Array.isArray(a);
};
NativeHx.isSameStructType = function(a,b) {
	return !Array.isArray(a) && !Array.isArray(b) && Object.prototype.hasOwnProperty.call(a,"_id") && Object.prototype.hasOwnProperty.call(b,"_id") && a._id == b._id;
};
NativeHx.isSameObj = function(a,b) {
	if(a == b) return true;
	if(a != null && b != null && Object.prototype.hasOwnProperty.call(a,"_id") && a._id == b._id && HaxeRuntime._structargs_.get(a._id).length == 0) return true;
	return false;
};
NativeHx.length__ = function(arr) {
	return arr.length;
};
NativeHx.strlen = function(s) {
	return s.length;
};
NativeHx.strIndexOf = function(str,substr) {
	return str.indexOf(substr,0);
};
NativeHx.strRangeIndexOf = function(str,substr,start,end) {
	if(end >= str.length) return str.indexOf(substr,start);
	var rv = HxOverrides.substr(str,start,end - start).indexOf(substr,0);
	if(rv < 0) return rv; else return start + rv;
};
NativeHx.substring = function(str,start,end) {
	return HxOverrides.substr(str,start,end);
};
NativeHx.toLowerCase = function(str) {
	return str.toLowerCase();
};
NativeHx.toUpperCase = function(str) {
	return str.toUpperCase();
};
NativeHx.string2utf8 = function(str) {
	var a = [];
	var buf = new haxe_io_BytesOutput();
	buf.writeString(str);
	var bytes = buf.getBytes();
	var _g1 = 0;
	var _g = bytes.length;
	while(_g1 < _g) {
		var i = _g1++;
		a.push(bytes.b[i]);
	}
	return a;
};
NativeHx.s2a = function(str) {
	var arr = [];
	var _g1 = 0;
	var _g = str.length;
	while(_g1 < _g) {
		var i = _g1++;
		arr.push(HxOverrides.cca(str,i));
	}
	return arr;
};
NativeHx.list2string = function(h) {
	var result = [];
	while(Object.prototype.hasOwnProperty.call(h,"head")) {
		var s = Std.string(h.head);
		result.push(s);
		h = h.tail;
	}
	result.reverse();
	return result.join("");
};
NativeHx.list2array = function(h) {
	var result = [];
	while(Object.prototype.hasOwnProperty.call(h,"head")) {
		result.push(h.head);
		h = h.tail;
	}
	result.reverse();
	return result;
};
NativeHx.bitXor = function(a,b) {
	return a ^ b;
};
NativeHx.bitAnd = function(a,b) {
	return a & b;
};
NativeHx.bitOr = function(a,b) {
	return a | b;
};
NativeHx.bitUshr = function(a,b) {
	return a >>> b;
};
NativeHx.bitShl = function(a,b) {
	return a << b;
};
NativeHx.bitNot = function(a) {
	return ~a;
};
NativeHx.concat = function(arr1,arr2) {
	return arr1.concat(arr2);
};
NativeHx.replace = function(arr,i,v) {
	if(arr == null || i < 0) return []; else if(i == arr.length && NativeHx.useConcatForPush) return arr.concat([v]); else {
		var new_arr = arr.slice(0,arr.length);
		new_arr[i] = v;
		return new_arr;
	}
};
NativeHx.map = function(values,clos) {
	var n = values.length;
	var result = Array(n);
	var _g = 0;
	while(_g < n) {
		var i = _g++;
		result[i] = clos(values[i]);
	}
	return result;
};
NativeHx.iter = function(values,clos) {
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		clos(v);
	}
};
NativeHx.mapi = function(values,clos) {
	var n = values.length;
	var result = Array(n);
	var _g = 0;
	while(_g < n) {
		var i = _g++;
		result[i] = clos(i,values[i]);
	}
	return result;
};
NativeHx.iteri = function(values,clos) {
	var i = 0;
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		clos(i,v);
		i++;
	}
};
NativeHx.iteriUntil = function(values,clos) {
	var i = 0;
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		if(clos(i,v)) return i;
		i++;
	}
	return i;
};
NativeHx.fold = function(values,init,fn) {
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		init = fn(init,v);
	}
	return init;
};
NativeHx.foldi = function(values,init,fn) {
	var i = 0;
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		init = fn(i,init,v);
		i++;
	}
	return init;
};
NativeHx.filter = function(values,clos) {
	var result = [];
	var _g = 0;
	while(_g < values.length) {
		var v = values[_g];
		++_g;
		if(clos(v)) result.push(v);
	}
	return result;
};
NativeHx.random = function() {
	return Math.random();
};
NativeHx.deleteNative = function(clip) {
	if(clip != null) {
		clip.renderable = false;
		if(clip.parent != null && clip.parent.removeChild != null) clip.parent.removeChild(clip);
		if(clip.destroy != null) clip.destroy({ children : true, texture : false, baseTexture : false});
	}
};
NativeHx.timestamp = function() {
	return NativeTime.timestamp();
};
NativeHx.getCurrentDate = function() {
	var date = new Date();
	return NativeHx.makeStructValue("Date",[date.getFullYear(),date.getMonth() + 1,date.getDate()],HaxeRuntime.makeStructValue("IllegalStruct",[],null));
};
NativeHx.defer = function(cb) {
	if(NativeHx.DeferQueue.length == 0) haxe_Timer.delay(function() {
		var _g = 0;
		var _g1 = NativeHx.DeferQueue;
		while(_g < _g1.length) {
			var f = _g1[_g];
			++_g;
			f();
		}
		NativeHx.DeferQueue = [];
	},0);
	NativeHx.DeferQueue.push(cb);
};
NativeHx.timer = function(ms,cb) {
	var fn = function() {
		try {
			cb();
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			var stackAsString = "n/a";
			var actualStack = Assert.callStackToString(haxe_CallStack.callStack());
			var crashInfo = Std.string(e) + "\nStack at timer creation:\n" + stackAsString + "\nStack:\n" + actualStack;
			NativeHx.println("FATAL ERROR: timer callback: " + crashInfo);
			Assert.printStack(e);
			NativeHx.callFlowCrashHandlers("[Timer Handler]: " + crashInfo);
		}
	};
	if(ms == 0) {
		NativeHx.defer(fn);
		return;
	}
	haxe_Timer.delay(fn,ms);
};
NativeHx.sin = function(a) {
	return Math.sin(a);
};
NativeHx.asin = function(a) {
	return Math.asin(a);
};
NativeHx.acos = function(a) {
	return Math.acos(a);
};
NativeHx.atan = function(a) {
	return Math.atan(a);
};
NativeHx.atan2 = function(a,b) {
	return Math.atan2(a,b);
};
NativeHx.exp = function(a) {
	return Math.exp(a);
};
NativeHx.log = function(a) {
	return Math.log(a);
};
NativeHx.enumFromTo = function(from,to) {
	var newArray = [];
	var _g1 = from;
	var _g = to + 1;
	while(_g1 < _g) {
		var i = _g1++;
		newArray.push(i);
	}
	return newArray;
};
NativeHx.getAllUrlParameters = function() {
	var parameters = new haxe_ds_StringMap();
	var paramString = window.location.search.substring(1);
	var params = paramString.split("&");
	var _g = 0;
	while(_g < params.length) {
		var keyvalue = params[_g];
		++_g;
		var pair = keyvalue.split("=");
		var value;
		if(pair.length > 1) value = decodeURIComponent(pair[1].split("+").join(" ")); else value = "";
		parameters.set(pair[0],value);
	}
	var i = 0;
	var result = [];
	var $it0 = parameters.keys();
	while( $it0.hasNext() ) {
		var key = $it0.next();
		var keyvalue1 = [];
		keyvalue1[0] = key;
		keyvalue1[1] = __map_reserved[key] != null?parameters.getReserved(key):parameters.h[key];
		result[i] = keyvalue1;
		i++;
	}
	return result;
};
NativeHx.getUrlParameter = function(name) {
	var value = "";
	value = Util.getParameter(name);
	if(value != null) return value; else return "";
};
NativeHx.isTouchScreen = function() {
	return NativeHx.isMobile() || (('ontouchstart' in window) || (window.DocumentTouch && document instanceof DocumentTouch) || window.matchMedia('(pointer: coarse)').matches);
};
NativeHx.isMobile = function() {
	return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Windows Phone/i.test(navigator.userAgent);
};
NativeHx.getTargetName = function() {
	var testdiv = window.document.createElement("div");
	testdiv.style.height = "1in";
	testdiv.style.width = "1in";
	testdiv.style.left = "-100%";
	testdiv.style.top = "-100%";
	testdiv.style.position = "absolute";
	window.document.body.appendChild(testdiv);
	var dpi = testdiv.offsetHeight * window.devicePixelRatio;
	window.document.body.removeChild(testdiv);
	if(!NativeHx.isMobile()) return "js,pixi,dpi=" + dpi; else return "js,pixi,mobile,dpi=" + dpi;
};
NativeHx.isIE = function() {
	return window.navigator.userAgent.indexOf("MSIE") >= 0;
};
NativeHx.setKeyValue = function(k,v) {
	return NativeHx.setKeyValueJS(k,v,false);
};
NativeHx.getKeyValue = function(key,def) {
	return NativeHx.getKeyValueJS(key,def,false);
};
NativeHx.removeKeyValue = function(key) {
	var useMask = StringTools.endsWith(key,"*");
	var mask = "";
	if(useMask) mask = HxOverrides.substr(key,0,key.length - 1);
	NativeHx.removeKeyValueJS(key,false);
};
NativeHx.setSessionKeyValue = function(k,v) {
	return NativeHx.setKeyValueJS(k,v,true);
};
NativeHx.getSessionKeyValue = function(key,def) {
	return NativeHx.getKeyValueJS(key,def,true);
};
NativeHx.removeSessionKeyValue = function(key) {
	NativeHx.removeKeyValueJS(key,true);
};
NativeHx.setKeyValueJS = function(k,v,session) {
	try {
		var storage;
		if(session) storage = sessionStorage; else storage = localStorage;
		if(NativeHx.isIE()) storage.setItem(k,encodeURIComponent(v)); else storage.setItem(k,v);
		return true;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Cannot set value for key \"" + k + "\": " + Std.string(e));
		return false;
	}
};
NativeHx.getKeyValueJS = function(key,def,session) {
	try {
		var storage;
		if(session) storage = sessionStorage; else storage = localStorage;
		var value = storage.getItem(key);
		if(null == value) return def;
		if(NativeHx.isIE()) return decodeURIComponent(value.split("+").join(" ")); else return value;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Cannot get value for key \"" + key + "\": " + Std.string(e));
		return def;
	}
};
NativeHx.removeKeyValueJS = function(key,session) {
	var useMask = StringTools.endsWith(key,"*");
	var mask = "";
	if(useMask) mask = HxOverrides.substr(key,0,key.length - 1);
	try {
		var storage;
		if(session) storage = sessionStorage; else storage = localStorage;
		if(storage.length == 0) return;
		if(useMask) {
			var nextKey;
			var _g1 = 0;
			var _g = storage.length;
			while(_g1 < _g) {
				var i = _g1++;
				nextKey = storage.key(i);
				if(StringTools.startsWith(nextKey,mask)) storage.removeItem(nextKey);
			}
		} else storage.removeItem(key);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Cannot remove key \"" + key + "\": " + Std.string(e));
	}
};
NativeHx.clearTrace = function() {
};
NativeHx.printCallstack = function() {
	console.trace();
};
NativeHx.captureCallstack = function() {
	return null;
};
NativeHx.captureCallstackItem = function(index) {
	return null;
};
NativeHx.impersonateCallstackItem = function(item,index) {
};
NativeHx.impersonateCallstackFn = function(fn,index) {
};
NativeHx.impersonateCallstackNone = function(index) {
};
NativeHx.failWithError = function(e) {
	throw new js__$Boot_HaxeError("Runtime failure: " + e);
};
NativeHx.makeStructValue = function(name,args,default_value) {
	return HaxeRuntime.makeStructValue(name,args,default_value);
};
NativeHx.quit = function(c) {
	window.open("","_top").close();
};
NativeHx.getFileContent = function(file) {
	return "";
};
NativeHx.getFileContentBinary = function(file) {
	throw new js__$Boot_HaxeError("Not implemented for this target: getFileContentBinary");
	return "";
};
NativeHx.setFileContent = function(file,content) {
	return false;
};
NativeHx.setFileContentUTF16 = function(file,content) {
	return false;
};
NativeHx.setFileContentBinary = function(file,content) {
	return false;
};
NativeHx.setFileContentBytes = function(file,content) {
	return NativeHx.setFileContentBinary(file,content);
};
NativeHx.startProcess = function(command,args,cwd,stdIn,onExit) {
	return false;
};
NativeHx.runProcess = function(command,args,cwd,onstdout,onstderr,onExit) {
	return false;
};
NativeHx.startDetachedProcess = function(command,args,cwd) {
	return false;
};
NativeHx.writeProcessStdin = function(process,arg) {
	return false;
};
NativeHx.killProcess = function(process) {
	return false;
};
NativeHx.fromCharCode = function(c) {
	return String.fromCharCode(c);
};
NativeHx.utc2local = function(stamp) {
	return NativeTime.utc2local(stamp);
};
NativeHx.local2utc = function(stamp) {
	return NativeTime.local2utc(stamp);
};
NativeHx.string2time = function(date) {
	return NativeTime.string2time(date);
};
NativeHx.dayOfWeek = function(year,month,day) {
	return NativeTime.dayOfWeek(year,month,day);
};
NativeHx.time2string = function(date) {
	return NativeTime.time2string(date);
};
NativeHx.getUrl = function(u,t) {
	try {
		window.open(u,t);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		if(e != null && e.number != -2147467259) throw new js__$Boot_HaxeError(e);
	}
};
NativeHx.getUrl2 = function(u,t) {
	try {
		return window.open(u,t) != null;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		if(e != null && e.number != -2147467259) throw new js__$Boot_HaxeError(e); else Errors.report(e);
		return false;
	}
};
NativeHx.getCharCodeAt = function(s,i) {
	return HxOverrides.cca(s,i);
};
NativeHx.loaderUrl = function() {
	return window.location.href;
};
NativeHx.number2double = function(n) {
	return n;
};
NativeHx.stringbytes2double = function(s) {
	return NativeHx.stringToDouble(s);
};
NativeHx.stringbytes2int = function(s) {
	return HxOverrides.cca(s,0) | HxOverrides.cca(s,1) << 16;
};
NativeHx.initBinarySerialization = function() {
	if(typeof(ArrayBuffer) == "undefined" || typeof(Float64Array) == "undefined") {
		var binaryParser = new js_BinaryParser(false,false);
		NativeHx.doubleToString = function(value) {
			return NativeHx.packDoubleBytes(binaryParser.fromDouble(value));
		};
		NativeHx.stringToDouble = function(str) {
			return binaryParser.toDouble(NativeHx.unpackDoubleBytes(str));
		};
	} else {
		var arrayBuffer = new ArrayBuffer(16);
		var uint16Array = new Uint16Array(arrayBuffer);
		var float64Array = new Float64Array(arrayBuffer);
		NativeHx.doubleToString = function(value1) {
			float64Array[0] = value1;
			var ret_b = "";
			ret_b += String.fromCharCode(uint16Array[0]);
			ret_b += String.fromCharCode(uint16Array[1]);
			ret_b += String.fromCharCode(uint16Array[2]);
			ret_b += String.fromCharCode(uint16Array[3]);
			return ret_b;
		};
		NativeHx.stringToDouble = function(str1) {
			uint16Array[0] = HxOverrides.cca(str1,0);
			uint16Array[1] = HxOverrides.cca(str1,1);
			uint16Array[2] = HxOverrides.cca(str1,2);
			uint16Array[3] = HxOverrides.cca(str1,3);
			return float64Array[0];
		};
	}
};
NativeHx.packDoubleBytes = function(s) {
	var ret = new StringBuf();
	var _g1 = 0;
	var _g = s.length / 2;
	while(_g1 < _g) {
		var i = _g1++;
		ret.addChar(HxOverrides.cca(s,i * 2) | HxOverrides.cca(s,i * 2 + 1) << 8);
	}
	return ret.b;
};
NativeHx.unpackDoubleBytes = function(s) {
	var ret = new StringBuf();
	var _g1 = 0;
	var _g = s.length;
	while(_g1 < _g) {
		var i = _g1++;
		ret.addChar(HxOverrides.cca(s,i) & 255);
		ret.addChar(HxOverrides.cca(s,i) >> 8);
	}
	return ret.b;
};
NativeHx.writeBinaryInt32 = function(value,buf) {
	buf.b += String.fromCharCode(value & 65535);
	buf.b += String.fromCharCode(value >> 16);
};
NativeHx.writeInt = function(value,buf) {
	if((value & -32768) != 0) {
		buf.b += String.fromCharCode(65525);
		buf.b += String.fromCharCode(value & 65535);
		buf.b += String.fromCharCode(value >> 16);
	} else buf.b += String.fromCharCode(value);
};
NativeHx.writeStructDefs = function(buf) {
	NativeHx.writeArrayLength(NativeHx.structDefs.length,buf);
	var _g = 0;
	var _g1 = NativeHx.structDefs;
	while(_g < _g1.length) {
		var struct_def = _g1[_g];
		++_g;
		buf.b += String.fromCharCode(65528);
		buf.b += "\x02";
		buf.addChar(struct_def[0]);
		buf.b += String.fromCharCode(65530);
		buf.addChar(struct_def[1].length);
		buf.addSub(struct_def[1],0,null);
	}
};
NativeHx.writeArrayLength = function(arr_len,buf) {
	if(arr_len == 0) buf.b += String.fromCharCode(65527); else if(arr_len > 65535) {
		buf.b += String.fromCharCode(65529);
		buf.b += String.fromCharCode(arr_len & 65535);
		buf.b += String.fromCharCode(arr_len >> 16);
	} else {
		buf.b += String.fromCharCode(65528);
		buf.b += String.fromCharCode(arr_len);
	}
};
NativeHx.writeBinaryValue = function(value,buf) {
	{
		var _g = HaxeRuntime.typeOf(value);
		switch(_g[1]) {
		case 0:
			buf.b += String.fromCharCode(65535);
			break;
		case 1:
			buf.b += String.fromCharCode(value?65534:65533);
			break;
		case 3:
			buf.b += String.fromCharCode(65532);
			buf.addSub(NativeHx.doubleToString(value),0,null);
			break;
		case 4:
			var str_len = value.length;
			if(value.length > 65535) {
				buf.b += String.fromCharCode(65531);
				buf.b += String.fromCharCode(str_len & 65535);
				buf.b += String.fromCharCode(str_len >> 16);
			} else {
				buf.b += String.fromCharCode(65530);
				buf.b += String.fromCharCode(str_len);
			}
			buf.addSub(value,0,null);
			break;
		case 5:
			var t = _g[2];
			var arr_len = value.length;
			NativeHx.writeArrayLength(arr_len,buf);
			var _g1 = 0;
			while(_g1 < arr_len) {
				var i = _g1++;
				NativeHx.writeBinaryValue(value[i],buf);
			}
			break;
		case 6:
			var n = _g[2];
			var struct_id = value._id;
			var struct_fields = HaxeRuntime._structargs_.h[struct_id];
			var field_types = HaxeRuntime._structargtypes_.h[struct_id];
			var fields_count = struct_fields.length;
			var struct_idx = 0;
			if(NativeHx.structIdxs.h.hasOwnProperty(struct_id)) struct_idx = NativeHx.structIdxs.h[struct_id]; else {
				struct_idx = NativeHx.structDefs.length;
				NativeHx.structIdxs.h[struct_id] = struct_idx;
				NativeHx.structDefs.push([fields_count,HaxeRuntime._structnames_.h[struct_id]]);
			}
			buf.b += String.fromCharCode(65524);
			buf.b += String.fromCharCode(struct_idx);
			var _g11 = 0;
			while(_g11 < fields_count) {
				var i1 = _g11++;
				var field = Reflect.field(value,struct_fields[i1]);
				if(field_types[i1] == RuntimeType.RTInt) NativeHx.writeInt(field,buf); else NativeHx.writeBinaryValue(field,buf);
			}
			break;
		case 7:
			var t1 = _g[2];
			buf.b += String.fromCharCode(65526);
			NativeHx.writeBinaryValue(value.__v,buf);
			break;
		default:
			throw new js__$Boot_HaxeError("Cannot serialize " + Std.string(value));
		}
	}
};
NativeHx.toBinary = function(value) {
	var buf = new StringBuf();
	NativeHx.structIdxs = new haxe_ds_IntMap();
	NativeHx.structDefs = [];
	NativeHx.writeBinaryValue(value,buf);
	var str = buf.b;
	var struct_defs_buf = new StringBuf();
	NativeHx.writeStructDefs(struct_defs_buf);
	var ret = String.fromCharCode(str.length + 2 & 65535) + String.fromCharCode(str.length + 2 >> 16) + str + struct_defs_buf.b;
	return ret;
};
NativeHx.fromBinary = function(string,defvalue,fixups) {
	if(Type.getClass(string) == JSBinflowBuffer) return string.deserialise(defvalue,fixups); else return string;
};
NativeHx.getTotalMemoryUsed = function() {
	return 0.0;
};
NativeHx.addCrashHandler = function(cb) {
	NativeHx.FlowCrashHandlers.push(cb);
	return function() {
		HxOverrides.remove(NativeHx.FlowCrashHandlers,cb);
	};
};
NativeHx.callFlowCrashHandlers = function(msg) {
	msg += "Call stack: " + Assert.callStackToString(haxe_CallStack.exceptionStack());
	var _g = 0;
	var _g1 = NativeHx.FlowCrashHandlers.slice(0,NativeHx.FlowCrashHandlers.length);
	while(_g < _g1.length) {
		var hdlr = _g1[_g];
		++_g;
		hdlr(msg);
	}
};
NativeHx.addPlatformEventListener = function(event,cb) {
	if(!NativeHx.PlatformEventListeners.exists(event)) {
		var value = [];
		NativeHx.PlatformEventListeners.set(event,value);
	}
	NativeHx.PlatformEventListeners.get(event).push(cb);
	return function() {
		var _this = NativeHx.PlatformEventListeners.get(event);
		HxOverrides.remove(_this,cb);
	};
};
NativeHx.notifyPlatformEvent = function(event) {
	var cancelled = false;
	if(NativeHx.PlatformEventListeners.exists(event)) {
		var _g = 0;
		var _g1 = NativeHx.PlatformEventListeners.get(event);
		while(_g < _g1.length) {
			var cb = _g1[_g];
			++_g;
			cancelled = cb() || cancelled;
		}
	}
	return cancelled;
};
NativeHx.addCameraPhotoEventListener = function(cb) {
	return function() {
	};
};
NativeHx.addCameraVideoEventListener = function(cb) {
	return function() {
	};
};
NativeHx.md5 = function(content) {
	var b_b = "";
	var c = NativeHx.string2utf8(content);
	var _g = 0;
	while(_g < c.length) {
		var i = c[_g];
		++_g;
		b_b += String.fromCharCode(i);
	}
	return Md5.encode(b_b);
};
NativeHx.concurrentAsync = function(fine,tasks,cb) {
	
var fns = tasks.map(function(c, i, a) {
	var v = function v (callback) {
		var r = c.call();
		callback(null, r);
	}
	return v;
});

async.parallel(fns, function(err, results) { cb(results) });;
};
var NativeTime = function() { };
NativeTime.__name__ = true;
NativeTime.timestamp = function() {
	var t = new Date().getTime();
	return t;
};
NativeTime.utc2local = function(stamp) {
	var date;
	var d = new Date();
	d.setTime(stamp);
	date = d;
	var offset = date.getTimezoneOffset() * 60000.;
	return stamp - offset;
};
NativeTime.local2utc = function(stamp) {
	var date;
	var d = new Date();
	d.setTime(stamp);
	date = d;
	var offset = date.getTimezoneOffset() * 60000.;
	date = DateTools.delta(date,offset);
	offset = date.getTimezoneOffset() * 60000.;
	return stamp + offset;
};
NativeTime.getTimeOffset = function() {
	var now = new Date();
	now = new Date(now.getFullYear(),now.getMonth(),now.getDate(),0,0,0);
	return now.getTime() - 86400000. * Math.round(now.getTime() / 24 / 3600 / 1000);
};
NativeTime.string2time = function(date) {
	return HxOverrides.strDate(date).getTime();
};
NativeTime.time2string = function(date) {
	var _this;
	var d = new Date();
	d.setTime(date);
	_this = d;
	return HxOverrides.dateStr(_this);
};
NativeTime.dayOfWeek = function(year,month,day) {
	var d = new Date(year,month - 1,day,0,0,0);
	return (d.getDay() + 6) % 7;
};
var Reflect = function() { };
Reflect.__name__ = true;
Reflect.field = function(o,field) {
	try {
		return o[field];
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return null;
	}
};
Reflect.setField = function(o,field,value) {
	o[field] = value;
};
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(f != "__id__" && f != "hx__closures__" && hasOwnProperty.call(o,f)) a.push(f);
		}
	}
	return a;
};
Reflect.isFunction = function(f) {
	return typeof(f) == "function" && !(f.__name__ || f.__ename__);
};
Reflect.isObject = function(v) {
	if(v == null) return false;
	var t = typeof(v);
	return t == "string" || t == "object" && v.__enum__ == null || t == "function" && (v.__name__ || v.__ename__) != null;
};
var GraphOp = { __ename__ : true, __constructs__ : ["MoveTo","LineTo","CurveTo"] };
GraphOp.MoveTo = function(x,y) { var $x = ["MoveTo",0,x,y]; $x.__enum__ = GraphOp; $x.toString = $estr; return $x; };
GraphOp.LineTo = function(x,y) { var $x = ["LineTo",1,x,y]; $x.__enum__ = GraphOp; $x.toString = $estr; return $x; };
GraphOp.CurveTo = function(x,y,cx,cy) { var $x = ["CurveTo",2,x,y,cx,cy]; $x.__enum__ = GraphOp; $x.toString = $estr; return $x; };
var Util = function() { };
Util.__name__ = true;
Util.getParameter = function(name) {
	var href = window.location.href;
	var href2;
	if(window.urlParameters) href2 = window.urlParameters; else href2 = "";
	var regexS = "[\\?&]" + name + "=([^&#]*)";
	var regex = new EReg(regexS,"");
	if(regex.match(href)) return StringTools.urlDecode(regex.matched(1)); else if(regex.match(href2)) return StringTools.urlDecode(regex.matched(1)); else return null;
};
Util.makePath = function(dir,name) {
	if(StringTools.endsWith(dir,"/")) return dir + name; else return dir + "/" + name;
};
Util.openFile = function(path,mode) {
	if(mode == null) mode = true;
	return null;
};
Util.createDir = function(dir) {
};
Util.println = function(s) {
};
Util.clearCache = function() {
	Util.filesCache = new haxe_ds_StringMap();
	Util.filesHashCache = new haxe_ds_StringMap();
};
Util.readFile = function(file) {
	var content = Util.filesCache.get(file);
	if(content == null) {
	}
	return content;
};
Util.setFileContent = function(file,content) {
	Util.filesCache.set(file,content);
	Util.filesHashCache.set(file,null);
};
Util.getFileContent = function(file,content) {
	Util.filesCache.get(file);
};
Util.fileMd5 = function(file) {
	var hash = Util.filesHashCache.get(file);
	if(hash == null) {
		var content = Util.readFile(file);
		if(content != null) {
			var value = Md5.encode(content);
			Util.filesHashCache.set(file,value);
		}
	}
	return hash;
};
Util.writeFile = function(file,content) {
};
Util.compareStrings = function(a,b) {
	if(a < b) return -1;
	if(a > b) return 1;
	return 0;
};
Util.fromCharCode = function(code) {
	return String.fromCharCode(code);
};
var StringTools = function() { };
StringTools.__name__ = true;
StringTools.urlDecode = function(s) {
	return decodeURIComponent(s.split("+").join(" "));
};
StringTools.htmlEscape = function(s,quotes) {
	s = s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
	if(quotes) return s.split("\"").join("&quot;").split("'").join("&#039;"); else return s;
};
StringTools.startsWith = function(s,start) {
	return s.length >= start.length && HxOverrides.substr(s,0,start.length) == start;
};
StringTools.endsWith = function(s,end) {
	var elen = end.length;
	var slen = s.length;
	return slen >= elen && HxOverrides.substr(s,slen - elen,elen) == end;
};
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	return c > 8 && c < 14 || c == 32;
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) r++;
	if(r > 0) return HxOverrides.substr(s,r,l - r); else return s;
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) r++;
	if(r > 0) return HxOverrides.substr(s,0,l - r); else return s;
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
StringTools.replace = function(s,sub,by) {
	return s.split(sub).join(by);
};
StringTools.hex = function(n,digits) {
	var s = "";
	var hexChars = "0123456789ABCDEF";
	do {
		s = hexChars.charAt(n & 15) + s;
		n >>>= 4;
	} while(n > 0);
	if(digits != null) while(s.length < digits) s = "0" + s;
	return s;
};
StringTools.fastCodeAt = function(s,index) {
	return s.charCodeAt(index);
};
var haxe_Timer = function(time_ms) {
	var me = this;
	this.id = setInterval(function() {
		me.run();
	},time_ms);
};
haxe_Timer.__name__ = true;
haxe_Timer.delay = function(f,time_ms) {
	var t = new haxe_Timer(time_ms);
	t.run = function() {
		t.stop();
		f();
	};
	return t;
};
haxe_Timer.prototype = {
	stop: function() {
		if(this.id == null) return;
		clearInterval(this.id);
		this.id = null;
	}
	,run: function() {
	}
	,__class__: haxe_Timer
};
var _$RenderSupportHx_Graphics = function(clip) {
	this.owner = clip;
	this.graphOps = [];
	this.strokeOpacity = this.fillOpacity = 0.0;
	this.strokeWidth = 0.0;
};
_$RenderSupportHx_Graphics.__name__ = true;
_$RenderSupportHx_Graphics.prototype = {
	addGraphOp: function(op) {
		this.graphOps.push(op);
	}
	,setLineStyle: function(width,color,opacity) {
		this.strokeWidth = width;
		this.strokeColor = color;
		this.strokeOpacity = opacity;
	}
	,setSolidFill: function(color,opacity) {
		this.fillColor = color;
		this.fillOpacity = opacity;
	}
	,setGradientFill: function(colors,alphas,offsets,matrix,type) {
		this.fillGradientColors = colors;
		this.fillGradientAlphas = alphas;
		this.fillGradientOffsets = offsets;
		this.fillGradientMatrix = matrix;
		this.fillGradientType = type;
	}
	,measure: function() {
		var max_x = -Infinity;
		var max_y = -Infinity;
		var min_x = Infinity;
		var min_y = Infinity;
		var _g1 = 0;
		var _g = this.graphOps.length;
		while(_g1 < _g) {
			var i = _g1++;
			var op = this.graphOps[i];
			switch(op[1]) {
			case 0:
				var y = op[3];
				var x = op[2];
				if(x > max_x) max_x = x;
				if(x < min_x) min_x = x;
				if(y > max_y) max_y = y;
				if(y < min_y) min_y = y;
				break;
			case 1:
				var y1 = op[3];
				var x1 = op[2];
				if(i == 0) max_x = max_y = min_x = min_y = 0.0;
				if(x1 > max_x) max_x = x1;
				if(x1 < min_x) min_x = x1;
				if(y1 > max_y) max_y = y1;
				if(y1 < min_y) min_y = y1;
				break;
			case 2:
				var cy = op[5];
				var cx = op[4];
				var y2 = op[3];
				var x2 = op[2];
				if(i == 0) max_x = max_y = min_x = min_y = 0.0;
				if(x2 > max_x) max_x = x2;
				if(x2 < min_x) min_x = x2;
				if(y2 > max_y) max_y = y2;
				if(y2 < min_y) min_y = y2;
				if(cx > max_x) max_x = cx;
				if(cx < min_x) min_x = cx;
				if(cy > max_y) max_y = cy;
				if(cy < min_y) min_y = cy;
				break;
			}
		}
		return { x0 : min_x, y0 : min_y, x1 : max_x + this.strokeWidth, y1 : max_y + this.strokeWidth};
	}
	,createSVGElement: function(name,attrs) {
		var element = window.document.createElementNS("http://www.w3.org/2000/svg",name);
		var _g = 0;
		while(_g < attrs.length) {
			var a = attrs[_g];
			++_g;
			element.setAttribute(a.n,a.v);
		}
		return element;
	}
	,addSVGGradient: function(svg,id) {
		var defs = this.createSVGElement("defs",[]);
		svg.appendChild(defs);
		var width = this.fillGradientMatrix[0];
		var height = this.fillGradientMatrix[1];
		var rotation = this.fillGradientMatrix[2];
		var xOffset = this.fillGradientMatrix[3];
		var yOffset = this.fillGradientMatrix[4];
		var grad = this.createSVGElement("linearGradient",[{ n : "id", v : id},{ n : "x1", v : xOffset},{ n : "y1", v : yOffset},{ n : "x2", v : width * Math.cos(rotation / 180.0 * Math.PI)},{ n : "y2", v : height * Math.sin(rotation / 180.0 * Math.PI)}]);
		defs.appendChild(grad);
		var _g1 = 0;
		var _g = this.fillGradientColors.length;
		while(_g1 < _g) {
			var i = _g1++;
			var stop_pt = this.createSVGElement("stop",[{ n : "offset", v : "" + this.fillGradientOffsets[i] * 100.0 + "%"},{ n : "stop-color", v : RenderSupportHx.makeCSSColor(this.fillGradientColors[i],this.fillGradientAlphas[i])}]);
			grad.appendChild(stop_pt);
		}
	}
	,renderSVG: function() {
		var wh = this.measure();
		var svg = this.createSVGElement("svg",[{ n : "xmlns", v : "http://www.w3.org/2000/svg"},{ n : "version", v : "1.1"}]);
		var path_data = "";
		var _g = 0;
		var _g1 = this.graphOps;
		while(_g < _g1.length) {
			var op = _g1[_g];
			++_g;
			switch(op[1]) {
			case 0:
				var y = op[3];
				var x = op[2];
				path_data += "M " + x + " " + y + " ";
				break;
			case 1:
				var y1 = op[3];
				var x1 = op[2];
				path_data += "L " + x1 + " " + y1 + " ";
				break;
			case 2:
				var cy = op[5];
				var cx = op[4];
				var y2 = op[3];
				var x2 = op[2];
				path_data += "S " + cx + " " + cy + " " + x2 + " " + y2 + " ";
				break;
			}
		}
		var svgpath_attr = [{ n : "d", v : path_data}];
		if(this.strokeOpacity != 0.0) svgpath_attr.push({ n : "stroke", v : RenderSupportHx.makeCSSColor(this.strokeColor,this.strokeOpacity)});
		if(this.fillOpacity != 0.0) svgpath_attr.push({ n : "fill", v : RenderSupportHx.makeCSSColor(this.fillColor,this.fillOpacity)}); else if(this.fillGradientColors != null) {
			var id = "grad" + new Date().getTime();
			this.addSVGGradient(svg,id);
			svgpath_attr.push({ n : "fill", v : "url(#" + id + ")"});
		} else svgpath_attr.push({ n : "fill", v : RenderSupportHx.makeCSSColor(16777215,0.0)});
		svgpath_attr.push({ n : "transform", v : "translate(" + -wh.x0 + "," + -wh.y0 + ")"});
		var svgpath = this.createSVGElement("path",svgpath_attr);
		svg.setAttribute("width",wh.x1 - wh.x0);
		svg.setAttribute("height",wh.y1 - wh.y0);
		svg.appendChild(svgpath);
		svg.style.left = "" + wh.x0 + "px";
		svg.style.top = "" + wh.y0 + "px";
		this.owner.appendChild(svg);
	}
	,renderCanvas: function() {
		var wh = this.measure();
		var canvas = window.document.createElement("CANVAS");
		var ctx = canvas.getContext("2d");
		this.owner.appendChild(canvas);
		canvas.height = wh.y1 - wh.y0;
		canvas.width = wh.x1 - wh.x0;
		canvas.style.top = "" + wh.y0 + "px";
		canvas.style.left = "" + wh.x0 + "px";
		canvas.x0 = wh.x0;
		canvas.y0 = wh.y0;
		canvas.style.width = "" + (wh.x1 - wh.x0) + "px";
		canvas.style.height = "" + (wh.y1 - wh.y0) + "px";
		if(this.strokeOpacity != 0.0) {
			ctx.lineWidth = this.strokeWidth;
			ctx.strokeStyle = RenderSupportHx.makeCSSColor(this.strokeColor,this.strokeOpacity);
		}
		if(this.fillOpacity != 0.0) ctx.fillStyle = RenderSupportHx.makeCSSColor(this.fillColor,this.fillOpacity);
		if(this.fillGradientColors != null) {
			var width = this.fillGradientMatrix[0];
			var height = this.fillGradientMatrix[1];
			var rotation = this.fillGradientMatrix[2];
			var xOffset = this.fillGradientMatrix[3];
			var yOffset = this.fillGradientMatrix[4];
			var gradient = ctx.createLinearGradient(xOffset,yOffset,width * Math.cos(rotation / 180.0 * Math.PI),height * Math.sin(rotation / 180.0 * Math.PI));
			var _g1 = 0;
			var _g = this.fillGradientColors.length;
			while(_g1 < _g) {
				var i = _g1++;
				gradient.addColorStop(this.fillGradientOffsets[i],RenderSupportHx.makeCSSColor(this.fillGradientColors[i],this.fillGradientAlphas[i]));
			}
			ctx.fillStyle = gradient;
		}
		ctx.translate(-wh.x0,-wh.y0);
		ctx.beginPath();
		ctx.moveTo(0.0,0.0);
		var _g2 = 0;
		var _g11 = this.graphOps;
		while(_g2 < _g11.length) {
			var op = _g11[_g2];
			++_g2;
			switch(op[1]) {
			case 0:
				var y = op[3];
				var x = op[2];
				ctx.moveTo(x,y);
				break;
			case 1:
				var y1 = op[3];
				var x1 = op[2];
				ctx.lineTo(x1,y1);
				break;
			case 2:
				var cy = op[5];
				var cx = op[4];
				var y2 = op[3];
				var x2 = op[2];
				ctx.quadraticCurveTo(cx,cy,x2,y2);
				break;
			}
		}
		if(this.fillOpacity != 0.0 || this.fillGradientColors != null) {
			ctx.closePath();
			ctx.fill();
		}
		if(this.strokeOpacity != 0.0) ctx.stroke();
	}
	,render: function() {
		if(_$RenderSupportHx_Graphics.svg) this.renderSVG(); else this.renderCanvas();
	}
	,__class__: _$RenderSupportHx_Graphics
};
var haxe_Resource = function() { };
haxe_Resource.__name__ = true;
haxe_Resource.getString = function(name) {
	var _g = 0;
	var _g1 = haxe_Resource.content;
	while(_g < _g1.length) {
		var x = _g1[_g];
		++_g;
		if(x.name == name) {
			if(x.str != null) return x.str;
			var b = haxe_crypto_Base64.decode(x.data);
			return b.toString();
		}
	}
	return null;
};
var haxe_io_Bytes = function(data) {
	this.length = data.byteLength;
	this.b = new Uint8Array(data);
	this.b.bufferValue = data;
	data.hxBytes = this;
	data.bytes = this.b;
};
haxe_io_Bytes.__name__ = true;
haxe_io_Bytes.alloc = function(length) {
	return new haxe_io_Bytes(new ArrayBuffer(length));
};
haxe_io_Bytes.ofString = function(s) {
	var a = [];
	var i = 0;
	while(i < s.length) {
		var c = StringTools.fastCodeAt(s,i++);
		if(55296 <= c && c <= 56319) c = c - 55232 << 10 | StringTools.fastCodeAt(s,i++) & 1023;
		if(c <= 127) a.push(c); else if(c <= 2047) {
			a.push(192 | c >> 6);
			a.push(128 | c & 63);
		} else if(c <= 65535) {
			a.push(224 | c >> 12);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		} else {
			a.push(240 | c >> 18);
			a.push(128 | c >> 12 & 63);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		}
	}
	return new haxe_io_Bytes(new Uint8Array(a).buffer);
};
haxe_io_Bytes.prototype = {
	get: function(pos) {
		return this.b[pos];
	}
	,set: function(pos,v) {
		this.b[pos] = v & 255;
	}
	,getString: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
		var s = "";
		var b = this.b;
		var fcc = String.fromCharCode;
		var i = pos;
		var max = pos + len;
		while(i < max) {
			var c = b[i++];
			if(c < 128) {
				if(c == 0) break;
				s += fcc(c);
			} else if(c < 224) s += fcc((c & 63) << 6 | b[i++] & 127); else if(c < 240) {
				var c2 = b[i++];
				s += fcc((c & 31) << 12 | (c2 & 127) << 6 | b[i++] & 127);
			} else {
				var c21 = b[i++];
				var c3 = b[i++];
				var u = (c & 15) << 18 | (c21 & 127) << 12 | (c3 & 127) << 6 | b[i++] & 127;
				s += fcc((u >> 10) + 55232);
				s += fcc(u & 1023 | 56320);
			}
		}
		return s;
	}
	,toString: function() {
		return this.getString(0,this.length);
	}
	,__class__: haxe_io_Bytes
};
var haxe_crypto_Base64 = function() { };
haxe_crypto_Base64.__name__ = true;
haxe_crypto_Base64.decode = function(str,complement) {
	if(complement == null) complement = true;
	if(complement) while(HxOverrides.cca(str,str.length - 1) == 61) str = HxOverrides.substr(str,0,-1);
	return new haxe_crypto_BaseCode(haxe_crypto_Base64.BYTES).decodeBytes(haxe_io_Bytes.ofString(str));
};
var haxe_crypto_BaseCode = function(base) {
	var len = base.length;
	var nbits = 1;
	while(len > 1 << nbits) nbits++;
	if(nbits > 8 || len != 1 << nbits) throw new js__$Boot_HaxeError("BaseCode : base length must be a power of two.");
	this.base = base;
	this.nbits = nbits;
};
haxe_crypto_BaseCode.__name__ = true;
haxe_crypto_BaseCode.prototype = {
	initTable: function() {
		var tbl = [];
		var _g = 0;
		while(_g < 256) {
			var i = _g++;
			tbl[i] = -1;
		}
		var _g1 = 0;
		var _g2 = this.base.length;
		while(_g1 < _g2) {
			var i1 = _g1++;
			tbl[this.base.b[i1]] = i1;
		}
		this.tbl = tbl;
	}
	,decodeBytes: function(b) {
		var nbits = this.nbits;
		var base = this.base;
		if(this.tbl == null) this.initTable();
		var tbl = this.tbl;
		var size = b.length * nbits >> 3;
		var out = haxe_io_Bytes.alloc(size);
		var buf = 0;
		var curbits = 0;
		var pin = 0;
		var pout = 0;
		while(pout < size) {
			while(curbits < 8) {
				curbits += nbits;
				buf <<= nbits;
				var i = tbl[b.get(pin++)];
				if(i == -1) throw new js__$Boot_HaxeError("BaseCode : invalid encoded char");
				buf |= i;
			}
			curbits -= 8;
			out.set(pout++,buf >> curbits & 255);
		}
		return out;
	}
	,__class__: haxe_crypto_BaseCode
};
var Std = function() { };
Std.__name__ = true;
Std.string = function(s) {
	return js_Boot.__string_rec(s,"");
};
Std["int"] = function(x) {
	return x | 0;
};
Std.parseInt = function(x) {
	var v = parseInt(x,10);
	if(v == 0 && (HxOverrides.cca(x,1) == 120 || HxOverrides.cca(x,1) == 88)) v = parseInt(x);
	if(isNaN(v)) return null;
	return v;
};
Std.parseFloat = function(x) {
	return parseFloat(x);
};
var js_Boot = function() { };
js_Boot.__name__ = true;
js_Boot.getClass = function(o) {
	if((o instanceof Array) && o.__enum__ == null) return Array; else {
		var cl = o.__class__;
		if(cl != null) return cl;
		var name = js_Boot.__nativeClassName(o);
		if(name != null) return js_Boot.__resolveNativeClass(name);
		return null;
	}
};
js_Boot.__string_rec = function(o,s) {
	if(o == null) return "null";
	if(s.length >= 5) return "<...>";
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) t = "object";
	switch(t) {
	case "object":
		if(o instanceof Array) {
			if(o.__enum__) {
				if(o.length == 2) return o[0];
				var str2 = o[0] + "(";
				s += "\t";
				var _g1 = 2;
				var _g = o.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					if(i1 != 2) str2 += "," + js_Boot.__string_rec(o[i1],s); else str2 += js_Boot.__string_rec(o[i1],s);
				}
				return str2 + ")";
			}
			var l = o.length;
			var i;
			var str1 = "[";
			s += "\t";
			var _g2 = 0;
			while(_g2 < l) {
				var i2 = _g2++;
				str1 += (i2 > 0?",":"") + js_Boot.__string_rec(o[i2],s);
			}
			str1 += "]";
			return str1;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			return "???";
		}
		if(tostr != null && tostr != Object.toString && typeof(tostr) == "function") {
			var s2 = o.toString();
			if(s2 != "[object Object]") return s2;
		}
		var k = null;
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		for( var k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) str += ", \n";
		str += s + k + " : " + js_Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "function":
		return "<function>";
	case "string":
		return o;
	default:
		return String(o);
	}
};
js_Boot.__interfLoop = function(cc,cl) {
	if(cc == null) return false;
	if(cc == cl) return true;
	var intf = cc.__interfaces__;
	if(intf != null) {
		var _g1 = 0;
		var _g = intf.length;
		while(_g1 < _g) {
			var i = _g1++;
			var i1 = intf[i];
			if(i1 == cl || js_Boot.__interfLoop(i1,cl)) return true;
		}
	}
	return js_Boot.__interfLoop(cc.__super__,cl);
};
js_Boot.__instanceof = function(o,cl) {
	if(cl == null) return false;
	switch(cl) {
	case Int:
		return (o|0) === o;
	case Float:
		return typeof(o) == "number";
	case Bool:
		return typeof(o) == "boolean";
	case String:
		return typeof(o) == "string";
	case Array:
		return (o instanceof Array) && o.__enum__ == null;
	case Dynamic:
		return true;
	default:
		if(o != null) {
			if(typeof(cl) == "function") {
				if(o instanceof cl) return true;
				if(js_Boot.__interfLoop(js_Boot.getClass(o),cl)) return true;
			} else if(typeof(cl) == "object" && js_Boot.__isNativeObj(cl)) {
				if(o instanceof cl) return true;
			}
		} else return false;
		if(cl == Class && o.__name__ != null) return true;
		if(cl == Enum && o.__ename__ != null) return true;
		return o.__enum__ == cl;
	}
};
js_Boot.__nativeClassName = function(o) {
	var name = js_Boot.__toStr.call(o).slice(8,-1);
	if(name == "Object" || name == "Function" || name == "Math" || name == "JSON") return null;
	return name;
};
js_Boot.__isNativeObj = function(o) {
	return js_Boot.__nativeClassName(o) != null;
};
js_Boot.__resolveNativeClass = function(name) {
	return $global[name];
};
var RenderSupportHx = function() {
};
RenderSupportHx.__name__ = true;
RenderSupportHx.loadWebFonts = function() {
	var webfontconfig = JSON.parse(haxe_Resource.getString("webfontconfig"));
	webfontconfig.active = function() {
		Errors.print("Web fonts are loaded");
	};
	webfontconfig.loading = function() {
		Errors.print("Loading web fonts...");
	};
	WebFont.load(webfontconfig);
};
RenderSupportHx.oldinit = function() {
	haxe_Timer.delay(function() {
		window.document.body.style.backgroundImage = "none";
	},100);
	var indicator = window.document.getElementById("loading_js_indicator");
	if(null != indicator) indicator.style.display = "none";
	RenderSupportHx.prepareCurrentClip();
	RenderSupportHx.makeTempClip();
	RenderSupportHx.startMouseListening();
	RenderSupportHx.ImageCache = new haxe_ds_StringMap();
	RenderSupportHx.PendingImages = new haxe_ds_StringMap();
	RenderSupportHx.StageScale = 1.0;
	if("1" == Util.getParameter("svg")) {
		Errors.print("Using SVG rendering");
		_$RenderSupportHx_Graphics.svg = true;
	} else {
		Errors.print("Using HTML 5 rendering");
		_$RenderSupportHx_Graphics.svg = false;
	}
	RenderSupportHx.loadWebFonts();
	RenderSupportHx.AriaClips = [];
	RenderSupportHx.AriaDialogsStack = [];
	RenderSupportHx.addGlobalKeyHandlers();
	RenderSupportHx.attachEventListener(RenderSupportHx.getStage(),"focusin",function() {
		var selected = window.document.activeElement;
		if(selected != null && selected.getAttribute("role") != null) {
			var h = RenderSupportHx.getElementHeight(selected);
			var w = RenderSupportHx.getElementWidth(selected);
			var global_scale = RenderSupportHx.getGlobalScale(selected);
			h = h / global_scale.scale_y;
			w = w / global_scale.scale_x;
			selected.style.height = "" + h + "px";
			selected.style.width = "" + w + "px";
		}
	});
	var receiveMessage = function(e) {
		var hasNestedWindow = null;
		hasNestedWindow = function(iframe,win) {
			try {
				if(iframe.contentWindow == win) return true;
				var iframes = iframe.contentWindow.document.getElementsByTagName("iframe");
				var _g1 = 0;
				var _g = iframes.length;
				while(_g1 < _g) {
					var i = _g1++;
					if(hasNestedWindow(iframes[i],win)) return true;
				}
			} catch( e1 ) {
				haxe_CallStack.lastException = e1;
				if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
				Errors.print(e1);
			}
			return false;
		};
		var content_win = e.source;
		var all_iframes = window.document.getElementsByTagName("iframe");
		var _g11 = 0;
		var _g2 = all_iframes.length;
		while(_g11 < _g2) {
			var i1 = _g11++;
			var f = all_iframes[i1];
			if(hasNestedWindow(f,content_win)) {
				f.callflow(["postMessage",e.data]);
				return;
			}
		}
		Errors.report("Warning: unknown message source");
	};
	window.addEventListener("message",receiveMessage);
};
RenderSupportHx.getPixelsPerCm = function() {
	return 37.795275590551178;
};
RenderSupportHx.setHitboxRadius = function(radius) {
	return false;
};
RenderSupportHx.hideWaitMessage = function() {
	try {
		window.document.getElementById("wait_message").style.display = "none";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
	}
};
RenderSupportHx.updateCSSTransform = function(clip) {
	var transform = "translate(" + Std.string(clip.x) + "px," + Std.string(clip.y) + "px) scale(" + Std.string(clip.scale_x) + "," + Std.string(clip.scale_y) + ") rotate(" + Std.string(clip.rot) + "deg)";
	clip.style.WebkitTransform = transform;
	clip.style.msTransform = transform;
	clip.style.transform = transform;
};
RenderSupportHx.isFirefox = function() {
	var useragent = window.navigator.userAgent;
	return useragent.indexOf("Firefox") >= 0;
};
RenderSupportHx.isWinFirefox = function() {
	var useragent = window.navigator.userAgent;
	return useragent.indexOf("Firefox") >= 0 && useragent.indexOf("Windows") >= 0;
};
RenderSupportHx.isTouchScreen = function() {
	return NativeHx.isTouchScreen();
};
RenderSupportHx.addGlobalKeyHandlers = function() {
	RenderSupportHx.attachEventListener(RenderSupportHx.getStage(),"keydown",function(e) {
		if(e.which == 13 || e.which == 32 || e.which == 113) {
			var active = window.document.activeElement;
			if(active != null && RenderSupportHx.isAriaClip(active)) RenderSupportHx.simulateClickForClip(active);
		} else if(e.ctrlKey && e.which == 38) {
			if(RenderSupportHx.StageScale < 2.0) {
				RenderSupportHx.StageScale = 2.0;
				window.document.body.style.overflow = "auto";
				RenderSupportHx.setClipScaleX(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
				RenderSupportHx.setClipScaleY(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
			}
		} else if(e.ctrlKey && e.which == 40) {
			if(RenderSupportHx.StageScale > 1.0) {
				RenderSupportHx.StageScale = 1.0;
				window.document.body.scrollLeft = window.document.body.scrollTop = 0;
				window.document.body.style.overflow = "hidden";
				RenderSupportHx.setClipScaleX(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
				RenderSupportHx.setClipScaleY(RenderSupportHx.CurrentClip,RenderSupportHx.StageScale);
			}
		}
	});
};
RenderSupportHx.isAriaClip = function(clip) {
	var role = clip.getAttribute("role");
	return role == "button" || role == "checkbox" || role == "dialog";
};
RenderSupportHx.addAriaClip = function(clip) {
	var role = clip.getAttribute("role");
	if(role == "dialog") RenderSupportHx.AriaDialogsStack.push(clip); else RenderSupportHx.AriaClips.push(clip);
};
RenderSupportHx.removeAriaClip = function(clip) {
	var role = clip.getAttribute("role");
	if(role == "dialog") {
		var x = clip;
		HxOverrides.remove(RenderSupportHx.AriaDialogsStack,x);
	} else {
		var x1 = clip;
		HxOverrides.remove(RenderSupportHx.AriaClips,x1);
	}
};
RenderSupportHx.simulateClickForClip = function(clip) {
	RenderSupportHx.MouseX = RenderSupportHx.getElementX(clip) + 2.0;
	RenderSupportHx.MouseY = RenderSupportHx.getElementY(clip) + 2.0;
	var stage = RenderSupportHx.getStage();
	if(stage.flowmousedown != null) stage.flowmousedown();
	if(stage.flowmouseup != null) stage.flowmouseup();
};
RenderSupportHx.prepareCurrentClip = function() {
	RenderSupportHx.CurrentClip = window.document.getElementById("flow");
	RenderSupportHx.CurrentClip.x = RenderSupportHx.CurrentClip.y = RenderSupportHx.CurrentClip.rot = 0;
	RenderSupportHx.CurrentClip.scale_x = RenderSupportHx.CurrentClip.scale_y = 1.0;
	var stage = RenderSupportHx.getStage();
	stage.x = stage.y = stage.rot = 0;
	stage.scale_x = stage.scale_y = 1.0;
	if("1" == Util.getParameter("forceredraw")) {
		Errors.report("Turning on workaround for Chrome & FF rendering issue");
		var needs_redraw = false;
		var redraw_timer = new haxe_Timer(500);
		redraw_timer.run = function() {
			if(needs_redraw) {
				RenderSupportHx.CurrentClip.style.display = "none";
				RenderSupportHx.CurrentClip.offsetHeight;
				RenderSupportHx.CurrentClip.style.display = "block";
				needs_redraw = false;
			}
		};
		RenderSupportHx.CurrentClip.addEventListener("DOMNodeInserted",function() {
			needs_redraw = true;
		},true);
	}
};
RenderSupportHx.makeTempClip = function() {
	RenderSupportHx.TempClip = RenderSupportHx.makeClip();
	RenderSupportHx.TempClip.setAttribute("aria-hidden","true");
	RenderSupportHx.TempClip.style.opacity = 0.0;
	RenderSupportHx.TempClip.style.zIndex = -1000;
	window.document.body.appendChild(RenderSupportHx.TempClip);
};
RenderSupportHx.attachEventListener = function(item,event,cb) {
	if(RenderSupportHx.isFirefox() && event == "mousewheel") item.addEventListener("DOMMouseScroll",cb,true); else if(item.addEventListener) item.addEventListener(event,cb,true); else if(item.attachEvent) {
		if(item == window) window.document.attachEvent("on" + event,cb); else item.attachEvent("on" + event,cb);
	}
};
RenderSupportHx.detachEventListener = function(item,event,cb) {
	item.removeEventListener(event,cb,false);
};
RenderSupportHx.startMouseListening = function() {
	if(!RenderSupportHx.isTouchScreen()) RenderSupportHx.attachEventListener(window,"mousemove",function(e) {
		RenderSupportHx.MouseX = e.clientX + window.pageXOffset;
		RenderSupportHx.MouseY = e.clientY + window.pageYOffset;
	}); else {
		RenderSupportHx.attachEventListener(window,"touchmove",function(e1) {
			if(e1.touches.length != 1) return;
			RenderSupportHx.MouseX = e1.touches[0].clientX + window.pageXOffset;
			RenderSupportHx.MouseY = e1.touches[0].clientY + window.pageYOffset;
		});
		RenderSupportHx.attachEventListener(window,"touchstart",function(e2) {
			if(e2.touches.length != 1) return;
			RenderSupportHx.MouseX = e2.touches[0].clientX + window.pageXOffset;
			RenderSupportHx.MouseY = e2.touches[0].clientY + window.pageYOffset;
		});
	}
};
RenderSupportHx.setSelectable = function(element,selectable) {
	if(selectable) {
		element.style.WebkitUserSelect = "text";
		element.style.MozUserSelect = "text";
		element.style.MsUserSelect = "text";
	} else {
		element.style.WebkitUserSelect = "none";
		element.style.MozUserSelect = "none";
		element.style.MsUserSelect = "none";
	}
};
RenderSupportHx.getElementWidth = function(el) {
	var width = el.getBoundingClientRect().width;
	var childs = el.children;
	if(childs == null) return width;
	var _g = 0;
	while(_g < childs.length) {
		var c = childs[_g];
		++_g;
		var cw;
		cw = RenderSupportHx.getElementWidth(c) + (c.x != null?c.x:0.0);
		if(cw > width) width = cw;
	}
	return width;
};
RenderSupportHx.getElementHeight = function(el) {
	var height = el.getBoundingClientRect().height;
	var childs = el.children;
	if(childs == null) return height;
	var _g = 0;
	while(_g < childs.length) {
		var c = childs[_g];
		++_g;
		var ch;
		ch = RenderSupportHx.getElementHeight(c) + (c.y != null?c.y:0.0);
		if(ch > height) height = ch;
	}
	return height;
};
RenderSupportHx.getElementX = function(el) {
	if(el == window) return 0;
	var rect = el.getBoundingClientRect();
	return rect.left;
};
RenderSupportHx.getElementY = function(el) {
	if(el == window) return 0;
	var rect = el.getBoundingClientRect();
	return rect.top;
};
RenderSupportHx.getGlobalScale = function(el) {
	var scale = { scale_x : 1.0, scale_y : 1.0};
	while(el != null && el.scale_x != null && el.scale_y != null) {
		scale.scale_x *= el.scale_x;
		scale.scale_y *= el.scale_y;
		el = el.parentNode;
	}
	return scale;
};
RenderSupportHx.makeCanvasWH = function(w,h) {
	var canvas = window.document.createElement("canvas");
	canvas.height = h;
	canvas.width = w;
	canvas.x0 = canvas.y0 = 0.0;
	return canvas;
};
RenderSupportHx.makeCSSColor = function(color,alpha) {
	return "rgba(" + (color >> 16 & 255) + "," + (color >> 8 & 255) + "," + (color & 255) + "," + alpha + ")";
};
RenderSupportHx.loadImage = function(clip,url,error_cb,metricsFn) {
	var image_loaded = function(cl,mFn,img) {
		mFn(img.width,img.height);
		cl.appendChild(img.cloneNode(false));
	};
	if(RenderSupportHx.ImageCache.exists(url)) image_loaded(clip,metricsFn,RenderSupportHx.ImageCache.get(url)); else if(RenderSupportHx.PendingImages.exists(url)) RenderSupportHx.PendingImages.get(url).push({ c : clip, m : metricsFn, e : error_cb}); else {
		RenderSupportHx.PendingImages.set(url,[{ c : clip, m : metricsFn, e : error_cb}]);
		var img1 = new Image();
		img1.onload = function() {
			RenderSupportHx.ImageCache.set(url,img1);
			var listeners = RenderSupportHx.PendingImages.get(url);
			var _g1 = 0;
			var _g = listeners.length;
			while(_g1 < _g) {
				var i = _g1++;
				var listener = listeners[i];
				image_loaded(listener.c,listener.m,img1);
			}
			RenderSupportHx.PendingImages.remove(url);
		};
		img1.onerror = function() {
			var listeners1 = RenderSupportHx.PendingImages.get(url);
			var _g11 = 0;
			var _g2 = listeners1.length;
			while(_g11 < _g2) {
				var i1 = _g11++;
				listeners1[i1].e();
			}
			RenderSupportHx.PendingImages.remove(url);
		};
		img1.src = url + "?" + StringTools.htmlEscape("" + new Date().getTime());
	}
};
RenderSupportHx.loadSWF = function(clip,url,error_cb,metricsFn) {
	if(StringTools.startsWith(url,"http://www")) {
		var domain_and_path = HxOverrides.substr(url,7,null);
		var pos = domain_and_path.indexOf("/");
		url = HxOverrides.substr(domain_and_path,pos,null);
	}
	var swf = window.document.createElement("OBJECT");
	swf.type = "application/x-shockwave-flash";
	swf.data = url + "?" + StringTools.htmlEscape("" + new Date().getTime());
	clip.appendChild(swf);
	var load_time = new Date().getTime();
	var try_swf_access = null;
	try_swf_access = function() {
		if(new Date().getTime() - load_time > 5000) {
			error_cb();
			return;
		}
		if(swf == null || swf.TGetProperty == null) {
			haxe_Timer.delay(try_swf_access,450);
			return;
		}
		var width = 1.3333333333333333 * swf.TGetProperty("/",8);
		var height = 1.3333333333333333 * swf.TGetProperty("/",9);
		swf.style.width = "" + width + "px";
		swf.style.height = "" + height + "px";
		metricsFn(width,height);
	};
	haxe_Timer.delay(try_swf_access,450);
};
RenderSupportHx.setAccessCallback = function(clip,callback) {
};
RenderSupportHx.setAccessAttributes = function(clip,properties) {
	var setClipRole = function(role) {
		if(role == "live") {
			clip.setAttribute("aria-live","polite");
			clip.setAttribute("relevant","additions");
			clip.setAttribute("role","aria-live");
		} else clip.setAttribute("role",role);
	};
	var _g = 0;
	while(_g < properties.length) {
		var p = properties[_g];
		++_g;
		var key = p[0];
		var value = p[1];
		if(key == "role") setClipRole(value); else if(key == "tooltip") clip.setAttribute("title",value); else if(key == "tabindex" && Std.parseInt(value) >= 0) {
			if(clip.input) clip.children[0].setAttribute("tabindex",Std.parseInt(value)); else clip.setAttribute("tabindex",Std.parseInt(value));
		} else if(key == "description") clip.setAttribute("aria-label",value); else if(key == "state") {
			if(value == "checked") clip.setAttribute("aria-checked","true"); else if(value == "unchecked") clip.setAttribute("aria-checked","false");
		} else if(key == "selectable") RenderSupportHx.setSelectable(clip,"true" == value);
	}
};
RenderSupportHx.currentClip = function() {
	return RenderSupportHx.CurrentClip;
};
RenderSupportHx.enableResize = function() {
	RenderSupportHx.hideWaitMessage();
};
RenderSupportHx.getStageWidth = function() {
	return window.innerWidth;
};
RenderSupportHx.getStageHeight = function() {
	return window.innerHeight;
};
RenderSupportHx.makeTextField = function(fontfamily) {
	var field = RenderSupportHx.makeClip();
	RenderSupportHx.TempClip.appendChild(field);
	return field;
};
RenderSupportHx.setStyleByFlowFont = function(style,fontfamily) {
	var fs = FlowFontStyle.fromFlowFont(fontfamily);
	if(fs != null) {
		style.fontFamily = fs.family;
		style.fontWeight = fs.weight;
		style.fontStyle = fs.style;
	} else style.fontFamily = fontfamily;
};
RenderSupportHx.setTextAndStyle = function(textfield,text,fontfamily,fontsize,fontweight,fontslope,fillcolour,fillopacity,letterspacing,backgroundcolour,backgroundopacity,forTextinput) {
	fontsize = fontsize * 0.97;
	var style;
	if(textfield.input) style = textfield.children[0].style; else style = textfield.style;
	RenderSupportHx.setStyleByFlowFont(style,fontfamily);
	style.fontSize = "" + Math.floor(fontsize) + "px";
	style.opacity = "" + fillopacity;
	style.color = "#" + StringTools.hex(fillcolour,6);
	style.fontWeight = fontweight;
	style.fontStyle = fontslope;
	if(letterspacing != 0) style.letterSpacing = "" + letterspacing + "px";
	if(backgroundopacity != 0.0) style.backgroundColor = "#" + StringTools.hex(backgroundcolour,6);
	textfield.font_size = fontsize;
	if(textfield.input) {
		if(textfield.children[0].value != text) textfield.children[0].value = text;
	} else {
		if(textfield.innerHTML != text) textfield.innerHTML = text;
		RenderSupportHx.patchTextFormatting(textfield);
	}
	return null;
};
RenderSupportHx.patchTextFormatting = function(node) {
	if(node.tagName == "FONT") {
		node.style.fontSize = Std.string(node.size) + "px";
		node.size = "";
		RenderSupportHx.setStyleByFlowFont(node.style,node.face);
		node.face = "";
	}
	var childs = node.children;
	if(childs.length == 0) {
		node.innerHTML = StringTools.replace(node.innerHTML," ","&nbsp;");
		node.innerHTML = StringTools.replace(node.innerHTML,"\n","<br>");
	} else {
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			RenderSupportHx.patchTextFormatting(c);
		}
	}
};
RenderSupportHx.setAdvancedText = function(textfield,sharpness,antialiastype,gridfittype) {
};
RenderSupportHx.makeVideo = function(width,height,metricsFn,durationFn) {
	var ve = window.document.createElement("VIDEO");
	if(width > 0.0) ve.width = width;
	if(height > 0.0) ve.height = height;
	ve.addEventListener("loadedmetadata",function(e) {
		durationFn(ve.duration);
		metricsFn(ve.videoWidth,ve.videoHeight);
	},false);
	return [ve,ve];
};
RenderSupportHx.setVideoVolume = function(str,volume) {
	str.volume = volume;
};
RenderSupportHx.setVideoLooping = function(str,loop) {
};
RenderSupportHx.setVideoControls = function(str,controls) {
};
RenderSupportHx.setVideoSubtitle = function(str,text,size,color) {
};
RenderSupportHx.playVideo = function(str,filename,startPaused) {
	str.src = filename;
	if(!startPaused) str.play();
};
RenderSupportHx.seekVideo = function(str,seek) {
	str.currentTime = seek;
};
RenderSupportHx.getVideoPosition = function(str) {
	return str.currentTime;
};
RenderSupportHx.pauseVideo = function(str) {
	str.pause();
};
RenderSupportHx.resumeVideo = function(str) {
	str.play();
};
RenderSupportHx.closeVideo = function(str) {
};
RenderSupportHx.getTextFieldWidth = function(textfield) {
	if(textfield.input == true) return textfield.width; else return textfield.offsetWidth;
};
RenderSupportHx.setTextFieldWidth = function(textfield,width) {
	if(textfield.input) {
		textfield.width = width;
		textfield.children[0].style.width = "" + width + "px";
	}
};
RenderSupportHx.getTextFieldHeight = function(textfield) {
	if(textfield.input == true) return textfield.height; else return textfield.offsetHeight;
};
RenderSupportHx.setTextFieldHeight = function(textfield,height) {
	if(textfield.input) {
		textfield.height = height;
		textfield.children[0].style.height = "" + height + "px";
	}
};
RenderSupportHx.setAutoAlign = function(textfield,autoalign) {
	var input_;
	if(textfield.input) input_ = textfield.children[0]; else input_ = textfield;
	switch(autoalign) {
	case "AutoAlignLeft":
		input_.style.textAlign = "left";
		break;
	case "AutoAlignRight":
		input_.style.textAlign = "right";
		break;
	case "AutoAlignCenter":
		input_.style.textAlign = "center";
		break;
	case "AutoAlignNone":
		input_.style.textAlign = "none";
		break;
	default:
		input_.style.textAlign = "left";
	}
};
RenderSupportHx.setTextInput = function(textfield) {
	var input = window.document.createElement("INPUT");
	input.type = "text";
	textfield.input = true;
	textfield.appendChild(input);
};
RenderSupportHx.setTextInputType = function(textfield,type) {
	if(textfield.input) textfield.children[0].type = type;
};
RenderSupportHx.setTabIndex = function(textfield,index) {
	if(index >= 0) {
		if(textfield.input) textfield.children[0].setAttribute("tabindex",index); else textfield.setAttribute("tabindex",index);
	}
};
RenderSupportHx.setTabEnabled = function(textfield,enabled) {
};
RenderSupportHx.getContent = function(textfield) {
	if(textfield.input) return textfield.children[0].value; else return textfield.innerHTML;
};
RenderSupportHx.getCursorPosition = function(textfield) {
	return RenderSupportHx.getCaret(textfield.children[0]);
};
RenderSupportHx.getCaret = function(el) {
	if(el.selectionStart) return el.selectionStart; else if(window.document.selection) {
		el.focus();
		var r = window.document.selection.createRange();
		if(r == null) return 0;
		var re = el.createTextRange();
		var rc = re.duplicate();
		re.moveToBookmark(r.getBookmark());
		rc.setEndPoint("EndToStart",re);
		return rc.text.length;
	}
	return 0;
};
RenderSupportHx.getFocus = function(clip) {
	var item;
	if(clip.input) item = clip.children[0]; else item = clip.focus();
	return window.document.activeElement == item;
};
RenderSupportHx.getScrollV = function(textfield) {
	return 0;
};
RenderSupportHx.setScrollV = function(textfield,suggestedPosition) {
};
RenderSupportHx.getBottomScrollV = function(textfield) {
	return 0;
};
RenderSupportHx.getNumLines = function(textfield) {
	return 0;
};
RenderSupportHx.setFocus = function(clip,focus) {
	haxe_Timer.delay(function() {
		var item;
		if(clip.input) item = clip.children[0]; else item = clip;
		if(focus) item.focus(); else item.blur();
	},10);
};
RenderSupportHx.setMultiline = function(clip,multiline) {
	if(clip.input && multiline && !clip.multiline) {
		clip.removeChild(clip.children[0]);
		var textarea = window.document.createElement("TEXTAREA");
		if(clip.width) textarea.style.width = "" + Std.string(clip.width) + "px";
		if(clip.height) textarea.style.height = "" + Std.string(clip.height) + "px";
		clip.appendChild(textarea);
		clip.multiline = true;
	}
};
RenderSupportHx.setWordWrap = function(clip,wordWrap) {
};
RenderSupportHx.getSelectionStart = function(textfield) {
	if(textfield.input == true) return textfield.children[0].selectionStart; else return 0;
};
RenderSupportHx.getSelectionEnd = function(textfield) {
	if(textfield.input == true) return textfield.children[0].selectionEnd; else return 0;
};
RenderSupportHx.setSelection = function(textfield,start,end) {
	if(textfield.input == true) haxe_Timer.delay(function() {
		if(window.document.activeElement == textfield.children[0]) textfield.children[0].setSelectionRange(start,end);
	},120);
};
RenderSupportHx.setReadOnly = function(textfield,readOnly) {
	if(textfield.input == true) textfield.children[0].disabled = readOnly;
};
RenderSupportHx.setMaxChars = function(textfield,maxChars) {
	if(textfield.input) textfield.children[0].maxLength = maxChars;
};
RenderSupportHx.addChild = function(parent,child) {
	if(child == null || parent == null) return;
	parent.appendChild(child);
	if(RenderSupportHx.isAriaClip(child)) RenderSupportHx.addAriaClip(child);
};
RenderSupportHx.removeChild = function(parent,child) {
	try {
		if(RenderSupportHx.isAriaClip(child)) RenderSupportHx.removeAriaClip(child);
		parent.removeChild(child);
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
	}
};
RenderSupportHx.makeClip = function() {
	var clip = window.document.createElement("div");
	clip.x = 0.0;
	clip.y = 0.0;
	clip.scale_x = 1.0;
	clip.scale_y = 1.0;
	clip.rot = 0.0;
	return clip;
};
RenderSupportHx.setClipCallstack = function(clip,callstack) {
};
RenderSupportHx.setClipX = function(clip,x) {
	if(clip.x != x) {
		clip.x = x;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipY = function(clip,y) {
	if(clip.y != y) {
		clip.y = y;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipScaleX = function(clip,scale_x) {
	if(clip.iframe != null) {
		if(RenderSupportHx.isIOS()) clip.style.width = scale_x * 100.0 + "px";
		clip.iframe.width = scale_x * 100.0;
	} else if(clip.scale_x != scale_x) {
		clip.scale_x = scale_x;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipScaleY = function(clip,scale_y) {
	if(clip.iframe != null) {
		if(RenderSupportHx.isIOS()) clip.style.height = scale_y * 100.0 + "px";
		clip.iframe.height = scale_y * 100.0;
	} else if(clip.scale_y != scale_y) {
		clip.scale_y = scale_y;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipRotation = function(clip,r) {
	if(r != clip.rot) {
		clip.rot = r;
		RenderSupportHx.updateCSSTransform(clip);
	}
};
RenderSupportHx.setClipAlpha = function(clip,a) {
	clip.style.opacity = a;
	if(a <= 0.01) clip.className = "hiddenByAlpha"; else if(clip.className == "hiddenByAlpha") clip.className = "";
};
RenderSupportHx.setClipMask = function(clip,mask) {
	mask.style.display = "none";
};
RenderSupportHx.getStage = function() {
	return window;
};
RenderSupportHx.addKeyEventListener = function(clip,event,fn) {
	var keycb = function(e) {
		var shift = e.shiftKey;
		var alt = e.altKey;
		var ctrl = e.ctrlKey;
		var meta = e.metaKey;
		var s = "";
		if(e.which == 13) {
			var active = window.document.activeElement;
			if(active != null && RenderSupportHx.isAriaClip(active)) return;
			s = "enter";
		} else if(e.which == 27) s = "esc"; else if(e.which == 9) s = "tab"; else if(e.which == 16) s = "shift"; else if(e.which == 17) s = "ctrl"; else if(e.which == 18) s = "alt"; else if(e.which == 37) s = "left"; else if(e.which == 38) s = "up"; else if(e.which == 39) s = "right"; else if(e.which == 40) s = "down"; else if(e.which == 46) s = "delete"; else if(e.which >= 112 && e.which <= 123) s = "F" + (e.which - 111); else s = String.fromCharCode(e.which);
		fn(s,ctrl,shift,alt,meta,e.keyCode,e.preventDefault.bind(e));
	};
	if(RenderSupportHx.isFirefox() && event == "mousewheel") clip.addEventListener("DOMMouseScroll",keycb,true); else if(clip.addEventListener) clip.addEventListener(event,keycb,true); else if(clip.attachEvent) {
		if(clip == window) window.document.attachEvent("on" + event,keycb); else clip.attachEvent("on" + event,keycb);
	}
	return function() {
		clip.removeEventListener(event,keycb,false);
	};
};
RenderSupportHx.addStreamStatusListener = function(clip,fn) {
	var on_start = function() {
		fn("NetStream.Play.Start");
	};
	var on_stop = function() {
		fn("NetStream.Play.Stop");
	};
	var on_not_found = function() {
		fn("NetStream.Play.StreamNotFound");
	};
	clip.addEventListener("loadeddata",on_start);
	clip.addEventListener("ended",on_stop);
	clip.addEventListener("error",on_not_found);
	return function() {
		clip.removeEventListener("loadeddata",on_start);
		clip.removeEventListener("ended",on_stop);
		clip.removeEventListener("error",on_not_found);
	};
};
RenderSupportHx.addEventListener = function(clip,event,fn) {
	var eventname = "";
	if(event == "click") eventname = "click"; else if(event == "mousedown") eventname = "mousedown"; else if(event == "mouseup") eventname = "mouseup"; else if(event == "mousemove") eventname = "mousemove"; else if(event == "mouseenter") eventname = "mouseover"; else if(event == "mouseleave") eventname = "mouseout"; else if(event == "rollover") eventname = "mouseover"; else if(event == "rollout") eventname = "mouseout"; else if(event == "change") eventname = "input"; else if(event == "focusin") eventname = "focus"; else if(event == "focusout") eventname = "blur"; else if(event == "resize") {
		RenderSupportHx.attachEventListener(window,"resize",fn);
		return function() {
			RenderSupportHx.detachEventListener(window,"resize",fn);
		};
	} else if(event == "scroll") eventname = "scroll"; else {
		Errors.report("Unknown event");
		return function() {
		};
	}
	if(RenderSupportHx.isTouchScreen() && (eventname == "mousedown" || eventname == "mouseup")) {
		if(eventname == "mousedown") {
			var touchstartWrapper = function(e) {
				if(e.touches.length != 1) return;
				fn();
			};
			if(RenderSupportHx.isFirefox() && false) clip.addEventListener("DOMMouseScroll",touchstartWrapper,true); else if(clip.addEventListener) clip.addEventListener("touchstart",touchstartWrapper,true); else if(clip.attachEvent) {
				if(clip == window) window.document.attachEvent("on" + "touchstart",touchstartWrapper); else clip.attachEvent("on" + "touchstart",touchstartWrapper);
			}
			return function() {
				clip.removeEventListener(eventname,touchstartWrapper,false);
			};
		} else {
			var touchendWrapper = function(e1) {
				if(e1.touches.length != 0) return;
				fn();
			};
			if(RenderSupportHx.isFirefox() && false) clip.addEventListener("DOMMouseScroll",touchendWrapper,true); else if(clip.addEventListener) clip.addEventListener("touchend",touchendWrapper,true); else if(clip.attachEvent) {
				if(clip == window) window.document.attachEvent("on" + "touchend",touchendWrapper); else clip.attachEvent("on" + "touchend",touchendWrapper);
			}
			return function() {
				clip.removeEventListener(eventname,touchendWrapper,false);
			};
		}
	} else {
		if(RenderSupportHx.isFirefox() && eventname == "mousewheel") clip.addEventListener("DOMMouseScroll",fn,true); else if(clip.addEventListener) clip.addEventListener(eventname,fn,true); else if(clip.attachEvent) {
			if(clip == window) window.document.attachEvent("on" + eventname,fn); else clip.attachEvent("on" + eventname,fn);
		}
		if(clip == window) {
			if(eventname == "mousedown") clip.flowmousedown = fn; else if(eventname == "mouseup") clip.flowmouseup = fn;
		}
		return function() {
			clip.removeEventListener(eventname,fn,false);
		};
	}
};
RenderSupportHx.addFileDropListener = function(clip,maxFilesCount,mimeTypeRegExFilter,onDone) {
	return function() {
	};
};
RenderSupportHx.addMouseWheelEventListener = function(clip,fn) {
	var wheel_cb = function(event) {
		var delta = 0.0;
		if(event.wheelDelta != null) delta = event.wheelDelta / 120; else if(event.detail != null) delta = -event.detail / 3;
		if(event.preventDefault != null) event.preventDefault();
		fn(delta);
	};
	RenderSupportHx.attachEventListener(window,"mousewheel",wheel_cb);
	return function() {
		RenderSupportHx.detachEventListener(window,"mousewheel",wheel_cb);
	};
};
RenderSupportHx.addFinegrainMouseWheelEventListener = function(clip,f) {
	return RenderSupportHx.addMouseWheelEventListener(clip,function(delta) {
		f(delta,0);
	});
};
RenderSupportHx.hasChild = function(clip,child) {
	var childs = clip.children;
	if(childs != null) {
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			if(c == child) return true;
			if(RenderSupportHx.hasChild(c,child)) return true;
		}
	}
	return false;
};
RenderSupportHx.isIOS = function() {
	return window.navigator.userAgent.indexOf("iPhone") != -1 || window.navigator.userAgent.indexOf("iPad") != -1 || window.navigator.userAgent.indexOf("iPod") != -1;
};
RenderSupportHx.getMouseX = function(clip) {
	var gs = RenderSupportHx.getGlobalScale(clip);
	return (RenderSupportHx.MouseX - RenderSupportHx.getElementX(clip)) / gs.scale_x;
};
RenderSupportHx.getMouseY = function(clip) {
	var gs = RenderSupportHx.getGlobalScale(clip);
	return (RenderSupportHx.MouseY - RenderSupportHx.getElementY(clip)) / gs.scale_y;
};
RenderSupportHx.hittest = function(clip,x,y) {
	var hitted = window.document.elementFromPoint(Math.round(x),Math.round(y));
	return hitted == clip || RenderSupportHx.hasChild(clip,hitted);
};
RenderSupportHx.getGraphics = function(clip) {
	return new _$RenderSupportHx_Graphics(clip);
};
RenderSupportHx.setLineStyle = function(graphics,width,color,opacity) {
	graphics.setLineStyle(width,color,opacity);
};
RenderSupportHx.setLineStyle2 = function(graphics,width,color,opacity,pixelHinting) {
	graphics.setLineStyle(width,color,opacity);
};
RenderSupportHx.beginFill = function(graphics,color,opacity) {
	graphics.setSolidFill(color,opacity);
};
RenderSupportHx.beginGradientFill = function(graphics,colors,alphas,offsets,matrix,type) {
	graphics.setGradientFill(colors,alphas,offsets,matrix);
};
RenderSupportHx.setLineGradientStroke = function(graphics,colours,alphas,offsets,matrix) {
};
RenderSupportHx.makeMatrix = function(width,height,rotation,xOffset,yOffset) {
	return [width,height,rotation,xOffset,yOffset];
};
RenderSupportHx.moveTo = function(graphics,x,y) {
	graphics.addGraphOp(GraphOp.MoveTo(x,y));
};
RenderSupportHx.lineTo = function(graphics,x,y) {
	graphics.addGraphOp(GraphOp.LineTo(x,y));
};
RenderSupportHx.curveTo = function(graphics,cx,cy,x,y) {
	graphics.addGraphOp(GraphOp.CurveTo(x,y,cx,cy));
};
RenderSupportHx.endFill = function(graphics) {
	graphics.render();
};
RenderSupportHx.makePicture = function(url,cache,metricsFn,errorFn,onlyDownload) {
	var error_cb = function() {
		errorFn("Error while loading image " + url);
	};
	var clip = RenderSupportHx.makeClip();
	clip.setAttribute("role","img");
	if(HxOverrides.substr(url,url.length - 3,3).toLowerCase() == "swf") {
		var loaad_swf_if_no_png = function() {
			RenderSupportHx.loadSWF(clip,url,error_cb,metricsFn);
		};
		RenderSupportHx.loadImage(clip,StringTools.replace(url,".swf",".png"),loaad_swf_if_no_png,metricsFn);
	} else RenderSupportHx.loadImage(clip,url,error_cb,metricsFn);
	return clip;
};
RenderSupportHx.setCursor = function(cursor) {
	var css_cursor;
	switch(cursor) {
	case "arrow":
		css_cursor = "default";
		break;
	case "auto":
		css_cursor = "auto";
		break;
	case "finger":
		css_cursor = "pointer";
		break;
	case "move":
		css_cursor = "move";
		break;
	case "text":
		css_cursor = "text";
		break;
	default:
		css_cursor = "default";
	}
	window.document.body.style.cursor = css_cursor;
};
RenderSupportHx.getCursor = function() {
	var _g = window.document.body.style.cursor;
	switch(_g) {
	case "default":
		return "arrow";
	case "auto":
		return "auto";
	case "pointer":
		return "finger";
	case "move":
		return "move";
	case "text":
		return "text";
	default:
		return "default";
	}
};
RenderSupportHx.addFilters = function(clip,filters) {
	var filters_value = filters.join(" ");
	clip.style.WebkitFilter = filters_value;
};
RenderSupportHx.makeBevel = function(angle,distance,radius,spread,color1,alpha1,color2,alpha2,inside) {
	return "drop-shadow(-1px -1px #888888)";
};
RenderSupportHx.makeBlur = function(radius,spread) {
	return "blur(" + radius + "px)";
};
RenderSupportHx.makeDropShadow = function(angle,distance,radius,spread,color,alpha,inside) {
	return "drop-shadow(" + Math.cos(angle) * distance + "px " + Math.sin(angle) * distance + "px " + radius + "px " + spread + "px " + Std.string(RenderSupportHx.makeCSSColor(color,alpha)) + ")";
};
RenderSupportHx.makeGlow = function(radius,spread,color,alpha,inside) {
	return "";
};
RenderSupportHx.setScrollRect = function(clip,left,top,width,height) {
	clip.style.top = "" + -top + "px";
	clip.style.left = "" + -left + "px";
	clip.rect_top = top;
	clip.rect_left = left;
	clip.rect_right = left + width;
	clip.rect_bottom = top + height;
	clip.style.clip = "rect(" + Std.string(clip.rect_top) + "px," + Std.string(clip.rect_right) + "px," + Std.string(clip.rect_bottom) + "px," + Std.string(clip.rect_left) + "px)";
	return null;
};
RenderSupportHx.getTextMetrics = function(textfield) {
	var font_size = 16.0;
	if(textfield.font_size != null) font_size = textfield.font_size;
	var ascent = 0.9 * font_size;
	var descent = 0.1 * font_size;
	var leading = 0.15 * font_size;
	return [ascent,descent,leading];
};
RenderSupportHx.makeBitmap = function() {
	return null;
};
RenderSupportHx.bitmapDraw = function(bitmap,clip,width,height) {
};
RenderSupportHx.addPasteEventListener = function(callback) {
	return function() {
	};
};
RenderSupportHx.getClipVisible = function(clip) {
	if(clip == null) return false;
	var p = clip;
	var stage = RenderSupportHx.getStage();
	while(p != null && p != stage) {
		if(p.style != null && p.style.display == "none") return false;
		p = p.parentNode;
	}
	return true;
};
RenderSupportHx.setClipVisible = function(clip,vis) {
	if(vis) clip.style.display = ""; else clip.style.display = "none";
};
RenderSupportHx.setFullScreenTarget = function(clip) {
};
RenderSupportHx.setFullScreenRectangle = function(x,y,w,h) {
};
RenderSupportHx.resetFullScreenTarget = function() {
};
RenderSupportHx.toggleFullScreen = function(fs) {
};
RenderSupportHx.setFullScreen = function(fs) {
};
RenderSupportHx.onFullScreen = function(fn) {
	return function() {
	};
};
RenderSupportHx.isFullScreen = function() {
	return false;
};
RenderSupportHx.setWindowTitle = function(title) {
	window.document.title = title;
};
RenderSupportHx.setFavIcon = function(url) {
	var head = window.document.getElementsByTagName("head")[0];
	var oldNode = window.document.getElementById("dynamic-favicon");
	var node = window.document.createElement("link");
	node.setAttribute("id","dynamic-favicon");
	node.setAttribute("rel","shortcut icon");
	node.setAttribute("href",url);
	node.setAttribute("type","image/ico");
	if(oldNode != null) head.removeChild(oldNode);
	head.appendChild(node);
};
RenderSupportHx.takeSnapshot = function(path) {
};
RenderSupportHx.getScreenPixelColor = function(x,y) {
	return 0;
};
RenderSupportHx.makeWebClip = function(url,domain,useCache,reloadBlock,cb,ondone,shrinkToFit) {
	var clip = RenderSupportHx.makeClip();
	if(RenderSupportHx.isIOS()) {
		clip.style.webkitOverflowScrolling = "touch";
		clip.style.overflowY = "scroll";
	}
	try {
		window.document.domain = domain;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report(e);
	}
	var iframe = window.document.createElement("iframe");
	iframe.width = iframe.height = 100.0;
	iframe.src = url;
	iframe.allowFullscreen = true;
	iframe.frameBorder = "no";
	clip.appendChild(iframe);
	clip.iframe = iframe;
	iframe.callflow = cb;
	iframe.onload = function() {
		try {
			ondone("OK");
			iframe.contentWindow.callflow = cb;
			if(iframe.contentWindow.pushCallflowBuffer) iframe.contentWindow.pushCallflowBuffer();
		} catch( e1 ) {
			haxe_CallStack.lastException = e1;
			if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
			Errors.report(e1);
		}
	};
	return clip;
};
RenderSupportHx.webClipHostCall = function(clip,name,args) {
	return clip.iframe.contentWindow[name].apply(clip.iframe.contentWindow,args);
};
RenderSupportHx.setWebClipSandBox = function(clip,value) {
	clip.iframe.sandbox = value;
};
RenderSupportHx.setWebClipDisabled = function(clip,value) {
};
RenderSupportHx.webClipEvalJS = function(clip,code) {
	return null;
};
RenderSupportHx.setWebClipZoomable = function(clip,zoomable) {
};
RenderSupportHx.getNumberOfCameras = function() {
	return 0;
};
RenderSupportHx.getCameraInfo = function(id) {
	return "";
};
RenderSupportHx.makeCamera = function(uri,camID,camWidth,camHeight,camFps,vidWidth,vidHeight,recordMode,cbOnReadyForRecording,cbOnFailed) {
	return [null,null];
};
RenderSupportHx.startRecord = function(str,filename,mode) {
};
RenderSupportHx.stopRecord = function(str) {
};
RenderSupportHx.cameraTakePhoto = function(cameraId,additionalInfo,desiredWidth,desiredHeight,compressQuality,fileName,fitMode) {
};
RenderSupportHx.cameraTakeVideo = function(cameraId,additionalInfo,duration,size,quality,fileName) {
};
RenderSupportHx.addGestureListener = function(event,cb) {
	return function() {
	};
};
RenderSupportHx.setInterfaceOrientation = function(orientation) {
};
RenderSupportHx.setUrlHash = function(hash) {
	window.location.hash = hash;
};
RenderSupportHx.getUrlHash = function() {
	return window.location.hash;
	return "";
};
RenderSupportHx.addUrlHashListener = function(cb) {
	var wrapper = function(e) {
		cb(window.location.hash);
	};
	window.addEventListener("hashchange",wrapper);
	return function() {
		window.removeEventListener("hashchange",wrapper);
	};
};
RenderSupportHx.setGlobalZoomEnabled = function(enabled) {
};
RenderSupportHx.prototype = {
	__class__: RenderSupportHx
};
var DFontTexturePage = function(fontname,page) {
	this.fontname = fontname;
	this.page = page;
};
DFontTexturePage.__name__ = true;
DFontTexturePage.prototype = {
	__class__: DFontTexturePage
};
var GesturesDetector = function() { };
GesturesDetector.__name__ = true;
GesturesDetector.processPinch = function(p1,p2) {
	var distance = Math.sqrt((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y));
	var state = 1;
	if(!GesturesDetector.IsPinchInProgress) {
		GesturesDetector.IsPinchInProgress = true;
		GesturesDetector.PinchInitialDistance = distance;
		state = 0;
	}
	GesturesDetector.CurrentPinchFocus.x = (p1.x + p2.x) / 2.0;
	GesturesDetector.CurrentPinchFocus.y = (p1.y + p2.y) / 2.0;
	GesturesDetector.CurrentPinchScaleFactor = distance / GesturesDetector.PinchInitialDistance;
	var _g = 0;
	var _g1 = GesturesDetector.PinchListeners;
	while(_g < _g1.length) {
		var l = _g1[_g];
		++_g;
		l(state,GesturesDetector.CurrentPinchFocus.x,GesturesDetector.CurrentPinchFocus.y,GesturesDetector.CurrentPinchScaleFactor,0.0);
	}
};
GesturesDetector.endPinch = function() {
	GesturesDetector.IsPinchInProgress = false;
	var _g = 0;
	var _g1 = GesturesDetector.PinchListeners;
	while(_g < _g1.length) {
		var l = _g1[_g];
		++_g;
		l(2,GesturesDetector.CurrentPinchFocus.x,GesturesDetector.CurrentPinchFocus.y,GesturesDetector.CurrentPinchScaleFactor,0.0);
	}
};
GesturesDetector.addPinchListener = function(cb) {
	GesturesDetector.PinchListeners.push(cb);
	return function() {
		HxOverrides.remove(GesturesDetector.PinchListeners,cb);
	};
};
var _$RenderSupportJSPixi_FlowContainer = function() {
	this.boundsHeight = 0.0;
	this.boundsWidth = 0.0;
	var _g = this;
	PIXI.Container.call(this);
	this.on("childrenchanged",function() {
		if(_g.parent != null) _g.parent.emit("childrenchanged"); else if(_g == RenderSupportJSPixi.PixiStage) RenderSupportJSPixi.PixiStageChanged = true;
	});
	this.on("transformchanged",RenderSupportJSPixi.InvalidateStage);
	this.on("graphicschanged",RenderSupportJSPixi.InvalidateStage);
};
_$RenderSupportJSPixi_FlowContainer.__name__ = true;
_$RenderSupportJSPixi_FlowContainer.getFirstGraphicsOrSprite = function(clip) {
	if((clip instanceof _$RenderSupportJSPixi_FlowGraphics) || (clip instanceof _$RenderSupportJSPixi_FlowSprite)) return clip;
	if(clip.children != null) {
		var _g = 0;
		var _g1 = clip.children;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var g = _$RenderSupportJSPixi_FlowContainer.getFirstGraphicsOrSprite(c);
			if(g != null) return g;
		}
	}
	return null;
};
_$RenderSupportJSPixi_FlowContainer.__super__ = PIXI.Container;
_$RenderSupportJSPixi_FlowContainer.prototype = $extend(PIXI.Container.prototype,{
	addChild: function(child) {
		var addedChild = PIXI.Container.prototype.addChild.call(this,child);
		if(addedChild != null) {
			this.removeChildWidthHeight(addedChild);
			this.emit("childrenchanged");
		}
		return addedChild;
	}
	,addChildAt: function(child,index) {
		var addedChild = PIXI.Container.prototype.addChildAt.call(this,child,index);
		if(addedChild != null) {
			this.removeChildWidthHeight(addedChild);
			this.emit("childrenchanged");
		}
		return addedChild;
	}
	,removeChild: function(child) {
		var removedChild = PIXI.Container.prototype.removeChild.call(this,child);
		if(removedChild != null) {
			this.removeChildWidthHeight(removedChild);
			this.emit("childrenchanged");
		}
		return removedChild;
	}
	,removeChildWidthHeight: function(child) {
		this.removeWidthHeight(child.transform != null?child.x + child.boundsWidth * child.scale.x:child.boundsWidth,child.transform != null?child.y + child.boundsHeight * child.scale.y:child.boundsHeight);
	}
	,getWidthHeight: function() {
		return { width : this.boundsWidth, heigt : this.boundsHeight};
	}
	,getTransform: function() {
		return { x : this.x, y : this.y, scaleX : this.scale.x, scaleY : this.scale.y};
	}
	,removeWidthHeight: function(x,y,updateParent) {
		if(updateParent == null) updateParent = true;
		if(x == this.boundsWidth || y == this.boundsHeight) {
			var oldBoundsWidth = this.boundsWidth;
			var oldBoundsHeight = this.boundsHeight;
			this.recalculateWidthHeight(false);
			if(oldBoundsWidth != this.boundsWidth || oldBoundsHeight != this.boundsHeight) {
				if(updateParent) {
					this.emit("metricschanged");
					if(this.parent != null) this.parent.removeWidthHeight(this.x + oldBoundsWidth * this.scale.x,this.y + oldBoundsHeight * this.scale.y);
				}
			}
		}
	}
	,recalculateWidthHeight: function(updateParent) {
		if(updateParent == null) updateParent = true;
		this.boundsWidth = 0.0;
		this.boundsHeight = 0.0;
		var _g = 0;
		var _g1 = this.children;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			this.addWidthHeight(c.x + c.boundsWidth * c.scale.x,c.y + c.boundsHeight * c.scale.y,updateParent);
		}
	}
	,addWidthHeight: function(x,y,updateParent) {
		if(updateParent == null) updateParent = true;
		if(x > this.boundsWidth || y > this.boundsHeight) {
			this.boundsWidth = Math.max(this.boundsWidth,x);
			this.boundsHeight = Math.max(this.boundsHeight,y);
			if(updateParent) {
				this.emit("metricschanged");
				if(this.parent != null) this.parent.addWidthHeight(this.x + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * this.scale.y);
			}
		}
	}
	,setClipX: function(x) {
		if(this.scrollRect != null) x = x - this.scrollRect.x;
		if(this.x != x) {
			var previousX = this.x;
			this.x = x;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(previousX + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * this.scale.y);
		}
	}
	,setClipY: function(y) {
		if(this.scrollRect != null) y = y - this.scrollRect.y;
		if(this.y != y) {
			var previousY = this.y;
			this.y = y;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * this.scale.x,previousY + this.boundsHeight * this.scale.y);
		}
	}
	,setClipScaleX: function(scale) {
		if(this.scale.x != scale) {
			var previousScaleX = this.scale.x;
			this.scale.x = scale;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * previousScaleX,this.y + this.boundsHeight * this.scale.y);
		}
	}
	,setClipScaleY: function(scale) {
		if(this.scale.y != scale) {
			var previousScaleY = this.scale.y;
			this.scale.y = scale;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * previousScaleY);
		}
	}
	,setClipRotation: function(rotation) {
		if(this.rotation != rotation) {
			this.rotation = rotation;
			this.emit("transformchanged");
		}
	}
	,setScrollRect: function(left,top,width,height) {
		if(this.scrollRect != null) {
			this.setClipX(this.x + this.scrollRect.x * 2 - left);
			this.setClipY(this.y + this.scrollRect.y * 2 - top);
			this.scrollRect.clear();
		} else {
			this.setClipX(this.x - left);
			this.setClipY(this.y - top);
			this.scrollRect = new _$RenderSupportJSPixi_FlowGraphics();
			this.addChild(this.scrollRect);
			this.setClipMask(this.scrollRect);
		}
		this.scrollRect.beginFill(16777215);
		this.scrollRect.drawRect(0.0,0.0,width,height);
		this.scrollRect.endFill();
		this.scrollRect.setClipX(left);
		this.scrollRect.setClipY(top);
	}
	,removeScrollRect: function() {
		if(this.scrollRect != null) {
			this.setClipX(this.x + this.scrollRect.x);
			this.setClipY(this.y + this.scrollRect.y);
			this.removeChild(this.scrollRect);
			this.scrollRect = null;
		}
	}
	,setClipMask: function(maskContainer) {
		var _g = this;
		if(maskContainer != this.scrollRect) this.removeScrollRect();
		this.mask = null;
		if(RenderSupportJSPixi.RendererType == "webgl") {
			this.mask = _$RenderSupportJSPixi_FlowContainer.getFirstGraphicsOrSprite(maskContainer);
			if(this.mask == null) maskContainer.visible = false;
		} else {
			this.alphaMask = null;
			var obj = maskContainer;
			while(obj.children != null && obj.children.length == 1) obj = obj.children[0];
			if((obj instanceof _$RenderSupportJSPixi_FlowGraphics)) this.mask = obj; else this.alphaMask = maskContainer;
		}
		if(this.mask != null) this.mask.once("removed",function() {
			_g.mask = null;
		});
		maskContainer.once("childrenchanged",function() {
			_g.setClipMask(maskContainer);
		});
		this.emit("graphicschanged");
	}
	,__class__: _$RenderSupportJSPixi_FlowContainer
});
var _$RenderSupportJSPixi_NativeWidgetClip = function() {
	_$RenderSupportJSPixi_FlowContainer.call(this);
};
_$RenderSupportJSPixi_NativeWidgetClip.__name__ = true;
_$RenderSupportJSPixi_NativeWidgetClip.__super__ = _$RenderSupportJSPixi_FlowContainer;
_$RenderSupportJSPixi_NativeWidgetClip.prototype = $extend(_$RenderSupportJSPixi_FlowContainer.prototype,{
	getWidth: function() {
		return 0.0;
	}
	,getHeight: function() {
		return 0.0;
	}
	,updateNativeWidget: function() {
		if(this.worldVisible) {
			var lt = this.toGlobal(new PIXI.Point(0.0,0.0));
			this.nativeWidget.style.left = "" + lt.x + "px";
			this.nativeWidget.style.top = "" + lt.y + "px";
			var rb = this.toGlobal(new PIXI.Point(this.getWidth(),this.getHeight()));
			this.nativeWidget.style.width = "" + (rb.x - lt.x) + "px";
			this.nativeWidget.style.height = "" + (rb.y - lt.y) + "px";
			this.nativeWidget.style.opacity = this.worldAlpha;
			this.nativeWidget.style.display = "block";
		} else this.nativeWidget.style.display = "none";
	}
	,createNativeWidget: function(node_name) {
		var parentNode = null;
		if(this.nativeWidget != null) {
			parentNode = this.nativeWidget.parentNode;
			this.deleteNativeWidget();
		}
		this.nativeWidget = window.document.createElement(node_name);
		if(parentNode != null) parentNode.appendChild(this.nativeWidget); else window.document.body.appendChild(this.nativeWidget);
		this.nativeWidget.style.position = "fixed";
		RenderSupportJSPixi.PixiStage.on("drawframe",$bind(this,this.updateNativeWidget));
		this.on("removed",$bind(this,this.deleteNativeWidget));
	}
	,deleteNativeWidget: function() {
		RenderSupportJSPixi.PixiStage.off("drawframe",$bind(this,this.updateNativeWidget));
		if(this.nativeWidget != null) {
			if(this.nativeWidget.parentNode != null) this.nativeWidget.parentNode.removeChild(this.nativeWidget);
			delete nativeWidget;
			this.nativeWidget = null;
		}
	}
	,setFocus: function(focus) {
		if(this.nativeWidget != null) {
			if(focus) this.nativeWidget.focus(); else this.nativeWidget.blur();
		}
	}
	,getFocus: function() {
		return this.nativeWidget != null && window.document.activeElement == this.nativeWidget;
	}
	,requestFullScreen: function() {
		if(this.nativeWidget != null) RenderSupportJSPixi.requestFullScreen(this.nativeWidget);
	}
	,exitFullScreen: function() {
		if(this.nativeWidget != null) RenderSupportJSPixi.exitFullScreen(this.nativeWidget);
	}
	,__class__: _$RenderSupportJSPixi_NativeWidgetClip
});
var _$RenderSupportJSPixi_VideoClip = function(metricsFn,playFn,durationFn,positionFn) {
	this.fontFamily = "";
	this.endTime = 0;
	this.startTime = 0;
	this.StartPaused = false;
	this.VideoSprite = null;
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
	this.createNativeWidget("video");
	_$RenderSupportJSPixi_VideoClip.VideosOnStage.push(this);
	this.metricsFn = metricsFn;
	this.playFn = playFn;
	this.durationFn = durationFn;
	this.positionFn = positionFn;
	this.nativeWidget.addEventListener("loadedmetadata",$bind(this,this.metadataLoadedHandler),false);
	if(Platform.isIOS) {
		this.nativeWidget.addEventListener("webkitbeginfullscreen",RenderSupportJSPixi.fullScreenTrigger,false);
		this.nativeWidget.addEventListener("webkitendfullscreen",RenderSupportJSPixi.fullScreenTrigger,false);
	}
	this.nativeWidget.addEventListener("fullscreenchange",RenderSupportJSPixi.fullScreenTrigger,false);
	this.nativeWidget.addEventListener("webkitfullscreenchange",RenderSupportJSPixi.fullScreenTrigger,false);
	this.nativeWidget.addEventListener("mozfullscreenchange",RenderSupportJSPixi.fullScreenTrigger,false);
	if(!_$RenderSupportJSPixi_VideoClip.UsePixiTextures) this.nativeWidget.addTextTrack("subtitles","","en");
};
_$RenderSupportJSPixi_VideoClip.__name__ = true;
_$RenderSupportJSPixi_VideoClip.NeedsDrawing = function() {
	return _$RenderSupportJSPixi_VideoClip.UsePixiTextures && Lambda.exists(_$RenderSupportJSPixi_VideoClip.VideosOnStage,function(v) {
		return !v.nativeWidget.paused;
	});
};
_$RenderSupportJSPixi_VideoClip.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_VideoClip.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	metadataLoadedHandler: function() {
		this.durationFn(this.nativeWidget.duration);
		this.metricsFn(this.nativeWidget.videoWidth,this.nativeWidget.videoHeight);
		this.nativeWidget.width = this.nativeWidget.videoWidth;
		this.nativeWidget.height = this.nativeWidget.videoHeight;
		this.checkTimeRange(this.nativeWidget.currentTime,true);
		RenderSupportJSPixi.PixiStageChanged = true;
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures) this.createVideoSprite();
	}
	,updateNativeWidget: function() {
		if(!_$RenderSupportJSPixi_VideoClip.UsePixiTextures) _$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this);
		if(!this.nativeWidget.paused) this.checkTimeRange(this.nativeWidget.currentTime,true);
	}
	,checkTimeRange: function(currentTime,videoResponse) {
		try {
			if(currentTime < this.startTime && this.startTime < this.nativeWidget.duration) {
				this.nativeWidget.currentTime = this.startTime;
				this.positionFn(this.nativeWidget.currentTime);
			} else if(this.endTime > 0 && this.endTime > this.startTime && currentTime >= this.endTime) {
				if(this.nativeWidget.paused) this.nativeWidget.currentTime = this.endTime; else {
					this.nativeWidget.currentTime = this.startTime;
					if(!this.nativeWidget.loop) this.nativeWidget.pause();
				}
				this.positionFn(this.nativeWidget.currentTime);
			} else if(videoResponse) this.positionFn(this.nativeWidget.currentTime); else this.nativeWidget.currentTime = currentTime;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
		}
	}
	,createNativeWidget: function(node) {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.createNativeWidget.call(this,node);
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures) this.nativeWidget.style.display = "none";
	}
	,deleteNativeWidget: function() {
		HxOverrides.remove(_$RenderSupportJSPixi_VideoClip.VideosOnStage,this);
		this.deleteVideoSprite();
		this.deleteSubtitlesClip();
		this.nativeWidget.removeEventListener("loadedmetadata",$bind(this,this.metadataLoadedHandler));
		if(Platform.isIOS) {
			this.nativeWidget.removeEventListener("webkitbeginfullscreen",RenderSupportJSPixi.fullScreenTrigger);
			this.nativeWidget.removeEventListener("webkitendfullscreen",RenderSupportJSPixi.fullScreenTrigger);
		}
		this.nativeWidget.removeEventListener("fullscreenchange",RenderSupportJSPixi.fullScreenTrigger);
		this.nativeWidget.removeEventListener("webkitfullscreenchange",RenderSupportJSPixi.fullScreenTrigger);
		this.nativeWidget.removeEventListener("mozfullscreenchange",RenderSupportJSPixi.fullScreenTrigger);
		this.nativeWidget.autoplay = false;
		this.nativeWidget.pause();
		this.nativeWidget.src = "";
		this.nativeWidget.load();
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.deleteNativeWidget.call(this);
	}
	,getDescription: function() {
		if(this.nativeWidget != null) return "VideoClip (url = " + Std.string(this.nativeWidget.url) + ")"; else return "";
	}
	,setVolume: function(volume) {
		if(this.nativeWidget != null) this.nativeWidget.volume = volume;
	}
	,setLooping: function(loop) {
		if(this.nativeWidget != null) this.nativeWidget.loop = loop;
	}
	,playVideo: function(filename,startPaused) {
		if(this.nativeWidget != null) {
			this.nativeWidget.autoplay = !startPaused;
			this.nativeWidget.src = filename;
		}
	}
	,setTimeRange: function(start,end) {
		if(start >= 0) this.startTime = start; else this.startTime = 0;
		if(end > this.startTime) this.endTime = end; else this.endTime = this.nativeWidget.duration;
		this.checkTimeRange(this.nativeWidget.currentTime,true);
	}
	,setCurrentTime: function(time) {
		this.checkTimeRange(time,false);
	}
	,setVideoSubtitle: function(text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity) {
		if(text == "") this.deleteSubtitlesClip(); else this.setVideoSubtitleClip(text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity);
	}
	,setPlaybackRate: function(rate) {
		this.nativeWidget.playbackRate = rate;
	}
	,setVideoSubtitleClip: function(text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity) {
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures) {
			if(this.fontFamily != fontfamily && fontfamily != "") {
				this.fontFamily = fontfamily;
				this.deleteSubtitlesClip();
			}
			this.createSubtitlesClip();
			this.textField.setTextAndStyle(" " + text + " ",this.fontFamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity);
			this.updateSubtitlesClip();
		} else if(this.nativeWidget != null) {
			this.nativeWidget.textTracks[0].mode = "showing";
			if(this.lastCue != null) this.nativeWidget.textTracks[0].removeCue(this.lastCue);
			this.lastCue = new VTTCue(0,this.nativeWidget.duration,text);
			this.nativeWidget.textTracks[0].addCue(this.lastCue);
		}
	}
	,createSubtitlesClip: function() {
		if(this.textField == null) {
			this.textField = RenderSupportJSPixi.makeTextField(this.fontFamily);
			this.addChild(this.textField);
		}
	}
	,updateSubtitlesClip: function() {
		if(this.nativeWidget != null) {
			this.textField.x = (this.nativeWidget.width - this.textField.getWidth()) / 2;
			this.textField.y = this.nativeWidget.height - this.textField.getHeight() - 2;
		}
	}
	,deleteSubtitlesClip: function() {
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures) {
			this.removeChild(this.textField);
			this.textField = null;
		} else if(this.nativeWidget != null) this.nativeWidget.textTracks[0].mode = "disabled";
	}
	,createVideoSprite: function() {
		if(this.videoSprite == null && RenderSupportJSPixi.RendererType != "webgl") {
			var video_texture = PIXI.Texture.fromVideo(this.nativeWidget);
			video_texture.baseTexture.autoPlay = this.nativeWidget.autoplay;
			if(!this.nativeWidget.autoplay) video_texture.baseTexture.source.pause();
			this.videoSprite = new PIXI.Sprite(video_texture);
			this.videoSprite.width = this.nativeWidget.videoWidth;
			this.videoSprite.height = this.nativeWidget.videoHeight;
			this.addChild(this.videoSprite);
			if(this.textField != null) {
				this.swapChildren(this.videoSprite,this.textField);
				this.updateSubtitlesClip();
			}
		}
	}
	,deleteVideoSprite: function() {
		if(this.videoSprite != null) {
			this.videoSprite.destroy({ children : true, texture : true, baseTexture : true});
			this.removeChild(this.videoSprite);
			this.videoSprite = null;
		}
	}
	,getCurrentTime: function() {
		if(this.nativeWidget != null) return this.nativeWidget.currentTime; else return 0;
	}
	,pauseVideo: function() {
		if(this.nativeWidget != null && !this.nativeWidget.paused) this.nativeWidget.pause();
	}
	,resumeVideo: function() {
		if(this.nativeWidget != null && this.nativeWidget.paused) this.nativeWidget.play();
	}
	,addStreamStatusListener: function(fn) {
		var _g = this;
		var on_start = function() {
			fn("NetStream.Play.Start");
		};
		var on_stop = function() {
			fn("NetStream.Play.Stop");
		};
		var on_not_found = function() {
			fn("NetStream.Play.StreamNotFound");
		};
		var on_resume = function() {
			if(_g.nativeWidget != null && !_g.nativeWidget.paused) {
				fn("FlowGL.User.Resume");
				_g.playFn(true);
			}
		};
		var on_pause = function() {
			if(_g.nativeWidget != null && _g.nativeWidget.paused) {
				fn("FlowGL.User.Pause");
				_g.playFn(false);
			}
		};
		this.nativeWidget.addEventListener("loadeddata",on_start);
		this.nativeWidget.addEventListener("ended",on_stop);
		this.nativeWidget.addEventListener("error",on_not_found);
		this.nativeWidget.addEventListener("play",on_resume);
		this.nativeWidget.addEventListener("pause",on_pause);
		return function() {
			if(_g.nativeWidget != null) {
				_g.nativeWidget.removeEventListener("loadeddata",on_start);
				_g.nativeWidget.removeEventListener("ended",on_stop);
				_g.nativeWidget.removeEventListener("error",on_not_found);
				_g.nativeWidget.removeEventListener("play",on_resume);
				_g.nativeWidget.removeEventListener("pause",on_pause);
			}
		};
	}
	,getWidth: function() {
		return this.nativeWidget.width;
	}
	,getHeight: function() {
		return this.nativeWidget.height;
	}
	,__class__: _$RenderSupportJSPixi_VideoClip
});
var _$RenderSupportJSPixi_DebugClipsTree = function() {
	this.UpdateTimer = null;
	this.ClipBoundsRect = null;
	this.DebugWin = null;
	this.TreeDiv = null;
	var _g = this;
	this.DebugWin = window.open("","clipstree","width=800,height=500");
	var description = this.DebugWin.document.getElementById("DebugWinDescription");
	if(description == null) {
		description = this.DebugWin.document.createElement("p");
		description.id = "DebugWinDescription";
		description.innerHTML = "Clips tree for: " + window.document.location.href;
		this.DebugWin.document.body.insertBefore(description,this.DebugWin.document.body.firstChild);
	}
	var expandall_button = this.DebugWin.document.getElementById("expandall_button");
	if(expandall_button == null) {
		expandall_button = window.document.createElement("button");
		expandall_button.id = "expandall_button";
		expandall_button.innerHTML = "Expand All";
		expandall_button.onclick = function(e) {
			_g.expandAll(_g.TreeDiv.firstChild);
		};
		this.DebugWin.document.body.appendChild(expandall_button);
	}
	var collapseall_button = this.DebugWin.document.getElementById("collapseall_button");
	if(collapseall_button == null) {
		collapseall_button = window.document.createElement("button");
		collapseall_button.id = "collapseall_button";
		collapseall_button.innerHTML = "Collapse All";
		collapseall_button.onclick = function(e1) {
			_g.collapseAll(_g.TreeDiv.firstChild);
		};
		this.DebugWin.document.body.appendChild(collapseall_button);
	}
	this.TreeDiv = this.DebugWin.document.getElementById("TreeDiv");
	if(this.TreeDiv == null) {
		this.TreeDiv = window.document.createElement("div");
		this.TreeDiv.id = "TreeDiv";
		this.DebugWin.document.body.appendChild(this.TreeDiv);
	}
	this.ClipBoundsRect = this.DebugWin.document.getElementById("ClipBoundsRect");
	if(this.ClipBoundsRect == null) {
		this.ClipBoundsRect = window.document.createElement("div");
		this.ClipBoundsRect.id = "ClipBoundsRect";
		this.ClipBoundsRect.style.position = "fixed";
		this.ClipBoundsRect.style.backgroundColor = "rgba(255, 0, 0, 0.5)";
		window.document.body.appendChild(this.ClipBoundsRect);
	}
	while(this.TreeDiv.firstChild != null) this.TreeDiv.removeChild(this.TreeDiv.firstChild);
};
_$RenderSupportJSPixi_DebugClipsTree.__name__ = true;
_$RenderSupportJSPixi_DebugClipsTree.getInstance = function() {
	if(_$RenderSupportJSPixi_DebugClipsTree.instance == null) _$RenderSupportJSPixi_DebugClipsTree.instance = new _$RenderSupportJSPixi_DebugClipsTree();
	return _$RenderSupportJSPixi_DebugClipsTree.instance;
};
_$RenderSupportJSPixi_DebugClipsTree.prototype = {
	setClipBoundsRect: function(bounds) {
		this.ClipBoundsRect.style.left = bounds.x;
		this.ClipBoundsRect.style.top = bounds.y;
		this.ClipBoundsRect.style.width = bounds.width;
		this.ClipBoundsRect.style.height = bounds.height;
	}
	,clearTree: function() {
		this.TreeDiv.innerHTML = "";
	}
	,updateTree: function(stage) {
		var _g = this;
		if(this.UpdateTimer != null) this.UpdateTimer.stop();
		this.UpdateTimer = haxe_Timer.delay(function() {
			_g.doUpdateTree(stage);
		},1000);
	}
	,doUpdateTree: function(stage) {
		this.clearTree();
		this.addItem(this.TreeDiv,stage);
	}
	,expandNode: function(node) {
		if(node.list != null) node.list.style.display = "block";
		node.arrow.innerHTML = StringTools.replace(node.arrow.innerHTML,"▶","▼");
	}
	,collapseNode: function(node) {
		if(node.list != null) node.list.style.display = "none";
		node.arrow.innerHTML = StringTools.replace(node.arrow.innerHTML,"▼","▶");
	}
	,expandAll: function(node) {
		this.expandNode(node);
		if(node.list != null && node.list.children != null) {
			var childs = node.list.children;
			var _g = 0;
			while(_g < childs.length) {
				var c = childs[_g];
				++_g;
				this.expandAll(c);
			}
		}
	}
	,collapseAll: function(node) {
		this.collapseNode(node);
		if(node.list != null && node.list.children != null) {
			var childs = node.list.children;
			var _g = 0;
			while(_g < childs.length) {
				var c = childs[_g];
				++_g;
				this.collapseAll(c);
			}
		}
	}
	,getClipDescription: function(clip) {
		if(clip.getDescription) return clip.getDescription();
		if(clip.graphicsData) if(clip.graphicsData.length > 0) return "Graphics ( fill = " + clip.graphicsData[0].fill + " fillAlpha = " + clip.graphicsData[0].fillAlpha + ")"; else return "Graphics";
		if(clip.texture) {
			var baseTexture = clip.texture.baseTexture;
			if(baseTexture.imageUrl) return "Image (" + (baseTexture.imageUrl == null?"null":"" + baseTexture.imageUrl) + ")";
			return "Text Sprite";
		}
		return "Clip";
	}
	,addItem: function(root,item) {
		var _g = this;
		var li = window.document.createElement("li");
		li.style.color = "rgba(0,0,0,0)";
		root.appendChild(li);
		var arrow = window.document.createElement("div");
		li.appendChild(arrow);
		arrow.style.color = "black";
		arrow.style.fontSize = "10px";
		arrow.style.display = "inline";
		li.arrow = arrow;
		var description = window.document.createElement("div");
		description.style.display = "inline";
		description.innerHTML = this.getClipDescription(item);
		if(item.worldVisible) description.style.color = "#303030"; else {
			description.style.color = "#DDDDDD";
			description.innerHTML += " invisible";
		}
		description.style.fontSize = "10px";
		if(item.isMask) description.innerHTML += " mask";
		description.addEventListener("mouseover",function(e) {
			description.style.backgroundColor = "#DDDDDD";
		});
		description.addEventListener("mouseout",function(e1) {
			description.style.backgroundColor = "";
		});
		description.addEventListener("mousedown",function(e2) {
			_g.setClipBoundsRect(item.getBounds());
		});
		li.appendChild(description);
		li.description = description;
		if(item.children != null && item.children.length > 0) {
			arrow.innerHTML = "▶";
			var ul = window.document.createElement("ul");
			li.appendChild(ul);
			li.list = ul;
			var childs = item.children;
			var _g1 = 0;
			while(_g1 < childs.length) {
				var c = childs[_g1];
				++_g1;
				this.addItem(ul,c);
			}
			arrow.addEventListener("click",function(e3) {
				if(ul.style.display == "none") _g.expandNode(li); else _g.collapseNode(li);
			});
			ul.style.display = "none";
		}
	}
	,__class__: _$RenderSupportJSPixi_DebugClipsTree
};
var FontLoader = function() { };
FontLoader.__name__ = true;
FontLoader.hasDFont = function(fontfamily) {
	return FontLoader.DFonts.exists(fontfamily);
};
FontLoader.LoadFonts = function(use_dfont,on_done) {
	var done = 0;
	var onDone = function() {
		done++;
		if(done == 2) on_done();
	};
	if(PIXI.VERSION[0] > 3 && window.DFONT_VERSION != FontLoader.DFontVersionExpected) window.location.reload(true);
	FontLoader.loadDFonts(onDone,use_dfont);
	FontLoader.loadWebFonts(onDone);
};
FontLoader.loadWebFonts = function(onDone) {
	if(typeof(WebFont) != "undefined") {
		var webfontconfig = JSON.parse(haxe_Resource.getString("webfontconfig"));
		if(webfontconfig != null && Reflect.fields(webfontconfig).length > 0) {
			webfontconfig.active = onDone;
			webfontconfig.inactive = onDone;
			webfontconfig.loading = function() {
				Errors.print("Loading web fonts...");
			};
			WebFont.load(webfontconfig);
		} else onDone();
	} else {
		Errors.print("WebFont is not defined");
		onDone();
	}
};
FontLoader.loadDFonts = function(onDone,downloadTextures) {
	var dfonts = [];
	var uniqueDFonts = [];
	var dfontsResource = haxe_Resource.getString("dfonts");
	if(dfontsResource != null) {
		dfonts = JSON.parse(dfontsResource);
		if(dfonts.length == 0) {
			onDone();
			return;
		}
		var _g = 0;
		while(_g < dfonts.length) {
			var dfont = dfonts[_g];
			++_g;
			if(dfont.url == null) dfont.url = "dfontjs/" + Std.string(dfont.name) + "/index.json";
		}
	} else if(dfonts.length == 0) {
		Errors.print("Warning: No dfonts resource!");
		onDone();
		return;
	}
	var fontnamesStr = window.dfontnames;
	if(fontnamesStr != null) {
		var fontnames;
		var _g2 = [];
		var _g12 = 0;
		var _g21 = fontnamesStr.split("\n");
		while(_g12 < _g21.length) {
			var fn = _g21[_g12];
			++_g12;
			_g2.push(StringTools.trim(fn));
		}
		fontnames = _g2;
		fontnames = fontnames.filter(function(s) {
			return s != "";
		});
		var extraDFonts;
		var _g13 = [];
		var _g22 = 0;
		while(_g22 < fontnames.length) {
			var fn1 = fontnames[_g22];
			++_g22;
			_g13.push({ name : fn1, url : "dfontjs/" + fn1 + "/index.json"});
		}
		extraDFonts = _g13;
		if(window.dfonts_override != null) dfonts = extraDFonts; else dfonts = dfonts.concat(extraDFonts);
	}
	var fontURLs;
	var _g3 = new haxe_ds_StringMap();
	var _g14 = 0;
	while(_g14 < dfonts.length) {
		var f = dfonts[_g14];
		++_g14;
		var key = f.name;
		var value = f.url;
		if(__map_reserved[key] != null) _g3.setReserved(key,value); else _g3.h[key] = value;
	}
	fontURLs = _g3;
	Errors.print("Loading dfield fonts...");
	var loader = new PIXI.loaders.Loader();
	var pending = false;
	FontLoader.DFonts = new haxe_ds_StringMap();
	var $it0 = fontURLs.keys();
	while( $it0.hasNext() ) {
		var name1 = $it0.next();
		var embedded_dfont = haxe_Resource.getString(name1);
		if(embedded_dfont != null) {
			var dfont1 = JSON.parse(embedded_dfont);
			if(dfont1) DFontText.initDFontData(name1,dfont1); else Errors.print("Error parsing embedded dfont for " + name1);
		} else if(downloadTextures) {
			pending = true;
			loader.add(name1,__map_reserved[name1] != null?fontURLs.getReserved(name1):fontURLs.h[name1]);
		}
		{
			FontLoader.DFonts.set(name1,true);
			true;
		}
	}
	if(!downloadTextures) {
		onDone();
		return;
	}
	var onLoaded = function() {
		var texture_pages = [];
		var $it1 = fontURLs.keys();
		while( $it1.hasNext() ) {
			var name = $it1.next();
			var numPages = DFontText.getNumPages(name);
			var _g1 = 0;
			while(_g1 < numPages) {
				var page = _g1++;
				texture_pages.push(new DFontTexturePage(name,page));
			}
		}
		texture_pages.sort(function(p1,p2) {
			return p1.page - p2.page;
		});
		var _g11 = 0;
		while(_g11 < texture_pages.length) {
			var page1 = texture_pages[_g11];
			++_g11;
			DFontText.addTexture2Loader(page1.fontname,FontLoader.getDFontInfo(page1.fontname),page1.page,function() {
				RenderSupportJSPixi.PixiStageChanged = true;
			},loader);
		}
		loader.load();
		loader.once("complete",onDone);
	};
	if(pending) {
		loader.load();
		loader.once("complete",onLoaded);
	} else onLoaded();
};
FontLoader.getDFontInfo = function(fontfamily) {
	return DFontText.dfont_table[fontfamily];
};
var _$RenderSupportJSPixi_TextField = function() {
	this.preFocus = false;
	this.accessWidget = null;
	this.TextInputKeyUpFilters = [];
	this.TextInputKeyDownFilters = [];
	this.TextInputFilters = [];
	this.clipHeight = 0.0;
	this.clipWidth = 0.0;
	this.multiline = false;
	this.shouldPreventFromBlur = false;
	this.shouldPreventFromFocus = false;
	this.background = null;
	this.selectionEnd = -1;
	this.selectionStart = -1;
	this.cursorPosition = -1;
	this.maxChars = -1;
	this.readOnly = false;
	this.autoAlign = "AutoAlignLeft";
	this.interlineSpacing = 0.0;
	this.cropWords = false;
	this.fieldHeight = -1.0;
	this.fieldWidth = -1.0;
	this.wordWrap = false;
	this.type = "text";
	this.style = { };
	this.fontStyle = { weight : "", style : "", size : 0.0, family : ""};
	this.cursorWidth = 2;
	this.cursorOpacity = -1.0;
	this.cursorColor = -1;
	this.backgroundOpacity = 0.0;
	this.backgroundColor = 0;
	this.letterSpacing = 0.0;
	this.fillOpacity = 0.0;
	this.fillColor = 0;
	this.fontSlope = "";
	this.fontWeight = 0;
	this.fontSize = 0.0;
	this.fontFamily = "";
	this.text = "";
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
};
_$RenderSupportJSPixi_TextField.__name__ = true;
_$RenderSupportJSPixi_TextField.getBulletsString = function(l) {
	var bullet = String.fromCharCode(8226);
	var i = 0;
	var ret = "";
	var _g = 0;
	while(_g < l) {
		var i1 = _g++;
		ret += bullet;
	}
	return ret;
};
_$RenderSupportJSPixi_TextField.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_TextField.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	preOnFocus: function() {
		var _g = this;
		if(this.isInput()) {
			this.preFocus = true;
			this.updateNativeWidgetStyle();
			haxe_Timer.delay(function() {
				_g.preFocus = false;
				_g.updateNativeWidgetStyle();
			},10);
		}
	}
	,createNativeWidget: function(nodeName) {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.createNativeWidget.call(this,nodeName);
		if(Platform.isIE || Platform.isEdge) RenderSupportJSPixi.PixiStage.on("preonfocus",$bind(this,this.preOnFocus));
	}
	,deleteNativeWidget: function() {
		if(Platform.isIE || Platform.isEdge) RenderSupportJSPixi.PixiStage.off("preonfocus",$bind(this,this.preOnFocus));
		if(!this.shouldPreventFromBlur && window.document.activeElement == this.nativeWidget) this.nativeWidget.blur();
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.deleteNativeWidget.call(this);
	}
	,updateNativeWidget: function() {
		if(this.worldVisible) {
			var lt = this.toGlobal(new PIXI.Point(0.0,0.0));
			this.nativeWidget.style.left = "" + lt.x + "px";
			this.nativeWidget.style.top = "" + (lt.y + 1.0) + "px";
			var rb = this.toGlobal(new PIXI.Point(this.getWidth(),this.getHeight()));
			this.nativeWidget.style.width = "" + (rb.x - lt.x) + "px";
			this.nativeWidget.style.height = "" + (rb.y - lt.y) + "px";
			if(this.isInput()) {
				if(this.preFocus && this.multiline && Platform.isEdge) this.nativeWidget.style.opacity = 1; else if(this.isNativeWidgetShown()) this.nativeWidget.style.opacity = this.fillOpacity * this.worldAlpha; else this.nativeWidget.style.opacity = 0;
				this.nativeWidget.style.display = "block";
				if(this.isNativeWidgetShown()) {
					var scale_y = this.worldTransform.d;
					if(scale_y != 1.0) {
						this.nativeWidget.style.fontSize = this.fontSize * scale_y + "px";
						this.nativeWidget.style.lineHeight = (this.fontSize * 1.2 + this.interlineSpacing) * scale_y + "px";
					}
				}
			} else this.nativeWidget.style.display = "none";
		} else this.nativeWidget.style.display = "none";
	}
	,setTextAndStyle: function(text,fontFamily,fontSize,fontWeight,fontSlope,fillColor,fillOpacity,letterSpacing,backgroundColor,backgroundOpacity) {
		if(StringTools.endsWith(text,"\n")) this.text = text.substring(0,text.length - 1); else this.text = text;
		this.fontFamily = fontFamily;
		this.fontSize = fontSize;
		this.fontWeight = fontWeight;
		this.fontSlope = fontSlope;
		this.fillColor = fillColor;
		this.fillOpacity = fillOpacity;
		this.letterSpacing = letterSpacing;
		this.backgroundColor = backgroundColor;
		this.backgroundOpacity = backgroundOpacity;
		this.fontStyle = FlowFontStyle.fromFlowFont(fontFamily);
		this.updateNativeWidgetStyle();
	}
	,updateNativeWidgetStyle: function() {
		if(this.isNativeWidgetShown()) {
			this.setScrollRect(0,0,0,0);
			this.nativeWidget.type = this.type;
			if(this.accessWidget != null && this.accessWidget.autocomplete != null && this.accessWidget.autocomplete != "") this.nativeWidget.autocomplete = this.accessWidget.autocomplete; else if(this.type == "password" && this.nativeWidget.autocomplete == "") this.nativeWidget.autocomplete = "new-password";
			this.nativeWidget.value = this.text;
			this.nativeWidget.style.color = RenderSupportJSPixi.makeCSSColor(this.fillColor,this.fillOpacity);
			this.nativeWidget.style.letterSpacing = (RenderSupportJSPixi.UseDFont?this.letterSpacing + 0.022:this.letterSpacing) + "px";
			this.nativeWidget.style.fontFamily = this.fontStyle.family;
			if(this.fontWeight > 0) this.nativeWidget.style.fontWeight = this.fontWeight; else this.nativeWidget.style.fontWeight = this.fontStyle.weight;
			if(this.fontSlope != "") this.nativeWidget.style.fontStyle = this.fontSlope; else this.nativeWidget.style.fontStyle = this.fontStyle.style;
			this.nativeWidget.style.fontSize = this.fontSize * this.worldTransform.d + "px";
			this.nativeWidget.style.lineHeight = (this.fontSize * 1.2 + this.interlineSpacing) * this.worldTransform.d + "px";
			this.nativeWidget.style.backgroundColor = RenderSupportJSPixi.makeCSSColor(this.backgroundColor,this.backgroundOpacity);
			this.nativeWidget.style.cursor = "text";
			if(this.preFocus && this.multiline && Platform.isEdge) this.nativeWidget.style.opacity = 1; else this.nativeWidget.style.opacity = this.fillOpacity * this.worldAlpha;
			if(this.cursorColor >= 0) this.nativeWidget.style.caretColor = RenderSupportJSPixi.makeCSSColor(this.cursorColor,this.cursorOpacity);
			this.nativeWidget.readOnly = this.readOnly;
			if(this.maxChars >= 0) this.nativeWidget.maxLength = this.maxChars;
			if(this.tabIndex >= 0) this.nativeWidget.tabIndex = this.tabIndex;
			if(this.readOnly) this.nativeWidget.style.pointerEvents = "none"; else this.nativeWidget.style.pointerEvents = "auto";
			if(this.multiline) {
				this.nativeWidget.style.resize = "none";
				if(this.wordWrap) this.nativeWidget.wrap = "soft"; else this.nativeWidget.wrap = "off";
			}
			var _g = this.autoAlign;
			switch(_g) {
			case "AutoAlignLeft":
				this.nativeWidget.style.textAlign = "left";
				break;
			case "AutoAlignRight":
				this.nativeWidget.style.textAlign = "right";
				break;
			case "AutoAlignCenter":
				this.nativeWidget.style.textAlign = "center";
				break;
			case "AutoAlignNone":
				this.nativeWidget.style.textAlign = "none";
				break;
			default:
				this.nativeWidget.style.textAlign = "left";
			}
		} else {
			if(this.isInput()) {
				this.nativeWidget.style.cursor = "inherit";
				if(this.preFocus && this.multiline && Platform.isEdge) this.nativeWidget.style.opacity = 1; else this.nativeWidget.style.opacity = 0;
				this.nativeWidget.readOnly = this.readOnly || !this.preFocus;
			}
			this.layoutText();
		}
		this.emit("graphicschanged");
	}
	,layoutText: function() {
		this.removeScrollRect();
		var i = this.children.length;
		while(i >= 0) {
			this.removeChild(this.children[i]);
			i--;
		}
		var lines = (this.isInput() && this.type == "password"?_$RenderSupportJSPixi_TextField.getBulletsString(this.text.length):this.text).split("\n");
		this.clipWidth = 0.0;
		this.clipHeight = 0.0;
		var _g = 0;
		while(_g < lines.length) {
			var line = lines[_g];
			++_g;
			var line_width = 0.0;
			if(this.fieldWidth > 0.0 && this.wordWrap) {
				var words = line.split(" ");
				var x = 0.0;
				var _g2 = 0;
				var _g1 = words.length;
				while(_g2 < _g1) {
					var wordId = _g2++;
					var word;
					if(wordId == words.length - 1) word = words[wordId]; else word = words[wordId] + " ";
					var clip = this.makeTextClip(word,this.style);
					var textDimensions = this.getTextClipMetrics(clip);
					while(word.length > 0) {
						if(this.cropWords) {
							var currentLength = word.length;
							clip = this.makeTextClip(word,this.style);
							textDimensions = this.getTextClipMetrics(clip);
							while(textDimensions.width > this.fieldWidth) {
								--currentLength;
								clip = this.makeTextClip(HxOverrides.substr(word,0,currentLength),this.style);
								textDimensions = this.getTextClipMetrics(clip);
							}
							word = HxOverrides.substr(word,currentLength,word.length - currentLength);
							if(word == " ") word = "";
						} else word = "";
						if(x > 0.0 && x + textDimensions.width > this.fieldWidth) {
							x = 0.0;
							this.clipHeight += textDimensions.line_height * textDimensions.line_count + this.interlineSpacing;
						}
						clip.x += x;
						clip.y += this.clipHeight;
						this.addChild(clip);
						x += textDimensions.width;
						line_width = Math.max(line_width,x);
					}
					if(wordId == words.length - 1) this.clipHeight += textDimensions.line_height * textDimensions.line_count + this.interlineSpacing;
				}
				this.clipWidth = Math.max(this.clipWidth,line_width);
			} else {
				var clip1 = this.makeTextClip(line,this.style);
				var textDimensions1 = this.getTextClipMetrics(clip1);
				clip1.y += this.clipHeight;
				this.addChild(clip1);
				this.clipHeight += textDimensions1.line_height * textDimensions1.line_count + this.interlineSpacing;
				this.clipWidth = Math.max(this.clipWidth,textDimensions1.width);
			}
		}
		if((this.autoAlign == "AutoAlignRight" || this.autoAlign == "AutoAlignCenter") && this.fieldWidth > 0) {
			var textDimensions2 = 0;
			var newChildren = [];
			var _g3 = 0;
			var _g11 = this.children;
			while(_g3 < _g11.length) {
				var child = _g11[_g3];
				++_g3;
				if(child.x > 0) {
					textDimensions2 += this.getTextClipMetrics(child).width;
					newChildren.push(child);
				} else {
					if(newChildren.length > 0 && textDimensions2 < this.fieldWidth) {
						var widthDelta = this.fieldWidth - textDimensions2;
						if(this.autoAlign == "AutoAlignCenter") widthDelta = widthDelta / 2;
						var _g21 = 0;
						while(_g21 < newChildren.length) {
							var newChild = newChildren[_g21];
							++_g21;
							newChild.x = newChild.x + widthDelta;
						}
					}
					textDimensions2 = this.getTextClipMetrics(child).width;
					newChildren = [child];
				}
			}
			if(newChildren.length > 0 && textDimensions2 < this.fieldWidth) {
				var widthDelta1 = this.fieldWidth - textDimensions2;
				if(this.autoAlign == "AutoAlignCenter") widthDelta1 = widthDelta1 / 2;
				var _g4 = 0;
				while(_g4 < newChildren.length) {
					var newChild1 = newChildren[_g4];
					++_g4;
					newChild1.x = newChild1.x + widthDelta1;
				}
			}
			this.clipWidth = Math.max(this.clipWidth,this.fieldWidth);
		}
		this.setTextBackground();
		this.setScrollRect(0,0,this.getWidth(),this.getHeight());
	}
	,makeTextClip: function(text,style) {
		return { };
	}
	,getTextClipMetrics: function(clip) {
		return { };
	}
	,setTextBackground: function() {
		if(this.backgroundOpacity > 0.0) {
			if(this.background != null) this.removeChild(this.background);
			var text_bounds = this.getLocalBounds();
			this.background = new _$RenderSupportJSPixi_FlowGraphics();
			this.background.beginFill(this.backgroundColor,this.backgroundOpacity);
			this.background.drawRect(0.0,0.0,text_bounds.width,text_bounds.height);
			this.background.endFill();
			this.addChildAt(this.background,0);
		} else {
			if(this.background != null) this.removeChild(this.background);
			this.background = null;
		}
	}
	,setTextInputType: function(type) {
		this.type = type;
		this.updateNativeWidgetStyle();
	}
	,setWordWrap: function(wordWrap) {
		this.wordWrap = wordWrap;
		this.updateNativeWidgetStyle();
	}
	,setWidth: function(fieldWidth) {
		this.fieldWidth = fieldWidth;
		this.updateNativeWidgetStyle();
	}
	,setHeight: function(fieldHeight) {
		this.fieldHeight = fieldHeight;
		this.updateNativeWidgetStyle();
	}
	,setCropWords: function(cropWords) {
		this.cropWords = cropWords;
		this.updateNativeWidgetStyle();
	}
	,setCursorColor: function(color,opacity) {
		this.cursorColor = color;
		this.cursorOpacity = opacity;
		this.updateNativeWidgetStyle();
	}
	,setCursorWidth: function(width) {
		this.cursorWidth = width;
		this.updateNativeWidgetStyle();
	}
	,setInterlineSpacing: function(interlineSpacing) {
		this.interlineSpacing = interlineSpacing;
		this.updateNativeWidgetStyle();
	}
	,setAutoAlign: function(autoAlign) {
		this.autoAlign = autoAlign;
		this.updateNativeWidgetStyle();
	}
	,setTabIndex: function(tabIndex) {
		this.tabIndex = tabIndex;
		this.updateNativeWidgetStyle();
	}
	,setReadOnly: function(readOnly) {
		this.readOnly = readOnly;
		this.updateNativeWidgetStyle();
	}
	,setMaxChars: function(maxChars) {
		this.maxChars = maxChars;
		this.updateNativeWidgetStyle();
	}
	,setTextInput: function() {
		if(this.multiline) this.wordWrap = true;
		this.createNativeWidget(this.multiline?"textarea":"input");
		this.shouldPreventFromFocus = false;
		this.nativeWidget.onmousemove = $bind(this,this.onMouseMove);
		this.nativeWidget.onmousedown = $bind(this,this.onMouseDown);
		this.nativeWidget.onmouseup = $bind(this,this.onMouseUp);
		if(NativeHx.isTouchScreen()) {
			this.nativeWidget.ontouchstart = $bind(this,this.onMouseDown);
			this.nativeWidget.ontouchend = $bind(this,this.onMouseUp);
		}
		this.nativeWidget.onfocus = $bind(this,this.onFocus);
		this.nativeWidget.onblur = $bind(this,this.onBlur);
		if(this.accessWidget != null) this.accessWidget = this.nativeWidget;
		this.nativeWidget.addEventListener("input",$bind(this,this.onInput));
		this.nativeWidget.addEventListener("scroll",$bind(this,this.onScroll));
		this.nativeWidget.addEventListener("keydown",$bind(this,this.onKeyDown));
		this.nativeWidget.addEventListener("keyup",$bind(this,this.onKeyUp));
		this.updateNativeWidgetStyle();
	}
	,checkPositionSelection: function() {
		var hasChanges = false;
		var cursorPosition = this.getCursorPosition();
		var selectionStart = this.getSelectionStart();
		var selectionEnd = this.getSelectionEnd();
		if(this.cursorPosition != cursorPosition) {
			this.cursorPosition = cursorPosition;
			hasChanges = true;
		}
		if(this.selectionStart != selectionStart) {
			this.selectionStart = selectionStart;
			hasChanges = true;
		}
		if(this.selectionEnd != selectionEnd) {
			this.selectionEnd = selectionEnd;
			hasChanges = true;
		}
		if(hasChanges) this.emit("input");
	}
	,onMouseMove: function(e) {
		RenderSupportJSPixi.provideEvent(e);
	}
	,onMouseDown: function(e) {
		if(this.isNativeWidgetShown()) {
			this.checkPositionSelection();
			return;
		}
		this.nativeWidget.readOnly = this.shouldPreventFromFocus = RenderSupportJSPixi.getClipAt(new PIXI.Point(e.pageX,e.pageY)) != this;
		RenderSupportJSPixi.provideEvent(e);
		if((Platform.isIE || Platform.isEdge) && !this.shouldPreventFromFocus) {
			this.preOnFocus();
			this.nativeWidget.focus();
		}
	}
	,onMouseUp: function(e) {
		if(this.isNativeWidgetShown()) this.checkPositionSelection();
		RenderSupportJSPixi.provideEvent(e);
		this.shouldPreventFromFocus = false;
	}
	,onFocus: function(e) {
		if(this.isInput()) {
			if(this.shouldPreventFromFocus) {
				e.preventDefault();
				this.nativeWidget.blur();
				return;
			}
			this.emit("focus");
			if(this.parent != null) RenderSupportJSPixi.emitEvent(this.parent,"childfocused",this);
			this.updateNativeWidgetStyle();
		}
	}
	,onBlur: function(e) {
		if(this.isInput()) {
			if(this.shouldPreventFromBlur) {
				this.shouldPreventFromBlur = false;
				e.preventDefault();
				this.nativeWidget.focus();
				return;
			}
			if(window.document.activeElement == this.nativeWidget) this.nativeWidget.blur();
			this.emit("blur");
			this.updateNativeWidgetStyle();
		}
	}
	,onInput: function(e) {
		var newValue = this.nativeWidget.value;
		var selectionStart = this.getSelectionStart();
		var selectionEnd = this.getSelectionEnd();
		var _g = 0;
		var _g1 = this.TextInputFilters;
		while(_g < _g1.length) {
			var f = _g1[_g];
			++_g;
			newValue = f(newValue);
		}
		if(newValue != this.nativeWidget.value) this.nativeWidget.value = newValue;
		this.text = newValue;
		this.setSelection(selectionStart,selectionEnd);
		this.emit("input",newValue);
	}
	,onScroll: function(e) {
		this.emit("scroll",e);
	}
	,setMultiline: function(multiline) {
		if(this.multiline != multiline) {
			this.multiline = multiline;
			this.setTextInput();
		}
	}
	,onKeyDown: function(e) {
		if(this.TextInputKeyDownFilters.length > 0) {
			var ke = RenderSupportJSPixi.parseKeyEvent(e);
			var _g = 0;
			var _g1 = this.TextInputKeyDownFilters;
			while(_g < _g1.length) {
				var f = _g1[_g];
				++_g;
				if(!f(ke.key,ke.ctrl,ke.shift,ke.alt,ke.meta,ke.keyCode)) {
					ke.preventDefault();
					RenderSupportJSPixi.PixiStage.emit("keydown",ke);
					break;
				}
			}
		}
		if(this.isNativeWidgetShown()) this.checkPositionSelection();
	}
	,onKeyUp: function(e) {
		if(this.TextInputKeyUpFilters.length > 0) {
			var ke = RenderSupportJSPixi.parseKeyEvent(e);
			var _g = 0;
			var _g1 = this.TextInputKeyUpFilters;
			while(_g < _g1.length) {
				var f = _g1[_g];
				++_g;
				if(!f(ke.key,ke.ctrl,ke.shift,ke.alt,ke.meta,ke.keyCode)) {
					ke.preventDefault();
					RenderSupportJSPixi.PixiStage.emit("keyup",ke);
					break;
				}
			}
		}
		if(this.isNativeWidgetShown()) this.checkPositionSelection();
	}
	,getDescription: function() {
		if(this.isInput()) return "TextField (text = \"" + Std.string(this.nativeWidget.value) + "\")"; else return "TextField (text = \"" + this.text + "\")";
	}
	,isInput: function() {
		return this.nativeWidget != null;
	}
	,setFocus: function(focus) {
		this.shouldPreventFromFocus = false;
		if(focus) {
			if(Platform.isIE || Platform.isEdge) this.preOnFocus();
			this.nativeWidget.focus();
		} else this.nativeWidget.blur();
	}
	,isNativeWidgetShown: function() {
		return this.isInput() && window.document.activeElement == this.nativeWidget;
	}
	,getWidth: function() {
		return this.getBounds().width;
	}
	,getHeight: function() {
		return this.getBounds().height;
	}
	,getContent: function() {
		return this.text;
	}
	,getCursorPosition: function() {
		try {
			if(this.nativeWidget.selectionStart != null) return this.nativeWidget.selectionStart;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
		}
		if(window.document.selection != null) {
			this.nativeWidget.focus();
			var r = window.document.selection.createRange();
			if(r == null) return 0;
			var re = this.nativeWidget.createTextRange();
			var rc = re.duplicate();
			re.moveToBookmark(r.getBookmark());
			rc.setEndPoint("EndToStart",re);
			return rc.text.length;
		}
		return 0;
	}
	,getSelectionStart: function() {
		try {
			return this.nativeWidget.selectionStart;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			return 0;
		}
	}
	,getSelectionEnd: function() {
		try {
			return this.nativeWidget.selectionEnd;
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			return 0;
		}
	}
	,setSelection: function(start,end) {
		try {
			this.nativeWidget.setSelectionRange(start,end);
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
		}
	}
	,addTextInputFilter: function(filter) {
		var _g = this;
		this.TextInputFilters.push(filter);
		return function() {
			HxOverrides.remove(_g.TextInputFilters,filter);
		};
	}
	,addTextInputKeyDownEventFilter: function(filter) {
		var _g = this;
		this.TextInputKeyDownFilters.push(filter);
		return function() {
			HxOverrides.remove(_g.TextInputKeyDownFilters,filter);
		};
	}
	,addTextInputKeyUpEventFilter: function(filter) {
		var _g = this;
		this.TextInputKeyUpFilters.push(filter);
		return function() {
			HxOverrides.remove(_g.TextInputKeyUpFilters,filter);
		};
	}
	,getTextMetrics: function() {
		var ascent = 0.9 * this.fontSize;
		var descent = 0.1 * this.fontSize;
		var leading = 0.15 * this.fontSize;
		return [ascent,descent,leading];
	}
	,getLocalBounds: function() {
		if(this.isInput() && this.fieldHeight > 0.0 && this.fieldWidth > 0.0) return new PIXI.Rectangle(0.0,0.0,this.fieldWidth,this.fieldHeight); else return _$RenderSupportJSPixi_NativeWidgetClip.prototype.getLocalBounds.call(this);
	}
	,getBounds: function(skipUpdate,rect) {
		if(rect == null && this.isInput() && this.fieldHeight > 0.0 && this.fieldWidth > 0.0) {
			var lt = this.toGlobal(new PIXI.Point(0.0,0.0));
			var rb = this.toGlobal(new PIXI.Point(this.fieldWidth,this.fieldHeight));
			return new PIXI.Rectangle(lt.x,lt.y,rb.x - lt.x,rb.y - lt.y);
		} else return _$RenderSupportJSPixi_NativeWidgetClip.prototype.getBounds.call(this,skipUpdate,rect);
	}
	,calculateBounds: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.calculateBounds.call(this);
		if(this.isInput() && this.fieldHeight > 0.0 && this.fieldWidth > 0.0) this._bounds.addFrame(this.transform,0.0,0.0,this.fieldWidth,this.fieldHeight);
	}
	,__class__: _$RenderSupportJSPixi_TextField
});
var RenderSupportJSPixi = function() { };
RenderSupportJSPixi.__name__ = true;
RenderSupportJSPixi.getBackingStoreRatio = function() {
	if(Util.getParameter("resolution") != null) return Std.parseFloat(Util.getParameter("resolution")); else if(window.devicePixelRatio != null) return Math.max(window.devicePixelRatio,1.0); else return 1.0;
};
RenderSupportJSPixi.defer = function(fn,time) {
	if(time == null) time = 10;
	haxe_Timer.delay(fn,time);
};
RenderSupportJSPixi.preventDefaultFileDrop = function() {
	window.ondragover = window.ondrop = function(event) {
		if(event.dataTransfer.dropEffect != "copy") event.dataTransfer.dropEffect = "none";
		event.preventDefault();
		return false;
	};
};
RenderSupportJSPixi.init = function() {
	if(Util.getParameter("oldjs") != "1") RenderSupportJSPixi.initPixiRenderer(); else RenderSupportJSPixi.defer(RenderSupportJSPixi.StartFlowMain);
	return true;
};
RenderSupportJSPixi.printOptionValues = function() {
	if(RenderSupportJSPixi.AccessibilityEnabled) Errors.print("Flow Pixi renderer DEBUG mode is turned on");
	if(RenderSupportJSPixi.CacheTextsAsBitmap) Errors.print("Caches all textclips as bitmap is turned on");
};
RenderSupportJSPixi.workaroundIEArrayFromMethod = function() {
	
		if (!Array.from) {
			Array.from = (function () {
				var toStr = Object.prototype.toString;
				var isCallable = function (fn) {
					return typeof fn === 'function' || toStr.call(fn) === '[object Function]';
				};
				var toInteger = function (value) {
					var number = Number(value);
					if (isNaN(number)) { return 0; }
					if (number === 0 || !isFinite(number)) { return number; }
					return (number > 0 ? 1 : -1) * Math.floor(Math.abs(number));
				};
				var maxSafeInteger = Math.pow(2, 53) - 1;
				var toLength = function (value) {
					var len = toInteger(value);
					return Math.min(Math.max(len, 0), maxSafeInteger);
				};

				// The length property of the from method is 1.
				return function from(arrayLike/*, mapFn, thisArg */) {
					// 1. Let C be the this value.
					var C = this;

					// 2. Let items be ToObject(arrayLike).
					var items = Object(arrayLike);

					// 3. ReturnIfAbrupt(items).
					if (arrayLike == null) {
						throw new TypeError('Array.from requires an array-like object - not null or undefined');
					}

					// 4. If mapfn is undefined, then let mapping be false.
					var mapFn = arguments.length > 1 ? arguments[1] : void undefined;
					var T;
					if (typeof mapFn !== 'undefined') {
						// 5. else
						// 5. a If IsCallable(mapfn) is false, throw a TypeError exception.
						if (!isCallable(mapFn)) {
							throw new TypeError('Array.from: when provided, the second argument must be a function');
						}

						// 5. b. If thisArg was supplied, let T be thisArg; else let T be undefined.
						if (arguments.length > 2) {
							T = arguments[2];
						}
					}

					// 10. Let lenValue be Get(items, 'length').
					// 11. Let len be ToLength(lenValue).
					var len = toLength(items.length);

					// 13. If IsConstructor(C) is true, then
					// 13. a. Let A be the result of calling the [[Construct]] internal method of C with an argument list containing the single item len.
					// 14. a. Else, Let A be ArrayCreate(len).
					var A = isCallable(C) ? Object(new C(len)) : new Array(len);

					// 16. Let k be 0.
					var k = 0;
					// 17. Repeat, while k < len… (also steps a - h)
					var kValue;
					while (k < len) {
						kValue = items[k];
						if (mapFn) {
							A[k] = typeof T === 'undefined' ? mapFn(kValue, k) : mapFn.call(T, kValue, k);
						} else {
							A[k] = kValue;
						}
						k += 1;
					}
					// 18. Let putStatus be Put(A, 'length', len, true).
					A.length = len;
					// 20. Return A.
					return A;
				};
			}());
		}
};
RenderSupportJSPixi.workaroundIECustomEvent = function() {
	
		if ( typeof window.CustomEvent !== 'function' ) {
			function CustomEvent ( event, params ) {
				params = params || { bubbles: false, cancelable: false, detail: undefined };
				var evt = document.createEvent( 'CustomEvent' );
				evt.initCustomEvent( event, params.bubbles, params.cancelable, params.detail );

				for (var key in params) {
					evt[key] = params[key];
				}

				return evt;
			}

			CustomEvent.prototype = window.Event.prototype;

			window.CustomEvent = CustomEvent;
		};;
};
RenderSupportJSPixi.workaroundDOMOverOutEventsTransparency = function() {
	
		var binder = function(fn) {
			return fn.bind(RenderSupportJSPixi.PixiRenderer.plugins.interaction);
		}

		var emptyFn = function() {};

		var old_pointer_over = PIXI.interaction.InteractionManager.prototype.onPointerOver;
		var old_pointer_out = PIXI.interaction.InteractionManager.prototype.onPointerOut;

		PIXI.interaction.InteractionManager.prototype.onPointerOver = emptyFn;
		PIXI.interaction.InteractionManager.prototype.onPointerOut = emptyFn;

		var pointer_over = function(e) {
			if (e.fromElement == null)
				binder(old_pointer_over)(e);
		}

		var mouse_move = function(e) {
			pointer_over(e);
			document.removeEventListener('mousemove', mouse_move);
		}

		// if mouse is already over document
		document.addEventListener('mousemove', mouse_move);

		document.addEventListener('mouseover', pointer_over);

		document.addEventListener('mouseout', function(e) {
			if (e.toElement == null)
				binder(old_pointer_out)(e);
		});

		document.addEventListener('pointerover', function (e) {
			if (e.fromElement == null)
				binder(old_pointer_over)(e);
		});
		document.addEventListener('pointerout', function (e) {
			if (e.toElement == null)
				binder(old_pointer_out)(e);
		});;
};
RenderSupportJSPixi.initPixiRenderer = function() {
	if(PIXI.VERSION[0] > 3) RenderSupportJSPixi.workaroundDOMOverOutEventsTransparency();
	if(Platform.isIE) {
		RenderSupportJSPixi.workaroundIEArrayFromMethod();
		RenderSupportJSPixi.workaroundIECustomEvent();
	}
	RenderSupportJSPixi.backingStoreRatio = RenderSupportJSPixi.getBackingStoreRatio();
	var options = { antialias : RenderSupportJSPixi.Antialias, transparent : false, backgroundColor : 16777215, preserveDrawingBuffer : false, resolution : RenderSupportJSPixi.backingStoreRatio, roundPixels : RenderSupportJSPixi.RoundPixels, autoResize : true};
	if(RenderSupportJSPixi.RendererType != null && RenderSupportJSPixi.RendererType == "webgl") RenderSupportJSPixi.PixiRenderer = new PIXI.WebGLRenderer(window.innerWidth,window.innerHeight,options); else if(RenderSupportJSPixi.RendererType != null && RenderSupportJSPixi.RendererType == "auto") {
		RenderSupportJSPixi.PixiRenderer = PIXI.autoDetectRenderer(window.innerWidth,window.innerHeight,options);
		if((RenderSupportJSPixi.PixiRenderer instanceof PIXI.WebGLRenderer)) RenderSupportJSPixi.RendererType = "webgl"; else RenderSupportJSPixi.RendererType = "canvas";
	} else {
		RenderSupportJSPixi.PixiRenderer = new PIXI.CanvasRenderer(window.innerWidth,window.innerHeight,options);
		RenderSupportJSPixi.RendererType = "canvas";
	}
	RenderSupportJSPixi.PixiRenderer.maskManager.enableScissor = false;
	window.document.body.appendChild(RenderSupportJSPixi.PixiRenderer.view);
	RenderSupportJSPixi.preventDefaultFileDrop();
	RenderSupportJSPixi.initPixiStageEventListeners();
	RenderSupportJSPixi.initBrowserWindowEventListeners();
	RenderSupportJSPixi.initFullScreenEventListeners();
	FontLoader.LoadFonts(RenderSupportJSPixi.UseDFont,RenderSupportJSPixi.StartFlowMain);
	RenderSupportJSPixi.initClipboardListeners();
	_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap = RenderSupportJSPixi.CacheTextsAsBitmap;
	_$RenderSupportJSPixi_VideoClip.UsePixiTextures = RenderSupportJSPixi.UseVideoTextures && Platform.SupportsVideoTexture;
	RenderSupportJSPixi.printOptionValues();
	if(RenderSupportJSPixi.PixiRenderer.plugins != null && RenderSupportJSPixi.PixiRenderer.plugins.accessibility != null) {
		RenderSupportJSPixi.PixiRenderer.plugins.accessibility.destroy();
		RenderSupportJSPixi.PixiRenderer.plugins.accessibility = null;
	}
	if(Platform.isSafari) {
		RenderSupportJSPixi.PixiRenderer.view.style.position = "absolute";
		RenderSupportJSPixi.PixiRenderer.view.style.top = "0px";
	}
	window.document.body.selfZOrder = 0;
	RenderSupportJSPixi.requestAnimationFrame();
};
RenderSupportJSPixi.initBrowserWindowEventListeners = function() {
	RenderSupportJSPixi.WindowTopHeight = RenderSupportJSPixi.getScreenSize().height - window.innerHeight;
	window.addEventListener("resize",RenderSupportJSPixi.onBrowserWindowResize,false);
	window.addEventListener("message",RenderSupportJSPixi.receiveWindowMessage);
	window.addEventListener("focus",RenderSupportJSPixi.requestAnimationFrame,false);
};
RenderSupportJSPixi.initClipboardListeners = function() {
	var handler;
	var handlePaste = function(e) {
		if(window.clipboardData && window.clipboardData.getData) {
			NativeHx.clipboardData = window.clipboardData.getData("Text");
			NativeHx.clipboardDataHtml = "";
		} else if(e.clipboardData && e.clipboardData.getData) {
			NativeHx.clipboardData = e.clipboardData.getData("text/plain");
			NativeHx.clipboardDataHtml = e.clipboardData.getData("text/html");
		} else {
			NativeHx.clipboardData = "";
			NativeHx.clipboardDataHtml = "";
		}
		RenderSupportJSPixi.PixiStage.emit("paste");
	};
	handler = handlePaste;
	window.document.addEventListener("paste",handler,false);
};
RenderSupportJSPixi.initFullScreenEventListeners = function() {
	var _g = 0;
	var _g1 = ["fullscreenchange","mozfullscreenchange","webkitfullscreenchange","MSFullscreenChange"];
	while(_g < _g1.length) {
		var e = _g1[_g];
		++_g;
		window.document.addEventListener(e,RenderSupportJSPixi.fullScreenTrigger,false);
	}
};
RenderSupportJSPixi.receiveWindowMessage = function(e) {
	var hasNestedWindow = null;
	hasNestedWindow = function(iframe,win) {
		try {
			if(iframe.contentWindow == win) return true;
			var iframes = iframe.contentWindow.document.getElementsByTagName("iframe");
			var _g1 = 0;
			var _g = iframes.length;
			while(_g1 < _g) {
				var i = _g1++;
				if(hasNestedWindow(iframes[i],win)) return true;
			}
		} catch( e1 ) {
			haxe_CallStack.lastException = e1;
			if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
			Errors.print(e1);
		}
		return false;
	};
	var content_win = e.source;
	var all_iframes = window.document.getElementsByTagName("iframe");
	var _g11 = 0;
	var _g2 = all_iframes.length;
	while(_g11 < _g2) {
		var i1 = _g11++;
		var f = all_iframes[i1];
		if(hasNestedWindow(f,content_win)) {
			f.callflow(["postMessage",e.data]);
			return;
		}
	}
	Errors.report("Warning: unknown message source");
};
RenderSupportJSPixi.getScreenSize = function() {
	if(Platform.isIOS && Platform.isChrome) {
		var is_portrait = window.innerWidth < window.innerHeight;
		if(is_portrait) return { width : window.screen.width, height : window.screen.height}; else return { height : window.screen.width, width : window.screen.height};
	} else return { width : window.screen.width, height : window.screen.height};
};
RenderSupportJSPixi.onBrowserWindowResize = function(e) {
	RenderSupportJSPixi.PixiStageChanged = true;
	var options_antialias = RenderSupportJSPixi.Antialias;
	var options_transparent = false;
	var options_backgroundColor = 16777215;
	var options_preserveDrawingBuffer = false;
	var options_resolution = RenderSupportJSPixi.backingStoreRatio;
	var options_roundPixels = RenderSupportJSPixi.RoundPixels;
	var options_autoResize = true;
	RenderSupportJSPixi.backingStoreRatio = RenderSupportJSPixi.getBackingStoreRatio();
	RenderSupportJSPixi.PixiRenderer.resolution = RenderSupportJSPixi.backingStoreRatio;
	PIXI.Filter.resolution = RenderSupportJSPixi.backingStoreRatio;
	RenderSupportJSPixi.PixiRenderer.plugins.interaction.resolution = RenderSupportJSPixi.backingStoreRatio;
	var win_width = e.target.innerWidth;
	var win_height = e.target.innerHeight;
	if(Platform.isAndroid || Platform.isIOS && Platform.isChrome) {
		var screen_size = RenderSupportJSPixi.getScreenSize();
		win_width = screen_size.width;
		win_height = screen_size.height - RenderSupportJSPixi.WindowTopHeight;
		if(Platform.isAndroid) {
			RenderSupportJSPixi.PixiStage.y = 0.0;
			RenderSupportJSPixi.ensureCurrentInputVisible();
		}
	}
	RenderSupportJSPixi.PixiRenderer.resize(win_width,win_height);
	RenderSupportJSPixi.broadcastEvent(RenderSupportJSPixi.PixiStage,"resize",RenderSupportJSPixi.backingStoreRatio);
};
RenderSupportJSPixi.dropCurrentFocus = function() {
	if(window.document.activeElement != null && !RenderSupportJSPixi.isEmulating) window.document.activeElement.blur();
};
RenderSupportJSPixi.setDropCurrentFocusOnDown = function(drop) {
	if(RenderSupportJSPixi.DropCurrentFocusOnDown != drop) {
		RenderSupportJSPixi.DropCurrentFocusOnDown = drop;
		if(drop) RenderSupportJSPixi.PixiStage.on("mousedown",RenderSupportJSPixi.dropCurrentFocus); else RenderSupportJSPixi.PixiStage.off("mousedown",RenderSupportJSPixi.dropCurrentFocus);
	}
};
RenderSupportJSPixi.pixiStageOnMouseMove = function() {
	if(!RenderSupportJSPixi.isEmulating) RenderSupportJSPixi.switchFocusFramesShow(false);
};
RenderSupportJSPixi.initPixiStageEventListeners = function() {
	if(window.navigator.msPointerEnabled) {
		RenderSupportJSPixi.setStagePointerHandler("MSPointerDown",function() {
			RenderSupportJSPixi.PixiStage.emit("mousedown");
		});
		RenderSupportJSPixi.setStagePointerHandler("MSPointerUp",function() {
			RenderSupportJSPixi.PixiStage.emit("mouseup");
		});
		RenderSupportJSPixi.setStagePointerHandler("MSPointerMove",function() {
			RenderSupportJSPixi.PixiStage.emit("mousemove");
		});
	}
	if(NativeHx.isTouchScreen()) {
		RenderSupportJSPixi.setStagePointerHandler("touchstart",function() {
			RenderSupportJSPixi.PixiStage.emit("mousedown");
		});
		RenderSupportJSPixi.setStagePointerHandler("touchend",function() {
			RenderSupportJSPixi.PixiStage.emit("mouseup");
		});
		RenderSupportJSPixi.setStagePointerHandler("touchmove",function() {
			RenderSupportJSPixi.PixiStage.emit("mousemove");
		});
	}
	if(!Platform.isMobile) {
		RenderSupportJSPixi.setStagePointerHandler("mousedown",function() {
			RenderSupportJSPixi.PixiStage.emit("mousedown");
		});
		RenderSupportJSPixi.setStagePointerHandler("mouseup",function() {
			RenderSupportJSPixi.PixiStage.emit("mouseup");
		});
		RenderSupportJSPixi.setStagePointerHandler("mouserightdown",function() {
			RenderSupportJSPixi.PixiStage.emit("mouserightdown");
		});
		RenderSupportJSPixi.setStagePointerHandler("mouserightup",function() {
			RenderSupportJSPixi.PixiStage.emit("mouserightup");
		});
		RenderSupportJSPixi.setStagePointerHandler("mousemiddledown",function() {
			RenderSupportJSPixi.PixiStage.emit("mousemiddledown");
		});
		RenderSupportJSPixi.setStagePointerHandler("mousemiddleup",function() {
			RenderSupportJSPixi.PixiStage.emit("mousemiddleup");
		});
		RenderSupportJSPixi.setStagePointerHandler("mousemove",function() {
			RenderSupportJSPixi.PixiStage.emit("mousemove");
		});
		RenderSupportJSPixi.setStagePointerHandler("mouseout",function() {
			RenderSupportJSPixi.PixiStage.emit("mouseup");
		});
		RenderSupportJSPixi.setStagePointerHandler("mouseout",function() {
			RenderSupportJSPixi.PixiStage.emit("mouseup");
		});
		window.document.body.addEventListener("keydown",function(e) {
			RenderSupportJSPixi.PixiStage.emit("keydown",RenderSupportJSPixi.parseKeyEvent(e));
		});
		window.document.body.addEventListener("keyup",function(e1) {
			RenderSupportJSPixi.PixiStage.emit("keyup",RenderSupportJSPixi.parseKeyEvent(e1));
		});
	}
	RenderSupportJSPixi.PixiStage.on("mousedown",function() {
		RenderSupportJSPixi.MouseUpReceived = false;
	});
	RenderSupportJSPixi.PixiStage.on("mouseup",function() {
		RenderSupportJSPixi.MouseUpReceived = true;
	});
	RenderSupportJSPixi.switchFocusFramesShow(false);
	RenderSupportJSPixi.setDropCurrentFocusOnDown(true);
};
RenderSupportJSPixi.setStagePointerHandler = function(event,listener) {
	var cb;
	switch(event) {
	case "touchstart":case "touchmove":case "MSPointerDown":case "MSPointerMove":
		cb = function(e) {
			if(e.touches != null) {
				if(e.touches.length == 1) {
					RenderSupportJSPixi.MousePos.x = e.touches[0].pageX;
					RenderSupportJSPixi.MousePos.y = e.touches[0].pageY;
					listener();
				} else if(e.touches.length == 2) GesturesDetector.processPinch(new PIXI.Point(e.touches[0].pageX,e.touches[0].pageY),new PIXI.Point(e.touches[1].pageX,e.touches[1].pageY));
			}
		};
		break;
	case "touchend":case "MSPointerUp":
		cb = function(e1) {
			GesturesDetector.endPinch();
			if(e1.touches != null && e1.touches.length == 0) listener();
		};
		break;
	case "mouseout":
		cb = function(e2) {
			if(RenderSupportJSPixi.MouseUpReceived) return;
			var checkElement = function(el) {
				if(el != null) {
					var tagName = el.tagName.toLowerCase();
					return tagName == "input" || tagName == "textarea" || tagName == "div" && el.classList.contains("droparea");
				}
				return false;
			};
			if(checkElement(e2.toElement) && e2.fromElement != null || checkElement(e2.fromElement) && e2.toElement != null) return;
			listener();
		};
		break;
	case "mousedown":case "mouseup":
		cb = function(e3) {
			if(e3.target == RenderSupportJSPixi.PixiRenderer.view) e3.preventDefault();
			RenderSupportJSPixi.MousePos.x = e3.pageX;
			RenderSupportJSPixi.MousePos.y = e3.pageY;
			if(e3.which == 1 || e3.button == 0) listener();
		};
		break;
	case "mouserightdown":case "mouserightup":
		if(event == "mouserightdown") event = "mousedown"; else event = "mouseup";
		cb = function(e4) {
			RenderSupportJSPixi.MousePos.x = e4.pageX;
			RenderSupportJSPixi.MousePos.y = e4.pageY;
			if(e4.which == 3 || e4.button == 2) listener();
		};
		break;
	case "mousemiddledown":case "mousemiddleup":
		if(event == "mousemiddledown") event = "mousedown"; else event = "mouseup";
		cb = function(e5) {
			RenderSupportJSPixi.MousePos.x = e5.pageX;
			RenderSupportJSPixi.MousePos.y = e5.pageY;
			if(e5.which == 2 || e5.button == 1) listener();
		};
		break;
	default:
		cb = function(e6) {
			RenderSupportJSPixi.MousePos.x = e6.pageX;
			RenderSupportJSPixi.MousePos.y = e6.pageY;
			listener();
		};
	}
	if(event == "mouseout") window.document.body.addEventListener(event,cb); else RenderSupportJSPixi.PixiRenderer.view.addEventListener(event,cb);
};
RenderSupportJSPixi.emitForInteractives = function(clip,event) {
	if(clip.interactive) clip.emit(event);
	if(clip.children != null) {
		var childs = clip.children;
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			RenderSupportJSPixi.emitForInteractives(c,event);
		}
	}
};
RenderSupportJSPixi.provideEvent = function(e) {
	try {
		if(Platform.isIE) RenderSupportJSPixi.PixiRenderer.view.dispatchEvent(new CustomEvent(e.type, e)); else RenderSupportJSPixi.PixiRenderer.view.dispatchEvent(new e.constructor(e.type, e));
	} catch( er ) {
		haxe_CallStack.lastException = er;
		if (er instanceof js__$Boot_HaxeError) er = er.val;
		Errors.report("Error in provideEvent: " + Std.string(er));
	}
};
RenderSupportJSPixi.emulateMouseClickOnClip = function(clip) {
	var b = clip.getBounds();
	RenderSupportJSPixi.MousePos = clip.toGlobal(new PIXI.Point(b.width / 2.0,b.height / 2.0));
	RenderSupportJSPixi.emulateEvent("mousemove");
	RenderSupportJSPixi.emulateEvent("mouseover",100,clip);
	RenderSupportJSPixi.emulateEvent("mousedown",400);
	RenderSupportJSPixi.emulateEvent("mouseup",500);
	RenderSupportJSPixi.emulateEvent("mouseout",600,clip);
};
RenderSupportJSPixi.emulateEvent = function(event,delay,clip) {
	if(delay == null) delay = 10;
	RenderSupportJSPixi.defer(function() {
		RenderSupportJSPixi.isEmulating = true;
		if(event == "mousemove" || event == "mousedown" || event == "mouseup") RenderSupportJSPixi.PixiStage.emit(event); else if(event == "mouseover" || event == "mouseout") {
			if(clip != null) RenderSupportJSPixi.emitForInteractives(clip,event);
		}
		RenderSupportJSPixi.isEmulating = false;
	},delay);
};
RenderSupportJSPixi.ensureCurrentInputVisible = function() {
	var focused_node = window.document.activeElement;
	if(focused_node != null) {
		var node_name = focused_node.nodeName;
		node_name = node_name.toLowerCase();
		if(node_name == "input" || node_name == "textarea") {
			var rect = focused_node.getBoundingClientRect();
			if(rect.bottom > window.innerHeight) {
				RenderSupportJSPixi.PixiStage.y = window.innerHeight - rect.bottom;
				RenderSupportJSPixi.PixiStageChanged = true;
			}
		}
	}
};
RenderSupportJSPixi.switchFocusFramesShow = function(toShowFrames) {
	if(RenderSupportJSPixi.FocusFramesShown != toShowFrames) {
		RenderSupportJSPixi.FocusFramesShown = toShowFrames;
		var pixijscss = null;
		var _g = 0;
		var _g1 = window.document.styleSheets;
		while(_g < _g1.length) {
			var css = _g1[_g];
			++_g;
			if(css.href != null && css.href.indexOf("flowjspixi.css") >= 0) pixijscss = css;
		}
		if(pixijscss != null) {
			var newRuleIndex = 0;
			if(!toShowFrames) {
				pixijscss.insertRule(".focused { border: none !important; box-shadow: none !important; }",newRuleIndex);
				RenderSupportJSPixi.PixiStage.off("mousemove",RenderSupportJSPixi.pixiStageOnMouseMove);
			} else {
				pixijscss.deleteRule(newRuleIndex);
				RenderSupportJSPixi.PixiStage.on("mousemove",RenderSupportJSPixi.pixiStageOnMouseMove);
			}
		}
	}
};
RenderSupportJSPixi.StartFlowMain = function() {
	Errors.print("Starting flow main.");
	window.flow_main();
};
RenderSupportJSPixi.requestAnimationFrame = function() {
	window.cancelAnimationFrame(RenderSupportJSPixi.AnimationFrameId);
	RenderSupportJSPixi.AnimationFrameId = window.requestAnimationFrame(RenderSupportJSPixi.animate);
};
RenderSupportJSPixi.animate = function(timestamp) {
	RenderSupportJSPixi.PixiStage.emit("drawframe",timestamp);
	if(RenderSupportJSPixi.PixiStageChanged || _$RenderSupportJSPixi_VideoClip.NeedsDrawing()) {
		RenderSupportJSPixi.PixiRenderer.render(RenderSupportJSPixi.PixiStage);
		RenderSupportJSPixi.PixiStageChanged = false;
		if(RenderSupportJSPixi.ShowDebugClipsTree) _$RenderSupportJSPixi_DebugClipsTree.getInstance().updateTree(RenderSupportJSPixi.PixiStage);
	}
	RenderSupportJSPixi.requestAnimationFrame();
};
RenderSupportJSPixi.addPasteEventListener = function(fn) {
	RenderSupportJSPixi.PixiStage.on("paste",fn);
	return function() {
		RenderSupportJSPixi.PixiStage.off("paste",fn);
	};
};
RenderSupportJSPixi.InvalidateStage = function() {
	RenderSupportJSPixi.PixiStageChanged = true;
};
RenderSupportJSPixi.getPixelsPerCm = function() {
	return 37.795275590551178;
};
RenderSupportJSPixi.setHitboxRadius = function(radius) {
	return false;
};
RenderSupportJSPixi.addAccessAttributes = function(clip,attributes) {
	var _g = 0;
	while(_g < attributes.length) {
		var kv = attributes[_g];
		++_g;
		var key = kv[0];
		var val = kv[1];
		switch(key) {
		case "role":
			clip.accessWidget.setAttribute("role",val);
			if(RenderSupportJSPixi.accessRoleMap.get(val) == "button") {
				clip.accessWidget.onclick = (function() {
					return function() {
						if(clip.accessCallback != null) clip.accessCallback(); else RenderSupportJSPixi.emulateMouseClickOnClip(clip);
					};
				})();
				var onFocus = [clip.accessWidget.onfocus];
				var onBlur = [clip.accessWidget.onblur];
				clip.accessWidget.onfocus = (function(onFocus) {
					return function(e) {
						RenderSupportJSPixi.defer((function(onFocus) {
							return function() {
								if(onFocus[0] != null) onFocus[0](e);
								clip.accessWidget.classList.add("focused");
							};
						})(onFocus),50);
					};
				})(onFocus);
				clip.accessWidget.onblur = (function(onBlur) {
					return function(e1) {
						RenderSupportJSPixi.defer((function(onBlur) {
							return function() {
								if(onBlur[0] != null) onBlur[0](e1);
								clip.accessWidget.classList.remove("focused");
							};
						})(onBlur),50);
					};
				})(onBlur);
				if(clip.accessWidget.tabIndex == null) clip.accessWidget.tabIndex = 0;
			} else if(val == "textbox") {
				clip.accessWidget.onkeyup = (function() {
					return function(e2) {
						if(e2.keyCode == 13 && clip.accessCallback != null) clip.accessCallback();
					};
				})();
				if(clip.accessWidget.tabIndex == null) clip.accessWidget.tabIndex = 0;
			} else if(val == "iframe") {
				if(clip.accessWidget.tabIndex == null) clip.accessWidget.tabIndex = 0;
			}
			break;
		case "description":
			if(val != "") clip.accessWidget.setAttribute("aria-label",val);
			break;
		case "zorder":
			clip.accessWidget.selfZOrder = Std.parseInt(val);
			if(RenderSupportJSPixi.DebugAccessOrder) clip.accessWidget.setAttribute("selfzorder",val);
			RenderSupportJSPixi.updateAccessWidgetZOrder(clip.accessWidget);
			break;
		case "id":
			clip.accessWidget.id = val;
			break;
		case "enabled":
			if(val == "true") {
				clip.accessWidget.removeAttribute("disabled");
				clip.accessWidget.setAttribute("aria-disabled","false");
			} else {
				clip.accessWidget.setAttribute("disabled","disabled");
				clip.accessWidget.setAttribute("aria-disabled","true");
			}
			break;
		case "nodeindex":
			var nodeindex_strings = new EReg(" ","g").split(val);
			clip.accessWidget.nodeindex = [];
			if(RenderSupportJSPixi.DebugAccessOrder) clip.accessWidget.setAttribute("nodeindex",val);
			var _g2 = 0;
			var _g1 = nodeindex_strings.length;
			while(_g2 < _g1) {
				var i = _g2++;
				clip.accessWidget.nodeindex = clip.accessWidget.nodeindex.concat([Std.parseInt(nodeindex_strings[i])]);
			}
			if(clip.accessWidget.parentNode) RenderSupportJSPixi.addNode(clip.accessWidget.parentNode,clip.accessWidget);
			break;
		case "tabindex":
			clip.accessWidget.tabIndex = Std.parseInt(val);
			break;
		case "autocomplete":
			clip.accessWidget.autocomplete = val;
			break;
		default:
			clip.accessWidget.setAttribute(key,val);
		}
	}
};
RenderSupportJSPixi.setAccessibilityEnabled = function(enabled) {
	RenderSupportJSPixi.AccessibilityEnabled = enabled && Platform.AccessiblityAllowed;
};
RenderSupportJSPixi.setEnableFocusFrame = function(show) {
	RenderSupportJSPixi.EnableFocusFrame = show;
};
RenderSupportJSPixi.setAccessAttributes = function(clip,attributes) {
	if(!RenderSupportJSPixi.AccessibilityEnabled) return;
	if(clip.accessWidget == null) {
		if(clip.nativeWidget != null) {
			clip.accessWidget = clip.nativeWidget;
			RenderSupportJSPixi.addAccessAttributes(clip,attributes);
		} else {
			RenderSupportJSPixi.PixiStageChanged = true;
			var tagName = "div";
			if(attributes.length > 0 && attributes[0][0] == "role") {
				var mapval = RenderSupportJSPixi.accessRoleMap.get(attributes[0][1]);
				if(mapval != null) tagName = mapval;
			}
			var _g = 0;
			while(_g < attributes.length) {
				var kv = attributes[_g];
				++_g;
				if(kv[0] == "tag") tagName = kv[1];
			}
			clip.accessWidget = window.document.createElement(tagName);
			clip.accessWidget.addEventListener("focus",function() {
				clip.emit("focus");
				if(clip.parent != null) RenderSupportJSPixi.emitEvent(clip.parent,"childfocused",clip);
			});
			clip.accessWidget.addEventListener("blur",function() {
				clip.emit("blur");
			});
			clip.accessWidget.setAttribute("aria-disabled","false");
			clip.accessWidget.selfZOrder = 0;
			var updateDisplay = function(max_zorder) {
				if(clip.worldVisible && clip.accessWidget.zOrder >= max_zorder) clip.accessWidget.style.display = "block"; else clip.accessWidget.style.display = "none";
			};
			clip.accessWidget.updateDisplay = updateDisplay;
			RenderSupportJSPixi.addAccessAttributes(clip,attributes);
			if(tagName == "button") {
				if(clip.accessWidget.getAttribute("aria-label") == null) clip.accessWidget.setAttribute("aria-label","");
				clip.accessWidget.classList.add("accessButton");
			} else if(tagName == "input") {
				clip.accessWidget.style.position = "fixed";
				clip.accessWidget.style.cursor = "inherit";
				clip.accessWidget.style.opacity = 0;
				clip.accessWidget.setAttribute("readonly","");
			} else if(tagName == "form") clip.accessWidget.onsubmit = function() {
				return false;
			}; else clip.accessWidget.classList.add("accessElement");
			RenderSupportJSPixi.addNode(window.document.body,clip.accessWidget);
			clip.updateAccessWidget = function() {
				if(clip.accessWidget != null) {
					if(clip.worldVisible) {
						var max_zorder1 = window.document.body.zOrder;
						if(RenderSupportJSPixi.DebugAccessOrder) {
							var bounds = clip.getBounds(true);
							clip.accessWidget.style.left = "" + bounds.x + "px";
							clip.accessWidget.style.top = "" + bounds.y + "px";
							clip.accessWidget.style.width = "" + bounds.width + "px";
							clip.accessWidget.style.height = "" + bounds.height + "px";
						}
						if(clip.accessWidget.zOrder >= max_zorder1) clip.accessWidget.style.display = "block"; else clip.accessWidget.style.display = "none";
					} else clip.accessWidget.style.display = "none";
				}
			};
			clip.deleteAccessWidget = function() {
				RenderSupportJSPixi.PixiStage.off("drawframe",clip.updateAccessWidget);
				if(clip.accessWidget != null && clip.accessWidget.parentNode != null) {
					var parentNode = clip.accessWidget.parentNode;
					parentNode.removeChild(clip.accessWidget);
					delete clip.accessWidget;
					clip.accessWidget = null;
					RenderSupportJSPixi.updateAccessWidgetZOrder(parentNode);
				}
			};
			RenderSupportJSPixi.PixiStage.on("drawframe",clip.updateAccessWidget);
			clip.on("removed",clip.deleteAccessWidget);
		}
	} else RenderSupportJSPixi.addAccessAttributes(clip,attributes);
};
RenderSupportJSPixi.setAccessCallback = function(clip,callback) {
	clip.accessCallback = callback;
};
RenderSupportJSPixi.setShouldPreventFromBlur = function(clip) {
	if(clip.nativeWidget != null && clip.shouldPreventFromBlur != null) clip.shouldPreventFromBlur = true;
	var children = clip.children;
	if(children != null) {
		var _g = 0;
		while(_g < children.length) {
			var child = children[_g];
			++_g;
			RenderSupportJSPixi.setShouldPreventFromBlur(child);
		}
	}
};
RenderSupportJSPixi.updateAccessWidgetZOrder = function(accessWidget) {
	if(accessWidget != null && accessWidget.selfZOrder != null) {
		var previousZOrder = accessWidget.zOrder;
		accessWidget.zOrder = accessWidget.selfZOrder;
		var children = accessWidget.children;
		if(children != null) {
			var _g = 0;
			while(_g < children.length) {
				var child = children[_g];
				++_g;
				if(accessWidget.zOrder < child.zOrder) accessWidget.zOrder = child.zOrder;
			}
		}
		if(RenderSupportJSPixi.DebugAccessOrder) {
			accessWidget.setAttribute("zorder",accessWidget.zOrder);
			accessWidget.setAttribute("selfzorder",accessWidget.selfZOrder);
		}
		if(previousZOrder != accessWidget.zOrder && accessWidget != window.document.body) RenderSupportJSPixi.updateAccessWidgetZOrder(accessWidget.parentNode); else RenderSupportJSPixi.updateAccessWidgetsDisplay(accessWidget,window.document.body.zOrder);
	}
};
RenderSupportJSPixi.updateAccessWidgetsDisplay = function(accessWidget,max_zorder) {
	var children = accessWidget.children;
	if(children != null) {
		var _g = 0;
		while(_g < children.length) {
			var child = children[_g];
			++_g;
			if(child.updateDisplay != null) {
				child.updateDisplay(max_zorder);
				RenderSupportJSPixi.updateAccessWidgetsDisplay(child,max_zorder);
			}
		}
	}
};
RenderSupportJSPixi.currentClip = function() {
	return RenderSupportJSPixi.PixiStage;
};
RenderSupportJSPixi.hideFlowJSLoadingIndicator = function() {
	window.document.body.style.backgroundImage = "none";
	var indicator = window.document.getElementById("loading_js_indicator");
	if(null != indicator) indicator.style.display = "none";
};
RenderSupportJSPixi.enableResize = function() {
	RenderSupportJSPixi.hideFlowJSLoadingIndicator();
};
RenderSupportJSPixi.getStageWidth = function() {
	return RenderSupportJSPixi.PixiRenderer.width / RenderSupportJSPixi.backingStoreRatio;
};
RenderSupportJSPixi.getStageHeight = function() {
	return RenderSupportJSPixi.PixiRenderer.height / RenderSupportJSPixi.backingStoreRatio;
};
RenderSupportJSPixi.makeTextField = function(fontFamily) {
	if(RenderSupportJSPixi.UseDFont && FontLoader.hasDFont(fontFamily)) return new _$RenderSupportJSPixi_DFontText(); else return new _$RenderSupportJSPixi_PixiText();
};
RenderSupportJSPixi.capitalize = function(s) {
	return HxOverrides.substr(s,0,1).toUpperCase() + HxOverrides.substr(s,1,s.length - 1);
};
RenderSupportJSPixi.recognizeBuiltinFont = function(fontfamily,fontweight,fontslope) {
	if(StringTools.startsWith(fontfamily,"'Material Icons")) return "MaterialIcons"; else if(StringTools.startsWith(fontfamily,"'DejaVu Sans")) return "DejaVuSans"; else if(StringTools.startsWith(fontfamily,"'Franklin Gothic")) if(fontslope == "italic") return "Italic"; else if(fontweight == 700) return "Bold"; else return "Book"; else if(StringTools.startsWith(fontfamily,"Roboto")) return fontfamily + RenderSupportJSPixi.intFontWeight2StrSuffix(fontweight) + (fontslope == "normal"?"":HxOverrides.substr(fontslope,0,1).toUpperCase() + HxOverrides.substr(fontslope,1,fontslope.length - 1));
	return "";
};
RenderSupportJSPixi.intFontWeight2StrSuffix = function(w) {
	if(w <= 500) {
		if(w <= 300) {
			if(w <= 100) return "Thin"; else if(w <= 200) return "Ultra Light"; else return "Light";
		} else if(w <= 400) return ""; else return "Medium";
	} else if(w <= 700) {
		if(w <= 600) return "Semi Bold"; else return "Bold";
	} else if(w <= 800) return "Extra Bold"; else return "Black";
};
RenderSupportJSPixi.setTextAndStyle = function(textfield,text,fontfamily,fontsize,fontweight,fontslope,fillcolour,fillopacity,letterspacing,backgroundcolour,backgroundopacity,forTextinput) {
	var maybeBuiltin;
	if(fontweight > 0 || fontslope != "") maybeBuiltin = RenderSupportJSPixi.recognizeBuiltinFont(fontfamily,fontweight,fontslope); else maybeBuiltin = fontfamily;
	if(maybeBuiltin != "") fontfamily = maybeBuiltin;
	textfield.setTextAndStyle(text,fontfamily,fontsize,fontweight,fontslope,fillcolour,fillopacity,letterspacing,backgroundcolour,backgroundopacity);
};
RenderSupportJSPixi.setAdvancedText = function(textfield,sharpness,antialiastype,gridfittype) {
};
RenderSupportJSPixi.makeVideo = function(metricsFn,playFn,durationFn,positionFn) {
	return new _$RenderSupportJSPixi_VideoClip(metricsFn,playFn,durationFn,positionFn);
};
RenderSupportJSPixi.setVideoVolume = function(str,volume) {
	str.setVolume(volume);
};
RenderSupportJSPixi.setVideoLooping = function(str,loop) {
	str.setLooping(loop);
};
RenderSupportJSPixi.setVideoControls = function(str,controls) {
};
RenderSupportJSPixi.setVideoSubtitle = function(str,text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity) {
	str.setVideoSubtitle(text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity);
};
RenderSupportJSPixi.setVideoPlaybackRate = function(str,rate) {
	str.setPlaybackRate(rate);
};
RenderSupportJSPixi.setVideoTimeRange = function(str,start,end) {
	str.setTimeRange(start,end);
};
RenderSupportJSPixi.playVideo = function(vc,filename,startPaused) {
	vc.playVideo(filename,startPaused);
};
RenderSupportJSPixi.seekVideo = function(str,seek) {
	str.setCurrentTime(seek);
};
RenderSupportJSPixi.getVideoPosition = function(str) {
	return str.getCurrentTime();
};
RenderSupportJSPixi.pauseVideo = function(str) {
	str.pauseVideo();
};
RenderSupportJSPixi.resumeVideo = function(str) {
	str.resumeVideo();
};
RenderSupportJSPixi.closeVideo = function(str) {
};
RenderSupportJSPixi.getTextFieldWidth = function(textfield) {
	return textfield.getWidth();
};
RenderSupportJSPixi.setTextFieldWidth = function(textfield,width) {
	textfield.setWidth(width);
};
RenderSupportJSPixi.getTextFieldHeight = function(textfield) {
	return textfield.getHeight();
};
RenderSupportJSPixi.setTextFieldHeight = function(textfield,height) {
	if(height > 0.0) textfield.setHeight(height);
};
RenderSupportJSPixi.setTextFieldCropWords = function(textfield,crop) {
	textfield.setCropWords(crop);
};
RenderSupportJSPixi.setTextFieldCursorColor = function(textfield,color,opacity) {
	textfield.setCursorColor(color,opacity);
};
RenderSupportJSPixi.setTextFieldCursorWidth = function(textfield,width) {
	textfield.setCursorWidth(width);
};
RenderSupportJSPixi.setTextFieldInterlineSpacing = function(textfield,spacing) {
	textfield.setInterlineSpacing(spacing);
};
RenderSupportJSPixi.setAutoAlign = function(textfield,autoalign) {
	textfield.setAutoAlign(autoalign);
};
RenderSupportJSPixi.setTextInput = function(textfield) {
	textfield.setTextInput();
};
RenderSupportJSPixi.setTextInputType = function(textfield,type) {
	textfield.setTextInputType(type);
};
RenderSupportJSPixi.setTabIndex = function(textfield,index) {
	textfield.setTabIndex(index);
};
RenderSupportJSPixi.setTabEnabled = function(enabled) {
};
RenderSupportJSPixi.getContent = function(textfield) {
	return textfield.getContent();
};
RenderSupportJSPixi.getCursorPosition = function(textfield) {
	return textfield.getCursorPosition();
};
RenderSupportJSPixi.getFocus = function(clip) {
	return clip.getFocus();
};
RenderSupportJSPixi.getScrollV = function(textfield) {
	return 0;
};
RenderSupportJSPixi.setScrollV = function(textfield,suggestedPosition) {
};
RenderSupportJSPixi.getBottomScrollV = function(textfield) {
	return 0;
};
RenderSupportJSPixi.getNumLines = function(textfield) {
	return 0;
};
RenderSupportJSPixi.setFocus = function(clip,focus) {
	if(clip.setFocus != null) clip.setFocus(focus); else if(RenderSupportJSPixi.AccessibilityEnabled) {
		var accessWidget = RenderSupportJSPixi.findAccessibleChild(clip);
		if(accessWidget == null) return;
		if(accessWidget.getAttribute("tabindex") == null || accessWidget.getAttribute("tabindex").charAt(0) == "-" || accessWidget.disabled != false) accessWidget = accessWidget.querySelector("*[tabindex]:not([disabled]):not([tabindex^='-'])") || accessWidget;
		if(focus && accessWidget != null && $bind(accessWidget,accessWidget.focus) != null) accessWidget.focus(); else if(!focus && accessWidget != null && $bind(accessWidget,accessWidget.blur) != null) accessWidget.blur(); else {
			Errors.print("Can't set focus on element.");
			clip.emit("blur");
		}
	}
};
RenderSupportJSPixi.setMultiline = function(textfield,multiline) {
	textfield.setMultiline(multiline);
};
RenderSupportJSPixi.setWordWrap = function(textfield,wordWrap) {
	textfield.setWordWrap(wordWrap);
};
RenderSupportJSPixi.getSelectionStart = function(textfield) {
	return textfield.getSelectionStart();
};
RenderSupportJSPixi.getSelectionEnd = function(textfield) {
	return textfield.getSelectionEnd();
};
RenderSupportJSPixi.setSelection = function(textfield,start,end) {
	textfield.setSelection(start,end);
};
RenderSupportJSPixi.setReadOnly = function(textfield,readOnly) {
	textfield.setReadOnly(readOnly);
};
RenderSupportJSPixi.setMaxChars = function(textfield,maxChars) {
	textfield.setMaxChars(maxChars);
};
RenderSupportJSPixi.addTextInputFilter = function(textfield,filter) {
	return textfield.addTextInputFilter(filter);
};
RenderSupportJSPixi.addTextInputKeyEventFilter = function(textfield,event,filter) {
	if(event == "keydown") return textfield.addTextInputKeyDownEventFilter(filter); else return textfield.addTextInputKeyUpEventFilter(filter);
};
RenderSupportJSPixi.getAccessElement = function(clip) {
	if(clip.accessWidget != null) return clip.accessWidget; else if(clip.nativeWidget != null) return clip.nativeWidget; else return null;
};
RenderSupportJSPixi.addAccessChild = function(parent,clip) {
	var parentWidget = RenderSupportJSPixi.findParentAccessibleWidget(parent);
	var accessElement;
	if(clip.accessWidget != null) accessElement = clip.accessWidget; else if(clip.nativeWidget != null) accessElement = clip.nativeWidget; else accessElement = null;
	if(parentWidget != null) {
		if(accessElement != null) RenderSupportJSPixi.addNode(parentWidget,accessElement); else {
			var children = clip.children;
			if(children != null) {
				var _g = 0;
				while(_g < children.length) {
					var childclip = children[_g];
					++_g;
					RenderSupportJSPixi.addAccessChild(parent,childclip);
				}
			}
		}
	}
};
RenderSupportJSPixi.getNextAccessElement = function(parent,currentChild) {
	return Lambda.find(Array.from(parent.children),function(childclip) {
		if(currentChild != childclip && currentChild.nodeindex) {
			if(childclip.nodeindex) {
				var _g = 0;
				var childclipB = false;
				var stopCheck = false;
				while(!stopCheck && _g < childclip.nodeindex.length && _g < currentChild.nodeindex.length) {
					stopCheck = childclip.nodeindex[_g] != currentChild.nodeindex[_g];
					childclipB = childclip.nodeindex[_g] >= currentChild.nodeindex[_g];
					++_g;
				}
				return childclipB;
			} else return false;
		} else return false;
	});
};
RenderSupportJSPixi.findParentAccessible = function(clip) {
	if(clip == null) return null;
	var accessElement;
	if(clip.accessWidget != null) accessElement = clip.accessWidget; else if(clip.nativeWidget != null) accessElement = clip.nativeWidget; else accessElement = null;
	if(accessElement != null) return clip;
	return RenderSupportJSPixi.findParentAccessible(clip.parent);
};
RenderSupportJSPixi.findParentAccessibleWidget = function(clip) {
	if(clip == null) return null;
	var accessElement;
	if(clip.accessWidget != null) accessElement = clip.accessWidget; else if(clip.nativeWidget != null) accessElement = clip.nativeWidget; else accessElement = null;
	if(accessElement != null) return accessElement;
	return RenderSupportJSPixi.findParentAccessibleWidget(clip.parent);
};
RenderSupportJSPixi.findAccessibleChild = function(clip) {
	var accessElement = RenderSupportJSPixi.getAccessElement(clip);
	if(accessElement != null) return accessElement;
	var children = clip.children;
	if(children != null) {
		var _g = 0;
		while(_g < children.length) {
			var childclip = children[_g];
			++_g;
			var childElement = RenderSupportJSPixi.findAccessibleChild(childclip);
			if(childElement != null) return childElement;
		}
	}
	return null;
};
RenderSupportJSPixi.emitEvent = function(parent,event,value) {
	parent.emit(event,value);
	if(parent.parent != null) RenderSupportJSPixi.emitEvent(parent.parent,event,value);
};
RenderSupportJSPixi.broadcastEvent = function(parent,event,value) {
	parent.emit(event,value);
	if(parent.children != null) {
		var children = parent.children;
		var _g = 0;
		while(_g < children.length) {
			var c = children[_g];
			++_g;
			RenderSupportJSPixi.broadcastEvent(c,event,value);
		}
	}
	if(parent.mask != null) RenderSupportJSPixi.broadcastEvent(parent.mask,event,value);
};
RenderSupportJSPixi.addChild = function(parent,child) {
	parent.addChild(child);
	if(RenderSupportJSPixi.AccessibilityEnabled) RenderSupportJSPixi.addAccessChild(parent,child);
};
RenderSupportJSPixi.removeChild = function(parent,child) {
	parent.removeChild(child);
};
RenderSupportJSPixi.parentNodeIndex = function(parent,child) {
	var res = false;
	if(!child.contains(parent) && parent.nodeindex != null && child.nodeindex != null && parent.nodeindex.length != 0 && child.nodeindex.length >= parent.nodeindex.length) {
		res = true;
		var _g1 = 0;
		var _g = parent.nodeindex.length;
		while(_g1 < _g) {
			var i = _g1++;
			if(parent.nodeindex[i] != child.nodeindex[i]) {
				res = false;
				break;
			}
		}
	}
	return res;
};
RenderSupportJSPixi.equalNodeIndex = function(parent,child) {
	var res = false;
	if(parent.nodeindex != null && child.nodeindex != null && parent.nodeindex.length != 0 && child.nodeindex.length == parent.nodeindex.length) {
		res = true;
		var _g1 = 0;
		var _g = parent.nodeindex.length;
		while(_g1 < _g) {
			var i = _g1++;
			if(parent.nodeindex[i] != child.nodeindex[i]) {
				res = false;
				break;
			}
		}
	}
	return res;
};
RenderSupportJSPixi.addNode = function(parent,child) {
	try {
		var nextAccessChild = RenderSupportJSPixi.getNextAccessElement(parent,child);
		var previousParentNode = child.parentNode;
		if(nextAccessChild != null) {
			if(RenderSupportJSPixi.parentNodeIndex(nextAccessChild,child)) {
				if(RenderSupportJSPixi.equalNodeIndex(nextAccessChild,child)) {
					if(nextAccessChild.nextSibling == null) parent.appendChild(child); else parent.insertBefore(child,nextAccessChild.nextSibling);
				} else RenderSupportJSPixi.addNode(nextAccessChild,child);
			} else {
				if(RenderSupportJSPixi.DebugAccessOrder && parent != window.document.body && !RenderSupportJSPixi.parentNodeIndex(parent,child)) {
					console.log("Wrong accessWidget parentNode nodeindex");
					console.log(parent);
					console.log(child);
				}
				parent.insertBefore(child,nextAccessChild);
			}
		} else {
			if(RenderSupportJSPixi.DebugAccessOrder && parent != window.document.body && !RenderSupportJSPixi.parentNodeIndex(parent,child)) {
				console.log("Wrong accessWidget parentNode nodeindex");
				console.log(parent);
				console.log(child);
			}
			parent.appendChild(child);
		}
		if(child.parentNode == parent) {
			if(previousParentNode != child.parentNode) RenderSupportJSPixi.updateAccessWidgetZOrder(previousParentNode);
			RenderSupportJSPixi.updateAccessWidgetZOrder(child);
		}
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		if(RenderSupportJSPixi.DebugAccessOrder && parent != window.document.body && !RenderSupportJSPixi.parentNodeIndex(parent,child)) {
			console.log("Wrong accessWidget parentNode nodeindex");
			console.log(parent);
			console.log(child);
		}
		if(parent.parentNode != null) RenderSupportJSPixi.addNode(parent.parentNode,child); else RenderSupportJSPixi.addNode(window.document.body,child);
	}
};
RenderSupportJSPixi.makeClip = function() {
	return new _$RenderSupportJSPixi_FlowContainer();
};
RenderSupportJSPixi.addMetricsListener = function(clip,fn) {
	var func = function() {
		fn(clip.boundsWidth,clip.boundsHeight);
	};
	func();
	clip.on("metricschanged",func);
	return function() {
		clip.off("metricschanged",func);
	};
};
RenderSupportJSPixi.addGlobalTransformListener = function(clip,fn) {
	var prev_tr = RenderSupportJSPixi.getGlobalTransform(clip);
	fn(prev_tr);
	var func = function() {
		var tr = RenderSupportJSPixi.getGlobalTransform(clip);
		if(prev_tr != tr) fn(tr);
	};
	clip.on("transformchanged",func);
	return function() {
		clip.off("transformchanged",func);
	};
};
RenderSupportJSPixi.addTransformListener = function(clip,fn) {
	var func = function() {
		fn(clip.x,clip.y,clip.scale.x,clip.scale.y);
	};
	func();
	clip.on("transformchanged",func);
	return function() {
		clip.off("transformchanged",func);
	};
};
RenderSupportJSPixi.setClipCallstack = function(clip,callstack) {
};
RenderSupportJSPixi.setClipX = function(clip,x) {
	clip.setClipX(x);
};
RenderSupportJSPixi.setClipY = function(clip,y) {
	clip.setClipY(y);
};
RenderSupportJSPixi.setClipScaleX = function(clip,scale) {
	clip.setClipScaleX(scale);
};
RenderSupportJSPixi.setClipScaleY = function(clip,scale) {
	clip.setClipScaleY(scale);
};
RenderSupportJSPixi.setClipRotation = function(clip,r) {
	clip.setClipRotation(r * 0.0174532925);
};
RenderSupportJSPixi.getGlobalTransform = function(clip) {
	if(clip.parent != null && clip.renderable) {
		var a = clip.worldTransform;
		return [a.a,a.b,a.c,a.d,a.tx,a.ty];
	} else return [1.0,0.0,0.0,1.0,0.0,0.0];
};
RenderSupportJSPixi.deferUntilRender = function(fn) {
	RenderSupportJSPixi.PixiStage.once("drawframe",fn);
};
RenderSupportJSPixi.setClipAlpha = function(clip,a) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.alpha = a;
};
RenderSupportJSPixi.getFirstVideoWidget = function(clip) {
	if((clip instanceof _$RenderSupportJSPixi_VideoClip)) return clip;
	if(clip.children != null) {
		var _g = 0;
		var _g1 = clip.children;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			var video = RenderSupportJSPixi.getFirstVideoWidget(c);
			if(video != null) return video;
		}
	}
	return null;
};
RenderSupportJSPixi.setClipMask = function(clip,mask) {
	clip.setClipMask(mask);
};
RenderSupportJSPixi.getStage = function() {
	return RenderSupportJSPixi.PixiStage;
};
RenderSupportJSPixi.modifierStatePresent = function(e,m) {
	return e.getModifierState != null && e.getModifierState(m) != null;
};
RenderSupportJSPixi.parseKeyEvent = function(e) {
	var shift = false;
	var alt = false;
	var ctrl = false;
	var meta = false;
	var charCode = -1;
	var s = "";
	if(RenderSupportJSPixi.modifierStatePresent(e,"Shift")) shift = e.getModifierState("Shift"); else if(e.shiftKey != null) shift = e.shiftKey;
	if(RenderSupportJSPixi.modifierStatePresent(e,"Alt")) alt = e.getModifierState("Alt"); else if(e.altKey != null) alt = e.altKey; else if(RenderSupportJSPixi.modifierStatePresent(e,"AltGraph")) alt = e.getModifierState("AltGraph");
	if(RenderSupportJSPixi.modifierStatePresent(e,"Control")) ctrl = e.getModifierState("Control"); else if(e.ctrlKey != null) ctrl = e.ctrlKey;
	if(RenderSupportJSPixi.modifierStatePresent(e,"Meta")) meta = e.getModifierState("Meta"); else if(RenderSupportJSPixi.modifierStatePresent(e,"OS")) meta = e.getModifierState("OS"); else if(e.metaKey != null) meta = e.metaKey;
	if(Platform.isMacintosh) {
		var buf = meta;
		meta = ctrl;
		ctrl = buf;
	}
	if(e.charCode != null && e.charCode > 0) charCode = e.charCode; else if(e.which != null) charCode = e.which; else if(e.keyCode != null) charCode = e.keyCode;
	if(e.key != null && (Std.string(e.key).length == 1 || e.key == "Meta")) if(e.key == "Meta") {
		if(Platform.isMacintosh) s = "ctrl"; else s = "meta";
	} else s = e.key; else if(e.code != null && (Std.string(e.code).length == 1 || e.key == "MetaLeft" || e.key == "MetaRight")) if(e.code == "MetaLeft" || e.code == "MetaRight") {
		if(Platform.isMacintosh) s = "ctrl"; else s = "meta";
	} else s = e.code; else if(charCode >= 96 && charCode <= 105) s = Std.string(charCode - 96); else if(charCode >= 112 && charCode <= 123) s = "F" + (charCode - 111); else switch(charCode) {
	case 13:
		s = "enter";
		break;
	case 27:
		s = "esc";
		break;
	case 8:
		s = "backspace";
		break;
	case 9:
		RenderSupportJSPixi.switchFocusFramesShow(RenderSupportJSPixi.EnableFocusFrame);
		if(Platform.isIE || Platform.isEdge) RenderSupportJSPixi.PixiStage.emit("preonfocus");
		s = "tab";
		break;
	case 12:
		s = "clear";
		break;
	case 16:
		s = "shift";
		break;
	case 17:
		if(Platform.isMacintosh) s = "meta"; else s = "ctrl";
		break;
	case 18:
		s = "alt";
		break;
	case 19:
		s = "pause/break";
		break;
	case 20:
		s = "capslock";
		break;
	case 33:
		s = "pageup";
		break;
	case 34:
		s = "pagedown";
		break;
	case 35:
		s = "end";
		break;
	case 36:
		s = "home";
		break;
	case 37:
		s = "left";
		break;
	case 38:
		s = "up";
		break;
	case 39:
		s = "right";
		break;
	case 40:
		s = "down";
		break;
	case 45:
		s = "insert";
		break;
	case 46:
		s = "delete";
		break;
	case 48:
		if(shift) s = ")"; else s = "0";
		break;
	case 49:
		if(shift) s = "!"; else s = "1";
		break;
	case 50:
		if(shift) s = "@"; else s = "2";
		break;
	case 51:
		if(shift) s = "#"; else s = "3";
		break;
	case 52:
		if(shift) s = "$"; else s = "4";
		break;
	case 53:
		if(shift) s = "%"; else s = "5";
		break;
	case 54:
		if(shift) s = "^"; else s = "6";
		break;
	case 55:
		if(shift) s = "&"; else s = "7";
		break;
	case 56:
		if(shift) s = "*"; else s = "8";
		break;
	case 57:
		if(shift) s = "("; else s = "9";
		break;
	case 91:
		if(Platform.isMacintosh) s = "ctrl"; else s = "meta";
		break;
	case 92:
		s = "meta";
		break;
	case 93:
		if(Platform.isMacintosh) s = "ctrl"; else s = "context";
		break;
	case 106:
		s = "*";
		break;
	case 107:
		s = "+";
		break;
	case 109:
		s = "-";
		break;
	case 110:
		s = ".";
		break;
	case 111:
		s = "/";
		break;
	case 144:
		s = "numlock";
		break;
	case 145:
		s = "scrolllock";
		break;
	case 186:
		if(shift) s = ":"; else s = ";";
		break;
	case 187:
		if(shift) s = "+"; else s = "=";
		break;
	case 188:
		if(shift) s = "<"; else s = ",";
		break;
	case 189:
		if(shift) s = "_"; else s = "-";
		break;
	case 190:
		if(shift) s = ">"; else s = ".";
		break;
	case 191:
		if(shift) s = "?"; else s = "/";
		break;
	case 192:
		if(shift) s = "~"; else s = "`";
		break;
	case 219:
		if(shift) s = "{"; else s = "[";
		break;
	case 220:
		if(shift) s = "|"; else s = "\\";
		break;
	case 221:
		if(shift) s = "}"; else s = "]";
		break;
	case 222:
		if(shift) s = "\""; else s = "'";
		break;
	case 226:
		if(shift) s = "|"; else s = "\\";
		break;
	default:
		var keyUTF = String.fromCharCode(charCode);
		if(RenderSupportJSPixi.modifierStatePresent(e,"CapsLock")) {
			if(e.getModifierState("CapsLock")) s = keyUTF.toUpperCase(); else s = keyUTF.toLowerCase();
		} else s = keyUTF;
	}
	return { key : s, ctrl : ctrl, shift : shift, alt : alt, meta : meta, keyCode : e.keyCode, preventDefault : e.preventDefault.bind(e)};
};
RenderSupportJSPixi.addKeyEventListener = function(clip,event,fn) {
	var keycb = function(ke) {
		fn(ke.key,ke.ctrl,ke.shift,ke.alt,ke.meta,ke.keyCode,ke.preventDefault);
	};
	RenderSupportJSPixi.PixiStage.on(event,keycb);
	return function() {
		RenderSupportJSPixi.PixiStage.off(event,keycb);
	};
};
RenderSupportJSPixi.addStreamStatusListener = function(clip,fn) {
	return clip.addStreamStatusListener(fn);
};
RenderSupportJSPixi.addEventListener = function(clip,event,fn) {
	if(event == "resize") {
		RenderSupportJSPixi.PixiStage.on("resize",fn);
		return function() {
			RenderSupportJSPixi.PixiStage.off("resize",fn);
		};
	} else if(event == "mousedown" || event == "mousemove" || event == "mouseup" || event == "mousemiddledown" || event == "mousemiddleup") {
		RenderSupportJSPixi.PixiStage.on(event,fn);
		return function() {
			RenderSupportJSPixi.PixiStage.off(event,fn);
		};
	} else if(event == "mouserightdown" || event == "mouserightup") {
		var blockContextMenuFn = function() {
			return false;
		};
		RenderSupportJSPixi.PixiRenderer.view.oncontextmenu = blockContextMenuFn;
		var dropareas = window.document.getElementsByClassName("droparea");
		var _g = 0;
		while(_g < dropareas.length) {
			var droparea = dropareas[_g];
			++_g;
			droparea.oncontextmenu = blockContextMenuFn;
		}
		RenderSupportJSPixi.PixiStage.on(event,fn);
		return function() {
			RenderSupportJSPixi.PixiStage.off(event,fn);
		};
	} else if(event == "rollover") {
		clip.interactive = true;
		clip.on("mouseover",fn);
		return function() {
			clip.off("mouseover",fn);
		};
	} else if(event == "rollout") {
		clip.interactive = true;
		clip.on("mouseout",fn);
		return function() {
			clip.off("mouseout",fn);
		};
	} else if(event == "scroll") {
		clip.on("scroll",fn);
		return function() {
			clip.off("scroll",fn);
		};
	} else if(event == "change") {
		clip.on("input",fn);
		return function() {
			clip.off("input",fn);
		};
	} else if(event == "focusin") {
		clip.on("focus",fn);
		return function() {
			clip.off("focus",fn);
		};
	} else if(event == "focusout") {
		clip.on("blur",fn);
		return function() {
			clip.off("blur",fn);
		};
	} else {
		Errors.report("Unknown event: " + event);
		return function() {
		};
	}
};
RenderSupportJSPixi.addFileDropListener = function(clip,maxFilesCount,mimeTypeRegExpFilter,onDone) {
	var regExp = new EReg(mimeTypeRegExpFilter,"g");
	var dropArea = window.document.createElement("div");
	dropArea.className = "droparea";
	dropArea.style.position = "absolute";
	dropArea.oncontextmenu = RenderSupportJSPixi.PixiRenderer.view.oncontextmenu;
	clip.updateNativeWidget = function() {
		if(clip.worldVisible) {
			var bounds = clip.getBounds();
			dropArea.style.left = "" + bounds.x + "px";
			dropArea.style.top = "" + bounds.y + "px";
			dropArea.style.width = "" + bounds.width + "px";
			dropArea.style.height = "" + bounds.height + "px";
		} else dropArea.style.display = "none";
	};
	clip.createNativeWidget = function() {
		window.document.body.appendChild(dropArea);
		RenderSupportJSPixi.PixiStage.on("drawframe",clip.updateNativeWidget);
	};
	clip.deleteNativeWidget = function() {
		try {
			window.document.body.removeChild(dropArea);
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
		}
		RenderSupportJSPixi.PixiStage.off("drawframe",clip.updateNativeWidget);
	};
	if(clip.parent != null) clip.createNativeWidget(); else clip.on("added",function() {
		clip.createNativeWidget;
	});
	clip.on("removed",function() {
		clip.deleteNativeWidget;
	});
	dropArea.onmousemove = RenderSupportJSPixi.provideEvent;
	dropArea.onmousedown = RenderSupportJSPixi.provideEvent;
	dropArea.onmouseup = RenderSupportJSPixi.provideEvent;
	dropArea.ondragover = function(event) {
		event.dataTransfer.dropEffect = "copy";
		return false;
	};
	dropArea.ondrop = function(event1) {
		event1.preventDefault();
		var files = event1.dataTransfer.files;
		var fileArray = [];
		if(maxFilesCount < 0) maxFilesCount = files.length;
		var _g1 = 0;
		var _g = Math.floor(Math.min(files.length,maxFilesCount));
		while(_g1 < _g) {
			var idx = _g1++;
			var file = files.item(idx);
			if(!regExp.match(file.type)) {
				maxFilesCount++;
				continue;
			}
			fileArray.push(file);
		}
		onDone(fileArray);
	};
	return clip.deleteNativeWidget;
};
RenderSupportJSPixi.addExtendedEventListener = function(clip,event,fn) {
	if(event == "childfocused") {
		var parentFn = function(child) {
			var bounds = child.getBounds(true);
			var localPosition = clip.toLocal(new PIXI.Point(bounds.x,bounds.y));
			fn([localPosition.x,localPosition.y,bounds.width,bounds.height]);
		};
		clip.on(event,parentFn);
		return function() {
			clip.off(event,parentFn);
		};
	} else {
		Errors.report("Unknown event: " + event);
		return function() {
		};
	}
};
RenderSupportJSPixi.addDrawFrameEventListener = function(fn) {
	RenderSupportJSPixi.PixiStage.on("drawframe",fn);
	return function() {
		RenderSupportJSPixi.PixiStage.off("drawframe",fn);
	};
};
RenderSupportJSPixi.addMouseWheelEventListener = function(clip,fn) {
	var event_name = 'onwheel' in document.createElement('div') ? 'wheel' : // Modern browsers support 'wheel'
			document.onmousewheel !== undefined ? 'mousewheel' : // Webkit and IE support at least 'mousewheel'
			'DOMMouseScroll'; // let's assume that remaining browsers are older Firefox;
	var wheel_cb = function(event) {
		if(!event.ctrlKey) event.preventDefault();
		var sX = 0.0;
		var sY = 0.0;
		var pX = 0.0;
		var pY = 0.0;
		if(event.detail != null) sY = event.detail;
		if(event.wheelDelta != null) sY = -event.wheelDelta / 120;
		if(event.wheelDeltaY != null) sY = -event.wheelDeltaY / 120;
		if(event.wheelDeltaX != null) sX = -event.wheelDeltaX / 120;
		if(event.axis != null && ((event.axis) === event.HORIZONTAL_AXIS)) {
			sX = sY;
			sY = 0.0;
		}
		pX = sX * RenderSupportJSPixi.PIXEL_STEP;
		pY = sY * RenderSupportJSPixi.PIXEL_STEP;
		if(event.deltaY != null) pY = event.deltaY;
		if(event.deltaX != null) pX = event.deltaX;
		if((pX != 0.0 || pY != 0.0) && event.deltaMode != null) {
			if(event.deltaMode == 1) {
				pX *= RenderSupportJSPixi.LINE_HEIGHT;
				pY *= RenderSupportJSPixi.LINE_HEIGHT;
			} else {
				pX *= RenderSupportJSPixi.PAGE_HEIGHT;
				pY *= RenderSupportJSPixi.PAGE_HEIGHT;
			}
		}
		if(pX != 0.0 && sX == 0.0) if(pX < 1.0) sX = -1.0; else sX = 1.0;
		if(pY != 0.0 && sY == 0.0) if(pY < 1.0) sY = -1.0; else sY = 1.0;
		if(event.shiftKey != null && event.shiftKey && sX == 0.0) {
			sX = sY;
			sY = 0.0;
		}
		fn(-sX,-sY);
		return false;
	};
	window.addEventListener(event_name,wheel_cb,false);
	if(event_name == "DOMMouseScroll") window.addEventListener("MozMousePixelScroll",wheel_cb,false);
	return function() {
		window.removeEventListener(event_name,wheel_cb);
		if(event_name == "DOMMouseScroll") window.removeEventListener("MozMousePixelScroll",wheel_cb);
	};
};
RenderSupportJSPixi.addFinegrainMouseWheelEventListener = function(clip,f) {
	return RenderSupportJSPixi.addMouseWheelEventListener(clip,f);
};
RenderSupportJSPixi.getMouseX = function(clip) {
	if(clip == RenderSupportJSPixi.PixiStage) return RenderSupportJSPixi.MousePos.x; else return clip.toLocal(RenderSupportJSPixi.MousePos).x;
};
RenderSupportJSPixi.getMouseY = function(clip) {
	if(clip == RenderSupportJSPixi.PixiStage) return RenderSupportJSPixi.MousePos.y; else return clip.toLocal(RenderSupportJSPixi.MousePos).y;
};
RenderSupportJSPixi.setMouseX = function(x) {
	RenderSupportJSPixi.MousePos.x = x;
};
RenderSupportJSPixi.setMouseY = function(y) {
	RenderSupportJSPixi.MousePos.y = y;
};
RenderSupportJSPixi.hittestGraphics = function(g,global) {
	var graphicsData = g.graphicsData;
	if(graphicsData == null || graphicsData.length == 0) return false;
	var data = graphicsData[0];
	if(data.fill && data.shape != null) {
		var local = g.toLocal(global);
		return data.shape.contains(local.x,local.y);
	}
	return false;
};
RenderSupportJSPixi.dohittest = function(clip,global) {
	if(!clip.worldVisible || clip.isMask) return false;
	if(clip.mask != null && !RenderSupportJSPixi.hittestGraphics(clip.mask,global)) return false;
	if(clip.graphicsData != null) {
		if(RenderSupportJSPixi.hittestGraphics(clip,global)) return true;
	} else if(clip.texture != null) {
		var w = clip.texture.frame.width;
		var h = clip.texture.frame.height;
		var local = clip.toLocal(global);
		if(local.x > 0.0 && local.y > 0.0 && local.x < w && local.y < h) return true;
	} else if(clip.tint != null) {
		var b = clip.getLocalBounds();
		var local1 = clip.toLocal(global);
		local1.y += clip.y;
		if(local1.x > 0.0 && local1.y > 0.0 && local1.x < b.width && local1.y < b.height) return true;
	}
	if(clip.children != null) {
		var childs = clip.children;
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			if(RenderSupportJSPixi.dohittest(c,global)) return true;
		}
	}
	return false;
};
RenderSupportJSPixi.clipOnTheStage = function(clip) {
	return clip == RenderSupportJSPixi.PixiStage || clip.parent != null;
};
RenderSupportJSPixi.getClipAt = function(p,parent) {
	if(parent == null) parent = RenderSupportJSPixi.PixiStage;
	var cnt = parent.children.length;
	var _g = 0;
	while(_g < cnt) {
		var i = _g++;
		var child = parent.children[cnt - i - 1];
		if(child.visible && (child.mask == null || RenderSupportJSPixi.hittestGraphics(child.mask,p)) && !child.isMask && child.getBounds().contains(p.x,p.y)) {
			if((child instanceof _$RenderSupportJSPixi_TextField)) return child; else if(child.graphicsData != null && child.graphicsData.length > 0 && child.graphicsData[0].fillAlpha > 0) {
				if(RenderSupportJSPixi.hittestGraphics(child,p)) return child;
			} else if(child.texture != null) return child; else if(child.children != null) {
				var r = RenderSupportJSPixi.getClipAt(p,child);
				if(r != null) return r;
			}
		}
	}
	return null;
};
RenderSupportJSPixi.hittest = function(clip,x,y) {
	if(!(clip == RenderSupportJSPixi.PixiStage || clip.parent != null)) return false;
	var global = new PIXI.Point(x,y);
	clip.updateTransform();
	var parent = clip.parent;
	while(parent != null) {
		if(parent.mask != null && !RenderSupportJSPixi.hittestGraphics(parent.mask,global)) return false;
		parent = parent.parent;
	}
	return RenderSupportJSPixi.dohittest(clip,global);
};
RenderSupportJSPixi.getGraphics = function(parent) {
	var clip = new _$RenderSupportJSPixi_FlowGraphics();
	RenderSupportJSPixi.addChild(parent,clip);
	return clip;
};
RenderSupportJSPixi.setLineStyle = function(graphics,width,color,opacity) {
	graphics.lineStyle(width,color & 16777215,opacity);
};
RenderSupportJSPixi.setLineStyle2 = function(graphics,width,color,opacity,pixelHinting) {
	RenderSupportJSPixi.setLineStyle(graphics,width,color & 16777215,opacity);
};
RenderSupportJSPixi.beginFill = function(graphics,color,opacity) {
	graphics.beginFill(color & 16777215,opacity);
};
RenderSupportJSPixi.beginGradientFill = function(graphics,colors,alphas,offsets,matrix,type) {
	RenderSupportJSPixi.beginFill(graphics,0,1.0);
	graphics.gradient_data = { colors : colors, alphas : alphas, offsets : offsets, matrix : matrix, type : type};
};
RenderSupportJSPixi.setLineGradientStroke = function(graphics,colours,alphas,offsets,matrix) {
	RenderSupportJSPixi.setLineStyle(graphics,1.0,colours[0] & 16777215,alphas[0]);
};
RenderSupportJSPixi.makeMatrix = function(width,height,rotation,xOffset,yOffset) {
	return { width : width, height : height, rotation : rotation, xOffset : xOffset, yOffset : yOffset};
};
RenderSupportJSPixi.moveTo = function(graphics,x,y) {
	graphics.moveTo(x,y);
};
RenderSupportJSPixi.lineTo = function(graphics,x,y) {
	graphics.lineTo(x,y);
};
RenderSupportJSPixi.curveTo = function(graphics,cx,cy,x,y) {
	graphics.quadraticCurveTo(cx,cy,x,y);
};
RenderSupportJSPixi.makeCSSColor = function(color,alpha) {
	return "rgba(" + (color >> 16 & 255) + "," + (color >> 8 & 255) + "," + (color & 255) + "," + alpha + ")";
};
RenderSupportJSPixi.trimFloat = function(f,min,max) {
	if(f < min) return min; else if(f > max) return max; else return f;
};
RenderSupportJSPixi.endFill = function(graphics) {
	graphics.endFill();
	if(graphics.gradient_data != null) {
		var canvas;
		var _this = window.document;
		canvas = _this.createElement("canvas");
		var bounds = graphics.getBounds();
		canvas.width = bounds.width;
		canvas.height = bounds.height;
		var ctx = canvas.getContext("2d",null);
		var matrix = graphics.gradient_data.matrix;
		var gradient = ctx.createLinearGradient(matrix.xOffset,matrix.yOffset,matrix.width * Math.cos(matrix.rotation / 180.0 * Math.PI),matrix.height * Math.sin(matrix.rotation / 180.0 * Math.PI));
		var _g1 = 0;
		var _g = graphics.gradient_data.colors.length;
		while(_g1 < _g) {
			var i = _g1++;
			gradient.addColorStop(RenderSupportJSPixi.trimFloat(graphics.gradient_data.offsets[i],0.0,1.0),RenderSupportJSPixi.makeCSSColor(graphics.gradient_data.colors[i],graphics.gradient_data.alphas[i]));
		}
		ctx.fillStyle = gradient;
		ctx.fillRect(0.0,0.0,bounds.width,bounds.height);
		var sprite = new PIXI.Sprite(PIXI.Texture.fromCanvas(canvas));
		sprite.mask = graphics;
		graphics.parent.addChild(sprite);
		graphics.parent.on("removed",function() {
			graphics.parent.destroy({ children : true, texture : true, baseTexture : true});
		});
	}
};
RenderSupportJSPixi.makePicture = function(url,cache,metricsFn,errorFn,onlyDownload) {
	return new _$RenderSupportJSPixi_FlowSprite(url,cache,metricsFn,errorFn,onlyDownload);
};
RenderSupportJSPixi.setCursor = function(cursor) {
	var css_cursor;
	switch(cursor) {
	case "arrow":
		css_cursor = "default";
		break;
	case "auto":
		css_cursor = "auto";
		break;
	case "finger":
		css_cursor = "pointer";
		break;
	case "move":
		css_cursor = "move";
		break;
	case "text":
		css_cursor = "text";
		break;
	case "crosshair":
		css_cursor = "crosshair";
		break;
	case "help":
		css_cursor = "help";
		break;
	case "wait":
		css_cursor = "wait";
		break;
	case "context-menu":
		css_cursor = "context-menu";
		break;
	case "progress":
		css_cursor = "progress";
		break;
	case "copy":
		css_cursor = "copy";
		break;
	case "not-allowed":
		css_cursor = "not-allowed";
		break;
	case "all-scroll":
		css_cursor = "all-scroll";
		break;
	case "col-resize":
		css_cursor = "col-resize";
		break;
	case "row-resize":
		css_cursor = "row-resize";
		break;
	case "n-resize":
		css_cursor = "n-resize";
		break;
	case "e-resize":
		css_cursor = "e-resize";
		break;
	case "s-resize":
		css_cursor = "s-resize";
		break;
	case "w-resize":
		css_cursor = "w-resize";
		break;
	case "ne-resize":
		css_cursor = "ne-resize";
		break;
	case "nw-resize":
		css_cursor = "nw-resize";
		break;
	case "sw-resize":
		css_cursor = "sw-resize";
		break;
	case "ew-resize":
		css_cursor = "ew-resize";
		break;
	case "ns-resize":
		css_cursor = "ns-resize";
		break;
	case "nesw-resize":
		css_cursor = "nesw-resize";
		break;
	case "nwse-resize":
		css_cursor = "nwse-resize";
		break;
	case "zoom-in":
		css_cursor = "zoom-in";
		break;
	case "zoom-out":
		css_cursor = "zoom-out";
		break;
	case "grab":
		css_cursor = "grab";
		break;
	case "grabbing":
		css_cursor = "grabbing";
		break;
	default:
		css_cursor = "default";
	}
	window.document.body.style.cursor = css_cursor;
};
RenderSupportJSPixi.getCursor = function() {
	var _g = window.document.body.style.cursor;
	switch(_g) {
	case "default":
		return "arrow";
	case "auto":
		return "auto";
	case "pointer":
		return "finger";
	case "move":
		return "move";
	case "text":
		return "text";
	default:
		return "default";
	}
};
RenderSupportJSPixi.addFilters = function(clip,filters) {
	RenderSupportJSPixi.PixiStageChanged = true;
	if(RenderSupportJSPixi.RendererType == "canvas") {
		filters = filters.filter(function(f) {
			return f != null && 
					((typeof PIXI.filters.DropShadowFilter != "undefined") && (f instanceof PIXI.filters.DropShadowFilter)) ||
					((typeof PIXI.filters.BlurFilter != "undefined") && (f instanceof PIXI.filters.BlurFilter))
				;
		});
		clip.canvasFilters = filters;
	} else {
		filters = filters.filter(function(f1) {
			return f1 != null;
		});
		if(filters.length > 0) clip.filters = filters; else clip.filters = null;
	}
};
RenderSupportJSPixi.makeBevel = function(angle,distance,radius,spread,color1,alpha1,color2,alpha2,inside) {
	return null;
};
RenderSupportJSPixi.makeBlur = function(radius,spread) {
	return new PIXI.filters.BlurFilter(spread);
};
RenderSupportJSPixi.makeDropShadow = function(angle,distance,radius,spread,color,alpha,inside) {
	return new PIXI.filters.DropShadowFilter(angle,distance,radius,color,alpha);
};
RenderSupportJSPixi.makeGlow = function(radius,spread,color,alpha,inside) {
	return new PIXI.Filter(_$RenderSupportJSPixi_Shaders.VertexSrc.join("\n"),_$RenderSupportJSPixi_Shaders.GlowFragmentSrc.join("\n"),{ });
};
RenderSupportJSPixi.setScrollRect = function(clip,left,top,width,height) {
	clip.setScrollRect(left,top,width,height);
};
RenderSupportJSPixi.makeGraphicsRect = function(width,height) {
	var g = new _$RenderSupportJSPixi_FlowGraphics();
	g.beginFill(16777215);
	g.drawRect(0.0,0.0,width,height);
	g.endFill();
	return g;
};
RenderSupportJSPixi.getTextMetrics = function(textfield) {
	return textfield.getTextMetrics();
};
RenderSupportJSPixi.makeBitmap = function() {
	return null;
};
RenderSupportJSPixi.bitmapDraw = function(bitmap,clip,width,height) {
};
RenderSupportJSPixi.getClipVisible = function(clip) {
	return clip.worldVisible;
};
RenderSupportJSPixi.setClipVisible = function(clip,vis) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.visible = vis;
};
RenderSupportJSPixi.fullScreenTrigger = function() {
	RenderSupportJSPixi.IsFullScreen = RenderSupportJSPixi.isFullScreen();
	RenderSupportJSPixi.PixiStage.emit("fullscreen",RenderSupportJSPixi.IsFullScreen);
};
RenderSupportJSPixi.fullWindowTrigger = function(fw) {
	RenderSupportJSPixi.IsFullWindow = fw;
	RenderSupportJSPixi.PixiStage.emit("fullwindow",fw);
};
RenderSupportJSPixi.setFullWindowTarget = function(clip) {
	if(RenderSupportJSPixi.FullWindowTargetClip != clip) {
		if(RenderSupportJSPixi.IsFullWindow && RenderSupportJSPixi.FullWindowTargetClip != null) {
			RenderSupportJSPixi.toggleFullWindow(false);
			RenderSupportJSPixi.FullWindowTargetClip = clip;
			if(clip != null) RenderSupportJSPixi.toggleFullWindow(true);
		} else RenderSupportJSPixi.FullWindowTargetClip = clip;
	}
};
RenderSupportJSPixi.setFullScreenRectangle = function(x,y,w,h) {
};
RenderSupportJSPixi.resetFullWindowTarget = function() {
	RenderSupportJSPixi.setFullWindowTarget(null);
};
RenderSupportJSPixi.toggleFullWindow = function(fw) {
	if(RenderSupportJSPixi.FullWindowTargetClip != null && RenderSupportJSPixi.IsFullWindow != fw) {
		RenderSupportJSPixi.PixiStageChanged = true;
		if((RenderSupportJSPixi.FullWindowTargetClip instanceof _$RenderSupportJSPixi_VideoClip)) {
			if(fw) RenderSupportJSPixi.requestFullScreen(RenderSupportJSPixi.FullWindowTargetClip.nativeWidget); else RenderSupportJSPixi.exitFullScreen(RenderSupportJSPixi.FullWindowTargetClip.nativeWidget);
			return;
		}
		if(fw) {
			RenderSupportJSPixi.regularStageChildren = RenderSupportJSPixi.PixiStage.children;
			RenderSupportJSPixi.setShouldPreventFromBlur(RenderSupportJSPixi.FullWindowTargetClip);
			RenderSupportJSPixi.PixiStage.children = [];
			RenderSupportJSPixi.regularFullScreenClipParent = RenderSupportJSPixi.FullWindowTargetClip.parent;
			RenderSupportJSPixi.PixiStage.addChild(RenderSupportJSPixi.FullWindowTargetClip);
			var _clip_visible = RenderSupportJSPixi.FullWindowTargetClip.visible;
			var _g = 0;
			var _g1 = RenderSupportJSPixi.regularStageChildren;
			while(_g < _g1.length) {
				var child = _g1[_g];
				++_g;
				child._flow_visible = child.visible;
				child.visible = false;
			}
			RenderSupportJSPixi.FullWindowTargetClip.visible = _clip_visible;
			RenderSupportJSPixi.FullWindowTargetClip.updateTransform();
		} else if(RenderSupportJSPixi.regularFullScreenClipParent != null && RenderSupportJSPixi.regularStageChildren.length != 0) {
			var _g2 = 0;
			var _g11 = RenderSupportJSPixi.regularStageChildren;
			while(_g2 < _g11.length) {
				var child1 = _g11[_g2];
				++_g2;
				child1.visible = child1._flow_visible;
			}
			RenderSupportJSPixi.PixiStage.children = RenderSupportJSPixi.regularStageChildren;
			RenderSupportJSPixi.regularFullScreenClipParent.addChild(RenderSupportJSPixi.FullWindowTargetClip);
		}
		RenderSupportJSPixi.fullWindowTrigger(fw);
	}
};
RenderSupportJSPixi.requestFullScreen = function(element) {
	if($bind(element,element.requestFullscreen) != null) element.requestFullscreen(); else if(element.mozRequestFullScreen != null) element.mozRequestFullScreen(); else if(element.webkitRequestFullscreen != null) element.webkitRequestFullscreen(); else if(element.msRequestFullscreen != null) element.msRequestFullscreen(); else if(element.webkitEnterFullScreen != null) element.webkitEnterFullScreen();
};
RenderSupportJSPixi.exitFullScreen = function(element) {
	if((element instanceof HTMLCanvasElement)) element = window.document;
	if(element.exitFullscreen != null) element.exitFullscreen(); else if(element.mozCancelFullScreen != null) element.mozCancelFullScreen(); else if(element.webkitExitFullscreen != null) element.webkitExitFullscreen(); else if(element.msExitFullscreen != null) element.msExitFullscreen();
};
RenderSupportJSPixi.toggleFullScreen = function(fs) {
	if(fs) RenderSupportJSPixi.requestFullScreen(RenderSupportJSPixi.PixiRenderer.view); else RenderSupportJSPixi.exitFullScreen(RenderSupportJSPixi.PixiRenderer.view);
};
RenderSupportJSPixi.onFullScreen = function(fn) {
	RenderSupportJSPixi.PixiStage.on("fullscreen",fn);
	return function() {
		RenderSupportJSPixi.PixiStage.off("fullscreen",fn);
	};
};
RenderSupportJSPixi.isFullScreen = function() {
	return window.document.fullScreen || (window.document.mozFullScreen || (window.document.webkitIsFullScreen || (window.document.fullscreenElement != null || (window.document.msFullscreenElement != null || RenderSupportJSPixi.FullWindowTargetClip != null && RenderSupportJSPixi.FullWindowTargetClip.nativeWidget != null && RenderSupportJSPixi.FullWindowTargetClip.nativeWidget.webkitDisplayingFullscreen))));
};
RenderSupportJSPixi.onFullWindow = function(onChange) {
	RenderSupportJSPixi.PixiStage.on("fullwindow",onChange);
	return function() {
		RenderSupportJSPixi.PixiStage.off("fullwindow",onChange);
	};
};
RenderSupportJSPixi.isFullWindow = function() {
	return RenderSupportJSPixi.IsFullWindow;
};
RenderSupportJSPixi.setWindowTitle = function(title) {
	window.document.title = title;
};
RenderSupportJSPixi.setFavIcon = function(url) {
	var head = window.document.getElementsByTagName("head")[0];
	var oldNode = window.document.getElementById("dynamic-favicon");
	var node = window.document.createElement("link");
	node.setAttribute("id","dynamic-favicon");
	node.setAttribute("rel","shortcut icon");
	node.setAttribute("href",url);
	node.setAttribute("type","image/ico");
	if(oldNode != null) head.removeChild(oldNode);
	head.appendChild(node);
};
RenderSupportJSPixi.takeSnapshot = function(path) {
};
RenderSupportJSPixi.getScreenPixelColor = function(x,y) {
	var data = RenderSupportJSPixi.PixiRenderer.view.getContext("2d",null).getImageData(x * RenderSupportJSPixi.backingStoreRatio,y * RenderSupportJSPixi.backingStoreRatio,1,1).data;
	var rgb = data[0];
	rgb = (rgb << 8) + data[1];
	rgb = (rgb << 8) + data[2];
	return rgb;
};
RenderSupportJSPixi.makeWebClip = function(url,domain,useCache,reloadBlock,cb,ondone,shrinkToFit) {
	return new _$RenderSupportJSPixi_WebClip(url,domain,useCache,reloadBlock,cb,ondone,shrinkToFit);
};
RenderSupportJSPixi.webClipHostCall = function(clip,name,args) {
	return clip.hostCall(name,args);
};
RenderSupportJSPixi.setWebClipSandBox = function(clip,value) {
	clip.setSandBox(value);
};
RenderSupportJSPixi.setWebClipDisabled = function(clip,disabled) {
	clip.setDisableOverlay(disabled);
};
RenderSupportJSPixi.webClipEvalJS = function(clip,code) {
	clip.evalJS(code);
	return null;
};
RenderSupportJSPixi.getNumberOfCameras = function() {
	return 0;
};
RenderSupportJSPixi.getCameraInfo = function(id) {
	return "";
};
RenderSupportJSPixi.makeCamera = function(uri,camID,camWidth,camHeight,camFps,vidWidth,vidHeight,recordMode,cbOnReadyForRecording,cbOnFailed) {
	return [null,null];
};
RenderSupportJSPixi.startRecord = function(str,filename,mode) {
};
RenderSupportJSPixi.stopRecord = function(str) {
};
RenderSupportJSPixi.cameraTakePhoto = function(cameraId,additionalInfo,desiredWidth,desiredHeight,compressQuality,fileName,fitMode) {
};
RenderSupportJSPixi.addGestureListener = function(event,cb) {
	if(event == "pinch") return GesturesDetector.addPinchListener(cb); else return function() {
	};
};
RenderSupportJSPixi.setWebClipZoomable = function(clip,zoomable) {
};
RenderSupportJSPixi.setInterfaceOrientation = function(orientation) {
	var screen = window.screen;
	if(screen != null && screen.orientation != null && screen.orientation.lock != null) screen.orientation.lock(orientation);
};
RenderSupportJSPixi.setUrlHash = function(hash) {
	window.location.hash = hash;
};
RenderSupportJSPixi.getUrlHash = function() {
	return window.location.hash;
};
RenderSupportJSPixi.addUrlHashListener = function(cb) {
	var wrapper = function(e) {
		cb(window.location.hash);
	};
	window.addEventListener("hashchange",wrapper);
	return function() {
		window.removeEventListener("hashchange",wrapper);
	};
};
RenderSupportJSPixi.setGlobalZoomEnabled = function(enabled) {
};
RenderSupportJSPixi.removeAlphaChannel = function(color) {
	return color & 16777215;
};
var _$RenderSupportJSPixi_FlowGraphics = function() {
	this.boundsHeight = 0.0;
	this.boundsWidth = 0.0;
	this.penY = 0.0;
	this.penX = 0.0;
	var _g = this;
	PIXI.Graphics.call(this);
	this.on("childrenchanged",function() {
		if(_g.parent != null) _g.parent.emit("childrenchanged"); else if(_g == RenderSupportJSPixi.PixiStage) RenderSupportJSPixi.PixiStageChanged = true;
	});
	this.on("transformchanged",RenderSupportJSPixi.InvalidateStage);
	this.on("graphicschanged",RenderSupportJSPixi.InvalidateStage);
};
_$RenderSupportJSPixi_FlowGraphics.__name__ = true;
_$RenderSupportJSPixi_FlowGraphics.__super__ = PIXI.Graphics;
_$RenderSupportJSPixi_FlowGraphics.prototype = $extend(PIXI.Graphics.prototype,{
	moveTo: function(x,y) {
		var newGraphics = PIXI.Graphics.prototype.moveTo.call(this,x,y);
		this.penX = x;
		this.penY = y;
		this.emit("graphicschanged");
		this.addWidthHeight(x,y);
		return newGraphics;
	}
	,lineTo: function(x,y) {
		var newGraphics = PIXI.Graphics.prototype.lineTo.call(this,x,y);
		this.penX = x;
		this.penY = y;
		this.emit("graphicschanged");
		this.addWidthHeight(x,y);
		return PIXI.Graphics.prototype.lineTo.call(this,x,y);
	}
	,quadraticCurveTo: function(cx,cy,x,y) {
		var dx = x - this.penX;
		var dy = y - this.penY;
		if(Math.sqrt(dx * dx + dy * dy) / this.lineWidth > 3) {
			var newGraphics = PIXI.Graphics.prototype.quadraticCurveTo.call(this,cx,cy,x,y);
			this.penX = x;
			this.penY = y;
			this.emit("graphicschanged");
			this.addWidthHeight(x,y);
			return newGraphics;
		} else {
			this.lineTo(cx,cy);
			return this.lineTo(x,y);
		}
	}
	,endFill: function() {
		var newGraphics = PIXI.Graphics.prototype.endFill.call(this);
		this.emit("graphicschanged");
		return newGraphics;
	}
	,drawRect: function(x,y,width,height) {
		var newGraphics = PIXI.Graphics.prototype.drawRect.call(this,x,y,width,height);
		this.emit("graphicschanged");
		this.addWidthHeight(x + width,y + height);
		return newGraphics;
	}
	,clear: function() {
		var oldBoundsWidth = this.boundsWidth;
		var oldBoundsHeight = this.boundsHeight;
		this.boundsWidth = 0.0;
		this.boundsHeight = 0.0;
		this.removeWidthHeight(oldBoundsWidth,oldBoundsHeight);
		return PIXI.Graphics.prototype.clear.call(this);
	}
	,addChild: function(child) {
		var addedChild = PIXI.Graphics.prototype.addChild.call(this,child);
		if(addedChild != null) {
			this.removeChildWidthHeight(addedChild);
			this.emit("childrenchanged");
		}
		return addedChild;
	}
	,addChildAt: function(child,index) {
		var addedChild = PIXI.Graphics.prototype.addChildAt.call(this,child,index);
		if(addedChild != null) {
			this.removeChildWidthHeight(addedChild);
			this.emit("childrenchanged");
		}
		return addedChild;
	}
	,removeChild: function(child) {
		var removedChild = PIXI.Graphics.prototype.removeChild.call(this,child);
		if(removedChild != null) {
			this.removeChildWidthHeight(removedChild);
			this.emit("childrenchanged");
		}
		return removedChild;
	}
	,removeChildWidthHeight: function(child) {
		this.removeWidthHeight(child.transform != null?child.x + child.boundsWidth * child.scale.x:child.boundsWidth,child.transform != null?child.y + child.boundsHeight * child.scale.y:child.boundsHeight);
	}
	,removeWidthHeight: function(x,y,updateParent) {
		if(updateParent == null) updateParent = true;
		if(x == this.boundsWidth || y == this.boundsHeight) {
			var oldBoundsWidth = this.boundsWidth;
			var oldBoundsHeight = this.boundsHeight;
			this.recalculateWidthHeight(false);
			if(oldBoundsWidth != this.boundsWidth || oldBoundsHeight != this.boundsHeight) {
				if(updateParent) {
					this.emit("metricschanged");
					if(this.parent != null) this.parent.removeWidthHeight(this.x + oldBoundsWidth * this.scale.x,this.y + oldBoundsHeight * this.scale.y);
				}
			}
		}
	}
	,recalculateWidthHeight: function(updateParent) {
		if(updateParent == null) updateParent = true;
		this.boundsWidth = 0.0;
		this.boundsHeight = 0.0;
		var _g = 0;
		var _g1 = this.children;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			this.addWidthHeight(c.x + c.boundsWidth * c.scale.x,c.y + c.boundsHeight * c.scale.y,updateParent);
		}
	}
	,addWidthHeight: function(x,y,updateParent) {
		if(updateParent == null) updateParent = true;
		if(x > this.boundsWidth || y > this.boundsHeight) {
			this.boundsWidth = Math.max(this.boundsWidth,x);
			this.boundsHeight = Math.max(this.boundsHeight,y);
			if(updateParent) {
				this.emit("metricschanged");
				if(this.parent != null) this.parent.addWidthHeight(this.x + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * this.scale.y);
			}
		}
	}
	,setClipX: function(x) {
		if(this.x != x) {
			var previousX = this.x;
			this.x = x;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(previousX + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * this.scale.y);
		}
	}
	,setClipY: function(y) {
		if(this.y != y) {
			var previousY = this.y;
			this.y = y;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * this.scale.x,previousY + this.boundsHeight * this.scale.y);
		}
	}
	,setClipScaleX: function(scale) {
		if(this.scale.x != scale) {
			var previousScaleX = this.scale.x;
			this.scale.x = scale;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * previousScaleX,this.y + this.boundsHeight * this.scale.y);
		}
	}
	,setClipScaleY: function(scale) {
		if(this.scale.y != scale) {
			var previousScaleY = this.scale.y;
			this.scale.y = scale;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * previousScaleY);
		}
	}
	,setClipRotation: function(rotation) {
		if(this.rotation != rotation) {
			this.rotation = rotation;
			this.emit("transformchanged");
		}
	}
	,setScrollRect: function(left,top,width,height) {
		if(this.scrollRect != null) {
			this.setClipX(this.x + this.scrollRect.x * 2 - left);
			this.setClipY(this.y + this.scrollRect.y * 2 - top);
			this.scrollRect.clear();
		} else {
			this.setClipX(this.x - left);
			this.setClipY(this.y - top);
			this.scrollRect = new _$RenderSupportJSPixi_FlowGraphics();
			this.addChild(this.scrollRect);
			this.setClipMask(this.scrollRect);
		}
		this.scrollRect.beginFill(16777215);
		this.scrollRect.drawRect(0.0,0.0,width,height);
		this.scrollRect.endFill();
		this.scrollRect.setClipX(left);
		this.scrollRect.setClipY(top);
	}
	,removeScrollRect: function() {
		if(this.scrollRect != null) {
			this.setClipX(this.x + this.scrollRect.x);
			this.setClipY(this.y + this.scrollRect.y);
			this.removeChild(this.scrollRect);
			this.scrollRect = null;
		}
	}
	,setClipMask: function(maskContainer) {
		var _g = this;
		if(maskContainer != this.scrollRect) this.removeScrollRect();
		this.mask = null;
		if(RenderSupportJSPixi.RendererType == "webgl") {
			this.mask = _$RenderSupportJSPixi_FlowContainer.getFirstGraphicsOrSprite(maskContainer);
			if(this.mask == null) maskContainer.visible = false;
		} else {
			this.alphaMask = null;
			var obj = maskContainer;
			while(obj.children != null && obj.children.length == 1) obj = obj.children[0];
			if((obj instanceof _$RenderSupportJSPixi_FlowGraphics)) this.mask = obj; else this.alphaMask = maskContainer;
		}
		if(this.mask != null) this.mask.once("removed",function() {
			_g.mask = null;
		});
		maskContainer.once("childrenchanged",function() {
			_g.setClipMask(maskContainer);
		});
		this.emit("graphicschanged");
	}
	,__class__: _$RenderSupportJSPixi_FlowGraphics
});
var _$RenderSupportJSPixi_FlowSprite = function(url,cache,metricsFn,errorFn,onlyDownload) {
	this.retries = 0;
	this.onlyDownload = false;
	this.cache = false;
	this.loaded = false;
	this.url = "";
	this.boundsHeight = 0.0;
	this.boundsWidth = 0.0;
	PIXI.Sprite.call(this);
	this.url = url;
	this.cache = cache;
	this.metricsFn = metricsFn;
	this.errorFn = errorFn;
	this.onlyDownload = onlyDownload;
	if(StringTools.endsWith(url,".swf")) url = StringTools.replace(url,".swf",".png");
	this.on("removed",$bind(this,this.onRemoved));
	this.on("added",$bind(this,this.onAdded));
	this.on("childrenchanged",$bind(this,this.onChildrenChanged));
	this.on("transformchanged",RenderSupportJSPixi.InvalidateStage);
	this.on("graphicschanged",RenderSupportJSPixi.InvalidateStage);
};
_$RenderSupportJSPixi_FlowSprite.__name__ = true;
_$RenderSupportJSPixi_FlowSprite.pushTextureToCache = function(texture) {
	if(texture != null && texture.baseTexture != null && texture.baseTexture.imageUrl != null) {
		var url = texture.baseTexture.imageUrl;
		if(url != null) {
			if(_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.exists(url)) {
				var value = _$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.get(url) + 1;
				_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.set(url,value);
			} else {
				_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.set(url,1);
				if(Lambda.count(_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls) > 50) {
					var $it0 = _$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.keys();
					while( $it0.hasNext() ) {
						var k = $it0.next();
						if(Lambda.count(_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls) > 50) {
							_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.remove(k);
							PIXI.Texture.removeFromCache(url);
							PIXI.BaseTexture.removeFromCache(url);
						} else return;
					}
				}
			}
		}
	}
};
_$RenderSupportJSPixi_FlowSprite.removeTextureFromCache = function(texture) {
	if(texture != null && texture.baseTexture != null && texture.baseTexture.imageUrl != null) {
		var url = texture.baseTexture.imageUrl;
		if(url != null) {
			if(_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.exists(url)) {
				if(_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.get(url) > 1 || texture.width * texture.height < 250000) {
					var value = _$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.get(url) - 1;
					_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.set(url,value);
				} else {
					_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls.remove(url);
					PIXI.Texture.removeFromCache(url);
					PIXI.BaseTexture.removeFromCache(url);
				}
			}
		}
	}
};
_$RenderSupportJSPixi_FlowSprite.__super__ = PIXI.Sprite;
_$RenderSupportJSPixi_FlowSprite.prototype = $extend(PIXI.Sprite.prototype,{
	onAdded: function() {
		var _g = this;
		if(!this.loaded) {
			if(StringTools.endsWith(this.url,".svg")) {
				var svgXhr = new XMLHttpRequest();
				if(!Platform.isIE && !Platform.isEdge) svgXhr.overrideMimeType("image/svg+xml");
				svgXhr.onload = function() {
					_g.url = "data:image/svg+xml;utf8," + Std.string(svgXhr.response);
					_g.loadTexture();
				};
				svgXhr.open("GET",this.url,true);
				svgXhr.send();
			} else this.loadTexture();
		}
	}
	,onRemoved: function() {
		if(this.loaded && this.texture != null) _$RenderSupportJSPixi_FlowSprite.removeTextureFromCache(this.texture);
		this.texture = PIXI.Texture.EMPTY;
	}
	,onChildrenChanged: function() {
		if(this.parent != null) this.parent.emit("childrenchanged");
	}
	,onDispose: function() {
		this.renderable = false;
		if(this.loaded && this.texture != null) _$RenderSupportJSPixi_FlowSprite.removeTextureFromCache(this.texture);
		this.loaded = false;
		if(this.parent != null) this.loadTexture(); else this.texture = PIXI.Texture.EMPTY;
		this.emit("graphicschanged");
	}
	,onError: function() {
		this.renderable = false;
		if(this.loaded && this.texture != null) _$RenderSupportJSPixi_FlowSprite.removeTextureFromCache(this.texture);
		this.loaded = false;
		this.texture = PIXI.Texture.EMPTY;
		this.errorFn("Can not load " + this.url);
	}
	,onLoaded: function() {
		try {
			this.metricsFn(this.texture.width,this.texture.height);
			this.emit("graphicschanged");
			this.renderable = true;
			this.loaded = true;
			_$RenderSupportJSPixi_FlowSprite.pushTextureToCache(this.texture);
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			if(this.parent != null && this.retries < 2) this.loadTexture(); else this.onError();
		}
	}
	,loadTexture: function() {
		this.retries++;
		this.texture = PIXI.Texture.fromImage(this.url,true);
		if(this.texture.baseTexture == null) this.onError(); else {
			if(this.texture.baseTexture.hasLoaded) this.onLoaded();
			this.texture.baseTexture.on("loaded",$bind(this,this.onLoaded));
			this.texture.baseTexture.on("error",$bind(this,this.onError));
			this.texture.baseTexture.on("dispose",$bind(this,this.onDispose));
		}
	}
	,addChild: function(child) {
		var addedChild = PIXI.Sprite.prototype.addChild.call(this,child);
		if(addedChild != null) {
			this.removeChildWidthHeight(addedChild);
			this.emit("childrenchanged");
		}
		return addedChild;
	}
	,addChildAt: function(child,index) {
		var addedChild = PIXI.Sprite.prototype.addChildAt.call(this,child,index);
		if(addedChild != null) {
			this.removeChildWidthHeight(addedChild);
			this.emit("childrenchanged");
		}
		return addedChild;
	}
	,removeChild: function(child) {
		var removedChild = PIXI.Sprite.prototype.removeChild.call(this,child);
		if(removedChild != null) {
			this.removeChildWidthHeight(removedChild);
			this.emit("childrenchanged");
		}
		return removedChild;
	}
	,removeChildWidthHeight: function(child) {
		this.removeWidthHeight(child.transform != null?child.x + child.boundsWidth * child.scale.x:child.boundsWidth,child.transform != null?child.y + child.boundsHeight * child.scale.y:child.boundsHeight);
	}
	,getWidthHeight: function() {
		return { width : this.boundsWidth, heigt : this.boundsHeight};
	}
	,getTransform: function() {
		return { x : this.x, y : this.y, scaleX : this.scale.x, scaleY : this.scale.y};
	}
	,removeWidthHeight: function(x,y,updateParent) {
		if(updateParent == null) updateParent = true;
		if(x == this.boundsWidth || y == this.boundsHeight) {
			var oldBoundsWidth = this.boundsWidth;
			var oldBoundsHeight = this.boundsHeight;
			this.recalculateWidthHeight(false);
			if(oldBoundsWidth != this.boundsWidth || oldBoundsHeight != this.boundsHeight) {
				if(updateParent) {
					this.emit("metricschanged");
					if(this.parent != null) this.parent.removeWidthHeight(this.x + oldBoundsWidth * this.scale.x,this.y + oldBoundsHeight * this.scale.y);
				}
			}
		}
	}
	,recalculateWidthHeight: function(updateParent) {
		if(updateParent == null) updateParent = true;
		this.boundsWidth = 0.0;
		this.boundsHeight = 0.0;
		var _g = 0;
		var _g1 = this.children;
		while(_g < _g1.length) {
			var c = _g1[_g];
			++_g;
			this.addWidthHeight(c.x + c.boundsWidth * c.scale.x,c.y + c.boundsHeight * c.scale.y,updateParent);
		}
	}
	,addWidthHeight: function(x,y,updateParent) {
		if(updateParent == null) updateParent = true;
		if(x > this.boundsWidth || y > this.boundsHeight) {
			this.boundsWidth = Math.max(this.boundsWidth,x);
			this.boundsHeight = Math.max(this.boundsHeight,y);
			if(updateParent) {
				this.emit("metricschanged");
				if(this.parent != null) this.parent.addWidthHeight(this.x + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * this.scale.y);
			}
		}
	}
	,setClipX: function(x) {
		if(this.x != x) {
			var previousX = this.x;
			this.x = x;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(previousX + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * this.scale.y);
		}
	}
	,setClipY: function(y) {
		if(this.y != y) {
			var previousY = this.y;
			this.y = y;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * this.scale.x,previousY + this.boundsHeight * this.scale.y);
		}
	}
	,setClipScaleX: function(scale) {
		if(this.scale.x != scale) {
			var previousScaleX = this.scale.x;
			this.scale.x = scale;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * previousScaleX,this.y + this.boundsHeight * this.scale.y);
		}
	}
	,setClipScaleY: function(scale) {
		if(this.scale.y != scale) {
			var previousScaleY = this.scale.y;
			this.scale.y = scale;
			this.emit("transformchanged");
			if(this.parent != null) this.parent.removeWidthHeight(this.x + this.boundsWidth * this.scale.x,this.y + this.boundsHeight * previousScaleY);
		}
	}
	,setClipRotation: function(rotation) {
		if(this.rotation != rotation) {
			this.rotation = rotation;
			this.emit("transformchanged");
		}
	}
	,setScrollRect: function(left,top,width,height) {
		if(this.scrollRect != null) {
			this.setClipX(this.x + this.scrollRect.x * 2 - left);
			this.setClipY(this.y + this.scrollRect.y * 2 - top);
			this.scrollRect.clear();
		} else {
			this.setClipX(this.x - left);
			this.setClipY(this.y - top);
			this.scrollRect = new _$RenderSupportJSPixi_FlowGraphics();
			this.addChild(this.scrollRect);
			this.setClipMask(this.scrollRect);
		}
		this.scrollRect.beginFill(16777215);
		this.scrollRect.drawRect(0.0,0.0,width,height);
		this.scrollRect.endFill();
		this.scrollRect.setClipX(left);
		this.scrollRect.setClipY(top);
	}
	,removeScrollRect: function() {
		if(this.scrollRect != null) {
			this.setClipX(this.x + this.scrollRect.x);
			this.setClipY(this.y + this.scrollRect.y);
			this.removeChild(this.scrollRect);
			this.scrollRect = null;
		}
	}
	,setClipMask: function(maskContainer) {
		var _g = this;
		if(maskContainer != this.scrollRect) this.removeScrollRect();
		this.mask = null;
		if(RenderSupportJSPixi.RendererType == "webgl") {
			this.mask = _$RenderSupportJSPixi_FlowContainer.getFirstGraphicsOrSprite(maskContainer);
			if(this.mask == null) maskContainer.visible = false;
		} else {
			this.alphaMask = null;
			var obj = maskContainer;
			while(obj.children != null && obj.children.length == 1) obj = obj.children[0];
			if((obj instanceof _$RenderSupportJSPixi_FlowGraphics)) this.mask = obj; else this.alphaMask = maskContainer;
		}
		if(this.mask != null) this.mask.once("removed",function() {
			_g.mask = null;
		});
		maskContainer.once("childrenchanged",function() {
			_g.setClipMask(maskContainer);
		});
		this.emit("graphicschanged");
	}
	,__class__: _$RenderSupportJSPixi_FlowSprite
});
var _$RenderSupportJSPixi_WebClip = function(url,domain,useCache,reloadBlock,cb,ondone,shrinkToFit) {
	this.shrinkToFit = null;
	this.htmlPageHeight = null;
	this.htmlPageWidth = null;
	this.disableOverlay = null;
	this.iframe = null;
	var _g = this;
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
	if(domain != "") try {
		window.document.domain = domain;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		Errors.report("Can not set RealHTML domain" + Std.string(e));
	}
	this.createNativeWidget("div");
	if(Platform.isIOS) {
		this.nativeWidget.style.webkitOverflowScrolling = "touch";
		this.nativeWidget.style.overflowY = "scroll";
	}
	this.shrinkToFit = shrinkToFit;
	this.iframe = window.document.createElement("iframe");
	this.iframe.src = url;
	this.iframe.allowFullscreen = true;
	this.iframe.frameBorder = "no";
	this.iframe.callflow = cb;
	this.nativeWidget.appendChild(this.iframe);
	if(reloadBlock) this.appendReloadBlock();
	this.iframe.onload = function() {
		try {
			if(shrinkToFit) try {
				_g.htmlPageWidth = _g.iframe.contentWindow.document.body.scrollWidth;
				_g.htmlPageHeight = _g.iframe.contentWindow.document.body.scrollHeight;
				_g.applyShrinkToFit();
			} catch( e1 ) {
				haxe_CallStack.lastException = e1;
				if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
				_g.shrinkToFit = false;
				Errors.report(e1);
				_g.applyNativeWidgetSize();
			}
			ondone("OK");
			if(Platform.isIOS && (url.indexOf("flowjs") >= 0 || url.indexOf("lslti_provider") >= 0)) _g.iframe.scrolling = "no";
			_g.iframe.contentWindow.callflow = cb;
			if(_g.iframe.contentWindow.pushCallflowBuffer) _g.iframe.contentWindow.pushCallflowBuffer();
			if(Platform.isIOS && _g.iframe.contentWindow.setSplashScreen != null) _g.iframe.scrolling = "no";
		} catch( e2 ) {
			haxe_CallStack.lastException = e2;
			if (e2 instanceof js__$Boot_HaxeError) e2 = e2.val;
			Errors.report(e2);
		}
	};
};
_$RenderSupportJSPixi_WebClip.__name__ = true;
_$RenderSupportJSPixi_WebClip.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_WebClip.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	appendReloadBlock: function() {
		var _g = this;
		var div = window.document.createElement("div");
		div.style.cssText = "z-index: 101; position: absolute; top: 0; left: 0; width: 100%; height: 20px; opacity: 0.6;";
		var img = window.document.createElement("img");
		img.style.cssText = "position: absolute; height: 20px; width: 20px; top: 0; right: 0; background: #BEBEBE;";
		img.src = "http://localhost/flow/images/lms_reload.png";
		div.appendChild(img);
		var span = window.document.createElement("span");
		span.style.cssText = "position: absolute; right: 25px; top: 0px; color: white; display: none;";
		span.innerHTML = "Reload the page";
		div.appendChild(span);
		img.onmouseover = function(e) {
			div.style.background = "linear-gradient(to bottom right, #36372F, #ACA9A4)";
			span.style.display = "block";
			img.style.background = "none";
		};
		img.onmouseleave = function(e1) {
			div.style.background = "none";
			span.style.display = "nonde";
			img.style.background = "#BEBEBE";
		};
		div.onclick = function(e2) {
			_g.iframe.src = _g.iframe.src;
		};
		this.nativeWidget.appendChild(div);
	}
	,applyShrinkToFit: function() {
		if(this.worldVisible && this.nativeWidget != null && this.iframe != null && this.shrinkToFit && this.htmlPageHeight != null && this.htmlPageWidth != null) {
			var scaleH = this.nativeWidget.clientHeight / this.htmlPageHeight;
			var scaleW = this.nativeWidget.clientWidth / this.htmlPageWidth;
			var scaleWH = Math.min(1.0,Math.min(scaleH,scaleW));
			this.iframe.border = "0";
			this.iframe.style.position = "relative";
			this.iframe.style["-ms-zoom"] = scaleWH;
			this.iframe.style["-moz-transform"] = "scale(" + scaleWH + ")";
			this.iframe.style["-moz-transform-origin"] = "0 0";
			this.iframe.style["-o-transform"] = "scale(" + scaleWH + ")";
			this.iframe.style["-o-transform-origin"] = "0 0";
			this.iframe.style["-webkit-transform"] = "scale(" + scaleWH + ")";
			this.iframe.style["-webkit-transform-origin"] = "0 0";
			this.iframe.style.transform = "scale(" + scaleWH + ")";
			this.iframe.style["transform-origin"] = "0 0";
			this.iframe.width = this.iframe.clientWidth = this.htmlPageWidth;
			this.iframe.height = this.iframe.clientHeight = this.htmlPageHeight;
			this.iframe.style.width = this.htmlPageWidth;
			this.iframe.style.height = this.htmlPageHeight;
		}
	}
	,applyNativeWidgetSize: function() {
		if(this.worldVisible && this.nativeWidget != null && this.iframe != null) {
			this.iframe.style.width = this.nativeWidget.style.width;
			this.iframe.style.height = this.nativeWidget.style.height;
		}
	}
	,updateNativeWidget: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this);
		if(this.nativeWidget != null && this.nativeWidget.getAttribute("tabindex") != null) {
			this.iframe.setAttribute("tabindex",this.nativeWidget.getAttribute("tabindex"));
			this.nativeWidget.removeAttribute("tabindex");
		}
		if(this.worldVisible && this.nativeWidget != null) {
			if(this.shrinkToFit) this.applyShrinkToFit(); else this.applyNativeWidgetSize();
			if(this.disableOverlay && this.disableOverlay.style.display == "block") {
				this.disableOverlay.style.width = this.nativeWidget.style.width;
				this.disableOverlay.style.height = this.nativeWidget.style.height;
			}
		}
	}
	,getDescription: function() {
		return "WebClip (url = " + Std.string(this.iframe.src) + ")";
	}
	,getWidth: function() {
		return 100.0;
	}
	,getHeight: function() {
		return 100.0;
	}
	,hostCall: function(name,args) {
		try {
			return this.iframe.contentWindow[name].apply(this.iframe.contentWindow,args);
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			Errors.report("Error in hostCall: " + name + ", arg: " + Std.string(args));
			Errors.report(e);
		}
		return "";
	}
	,setDisableOverlay: function(disable) {
		if(this.disableOverlay && !disable) this.nativeWidget.removeChild(this.disableOverlay); else if(disable) {
			if(!this.disableOverlay) {
				this.disableOverlay = window.document.createElement("div");
				this.disableOverlay.style.cssText = "z-index: 100; background-color: rgba(0, 0, 0, 0.15);";
			}
			this.disableOverlay.style.display = "block";
			this.nativeWidget.appendChild(this.disableOverlay);
		}
	}
	,setSandBox: function(value) {
		this.iframe.sandbox = value;
	}
	,evalJS: function(code) {
		if(this.iframe.contentWindow != null) this.iframe.contentWindow.postMessage(code,"*");
	}
	,__class__: _$RenderSupportJSPixi_WebClip
});
var FlowFontStyle = function() { };
FlowFontStyle.__name__ = true;
FlowFontStyle.fromFlowFont = function(name) {
	if(FlowFontStyle.flowFontStyles == null) {
		var styles = JSON.parse(haxe_Resource.getString("fontstyles"));
		FlowFontStyle.flowFontStyles = { };
		var _g = 0;
		var _g1 = Reflect.fields(styles);
		while(_g < _g1.length) {
			var fontname = _g1[_g];
			++_g;
			Reflect.setField(FlowFontStyle.flowFontStyles,fontname.toLowerCase(),Reflect.field(styles,fontname));
		}
	}
	var style = Reflect.field(FlowFontStyle.flowFontStyles,name.toLowerCase());
	if(style != null) return style; else return { family : name, weight : "", size : 0.0, style : "normal"};
};
var _$RenderSupportJSPixi_PixiText = function() {
	_$RenderSupportJSPixi_TextField.call(this);
};
_$RenderSupportJSPixi_PixiText.__name__ = true;
_$RenderSupportJSPixi_PixiText.__super__ = _$RenderSupportJSPixi_TextField;
_$RenderSupportJSPixi_PixiText.prototype = $extend(_$RenderSupportJSPixi_TextField.prototype,{
	setTextAndStyle: function(text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity) {
		var from_flow_style = FlowFontStyle.fromFlowFont(fontfamily);
		_$RenderSupportJSPixi_TextField.prototype.setTextAndStyle.call(this,text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity);
		this.style = { fontSize : fontsize < 0.6?0.6:fontsize, fill : "#" + StringTools.hex(fillcolor & 16777215,6), letterSpacing : letterspacing, fontFamily : from_flow_style.family, fontWeight : fontweight > 0?"" + fontweight:from_flow_style.weight, fontStyle : fontslope != ""?fontslope:from_flow_style.style, padding : fontfamily == "MS Gothic"?2:0};
		if(this.interlineSpacing != 0) this.style.lineHeight = fontsize * 1.1 + this.interlineSpacing;
		this.metrics = _$RenderSupportJSPixi_DFontText.getDFontInfo(fontfamily);
		if(this.metrics != null) {
			var pixi_font_metrics = { ascent : this.metrics.ascender * fontsize, descent : -this.metrics.descender * fontsize, fontSize : (this.metrics.ascender - this.metrics.descender) * fontsize};
			PIXI.Text.fontPropertiesCache[PIXI.Text.getFontStyle(this.style)] = pixi_font_metrics;
		}
		_$RenderSupportJSPixi_TextField.prototype.setTextAndStyle.call(this,text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity);
	}
	,layoutText: function() {
		this.removeScrollRect();
		var widthDelta = 0.0;
		var i = this.children.length;
		while(i >= 0) {
			this.removeChild(this.children[i]);
			i--;
		}
		var clip = this.makeTextClip(this.text,this.style);
		this.addChild(clip);
		if((this.style.align == "center" || this.style.align == "right") && this.fieldWidth > 0) {
			var textWd = this.getTextClipMetrics(clip).width;
			if(textWd < this.fieldWidth) {
				widthDelta = this.fieldWidth - textWd;
				if(this.style.align == "center") widthDelta = widthDelta / 2;
				clip.x += widthDelta;
			}
			this.clipWidth = Math.max(this.clipWidth,this.fieldWidth);
		}
		this.setTextBackground();
		this.setScrollRect(0,0,this.getWidth() + widthDelta,this.getHeight());
	}
	,setCropWords: function(cropWords) {
		this.cropWords = cropWords;
		this.style.breakWords = cropWords;
		this.updateNativeWidgetStyle();
	}
	,setWordWrap: function(wordWrap) {
		this.wordWrap = wordWrap;
		this.style.wordWrap = wordWrap;
		this.updateNativeWidgetStyle();
	}
	,setWidth: function(fieldWidth) {
		this.fieldWidth = fieldWidth;
		if(fieldWidth > 0) this.style.wordWrapWidth = fieldWidth; else this.style.wordWrapWidth = 2048;
		this.updateNativeWidgetStyle();
	}
	,setInterlineSpacing: function(interlineSpacing) {
		this.interlineSpacing = interlineSpacing;
		this.style.lineHeight = this.fontSize * 1.15 + interlineSpacing;
		this.updateNativeWidgetStyle();
	}
	,setAutoAlign: function(autoAlign) {
		this.autoAlign = autoAlign;
		if(autoAlign == "AutoAlignRight") this.style.align = "right"; else if(autoAlign == "AutoAlignCenter") this.style.align = "center"; else this.style.align = "left";
		this.updateNativeWidgetStyle();
	}
	,makeTextClip: function(text,style) {
		var pixi_text = new PIXI.Text("");
		if(Platform.isChrome || Platform.isSafari) {
			pixi_text.canvas.style.webkitFontSmoothing = "antialiased";
			pixi_text.canvas.style.display = "none";
			window.document.body.appendChild(pixi_text.canvas);
		}
		pixi_text.text = text;
		pixi_text.style = style;
		pixi_text.alpha = this.fillOpacity;
		if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) pixi_text.cacheAsBitmap = true;
		return pixi_text;
	}
	,getTextClipMetrics: function(clip) {
		return PIXI.TextMetrics.measureText(clip.text,clip.style);
	}
	,__class__: _$RenderSupportJSPixi_PixiText
});
var _$RenderSupportJSPixi_DFontText = function() {
	_$RenderSupportJSPixi_TextField.call(this);
};
_$RenderSupportJSPixi_DFontText.__name__ = true;
_$RenderSupportJSPixi_DFontText.getDFontInfo = function(fontfamily) {
	return DFontText.dfont_table[fontfamily];
};
_$RenderSupportJSPixi_DFontText.getFirstDFontFamily = function() {
	return Object.keys(DFontText.dfont_table)[0];
};
_$RenderSupportJSPixi_DFontText.__super__ = _$RenderSupportJSPixi_TextField;
_$RenderSupportJSPixi_DFontText.prototype = $extend(_$RenderSupportJSPixi_TextField.prototype,{
	setTextAndStyle: function(text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity) {
		if(Platform.isFirefox && text.length * fontsize > 32765.0) {
			var len = Math.floor(32765.0 / fontsize);
			text = HxOverrides.substr(text,0,len);
		}
		if(_$RenderSupportJSPixi_DFontText.getDFontInfo(fontfamily) == null) {
			var defaultFontFamily = _$RenderSupportJSPixi_DFontText.getFirstDFontFamily();
			var met = _$RenderSupportJSPixi_DFontText.getDFontInfo(defaultFontFamily);
			if(met != null) {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded. Will use default font");
				DFontText.dfont_table[fontfamily] = met;
				fontfamily = defaultFontFamily;
			} else {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded yet. Default font is not loaded yet too");
				return;
			}
		}
		this.metrics = _$RenderSupportJSPixi_DFontText.getDFontInfo(fontfamily);
		this.style.font = fontsize + "px " + fontfamily;
		if(fillcolor != 0) this.style.tint = fillcolor; else this.style.tint = 65793;
		this.style.letterSpacing = letterspacing;
		_$RenderSupportJSPixi_TextField.prototype.setTextAndStyle.call(this,text,fontfamily,fontsize,fontweight,fontslope,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity);
	}
	,makeTextClip: function(text,style) {
		var clip = new DFontText(text,style);
		clip.resolution = RenderSupportJSPixi.PixiRenderer.resolution;
		clip.on("resize",function(ratio) {
			clip.resolution = ratio;
		});
		clip.alpha = this.fillOpacity;
		if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) clip.cacheAsBitmap = true;
		return clip;
	}
	,getTextClipMetrics: function(clip) {
		return clip.getTextDimensions();
	}
	,getTextMetrics: function() {
		if(this.metrics == null) return _$RenderSupportJSPixi_TextField.prototype.getTextMetrics.call(this); else return [(this.metrics.line_height + this.metrics.descender) * this.fontSize,this.metrics.descender * this.fontSize,0.15 * this.fontSize];
	}
	,getWidth: function() {
		if(this.fieldWidth > 0.0 && this.isInput()) return this.fieldWidth; else return this.clipWidth;
	}
	,getHeight: function() {
		if(this.fieldHeight > 0.0 && this.isInput()) return this.fieldHeight; else return this.clipHeight;
	}
	,__class__: _$RenderSupportJSPixi_DFontText
});
var _$RenderSupportJSPixi_Shaders = function() { };
_$RenderSupportJSPixi_Shaders.__name__ = true;
var haxe_IMap = function() { };
haxe_IMap.__name__ = true;
var haxe_ds_IntMap = function() {
	this.h = { };
};
haxe_ds_IntMap.__name__ = true;
haxe_ds_IntMap.__interfaces__ = [haxe_IMap];
haxe_ds_IntMap.prototype = {
	get: function(key) {
		return this.h[key];
	}
	,__class__: haxe_ds_IntMap
};
var haxe_ds_StringMap = function() {
	this.h = { };
};
haxe_ds_StringMap.__name__ = true;
haxe_ds_StringMap.__interfaces__ = [haxe_IMap];
haxe_ds_StringMap.prototype = {
	set: function(key,value) {
		if(__map_reserved[key] != null) this.setReserved(key,value); else this.h[key] = value;
	}
	,get: function(key) {
		if(__map_reserved[key] != null) return this.getReserved(key);
		return this.h[key];
	}
	,exists: function(key) {
		if(__map_reserved[key] != null) return this.existsReserved(key);
		return this.h.hasOwnProperty(key);
	}
	,setReserved: function(key,value) {
		if(this.rh == null) this.rh = { };
		this.rh["$" + key] = value;
	}
	,getReserved: function(key) {
		if(this.rh == null) return null; else return this.rh["$" + key];
	}
	,existsReserved: function(key) {
		if(this.rh == null) return false;
		return this.rh.hasOwnProperty("$" + key);
	}
	,remove: function(key) {
		if(__map_reserved[key] != null) {
			key = "$" + key;
			if(this.rh == null || !this.rh.hasOwnProperty(key)) return false;
			delete(this.rh[key]);
			return true;
		} else {
			if(!this.h.hasOwnProperty(key)) return false;
			delete(this.h[key]);
			return true;
		}
	}
	,keys: function() {
		var _this = this.arrayKeys();
		return HxOverrides.iter(_this);
	}
	,arrayKeys: function() {
		var out = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) out.push(key);
		}
		if(this.rh != null) {
			for( var key in this.rh ) {
			if(key.charCodeAt(0) == 36) out.push(key.substr(1));
			}
		}
		return out;
	}
	,iterator: function() {
		return new haxe_ds__$StringMap_StringMapIterator(this,this.arrayKeys());
	}
	,__class__: haxe_ds_StringMap
};
var RendersupportpixiFlowJsProgram = function() { };
RendersupportpixiFlowJsProgram.__name__ = true;
var Type = function() { };
Type.__name__ = true;
Type.getClass = function(o) {
	if(o == null) return null; else return js_Boot.getClass(o);
};
var haxe_StackItem = { __ename__ : true, __constructs__ : ["CFunction","Module","FilePos","Method","LocalFunction"] };
haxe_StackItem.CFunction = ["CFunction",0];
haxe_StackItem.CFunction.toString = $estr;
haxe_StackItem.CFunction.__enum__ = haxe_StackItem;
haxe_StackItem.Module = function(m) { var $x = ["Module",1,m]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
haxe_StackItem.FilePos = function(s,file,line) { var $x = ["FilePos",2,s,file,line]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
haxe_StackItem.Method = function(classname,method) { var $x = ["Method",3,classname,method]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
haxe_StackItem.LocalFunction = function(v) { var $x = ["LocalFunction",4,v]; $x.__enum__ = haxe_StackItem; $x.toString = $estr; return $x; };
var haxe_CallStack = function() { };
haxe_CallStack.__name__ = true;
haxe_CallStack.getStack = function(e) {
	if(e == null) return [];
	var oldValue = Error.prepareStackTrace;
	Error.prepareStackTrace = function(error,callsites) {
		var stack = [];
		var _g = 0;
		while(_g < callsites.length) {
			var site = callsites[_g];
			++_g;
			if(haxe_CallStack.wrapCallSite != null) site = haxe_CallStack.wrapCallSite(site);
			var method = null;
			var fullName = site.getFunctionName();
			if(fullName != null) {
				var idx = fullName.lastIndexOf(".");
				if(idx >= 0) {
					var className = HxOverrides.substr(fullName,0,idx);
					var methodName = HxOverrides.substr(fullName,idx + 1,null);
					method = haxe_StackItem.Method(className,methodName);
				}
			}
			stack.push(haxe_StackItem.FilePos(method,site.getFileName(),site.getLineNumber()));
		}
		return stack;
	};
	var a = haxe_CallStack.makeStack(e.stack);
	Error.prepareStackTrace = oldValue;
	return a;
};
haxe_CallStack.callStack = function() {
	try {
		throw new Error();
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		var a = haxe_CallStack.getStack(e);
		a.shift();
		return a;
	}
};
haxe_CallStack.exceptionStack = function() {
	return haxe_CallStack.getStack(haxe_CallStack.lastException);
};
haxe_CallStack.toString = function(stack) {
	var b = new StringBuf();
	var _g = 0;
	while(_g < stack.length) {
		var s = stack[_g];
		++_g;
		b.b += "\nCalled from ";
		haxe_CallStack.itemToString(b,s);
	}
	return b.b;
};
haxe_CallStack.itemToString = function(b,s) {
	switch(s[1]) {
	case 0:
		b.b += "a C function";
		break;
	case 1:
		var m = s[2];
		b.b += "module ";
		if(m == null) b.b += "null"; else b.b += "" + m;
		break;
	case 2:
		var line = s[4];
		var file = s[3];
		var s1 = s[2];
		if(s1 != null) {
			haxe_CallStack.itemToString(b,s1);
			b.b += " (";
		}
		if(file == null) b.b += "null"; else b.b += "" + file;
		b.b += " line ";
		if(line == null) b.b += "null"; else b.b += "" + line;
		if(s1 != null) b.b += ")";
		break;
	case 3:
		var meth = s[3];
		var cname = s[2];
		if(cname == null) b.b += "null"; else b.b += "" + cname;
		b.b += ".";
		if(meth == null) b.b += "null"; else b.b += "" + meth;
		break;
	case 4:
		var n = s[2];
		b.b += "local function #";
		if(n == null) b.b += "null"; else b.b += "" + n;
		break;
	}
};
haxe_CallStack.makeStack = function(s) {
	if(s == null) return []; else if(typeof(s) == "string") {
		var stack = s.split("\n");
		if(stack[0] == "Error") stack.shift();
		var m = [];
		var rie10 = new EReg("^   at ([A-Za-z0-9_. ]+) \\(([^)]+):([0-9]+):([0-9]+)\\)$","");
		var _g = 0;
		while(_g < stack.length) {
			var line = stack[_g];
			++_g;
			if(rie10.match(line)) {
				var path = rie10.matched(1).split(".");
				var meth = path.pop();
				var file = rie10.matched(2);
				var line1 = Std.parseInt(rie10.matched(3));
				m.push(haxe_StackItem.FilePos(meth == "Anonymous function"?haxe_StackItem.LocalFunction():meth == "Global code"?null:haxe_StackItem.Method(path.join("."),meth),file,line1));
			} else m.push(haxe_StackItem.Module(StringTools.trim(line)));
		}
		return m;
	} else return s;
};
var haxe__$Int64__$_$_$Int64 = function(high,low) {
	this.high = high;
	this.low = low;
};
haxe__$Int64__$_$_$Int64.__name__ = true;
haxe__$Int64__$_$_$Int64.prototype = {
	__class__: haxe__$Int64__$_$_$Int64
};
var haxe_ds__$StringMap_StringMapIterator = function(map,keys) {
	this.map = map;
	this.keys = keys;
	this.index = 0;
	this.count = keys.length;
};
haxe_ds__$StringMap_StringMapIterator.__name__ = true;
haxe_ds__$StringMap_StringMapIterator.prototype = {
	hasNext: function() {
		return this.index < this.count;
	}
	,next: function() {
		return this.map.get(this.keys[this.index++]);
	}
	,__class__: haxe_ds__$StringMap_StringMapIterator
};
var haxe_io_BytesBuffer = function() {
	this.b = [];
};
haxe_io_BytesBuffer.__name__ = true;
haxe_io_BytesBuffer.prototype = {
	addBytes: function(src,pos,len) {
		if(pos < 0 || len < 0 || pos + len > src.length) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = pos;
		var _g = pos + len;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,getBytes: function() {
		var bytes = new haxe_io_Bytes(new Uint8Array(this.b).buffer);
		this.b = null;
		return bytes;
	}
	,__class__: haxe_io_BytesBuffer
};
var haxe_io_Output = function() { };
haxe_io_Output.__name__ = true;
haxe_io_Output.prototype = {
	writeByte: function(c) {
		throw new js__$Boot_HaxeError("Not implemented");
	}
	,writeBytes: function(s,pos,len) {
		var k = len;
		var b = s.b.bufferValue;
		if(pos < 0 || len < 0 || pos + len > s.length) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
		while(k > 0) {
			this.writeByte(b[pos]);
			pos++;
			k--;
		}
		return len;
	}
	,writeFullBytes: function(s,pos,len) {
		while(len > 0) {
			var k = this.writeBytes(s,pos,len);
			pos += k;
			len -= k;
		}
	}
	,writeString: function(s) {
		var b = haxe_io_Bytes.ofString(s);
		this.writeFullBytes(b,0,b.length);
	}
	,__class__: haxe_io_Output
};
var haxe_io_BytesOutput = function() {
	this.b = new haxe_io_BytesBuffer();
};
haxe_io_BytesOutput.__name__ = true;
haxe_io_BytesOutput.__super__ = haxe_io_Output;
haxe_io_BytesOutput.prototype = $extend(haxe_io_Output.prototype,{
	writeByte: function(c) {
		this.b.b.push(c);
	}
	,writeBytes: function(buf,pos,len) {
		this.b.addBytes(buf,pos,len);
		return len;
	}
	,getBytes: function() {
		return this.b.getBytes();
	}
	,__class__: haxe_io_BytesOutput
});
var haxe_io_Eof = function() { };
haxe_io_Eof.__name__ = true;
haxe_io_Eof.prototype = {
	toString: function() {
		return "Eof";
	}
	,__class__: haxe_io_Eof
};
var haxe_io_Error = { __ename__ : true, __constructs__ : ["Blocked","Overflow","OutsideBounds","Custom"] };
haxe_io_Error.Blocked = ["Blocked",0];
haxe_io_Error.Blocked.toString = $estr;
haxe_io_Error.Blocked.__enum__ = haxe_io_Error;
haxe_io_Error.Overflow = ["Overflow",1];
haxe_io_Error.Overflow.toString = $estr;
haxe_io_Error.Overflow.__enum__ = haxe_io_Error;
haxe_io_Error.OutsideBounds = ["OutsideBounds",2];
haxe_io_Error.OutsideBounds.toString = $estr;
haxe_io_Error.OutsideBounds.__enum__ = haxe_io_Error;
haxe_io_Error.Custom = function(e) { var $x = ["Custom",3,e]; $x.__enum__ = haxe_io_Error; $x.toString = $estr; return $x; };
var haxe_io_FPHelper = function() { };
haxe_io_FPHelper.__name__ = true;
haxe_io_FPHelper.i32ToFloat = function(i) {
	var sign = 1 - (i >>> 31 << 1);
	var exp = i >>> 23 & 255;
	var sig = i & 8388607;
	if(sig == 0 && exp == 0) return 0.0;
	return sign * (1 + Math.pow(2,-23) * sig) * Math.pow(2,exp - 127);
};
haxe_io_FPHelper.floatToI32 = function(f) {
	if(f == 0) return 0;
	var af;
	if(f < 0) af = -f; else af = f;
	var exp = Math.floor(Math.log(af) / 0.6931471805599453);
	if(exp < -127) exp = -127; else if(exp > 128) exp = 128;
	var sig = Math.round((af / Math.pow(2,exp) - 1) * 8388608) & 8388607;
	return (f < 0?-2147483648:0) | exp + 127 << 23 | sig;
};
haxe_io_FPHelper.i64ToDouble = function(low,high) {
	var sign = 1 - (high >>> 31 << 1);
	var exp = (high >> 20 & 2047) - 1023;
	var sig = (high & 1048575) * 4294967296. + (low >>> 31) * 2147483648. + (low & 2147483647);
	if(sig == 0 && exp == -1023) return 0.0;
	return sign * (1.0 + Math.pow(2,-52) * sig) * Math.pow(2,exp);
};
haxe_io_FPHelper.doubleToI64 = function(v) {
	var i64 = haxe_io_FPHelper.i64tmp;
	if(v == 0) {
		i64.low = 0;
		i64.high = 0;
	} else {
		var av;
		if(v < 0) av = -v; else av = v;
		var exp = Math.floor(Math.log(av) / 0.6931471805599453);
		var sig;
		var v1 = (av / Math.pow(2,exp) - 1) * 4503599627370496.;
		sig = Math.round(v1);
		var sig_l = sig | 0;
		var sig_h = sig / 4294967296.0 | 0;
		i64.low = sig_l;
		i64.high = (v < 0?-2147483648:0) | exp + 1023 << 20 | sig_h;
	}
	return i64;
};
var js_BinaryBuffer = function(bigEndian,buffer) {
	this.bigEndian = bigEndian;
	this.buffer = [];
	this.setBuffer(buffer);
};
js_BinaryBuffer.__name__ = true;
js_BinaryBuffer.prototype = {
	readBits: function(start,length) {
		//shl fix: Henri Torgemane ~1996 (compressed by Jonas Raoni)
			    function shl(a, b){
				for(++b; --b; a = ((a %= 0x7fffffff + 1) & 0x40000000) == 0x40000000 ? a * 2 : (a - 0x40000000) * 2 + 0x7fffffff + 1);
				return a;
			    }
			    if(start < 0 || length <= 0)
				return 0;
			    this.checkBuffer(start + length);
			    for(var offsetLeft, offsetRight = start % 8, curByte = this.buffer.length - (start >> 3) - 1,
				lastByte = this.buffer.length + (-(start + length) >> 3), diff = curByte - lastByte,
				sum = ((this.buffer[ curByte ] >> offsetRight) & ((1 << (diff ? 8 - offsetRight : length)) - 1))
				+ (diff && (offsetLeft = (start + length) % 8) ? (this.buffer[ lastByte++ ] & ((1 << offsetLeft) - 1))
				<< (diff-- << 3) - offsetRight : 0); diff; sum += shl(this.buffer[ lastByte++ ], (diff-- << 3) - offsetRight)
			    );
			    return sum;
		;
	}
	,setBuffer: function(data) {
		if(data){
			for(var l, i = l = data.length, b = this.buffer = new Array(l); i; b[l - i] = data.charCodeAt(--i));
			this.bigEndian && b.reverse();
		    }
	}
	,hasNeededBits: function(neededBits) {
		return this.buffer.length >= -(-neededBits >> 3);
	}
	,checkBuffer: function(neededBits) {
		if(!this.hasNeededBits(neededBits)) {
			throw new Error("checkBuffer::missing bytes");;
		}
	}
	,__class__: js_BinaryBuffer
};
var js__$Boot_HaxeError = function(val) {
	Error.call(this);
	this.val = val;
	this.message = String(val);
	if(Error.captureStackTrace) Error.captureStackTrace(this,js__$Boot_HaxeError);
};
js__$Boot_HaxeError.__name__ = true;
js__$Boot_HaxeError.__super__ = Error;
js__$Boot_HaxeError.prototype = $extend(Error.prototype,{
	__class__: js__$Boot_HaxeError
});
var js_html_compat_ArrayBuffer = function(a) {
	if((a instanceof Array) && a.__enum__ == null) {
		this.a = a;
		this.byteLength = a.length;
	} else {
		var len = a;
		this.a = [];
		var _g = 0;
		while(_g < len) {
			var i = _g++;
			this.a[i] = 0;
		}
		this.byteLength = len;
	}
};
js_html_compat_ArrayBuffer.__name__ = true;
js_html_compat_ArrayBuffer.sliceImpl = function(begin,end) {
	var u = new Uint8Array(this,begin,end == null?null:end - begin);
	var result = new ArrayBuffer(u.byteLength);
	var resultArray = new Uint8Array(result);
	resultArray.set(u);
	return result;
};
js_html_compat_ArrayBuffer.prototype = {
	slice: function(begin,end) {
		return new js_html_compat_ArrayBuffer(this.a.slice(begin,end));
	}
	,__class__: js_html_compat_ArrayBuffer
};
var js_html_compat_DataView = function(buffer,byteOffset,byteLength) {
	this.buf = buffer;
	if(byteOffset == null) this.offset = 0; else this.offset = byteOffset;
	if(byteLength == null) this.length = buffer.byteLength - this.offset; else this.length = byteLength;
	if(this.offset < 0 || this.length < 0 || this.offset + this.length > buffer.byteLength) throw new js__$Boot_HaxeError(haxe_io_Error.OutsideBounds);
};
js_html_compat_DataView.__name__ = true;
js_html_compat_DataView.prototype = {
	getInt8: function(byteOffset) {
		var v = this.buf.a[this.offset + byteOffset];
		if(v >= 128) return v - 256; else return v;
	}
	,getUint8: function(byteOffset) {
		return this.buf.a[this.offset + byteOffset];
	}
	,getInt16: function(byteOffset,littleEndian) {
		var v = this.getUint16(byteOffset,littleEndian);
		if(v >= 32768) return v - 65536; else return v;
	}
	,getUint16: function(byteOffset,littleEndian) {
		if(littleEndian) return this.buf.a[this.offset + byteOffset] | this.buf.a[this.offset + byteOffset + 1] << 8; else return this.buf.a[this.offset + byteOffset] << 8 | this.buf.a[this.offset + byteOffset + 1];
	}
	,getInt32: function(byteOffset,littleEndian) {
		var p = this.offset + byteOffset;
		var a = this.buf.a[p++];
		var b = this.buf.a[p++];
		var c = this.buf.a[p++];
		var d = this.buf.a[p++];
		if(littleEndian) return a | b << 8 | c << 16 | d << 24; else return d | c << 8 | b << 16 | a << 24;
	}
	,getUint32: function(byteOffset,littleEndian) {
		var v = this.getInt32(byteOffset,littleEndian);
		if(v < 0) return v + 4294967296.; else return v;
	}
	,getFloat32: function(byteOffset,littleEndian) {
		return haxe_io_FPHelper.i32ToFloat(this.getInt32(byteOffset,littleEndian));
	}
	,getFloat64: function(byteOffset,littleEndian) {
		var a = this.getInt32(byteOffset,littleEndian);
		var b = this.getInt32(byteOffset + 4,littleEndian);
		return haxe_io_FPHelper.i64ToDouble(littleEndian?a:b,littleEndian?b:a);
	}
	,setInt8: function(byteOffset,value) {
		if(value < 0) this.buf.a[byteOffset + this.offset] = value + 128 & 255; else this.buf.a[byteOffset + this.offset] = value & 255;
	}
	,setUint8: function(byteOffset,value) {
		this.buf.a[byteOffset + this.offset] = value & 255;
	}
	,setInt16: function(byteOffset,value,littleEndian) {
		this.setUint16(byteOffset,value < 0?value + 65536:value,littleEndian);
	}
	,setUint16: function(byteOffset,value,littleEndian) {
		var p = byteOffset + this.offset;
		if(littleEndian) {
			this.buf.a[p] = value & 255;
			this.buf.a[p++] = value >> 8 & 255;
		} else {
			this.buf.a[p++] = value >> 8 & 255;
			this.buf.a[p] = value & 255;
		}
	}
	,setInt32: function(byteOffset,value,littleEndian) {
		this.setUint32(byteOffset,value,littleEndian);
	}
	,setUint32: function(byteOffset,value,littleEndian) {
		var p = byteOffset + this.offset;
		if(littleEndian) {
			this.buf.a[p++] = value & 255;
			this.buf.a[p++] = value >> 8 & 255;
			this.buf.a[p++] = value >> 16 & 255;
			this.buf.a[p++] = value >>> 24;
		} else {
			this.buf.a[p++] = value >>> 24;
			this.buf.a[p++] = value >> 16 & 255;
			this.buf.a[p++] = value >> 8 & 255;
			this.buf.a[p++] = value & 255;
		}
	}
	,setFloat32: function(byteOffset,value,littleEndian) {
		this.setUint32(byteOffset,haxe_io_FPHelper.floatToI32(value),littleEndian);
	}
	,setFloat64: function(byteOffset,value,littleEndian) {
		var i64 = haxe_io_FPHelper.doubleToI64(value);
		if(littleEndian) {
			this.setUint32(byteOffset,i64.low);
			this.setUint32(byteOffset,i64.high);
		} else {
			this.setUint32(byteOffset,i64.high);
			this.setUint32(byteOffset,i64.low);
		}
	}
	,__class__: js_html_compat_DataView
};
var js_html_compat_Uint8Array = function() { };
js_html_compat_Uint8Array.__name__ = true;
js_html_compat_Uint8Array._new = function(arg1,offset,length) {
	var arr;
	if(typeof(arg1) == "number") {
		arr = [];
		var _g = 0;
		while(_g < arg1) {
			var i = _g++;
			arr[i] = 0;
		}
		arr.byteLength = arr.length;
		arr.byteOffset = 0;
		arr.buffer = new js_html_compat_ArrayBuffer(arr);
	} else if(js_Boot.__instanceof(arg1,js_html_compat_ArrayBuffer)) {
		var buffer = arg1;
		if(offset == null) offset = 0;
		if(length == null) length = buffer.byteLength - offset;
		if(offset == 0) arr = buffer.a; else arr = buffer.a.slice(offset,offset + length);
		arr.byteLength = arr.length;
		arr.byteOffset = offset;
		arr.buffer = buffer;
	} else if((arg1 instanceof Array) && arg1.__enum__ == null) {
		arr = arg1.slice();
		arr.byteLength = arr.length;
		arr.byteOffset = 0;
		arr.buffer = new js_html_compat_ArrayBuffer(arr);
	} else throw new js__$Boot_HaxeError("TODO " + Std.string(arg1));
	arr.subarray = js_html_compat_Uint8Array._subarray;
	arr.set = js_html_compat_Uint8Array._set;
	return arr;
};
js_html_compat_Uint8Array._set = function(arg,offset) {
	var t = this;
	if(js_Boot.__instanceof(arg.buffer,js_html_compat_ArrayBuffer)) {
		var a = arg;
		if(arg.byteLength + offset > t.byteLength) throw new js__$Boot_HaxeError("set() outside of range");
		var _g1 = 0;
		var _g = arg.byteLength;
		while(_g1 < _g) {
			var i = _g1++;
			t[i + offset] = a[i];
		}
	} else if((arg instanceof Array) && arg.__enum__ == null) {
		var a1 = arg;
		if(a1.length + offset > t.byteLength) throw new js__$Boot_HaxeError("set() outside of range");
		var _g11 = 0;
		var _g2 = a1.length;
		while(_g11 < _g2) {
			var i1 = _g11++;
			t[i1 + offset] = a1[i1];
		}
	} else throw new js__$Boot_HaxeError("TODO");
};
js_html_compat_Uint8Array._subarray = function(start,end) {
	var t = this;
	var a = js_html_compat_Uint8Array._new(t.slice(start,end));
	a.byteOffset = start;
	return a;
};
function $iterator(o) { if( o instanceof Array ) return function() { return HxOverrides.iter(o); }; return typeof(o.iterator) == 'function' ? $bind(o,o.iterator) : o.iterator; }
var $_, $fid = 0;
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $fid++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = function(){ return f.method.apply(f.scope, arguments); }; f.scope = o; f.method = m; o.hx__closures__[m.__id__] = f; } return f; }
if(Array.prototype.indexOf) HxOverrides.indexOf = function(a,o,i) {
	return Array.prototype.indexOf.call(a,o,i);
};
NativeHx.initBinarySerialization();
haxe_Resource.content = [{ name : "dfonts", data : "W3sibmFtZSI6IkJvb2sifSx7Im5hbWUiOiJJdGFsaWMifSx7Im5hbWUiOiJEZW1pIn0seyJuYW1lIjoiTWVkaXVtIn0seyJuYW1lIjoiTWVkaXVtSXRhbGljIn0seyJuYW1lIjoiQ29uZGVuc2VkIn0seyJuYW1lIjoiRGVqYVZ1U2FucyJ9LHsibmFtZSI6IkRlamFWdVNhbnNPYmxpcXVlIn0seyJuYW1lIjoiRGVqYVZ1U2VyaWYifSx7Im5hbWUiOiJGZWx0VGlwUm9tYW4ifSx7Im5hbWUiOiJNaW5pb24ifSx7Im5hbWUiOiJNaW5pb25JdGFsaWNzIn0seyJuYW1lIjoiTUhFZWxlbXNhbnNSZWd1bGFyIn0seyJuYW1lIjoiTm90b1NhbnNNaW5pbWFsIn0seyJuYW1lIjoiUHJveGltYVNlbWlCb2xkIn0seyJuYW1lIjoiUHJveGltYUV4dHJhQm9sZCJ9LHsibmFtZSI6IlByb3hpbWFTZW1pSXRhbGljIn0seyJuYW1lIjoiUHJveGltYUV4dHJhSXRhbGljIn0seyJuYW1lIjoiR290aGFtQm9sZCJ9LHsibmFtZSI6IkdvdGhhbUJvb2sifSx7Im5hbWUiOiJHb3RoYW1Cb29rSXRhbGljIn0seyJuYW1lIjoiR290aGFtSFRGQm9vayJ9XQ"},{ name : "fontstyles", data : "eyJib29rIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy11cnciLCJ3ZWlnaHQiOjQwMCwic3R5bGUiOiJub3JtYWwifSwiZGVtaSI6eyJmYW1pbHkiOiJmcmFua2xpbi1nb3RoaWMtdXJ3Iiwid2VpZ2h0Ijo3MDAsInN0eWxlIjoibm9ybWFsIn0sInByb3hpbWFleHRyYWJvbGQiOnsiZmFtaWx5IjoicHJveGltYS1ub3ZhIiwid2VpZ2h0Ijo3MDAsInN0eWxlIjoibm9ybWFsIn0sInByb3hpbWFzZW1pYm9sZCI6eyJmYW1pbHkiOiJwcm94aW1hLW5vdmEiLCJ3ZWlnaHQiOjYwMCwic3R5bGUiOiJub3JtYWwifSwibWVkaXVtIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy11cnciLCJ3ZWlnaHQiOjUwMCwic3R5bGUiOiJub3JtYWwifSwibWluaW9uaXRhbGljcyI6eyJmYW1pbHkiOiJtaW5pb24tcHJvIiwid2VpZ2h0Ijo0MDAsInN0eWxlIjoiaXRhbGljIn0sIml0YWxpYyI6eyJmYW1pbHkiOiJmcmFua2xpbi1nb3RoaWMtdXJ3Iiwid2VpZ2h0Ijo0MDAsInN0eWxlIjoibm9ybWFsIn0sImRlamF2dXNhbnMiOnsiZmFtaWx5IjoidmVyYS1zYW5zIiwic3R5bGUiOiJub3JtYWwifSwiY29uZGVuc2VkIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy1leHQtY29tcC11cnciLCJ3ZWlnaHQiOjcwMCwic3R5bGUiOiJub3JtYWwifX0"},{ name : "webfontconfig", data : "eyJ0eXBla2l0Ijp7ImlkIjoiaGZ6NnVmeiJ9fQ"}];
String.prototype.__class__ = String;
String.__name__ = true;
Array.__name__ = true;
Date.prototype.__class__ = Date;
Date.__name__ = ["Date"];
var Int = { __name__ : ["Int"]};
var Dynamic = { __name__ : ["Dynamic"]};
var Float = Number;
Float.__name__ = ["Float"];
var Bool = Boolean;
Bool.__ename__ = ["Bool"];
var Class = { __name__ : ["Class"]};
var Enum = { };
if(Array.prototype.filter == null) Array.prototype.filter = function(f1) {
	var a1 = [];
	var _g11 = 0;
	var _g2 = this.length;
	while(_g11 < _g2) {
		var i1 = _g11++;
		var e = this[i1];
		if(f1(e)) a1.push(e);
	}
	return a1;
};
if(Util.getParameter("oldjs") == "1") RenderSupportHx.oldinit(); else {
	window.RenderSupportHx = window.RenderSupportJSPixi;
}
var __map_reserved = {}
var ArrayBuffer = $global.ArrayBuffer || js_html_compat_ArrayBuffer;
if(ArrayBuffer.prototype.slice == null) ArrayBuffer.prototype.slice = js_html_compat_ArrayBuffer.sliceImpl;
var DataView = $global.DataView || js_html_compat_DataView;
var Uint8Array = $global.Uint8Array || js_html_compat_Uint8Array._new;
JSBinflowBuffer.DoubleSwapBuffer = new DataView(new ArrayBuffer(8));
Md5.inst = new Md5();
Platform.isAndroid = new EReg("android","i").match(window.navigator.userAgent);
Platform.isIEMobile = new EReg("iemobile","i").match(window.navigator.userAgent);
Platform.isChrome = new EReg("chrome|crios","i").match(window.navigator.userAgent);
Platform.isSafari = new EReg("safari","i").match(window.navigator.userAgent);
Platform.isIOS = new EReg("ipad|iphone|ipod","i").match(window.navigator.userAgent);
Platform.isIE = new EReg("MSIE|Trident","i").match(window.navigator.userAgent);
Platform.isEdge = new EReg("Edge","i").match(window.navigator.userAgent);
Platform.isFirefox = new EReg("firefox","i").match(window.navigator.userAgent);
Platform.isMobile = new EReg("webOS|BlackBerry|Windows Phone","i").match(window.navigator.userAgent) || Platform.isIEMobile || Platform.isAndroid || Platform.isIOS;
Platform.isMacintosh = new EReg("Mac","i").match(window.navigator.platform);
Platform.isWindows = new EReg("Win","i").match(window.navigator.platform);
Platform.isLinux = new EReg("Linux","i").match(window.navigator.platform);
Platform.SupportsVideoTexture = !Platform.isIEMobile;
Platform.AccessiblityAllowed = (Platform.isFirefox || Platform.isChrome) && !Platform.isMobile && !Platform.isEdge;
NativeHx.complainedMissingExternal = false;
NativeHx.clipboardData = "";
NativeHx.clipboardDataHtml = "";
NativeHx.useConcatForPush = Platform.isChrome || Platform.isSafari;
NativeHx.DeferQueue = [];
NativeHx.FlowCrashHandlers = [];
NativeHx.PlatformEventListeners = new haxe_ds_StringMap();
Util.filesCache = new haxe_ds_StringMap();
Util.filesHashCache = new haxe_ds_StringMap();
_$RenderSupportHx_Graphics.svgns = "http://www.w3.org/2000/svg";
haxe_crypto_Base64.CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
haxe_crypto_Base64.BYTES = haxe_io_Bytes.ofString(haxe_crypto_Base64.CHARS);
js_Boot.__toStr = {}.toString;
RenderSupportHx.typekitTryCount = 0;
RenderSupportHx.WebClipInitSize = 100.0;
GesturesDetector.IsPinchInProgress = false;
GesturesDetector.PinchInitialDistance = 1.0;
GesturesDetector.PinchListeners = [];
GesturesDetector.CurrentPinchScaleFactor = 1.0;
GesturesDetector.CurrentPinchFocus = { x : 0.0, y : 0.0};
_$RenderSupportJSPixi_VideoClip.UsePixiTextures = false;
_$RenderSupportJSPixi_VideoClip.VideosOnStage = [];
FontLoader.DFontVersionExpected = 4;
FontLoader.DFonts = new haxe_ds_StringMap();
_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap = false;
RenderSupportJSPixi.PixiStage = new _$RenderSupportJSPixi_FlowContainer();
RenderSupportJSPixi.MousePos = new PIXI.Point(0.0,0.0);
RenderSupportJSPixi.PixiStageChanged = true;
RenderSupportJSPixi.isEmulating = false;
RenderSupportJSPixi.AnimationFrameId = -1;
RenderSupportJSPixi.AccessibilityEnabled = false;
RenderSupportJSPixi.EnableFocusFrame = false;
RenderSupportJSPixi.ShowDebugClipsTree = Util.getParameter("clipstree") == "1";
RenderSupportJSPixi.CacheTextsAsBitmap = Util.getParameter("cachetext") == "1";
RenderSupportJSPixi.DebugAccessOrder = Util.getParameter("accessorder") == "1";
RenderSupportJSPixi.Antialias = Util.getParameter("antialias") != null?Util.getParameter("antialias") == "1":!NativeHx.isTouchScreen();
RenderSupportJSPixi.RoundPixels = Util.getParameter("roundpixels") != null?Util.getParameter("roundpixels") != "0":true;
RenderSupportJSPixi.RendererType = Util.getParameter("renderer") != null?Util.getParameter("renderer"):window.useRenderer;
RenderSupportJSPixi.UseVideoTextures = Util.getParameter("videotexture") != "0";
RenderSupportJSPixi.backingStoreRatio = RenderSupportJSPixi.getBackingStoreRatio();
RenderSupportJSPixi.UseDFont = Util.getParameter("dfont") != "0";
RenderSupportJSPixi.RenderSupportJSPixiInitialised = RenderSupportJSPixi.init();
RenderSupportJSPixi.RequestAnimationFrameId = -1;
RenderSupportJSPixi.FONT_THIN = 100;
RenderSupportJSPixi.FONT_ULTRA_LIGHT = 200;
RenderSupportJSPixi.FONT_LIGHT = 300;
RenderSupportJSPixi.FONT_BOOK = 400;
RenderSupportJSPixi.FONT_MEDIUM = 500;
RenderSupportJSPixi.FONT_SEMI_BOLD = 600;
RenderSupportJSPixi.FONT_BOLD = 700;
RenderSupportJSPixi.FONT_EXTRA_BOLD = 800;
RenderSupportJSPixi.FONT_BLACK = 900;
RenderSupportJSPixi.FONT_NORMAL = "normal";
RenderSupportJSPixi.FONT_ITALIC = "italic";
RenderSupportJSPixi.FONT_OBLIQUE = "oblique";
RenderSupportJSPixi.MouseUpReceived = false;
RenderSupportJSPixi.FlowMainFunction = "flow_main";
RenderSupportJSPixi.accessRoleMap = (function($this) {
	var $r;
	var _g = new haxe_ds_StringMap();
	if(__map_reserved.button != null) _g.setReserved("button","button"); else _g.h["button"] = "button";
	if(__map_reserved.checkbox != null) _g.setReserved("checkbox","button"); else _g.h["checkbox"] = "button";
	if(__map_reserved.radio != null) _g.setReserved("radio","button"); else _g.h["radio"] = "button";
	if(__map_reserved.menu != null) _g.setReserved("menu","button"); else _g.h["menu"] = "button";
	if(__map_reserved.listitem != null) _g.setReserved("listitem","button"); else _g.h["listitem"] = "button";
	if(__map_reserved.menuitem != null) _g.setReserved("menuitem","button"); else _g.h["menuitem"] = "button";
	if(__map_reserved.tab != null) _g.setReserved("tab","button"); else _g.h["tab"] = "button";
	if(__map_reserved.banner != null) _g.setReserved("banner","header"); else _g.h["banner"] = "header";
	if(__map_reserved.main != null) _g.setReserved("main","section"); else _g.h["main"] = "section";
	if(__map_reserved.navigation != null) _g.setReserved("navigation","nav"); else _g.h["navigation"] = "nav";
	if(__map_reserved.contentinfo != null) _g.setReserved("contentinfo","footer"); else _g.h["contentinfo"] = "footer";
	if(__map_reserved.form != null) _g.setReserved("form","form"); else _g.h["form"] = "form";
	if(__map_reserved.textbox != null) _g.setReserved("textbox","input"); else _g.h["textbox"] = "input";
	$r = _g;
	return $r;
}(this));
RenderSupportJSPixi.PIXEL_STEP = 10;
RenderSupportJSPixi.LINE_HEIGHT = 40;
RenderSupportJSPixi.PAGE_HEIGHT = 800;
RenderSupportJSPixi.sharedText = new PIXI.Text("");
RenderSupportJSPixi.IsFullScreen = false;
RenderSupportJSPixi.IsFullWindow = false;
_$RenderSupportJSPixi_FlowSprite.MAX_CHACHED_IMAGES = 50;
_$RenderSupportJSPixi_FlowSprite.cachedImagesUrls = new haxe_ds_StringMap();
_$RenderSupportJSPixi_DFontText.FireFoxMaxTextWidth = 32765.0;
_$RenderSupportJSPixi_Shaders.GlowFragmentSrc = ["precision lowp float;","varying vec2 vTextureCoord;","varying vec4 vColor;","uniform sampler2D uSampler;","void main() {","vec4 sum = vec4(0);","vec2 texcoord = vTextureCoord;","for(int xx = -4; xx <= 4; xx++) {","for(int yy = -3; yy <= 3; yy++) {","float dist = sqrt(float(xx*xx) + float(yy*yy));","float factor = 0.0;","if (dist == 0.0) {","factor = 2.0;","} else {","factor = 2.0/abs(float(dist));","}","sum += texture2D(uSampler, texcoord + vec2(xx, yy) * 0.002) * factor;","}","}","gl_FragColor = sum * 0.025 + texture2D(uSampler, texcoord);","}"];
_$RenderSupportJSPixi_Shaders.VertexSrc = ["attribute vec2 aVertexPosition;","attribute vec2 aTextureCoord;","attribute vec4 aColor;","uniform mat3 projectionMatrix;","varying vec2 vTextureCoord;","varying vec4 vColor;","void main(void)","{","gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);","vTextureCoord = aTextureCoord;","vColor = vec4(aColor.rgb * aColor.a, aColor.a);","}"];
RendersupportpixiFlowJsProgram.globals__ = (function($this) {
	var $r;
	HaxeRuntime._structnames_ = new haxe_ds_IntMap();
	HaxeRuntime._structids_ = new haxe_ds_StringMap();
	HaxeRuntime._structargs_ = new haxe_ds_IntMap();
	HaxeRuntime._structargtypes_ = new haxe_ds_IntMap();
	$r = new RenderSupportHx();
	return $r;
}(this));
haxe_io_FPHelper.i64tmp = (function($this) {
	var $r;
	var x = new haxe__$Int64__$_$_$Int64(0,0);
	$r = x;
	return $r;
}(this));
js_html_compat_Uint8Array.BYTES_PER_ELEMENT = 1;

(function() {
	var S = HaxeRuntime.initStruct;
	var t0 = RuntimeType.RTArray(RuntimeType.RTUnknown);
	var t1 = RuntimeType.RTUnknown;
	S(0,"Access",["J","g"],[t0,t1]);
	var t2 = RuntimeType.RTString;
	S(1,"AccessAttribute",["m","a"],[t2,t1]);
	S(2,"AccessCallback",["K"],[t1]);
	S(3,"AccessChildSelected",["L"],[t1]);
	S(4,"AccessDescription",["M"],[t2]);
	S(5,"AccessEnabled",["N"],[t1]);
	S(6,"AccessFocused",["O"],[t1]);
	S(7,"AccessGroup",["P"],[t2]);
	S(8,"AccessKbdShortcutString",["Q"],[t2]);
	S(9,"AccessRole",["R"],[t2]);
	S(10,"AccessSelectable",[],[]);
	S(11,"AccessState",["S"],[t1]);
	S(12,"AccessTabOrder",["T"],[t1]);
	var t3 = RuntimeType.RTInt;
	S(13,"AccessTabindex",["U"],[t3]);
	S(14,"AccessZorder",["V"],[t1]);
	S(15,"AllScrollCursor",[],[]);
	S(16,"AllowForms",[],[]);
	S(17,"AllowSameOrigin",[],[]);
	S(18,"AllowScripts",[],[]);
	S(19,"AllowTopNavigation",[],[]);
	S(20,"Alpha",["v","g"],[t1,t1]);
	S(21,"ArrowCursor",[],[]);
	S(22,"AutoAlign",["W"],[t1]);
	S(23,"AutoAlignCenter",[],[]);
	S(24,"AutoAlignLeft",[],[]);
	S(25,"AutoAlignNone",[],[]);
	S(26,"AutoAlignRight",[],[]);
	S(27,"Available2",["u","g"],[t1,t1]);
	S(28,"AvailableHeight",["k"],[t1]);
	S(29,"AvailableWidth",["j"],[t1]);
	S(30,"AvailableWidth2",["j"],[t1]);
	S(31,"BackgroundFill",["n"],[t3]);
	var t4 = RuntimeType.RTDouble;
	S(32,"BackgroundFillOpacity",["X"],[t4]);
	S(33,"Baseline",["Y","g"],[t1,t1]);
	S(34,"Bevel",["Z"],[t0]);
	S(35,"Blur",["Z"],[t0]);
	S(36,"Border",["q","s","r","t","g"],[t4,t4,t4,t4,t1]);
	S(37,"Camera",["a0","Z","b0","c0"],[t2,t0,t0,t0]);
	S(38,"CameraID",["A"],[t3]);
	S(39,"CameraSize",["j","k","d0"],[t3,t3,t4]);
	var t5 = RuntimeType.RTBool;
	S(40,"ClipCapabilities",["e0","f0","g0","h0","v"],[t5,t5,t5,t5,t5]);
	S(41,"ClosePath",[],[]);
	S(42,"ColResizeCursor",[],[]);
	S(43,"Color",["n","v"],[t3,t4]);
	S(44,"Cons",["head","tail"],[t1,t1]);
	S(45,"ConstBehaviour",["i0"],[t1]);
	S(46,"Constructor",["g","I"],[t1,t1]);
	S(47,"Content",["j0","l"],[t2,t0]);
	S(48,"ContextMenuCursor",[],[]);
	S(49,"ControlFocus",["k0","g"],[t1,t1]);
	S(50,"CopyCursor",[],[]);
	S(51,"Create",["I"],[t1]);
	S(52,"Crop2",["q","s","j","k","g","l0"],[t1,t1,t1,t1,t1,t1]);
	S(53,"CrosshairCursor",[],[]);
	S(54,"CubicBezierTo",["h","i","m0","n0"],[t4,t4,t4,t4]);
	S(55,"Cursor",["o0","g"],[t1,t1]);
	S(56,"DELETE",[],[]);
	S(57,"DEnd",[],[]);
	S(58,"DLink",["G","p0","q0","r0"],[t1,t1,t1,t5]);
	S(59,"DList",["b","s0"],[t1,t1]);
	S(60,"DebuggedSubscriber",["t0","I","u0","v0","w0"],[t1,t1,t1,t1,t1]);
	S(61,"DefaultCursor",[],[]);
	S(62,"DefinedTextStyle",["x0","y0","z0","A0","B0","C0","D0","E0","F0","G0","H0","I0"],[t2,t4,t3,t2,t3,t4,t4,t3,t4,t3,t3,t3]);
	S(63,"Disposable",["a","J0"],[t1,t1]);
	S(64,"DontCache",[],[]);
	S(65,"DropShadow",["Z"],[t0]);
	var t6 = RuntimeType.RTRefTo(RuntimeType.RTUnknown);
	S(66,"DynamicBehaviour",["a","K0"],[t6,t1]);
	S(67,"DynamicCursor",["L0"],[t1]);
	S(68,"EResizeCursor",[],[]);
	S(69,"EWResizeCursor",[],[]);
	S(70,"EatKeyDownOnFocus",[],[]);
	S(71,"EmailType",[],[]);
	S(72,"Empty",[],[]);
	S(73,"EmptyCursor",[],[]);
	S(74,"EmptyList",[],[]);
	S(75,"EmptyPopResult",[],[]);
	S(76,"EscapeHTML",["M0"],[t5]);
	S(77,"FileDrop",["N0","O0","P0"],[t3,t2,t1]);
	S(78,"Fill",["n"],[t3]);
	S(79,"FillOpacity",["X"],[t4]);
	S(80,"Filter2",["f0","g","l0"],[t0,t1,t1]);
	S(81,"FineGrainMouseWheel2",["I"],[t1]);
	S(82,"FingerCursor",[],[]);
	S(83,"FlowCallback",["I"],[t1]);
	S(84,"Focus",["k0"],[t5]);
	S(85,"FocusIn",["I"],[t1]);
	S(86,"FocusOut",["I"],[t1]);
	S(87,"FontAntiAliasAdvanced",[],[]);
	S(88,"FontAntiAliasNormal",[],[]);
	S(89,"FontFamily",["m"],[t2]);
	S(90,"FontGridFitNone",[],[]);
	S(91,"FontGridFitPixel",[],[]);
	S(92,"FontGridFitSubpixel",[],[]);
	S(93,"FontSize",["p"],[t4]);
	S(94,"FormMetrics",["j","k","Y","Q0"],[t4,t4,t4,t4]);
	S(95,"FullScreenPlayer",[],[]);
	S(96,"FullWindow",["R0","g"],[t1,t1]);
	S(97,"GET",[],[]);
	S(98,"GestureStateBegin",[],[]);
	S(99,"GestureStateEnd",[],[]);
	S(100,"GestureStateProgress",[],[]);
	S(101,"GetMouseInfo",["I"],[t1]);
	S(102,"Glow",["Z"],[t0]);
	S(103,"GrabCursor",[],[]);
	S(104,"GrabbingCursor",[],[]);
	S(105,"GradientFill",["S0","T0"],[t4,t0]);
	S(106,"GradientPoint",["n","v","U0"],[t3,t4,t4]);
	S(107,"Graphics",["x","l"],[t0,t0]);
	var t7 = RuntimeType.RTArray(RuntimeType.RTArray(RuntimeType.RTUnknown));
	S(108,"Grid",["V0"],[t7]);
	S(109,"Group",["w"],[t0]);
	S(110,"Height",["k"],[t1]);
	S(111,"HelpCursor",[],[]);
	var t8 = RuntimeType.RTArray(RuntimeType.RTString);
	S(112,"HtmlFont",["m","W0","l","X0"],[t2,t1,t1,t8]);
	S(113,"IAvailable",["u"],[t1]);
	S(114,"IAvailable2",["u"],[t1]);
	S(115,"IMetrics",["Y0"],[t1]);
	S(116,"IPending",["Z0"],[t1]);
	S(117,"ISize",["u"],[t1]);
	S(118,"ITag",["a1"],[t3]);
	S(119,"ITransformMatrix",["b1"],[t1]);
	S(120,"IgnoreHitTest",["c1"],[t1]);
	S(121,"IllegalStruct",[],[]);
	S(122,"Inner",["d1"],[t5]);
	S(123,"Inspect",["e1","g"],[t0,t1]);
	S(124,"Interactive",["b0","g"],[t0,t1]);
	S(125,"KeyDown2",["I"],[t1]);
	S(126,"KeyEvent",["f1","g1","h1","i1","j1","k1","l1"],[t2,t5,t5,t5,t5,t3,t1]);
	S(127,"KeyUp2",["I"],[t1]);
	S(128,"KeyValue",["f","a"],[t2,t2]);
	S(129,"KeyboardShortcut",["m1","M"],[t2,t2]);
	S(130,"KeyboardZOrderedHandler",["n1","I"],[t3,t1]);
	S(131,"Landscape",[],[]);
	S(132,"LegacyEscaping",[],[]);
	S(133,"LetterSpacing",["o1"],[t4]);
	S(134,"LineTo",["h","i"],[t4,t4]);
	S(135,"LoopPlayback",[],[]);
	S(136,"Mask2",["p1","q1","l0"],[t1,t1,t1]);
	S(137,"MaxChars",["r1"],[t3]);
	S(138,"MouseDisabled",["s1"],[t1]);
	S(139,"MouseDown2",["I"],[t1]);
	S(140,"MouseDownInfo",["h","i","t1","u1","v1"],[t4,t4,t4,t4,t1]);
	S(141,"MouseInfo",["h","i","t1","u1","v1"],[t4,t4,t4,t4,t5]);
	S(142,"MouseMiddleDown2",["I"],[t1]);
	S(143,"MouseMiddleUp2",["I"],[t1]);
	S(144,"MouseMove2",["I"],[t1]);
	S(145,"MouseRightDown2",["I"],[t1]);
	S(146,"MouseRightUp2",["I"],[t1]);
	S(147,"MouseUp2",["I"],[t1]);
	S(148,"MouseWheel",["I"],[t1]);
	S(149,"MoveCursor",[],[]);
	S(150,"MoveTo",["h","i"],[t4,t4]);
	S(151,"Multiline",["w1"],[t5]);
	S(152,"Mutable2",["g","l0"],[t1,t1]);
	S(153,"NEResizeCursor",[],[]);
	S(154,"NESWResizeCursor",[],[]);
	S(155,"NResizeCursor",[],[]);
	S(156,"NSResizeCursor",[],[]);
	S(157,"NWResizeCursor",[],[]);
	S(158,"NWSEResizeCursor",[],[]);
	S(159,"NativeForm",["x1","Y0","y1","I"],[t1,t1,t1,t1]);
	S(160,"NativeRenderResult",["z1","J0"],[t0,t1]);
	S(161,"NoAutoPlay",[],[]);
	S(162,"NoCursor",[],[]);
	S(163,"NoScreenOrientation",[],[]);
	S(164,"None",[],[]);
	S(165,"NotAllowedCursor",[],[]);
	S(166,"Numeric",["A1"],[t5]);
	S(167,"NumericType",[],[]);
	S(168,"OWASP",["B1"],[t3]);
	S(169,"OnConnectingError",["I"],[t1]);
	S(170,"OnError",["I"],[t1]);
	S(171,"OnLoaded",["I"],[t1]);
	S(172,"OnLoadingError",["I"],[t1]);
	S(173,"OnPageLoaded",["I"],[t1]);
	S(174,"OnVideoLoadingError",["I"],[t1]);
	S(175,"OnlyDownloadToCache",[],[]);
	S(176,"OverridePageDomain",["C1"],[t2]);
	S(177,"PATCH",[],[]);
	S(178,"POST",[],[]);
	S(179,"PUT",[],[]);
	S(180,"PageEvalJS",["I"],[t1]);
	S(181,"PageHostcallSetter",["I"],[t1]);
	S(182,"Pair",["b","c"],[t1,t1]);
	S(183,"PanGesture",["I"],[t1]);
	S(184,"PasswordMode",["D1"],[t5]);
	S(185,"PasswordType",[],[]);
	S(186,"PauseResume",[],[]);
	S(187,"Picture",["E1","l"],[t2,t0]);
	S(188,"PinchGesture",["I"],[t1]);
	S(189,"PixelStroke",["F1"],[t3]);
	S(190,"Placement",["G1","H1"],[t4,t4]);
	S(191,"PlaybackRateControl",[],[]);
	S(192,"PlayerControlsAlwaysVisible",[],[]);
	S(193,"PlayerIsPlaying",["I1"],[t1]);
	S(194,"PlayerLength",["J1"],[t1]);
	S(195,"PlayerPause",["K1"],[t1]);
	S(196,"PlayerPosition",["L1","M1"],[t1,t3]);
	S(197,"PlayerPosition2",["L1","N1"],[t1,t1]);
	S(198,"PlayerSeek",["L1"],[t1]);
	S(199,"PlayerVolume",["O1"],[t1]);
	S(200,"Point",["h","i"],[t4,t4]);
	S(201,"PopResult",["P1","G","Q1"],[t1,t1,t1]);
	S(202,"PopSetResult",["a","Q1"],[t1,t1]);
	S(203,"Portrait",[],[]);
	S(204,"PositionScale",["R1","h0"],[t1,t1]);
	S(205,"ProgressCursor",[],[]);
	S(206,"Promise",["H"],[t1]);
	S(207,"QuadraticBezierTo",["h","i","m0","n0"],[t4,t4,t4,t4]);
	S(208,"Quadruple",["b","c","d","e"],[t1,t1,t1,t1]);
	S(209,"RTMPServer",["S1"],[t2]);
	S(210,"RadialGradient",[],[]);
	S(211,"Radius",["T1"],[t4]);
	S(212,"ReadOnly",["U1"],[t5]);
	S(213,"RealHTML2",["E1","V1","l"],[t2,t1,t0]);
	S(214,"RealHtmlShrink2Fit",[],[]);
	S(215,"Recording",["W1"],[t1]);
	S(216,"ReloadBlock",["X1"],[t5]);
	S(217,"RenderResult",["z1","u","Y","Z0","Y1","Z1"],[t0,t1,t1,t1,t0,t1]);
	S(218,"RequestParameters",["Z"],[t0]);
	S(219,"RequestPayload",["a2"],[t2]);
	S(220,"RespectHandled",["c1"],[t1]);
	S(221,"RollOut",["I"],[t1]);
	S(222,"RollOver",["I"],[t1]);
	S(223,"Rotate",["b2","g"],[t1,t1]);
	S(224,"RowInfo",["c2","J0"],[t0,t1]);
	S(225,"RowResizeCursor",[],[]);
	S(226,"SResizeCursor",[],[]);
	S(227,"SWResizeCursor",[],[]);
	S(228,"SandBoxJS",["d2"],[t0]);
	S(229,"Scale",["h","i","g"],[t1,t1,t1]);
	S(230,"ScrollInfo",["e2","f2","g2"],[t3,t3,t3]);
	S(231,"Scrubber",[],[]);
	S(232,"SearchType",[],[]);
	S(233,"Selection",["h2","i2"],[t3,t3]);
	S(234,"Set",["j2"],[t1]);
	S(235,"SetPending",["Z0","g"],[t1,t1]);
	S(236,"ShadowColor",["n","v"],[t3,t4]);
	S(237,"Sharpness",["k2","l2","m2"],[t3,t1,t1]);
	S(238,"Size2",["u","g"],[t1,t1]);
	S(239,"SmartOption",["m"],[t2]);
	S(240,"Some",["a"],[t1]);
	S(241,"SoundOnly",[],[]);
	S(242,"Spread",["T1"],[t4]);
	S(243,"StandardEscaping",[],[]);
	S(244,"StateChanger",["S"],[t1]);
	S(245,"StateQuery",["n2"],[t1]);
	S(246,"StateQuery2",["n2"],[t6]);
	S(247,"StreamEndOffset",["U0"],[t4]);
	S(248,"StreamStartOffset",["U0"],[t4]);
	S(249,"StreamStatus",["I"],[t1]);
	S(250,"Stroke",["F1"],[t3]);
	S(251,"StrokeLineGradient",["S0","T0"],[t4,t0]);
	S(252,"StrokeOpacity",["X"],[t4]);
	S(253,"StrokeWidth",["j"],[t4]);
	S(254,"SwipeGesture",["I"],[t1]);
	S(255,"Switch",["o2","p2"],[t1,t0]);
	S(256,"SynchroCalls",["q2","r2"],[t1,t1]);
	S(257,"TabEnabled",["N"],[t5]);
	S(258,"TabIndex",["s2"],[t3]);
	S(259,"TelType",[],[]);
	S(260,"Text",["o","l"],[t2,t0]);
	S(261,"TextChange",["I"],[t1]);
	S(262,"TextCursor",[],[]);
	S(263,"TextInput",["S","b0","t2"],[t0,t0,t0]);
	S(264,"TextInputFilter",["H"],[t1]);
	S(265,"TextInputModel",["j0","j","k","u2","v2","k0","w2"],[t2,t4,t4,t3,t1,t5,t1]);
	S(266,"TextInputType",["x2"],[t1]);
	S(267,"TextScroll",["I"],[t1]);
	S(268,"TextSize",["j","k"],[t4,t4]);
	S(269,"TextType",[],[]);
	S(270,"Timer",["a","y2","h2"],[t1,t1,t1]);
	S(271,"TransformMatrix",["C","D","z2","A2","B2","C2"],[t4,t4,t4,t4,t4,t4]);
	S(272,"Translate",["h","i","g"],[t1,t1,t1]);
	S(273,"TreeEmpty",[],[]);
	S(274,"TreeNode",["f","a","q","r","D2"],[t1,t1,t1,t1,t3]);
	S(275,"Triple",["b","c","d"],[t1,t1,t1]);
	S(276,"Underlined",["l"],[t0]);
	S(277,"UniqCustomIx",["E2","F2"],[t0,t0]);
	S(278,"UpdateCachedContent",["G2"],[t5]);
	S(279,"UploadCancel",["H2"],[t1]);
	S(280,"UploadData",["I2"],[t1]);
	S(281,"UploadError",["J2"],[t1]);
	S(282,"UploadOpen",["K2"],[t1]);
	S(283,"UploadProgress",["L2"],[t1]);
	S(284,"UploadSelect",["M2"],[t1]);
	S(285,"UrlType",[],[]);
	S(286,"V2",["h","i"],[t4,t4]);
	S(287,"V2Circle",["N2","T1"],[t1,t4]);
	S(288,"Video",["a0","Z","b0","c0"],[t2,t0,t0,t0]);
	S(289,"VideoFullScreen",["O2"],[t1]);
	S(290,"VideoPlayerControls",["c0"],[t0]);
	S(291,"VideoPlayerSubtitles",["P2"],[t1]);
	S(292,"VideoSize",["j","k"],[t3,t3]);
	S(293,"VideoSubtitle",["o","l"],[t2,t0]);
	S(294,"Visible",["Q2","g"],[t1,t1]);
	S(295,"VolumeControl",[],[]);
	S(296,"WResizeCursor",[],[]);
	S(297,"WaitCursor",[],[]);
	S(298,"Width",["j"],[t1]);
	S(299,"WidthHeight",["j","k"],[t4,t4]);
	S(300,"WordWrap",["R2"],[t5]);
	S(301,"XmlAttribute",["f","a"],[t2,t2]);
	S(302,"XmlComment",["o"],[t2]);
	S(303,"XmlCommentEvent",["S2"],[t2]);
	S(304,"XmlElement",["T2","U2","V2"],[t2,t0,t0]);
	S(305,"XmlElement2",["T2","U2","V2"],[t2,t0,t0]);
	S(306,"XmlElementEnd",["T2"],[t2]);
	S(307,"XmlElementStart",["T2","U2"],[t2,t0]);
	S(308,"XmlEmptyElement",["T2","U2"],[t2,t0]);
	S(309,"XmlEndEvent",[],[]);
	S(310,"XmlKeepComments",[],[]);
	S(311,"XmlParseLeadingSpaces",["W2","X2"],[t5,t5]);
	S(312,"XmlProcessingEvent",["T2","U2"],[t2,t0]);
	S(313,"XmlText",["o"],[t2]);
	S(314,"XmlTextEvent",["o"],[t2]);
	S(315,"XmlValidateNames",[],[]);
	S(316,"ZOrderedHandler",["n1","Y2","I"],[t3,t1,t1]);
	S(317,"ZoomEnabled",["N"],[t1]);
	S(318,"ZoomInCursor",[],[]);
	S(319,"ZoomOutCursor",[],[]);
}());
var CMP = HaxeRuntime.compareByValue;
function OTC(fn, fn_name) {
	var top_args;
	window[fn_name] = function() {
		var result, old_top_args = top_args;
		top_args = arguments;
		while (top_args !== null) { var cur_args = top_args; top_args = null; result = fn.apply(null, cur_args); }
		top_args = old_top_args;
		return result;
	};
	window['sc_' + fn_name] = function() { top_args = arguments; };
}
function OTC1(fn, fn_name) {
	var top_arg;
	window[fn_name] = function(a1) {
		var result, old_top_arg = top_arg;
		top_arg = a1;
		while (top_arg !== undefined) { var cur_arg = top_arg; top_arg = undefined; result = fn(cur_arg);}
		top_arg = old_top_arg;
		return result;
	};
	window['sc_' + fn_name] = function(a1) { top_arg = a1; };
}
$0=function(_0,_1){
var sc__=_0;
switch(sc__._id){
case 164:{return _1;}
case 240:{var _2=sc__.a;return _2;}
}
}
$1=function(_0,_1,_2){
var sc__=_0;
switch(sc__._id){
case 164:{return _2;}
case 240:{var _3=sc__.a;return _1(_3);}
}
}
$2=NativeHx.length__;
$3=NativeHx.map;
$4=NativeHx.fold;
$5=NativeHx.enumFromTo;
$6=NativeHx.iteriUntil;
$7=NativeHx.elemIndex||function(_0,_1,_2){
var _3=$6(_0,(function(_4,_5){
return (CMP(_5,_1)==0);})
);
if((_3==$2(_0))){return _2;}else{return _3;}
}
$8=function(_0,_1){
return ($7(_0,_1,(-(1)|0))!=(-(1)|0));
}
$9=NativeHx.find||function(_0,_1){
var _2=$6(_0,(function(_3,_4){
return _1(_4);})
);
if((_2==$2(_0))){return ({_id:164});}else{return ({_id:240,a:_0[_2]});}
}
$a=NativeHx.isSameStructType;
$b=function(_0,_1){
return $4(_0,_1,(function(_2,_3){
if($a(_2,_3)){var _4=_3;
return _4;}else{return _2;}})
);
}
var $c={__v:[]}
$d=function(){
return (($b($c.__v,({_id:168,B1:0})).B1)>0);
}
var $e={__v:true}
$f=function(){
return (!$d()&&$e.__v);
}
var $g={__v:(function(_0,_1){
return _1(_0);})
}
$h=NativeHx.random;
$i=NativeHx.timestamp;
$j=NativeHx.println;
$k=function(_0){
if($f()){return $j(_0);}else{return null;}
}
$l=NativeHx.toString;
$m=NativeHx.hostCall;
$n=function(_0){
return _0;
}
$o=function(_0,_1,_2){
if((_0>=_1)){return [];}else{return $3($5(_0,((_1-1)|0)),_2);}
}
$p=function(_0){
return _0;
}
$q=NativeHx.fast_max||function(_0,_1){
if((CMP(_0,_1)>0)){return _0;}else{return _1;}
}
$r=function(){
return ({_id:59,b:({_id:57}),s0:({_id:57})});
}
var $s={__v:$n("no category")}
var $t={__v:$n("")}
var $u=({_id:66,a:{__v:0},K0:$r()})
$v=function(_0){
return ({_id:66,a:{__v:_0},K0:$r()});
}
$w=function(_0){
return ({_id:45,i0:_0});
}
var $x=$w(0.0)
$y=function(_0){
var sc__=_0;
switch(sc__._id){
case 45:{var _1=sc__.i0;return _1;}
case 66:{var _1=sc__.a;return _1.__v;}
}
}
$z=NativeHx.list2array;
$A=function(){
return ({_id:74});
}
$B=function(){
return ({_id:273});
}
$C=NativeHx.fast_setTree||function(_0,_1,_2){
var sc__=_0;
switch(sc__._id){
case 274:{var _3=sc__.f;var _4=sc__.a;var _5=sc__.q;var _6=sc__.r;var _7=sc__.D2;if((CMP(_1,_3)<0)){return $E(_3,_4,$C(_5,_1,_2),_6);}else{if((CMP(_1,_3)==0)){return ({_id:274,f:_3,a:_2,q:_5,r:_6,D2:_7});}else{return $E(_3,_4,_5,$C(_6,_1,_2));}}}
case 273:{return ({_id:274,f:_1,a:_2,q:({_id:273}),r:({_id:273}),D2:1});}
}
}
$D=function(_0,_1,_2,_3){
return ({_id:274,f:_0,a:_1,q:_2,r:_3,D2:(($q($H(_2),$H(_3))+1)|0)});
}
$E=function(_0,_1,_2,_3){
var _4=$H(_2);
var _5=$H(_3);
var _6=((_4-_5)|0);
var _7=({_id:274,f:_0,a:_1,q:_2,r:_3,D2:(($q(_4,_5)+1)|0)});
if((((_6==(-(1)|0))||(_6==0))||(_6==1))){return _7;}else{if((_6<0)){var sc__=_3;
switch(sc__._id){
case 273:{return _7;}
case 274:{var _8=sc__.q;var _9=sc__.r;if(($H(_8)<$H(_9))){return $J(_7);}else{return $J($D(_0,_1,_2,$I(_3)));}}
}}else{var sc__=_2;
switch(sc__._id){
case 273:{return _7;}
case 274:{var _a=sc__.q;var _b=sc__.r;if(($H(_a)<$H(_b))){return $I($D(_0,_1,$J(_2),_3));}else{return $I(_7);}}
}}}
}
OTC(NativeHx.fast_lookupTree||function(_0,_1){
var sc__=_0;
switch(sc__._id){
case 274:{var _2=sc__.f;var _3=sc__.a;var _4=sc__.q;var _5=sc__.r;if((CMP(_1,_2)<0)){return sc_$F(_4,_1);}else{if((CMP(_1,_2)==0)){return ({_id:240,a:_3});}else{return sc_$F(_5,_1);}}}
case 273:{return ({_id:164});}
}
}, '$F' )
$G=function(_0,_1,_2){
return $0($F(_0,_1),_2);
}
$H=function(_0){
var sc__=_0;
switch(sc__._id){
case 273:{return 0;}
case 274:{var _1=sc__.D2;return _1;}
}
}
$I=function(_0){
var sc__=_0;
switch(sc__._id){
case 273:{return _0;}
case 274:{var _1=sc__.f;var _2=sc__.a;var _3=sc__.q;var _4=sc__.r;var sc__=_3;
switch(sc__._id){
case 273:{return _0;}
case 274:{var _5=sc__.f;var _6=sc__.a;var _7=sc__.q;var _8=sc__.r;return $D(_5,_6,_7,$D(_1,_2,_8,_4));}
}}
}
}
$J=function(_0){
var sc__=_0;
switch(sc__._id){
case 273:{return _0;}
case 274:{var _1=sc__.f;var _2=sc__.a;var _3=sc__.q;var _4=sc__.r;var sc__=_4;
switch(sc__._id){
case 273:{return _0;}
case 274:{var _5=sc__.f;var _6=sc__.a;var _7=sc__.q;var _8=sc__.r;return $D(_5,_6,$D(_1,_2,_3,_7),_8);}
}}
}
}
$K=function(_0,_1){
return $L(_0,_1,$p);
}
$L=function(_0,_1,_2){
return $4(_0,$B(),(function(_3,_4){
return $C(_3,_1(_4),_2(_4));})
);
}
$M=NativeHx.strlen;
$N=NativeHx.strIndexOf;
$O=NativeHx.substring;
$P=NativeHx.toLowerCase;
$Q=NativeHx.getCharCodeAt;
$R=function(_0){
return Std.string(_0);
}
OTC(function(_0,_1,_2){
var _3=$N(_0,_1);
if((_3<0)){return ({_id:44,head:_0,tail:_2});}else{var _4=$M(_0);
if((_3<_4)){var _5=$O(_0,0,_3);
var _6=$M(_1);
return sc_$S($O(_0,((_3+_6)|0),((((_4-_3)|0)-_6)|0)),_1,({_id:44,head:_5,tail:_2}));}else{return ({_id:44,head:_0,tail:_2});}}
}, '$S' )
$T=function(_0,_1){
if((_1=="")){return [_0];}else{return $z($S(_0,_1,$A()));}
}
$U=function(_0,_1){
return $O(_0,0,_1);
}
$V=function(_0,_1){
var _2=$M(_0);
if((_1>=_2)){return "";}else{return $O(_0,_1,((_2-_1)|0));}
}
$W=function(_0,_1){
return ($N(_0,_1)>=0);
}
$X=function(_0){
return (1.0*_0);
}
$Y=function(_0){
if(_0){return 1;}else{return 0;}
}
$Z=function(_0){
return $81($01(_0));
}
$01=function(_0){
var _1=$M(_0);
if((_1==0)){return 0.0;}else{var _2=($Q(_0,0)==45);
if(_2){return -$11(_0,1,_1,0.0);}else{return $11(_0,0,_1,0.0);}}
}
OTC(function(_0,_1,_2,_3){
if((_1<_2)){var _4=$Q(_0,_1);
var _5=$41(_4);
if((_5!=(-(1)|0))){return sc_$11(_0,((_1+1)|0),_2,((10.0*_3)+$X(_5)));}else{if((_4==46)){return $21(_0,((_1+1)|0),_2,_3,10.0);}else{if(((_4==69)||(_4==101))){return $31(_0,((_1+1)|0),_2,_3);}else{return _3;}}}}else{return _3;}
}, '$11' )
OTC(function(_0,_1,_2,_3,_4){
if((_1<_2)){var _5=$Q(_0,_1);
var _6=$41(_5);
if((_6!=(-(1)|0))){return sc_$21(_0,((_1+1)|0),_2,(_3+($X(_6)/_4)),(_4*10.0));}else{if(((_5==69)||(_5==101))){return $31(_0,((_1+1)|0),_2,_3);}else{return _3;}}}else{return _3;}
}, '$21' )
$31=function(_0,_1,_2,_3){
if((_1<_2)){var _4=$Q(_0,_1);
var _5=(_4==45);
var _6=(_4==43);
var _7=$51(_0,((_1+$Y((_5||_6)))|0),_2,0);
return $61(_3,(_5?(-(_7)|0):_7));}else{return _3;}
}
$41=function(_0){
if(((48<=_0)&&(_0<=57))){return ((_0-48)|0);}else{return (-(1)|0);}
}
OTC(function(_0,_1,_2,_3){
if((_1<_2)){var _4=$Q(_0,_1);
var _5=$41(_4);
if((_5!=(-(1)|0))){return sc_$51(_0,((_1+1)|0),_2,((HaxeRuntime.mul_32(10,_3)+_5)|0));}else{return _3;}}else{return _3;}
}, '$51' )
OTC(function(_0,_1){
if((_1==0)){return _0;}else{if((_1<0)){return sc_$61((_0/10.0),((_1+1)|0));}else{return sc_$61((_0*10.0),((_1-1)|0));}}
}, '$61' )
$71=function(_0){
return ((_0)|0);
}
$81=function(_0){
if((_0>=0.0)){return $71(_0);}else{if(((-_0-$X($71(-_0)))>0.0)){return $71((_0-1.0));}else{return $71(_0);}}
}
$91=function(_0,_1){
if((_1>0)){var _2=$91(_0,((_1/2)|0));
if((((_1%2)|0)==0)){return HaxeRuntime.mul_32(_2,_2);}else{return HaxeRuntime.mul_32(HaxeRuntime.mul_32(_2,_2),_0);}}else{return 1;}
}
$a1=function(_0){
return (_0-(_0%1.0));
}
$b1=function(_0){
return $a1((_0+((_0<0.0)?-0.5:0.5)));
}
$c1=NativeHx.getAllUrlParameters;
$d1=function(_0){
var _1=$i1(_0);
return $f1(_1);
}
$e1=function(_0){
var _1=$i1(_0);
return $g1(_1);
}
$f1=function(_0){
return (((_0=="true")||(_0=="1"))||(_0=="TRUE"));
}
$g1=function(_0){
return (((_0=="false")||(_0=="0"))||(_0=="FALSE"));
}
$h1=function(){
return $4($c1(),$B(),(function(_0,_1){
return $C(_0,_1[0],_1[1]);})
);
}
$i1=function(_0){
return $G($j1,_0,"");
}
var $j1=$h1()
var $k1={__v:(function(){
return $d1("dev");})
}
$l1=function(){
return $k1.__v();
}
$m1=NativeHx.getTargetName;
var $n1=$T($m1(),",")
$o1=function(_0){
return $8($n1,_0);
}
var $p1=$o1("js")
var $q1=$o1("nodejs")
var $r1=$o1("nwjs")
var $s1=$o1("jslibrary")
var $t1=$o1("qt")
var $u1=$o1("opengl")
var $v1=$o1("flash")
var $w1=$o1("xaml")
var $x1=$o1("neko")
var $y1=$o1("c++")
var $z1=$o1("java")
var $A1=$o1("csharp")
var $B1=$o1("cgi")
var $C1=($o1("mobile")||$d1("overridemobile"))
var $D1=$o1("nativevideo")
var $E1=((($x1||$B1)||($y1&&!$o1("gui")))||($i1("nogui")!=""))
var $F1=(function(){var sc__=$9($n1,(function(_0){
return ($U(_0,4)=="dpi=");})
);
var __sw;switch(sc__._id){
case 164:{__sw=90;break}
case 240:{var _0=sc__.a;__sw=$Z($O(_0,4,(($M(_0)-4)|0)));break}
};return __sw}())
var $G1={__v:false}
var $H1={__v:false}
var $I1={__v:false}
var $J1={__v:false}
var $K1={__v:false}
var $L1={__v:""}
var $M1={__v:""}
var $N1={__v:""}
var $O1={__v:""}
var $P1={__v:""}
var $Q1={__v:""}
$R1=function(){
($W1());
return $N1.__v;

}
$S1=function(){
($W1());
return $O1.__v;

}
$T1=function(){
($W1());
return $P1.__v;

}
$U1=function(){
($W1());
return (($L1.__v+" ")+$M1.__v);

}
$V1=function(){
($W1());
return $Q1.__v;

}
$W1=function(){
if(($L1.__v=="")){var _0=$m("getOs",[]);
var _1=(($l(_0)!="{}")?_0:($o1("iOS")?"iOS":($o1("android")?"Android":($o1("windows")?"Windows":($o1("linux")?"Linux":($o1("macosx")?"MacOSX":""))))));
var _2=$T(_1,",");
(($L1.__v=((($2(_2)>0)&&(_2[0]!=""))?_2[0]:"other")));
(($M1.__v=((($2(_2)>1)&&(_2[1]!=""))?_2[1]:"other")));
(($G1.__v=($L1.__v=="Windows")));
var _3=$m("getUserAgent",[]);
(($Q1.__v=(($l(_3)!="{}")?_3:"other")));
(($H1.__v=(($L1.__v=="MacOSX")||$W($P($Q1.__v),"mac os x"))));
(($I1.__v=($L1.__v=="Linux")));
(($J1.__v=($L1.__v=="iOS")));
(($K1.__v=($L1.__v=="Android")));
var _4=$m("getVersion",[]);
(($N1.__v=(($l(_4)!="{}")?_4:"other")));
var _5=$m("getBrowser",[]);
(($O1.__v=(($l(_5)!="{}")?_5:"other")));
var _6=$m("getResolution",[]);
return ($P1.__v=(($l(_6)!="{}")?_6:"other"));



}else{return null;}
}
$X1=function(){
($W1());
return $G1.__v;

}
$Y1=function(){
var _0=$P($V1());
return ($W(_0,"windows nt 5.1")||$W(_0,"windows xp"));
}
$Z1=function(){
($W1());
return $H1.__v;

}
$02=function(){
($W1());
return $I1.__v;

}
$12=function(){
($W1());
return $J1.__v;

}
$22=function(){
($W1());
return $K1.__v;

}
var $32={__v:false}
var $42=((!$32.__v?(($32.__v=true),
($l1()?($k(("target: "+$m1())),
$k("target: "),
$k(("target: windows="+$l($X1()))),
$k(("target: windowsxp="+$l($Y1()))),
$k(("target: macosx="+$l($Z1()))),
$k(("target: linux="+$l($02()))),
$k(("target: ios="+$l($12()))),
$k(("target: android="+$l($22()))),
$k("target: "),
$k(("target: mobile="+$l($C1))),
$k(("target: screenDPI="+$l($F1))),
$k(("target: getOsFlow="+$l($U1()))),
$k(("target: getFlashVersion="+$l($R1()))),
$k(("target: getBrowser="+$l($S1()))),
$k(("target: getResolution="+$l($T1()))),
$k(("target: getUserAgent="+$l($V1())))):null)):null),
0)
$52=RenderSupportHx.currentClip;
$62=RenderSupportHx.addGestureListener;
$72=RenderSupportHx.addEventListener;
$82=RenderSupportHx.getStageWidth||function(){
return 0.0;
}
$92=RenderSupportHx.getStageHeight||function(){
return 0.0;
}
$a2=RenderSupportHx.getPixelsPerCm||function(){
return 37.795;
}
var $b2={__v:$B()}
var $c2=400
var $d2=500
var $e2=700
var $f2="normal"
var $g2="italic"
$h2=function(){
return $K([({_id:112,m:"Roboto",W0:({_id:240,a:$c2}),l:({_id:240,a:$f2}),X0:["Roboto"]}),({_id:112,m:"RobotoMedium",W0:({_id:240,a:$d2}),l:({_id:240,a:$f2}),X0:["Roboto"]}),({_id:112,m:"RobotoBold",W0:({_id:240,a:$e2}),l:({_id:240,a:$f2}),X0:["Roboto"]}),({_id:112,m:"RobotoItalic",W0:({_id:240,a:$c2}),l:({_id:240,a:$g2}),X0:["Roboto"]}),({_id:112,m:"Book",W0:({_id:240,a:$c2}),l:({_id:164}),X0:["Franklin Gothic"]}),({_id:112,m:"Italic",W0:({_id:240,a:$c2}),l:({_id:240,a:$g2}),X0:["Franklin Gothic"]}),({_id:112,m:"Medium",W0:({_id:240,a:$e2}),l:({_id:164}),X0:["Franklin Gothic","sans-serif"]}),({_id:112,m:"DejaVuSans",W0:({_id:240,a:$c2}),l:({_id:164}),X0:["DejaVu Sans"]}),({_id:112,m:"MaterialIcons",W0:({_id:240,a:$c2}),l:({_id:164}),X0:["Material Icons"]})],(function(_0){
return (_0.m);})
);
}
var $i2={__v:$h2()}
var $j2=$o(0,32,(function(_0){
return $91(2,_0);})
)
var $k2=$d1("debugfontmapping")
var $l2={__v:false}
$m2=function(){
return $l2.__v;
}
var $n2=($X1()?($u1?({_id:275,b:"Tahoma",c:"Tahoma",d:0.95}):((($y1||$p1)&&($i1("lang")!="ch"))?({_id:275,b:"NotoSans",c:"NotoSansMinimal",d:1.0}):($Y1()?({_id:275,b:"Microsoft YaHei",c:"Microsoft YaHei",d:1.0}):({_id:275,b:"Tahoma",c:"Tahoma",d:1.0})))):(($22()||$02())?({_id:275,b:"DroidSansFallback",c:"DroidSansFallback",d:1.0}):(($12()||$Z1())?({_id:275,b:"Tahoma",c:"NotoSansMinimal",d:0.95}):({_id:275,b:"DroidSansFallback",c:"DroidSansFallback",d:1.0}))))
var $o2=($X1()?($u1?({_id:275,b:"Tahoma",c:"Tahoma",d:0.95}):(($y1||$p1)?({_id:275,b:"Meiryo",c:"NotoSansMinimal",d:1.0}):($Y1()?({_id:275,b:"Microsoft YaHei",c:"Microsoft YaHei",d:1.0}):({_id:275,b:"Tahoma",c:"Tahoma",d:1.0})))):(($22()||$02())?({_id:275,b:"DroidSansFallback",c:"DroidSansFallback",d:1.0}):($12()?($p1?({_id:275,b:"HiraKakuProN-W3",c:"Verdana",d:0.95}):({_id:275,b:"HiraKakuProN-W3",c:"Verdana",d:1.0})):($Z1()?({_id:275,b:"Meiryo",c:"Tahoma",d:1.0}):({_id:275,b:"DroidSansFallback",c:"DroidSansFallback",d:1.0})))))
var $p2=($X1()?($u1?({_id:275,b:"Tahoma",c:"Tahoma",d:0.95}):(($y1||$p1)?({_id:275,b:"MS Gothic",c:"NotoSansMinimal",d:1.05}):($Y1()?({_id:275,b:"Microsoft YaHei",c:"Microsoft YaHei",d:1.0}):({_id:275,b:"Tahoma",c:"Tahoma",d:1.0})))):(($22()||$02())?({_id:275,b:"DroidSansFallback",c:"DroidSansFallback",d:1.0}):($12()?($p1?({_id:275,b:"HiraKakuProN-W3",c:"Verdana",d:0.95}):({_id:275,b:"HiraKakuProN-W3",c:"Verdana",d:1.0})):($Z1()?({_id:275,b:"Verdana",c:"Tahoma",d:0.95}):({_id:275,b:"DroidSansFallback",c:"DroidSansFallback",d:1.0})))))
var $q2=($X1()?($u1?({_id:275,b:"Tahoma",c:"Tahoma",d:0.95}):($Y1()?({_id:275,b:"Andalus",c:"Andalus",d:1.0}):({_id:275,b:"Tahoma",c:"Tahoma",d:1.0}))):($22()?({_id:275,b:"Roboto",c:"Roboto",d:1.0}):($02()?({_id:275,b:"DejaVu Sans",c:"DejaVu Sans",d:0.835}):($12()?({_id:275,b:"GeezaPro",c:"GeezaPro",d:($p1?0.95:1.0)}):($Z1()?({_id:275,b:"Geeza Pro",c:"Geeza Pro",d:0.95}):({_id:275,b:"DroidSansFallback",c:"DroidSansFallback",d:1.0}))))))
var $r2={__v:(function(_0,_1){
return ({_id:182,b:_0,c:_1});})
}
var $s2={__v:({_id:182,b:"",c:-1.0})}
var $t2=$v("")
var $u2={__v:(function(_0,_1){
return ({_id:182,b:_0,c:_1});})
}
var $v2={__v:$B()}
$w2=function(_0,_1){
var _2=$y($t2);
var _3=((_2=="ja")?$o2:((_2=="ko")?$p2:((_2=="ar")?$q2:$n2)));
return ({_id:182,b:(_3.b),c:$y2((_1*(_3.d)))});
}
var $x2=(function(){
var _0=$i1("overridefont");
if((_0=="")){return $p;}else{var _1=$T(_0,";");
var _2=_1[0];
var _3=(function(){
var _4=(($2(_1)>1)?$01(_1[1]):1.0);
if(((_4<0.01)||(_4>100.0))){return 1.0;}else{return _4;}}());
return (function(_5){
return (function(_6,_7){
var _8=_5(_6,_7);
return ({_id:182,b:((_2!="")?_2:(_8.b)),c:((_8.c)*_3)});})
;})
;}}())
$y2=function(_0){
return ($b1((_0*10.0))/10.0);
}
$z2=function(){
(($r2.__v=$x2(($m2()?$w2:$u2.__v))));
return ($s2.__v=({_id:182,b:"",c:-1.0}));

}
var $A2=($z2(),
0)
var $B2=(((($a2()>=100.0)||($i1("retina")=="1"))||($82()>2000.0))||($92()>2000.0))
var $C2=$v(0.0)
var $D2=$v(0.0)
var $E2={__v:$B()}
var $F2={__v:$B()}
var $G2={__v:$B()}
var $H2={__v:$B()}
var $I2={__v:$B()}
var $J2={__v:$B()}
var $K2={__v:$B()}
var $L2={__v:$B()}
var $M2={__v:$B()}
var $N2={__v:$B()}
var $O2={__v:({_id:164})}
var $P2={__v:({_id:164})}
var $Q2={__v:({_id:164})}
var $R2={__v:({_id:164})}
$S2=function(_0){
return $T2(_0,"");
}
$T2=function(_0,_1){
var _2=$V((_0.m),3);
if(($i1(_2)!="")){return $i1(_2);}else{return $1($R2.__v,(function(_3){
return $G(_3,_0,_1);})
,_1);}
}
var $U2=$v(0)
var $V2=({_id:239,m:"so_mobile"})
var $W2={__v:$B()}
var $X2=!$e1("download_pictures")
var $Y2=$d1("redraw")
var $Z2=({_id:40,e0:true,f0:true,g0:true,h0:true,v:true})
var $03=$w(({_id:299,j:0.0,k:0.0}))
var $13=({_id:217,z1:[],u:$03,Y:$w(0.0),Z0:$w(0),Y1:[],Z1:$Z2})
var $23=$S2($V2)
var $33={__v:$B()}
$43=function(){
(($P2.__v=({_id:164})));
(($Q2.__v=({_id:164})));
return ($O2.__v=({_id:164}));

}
$53=function(_0){
if((_0==1)){return ({_id:100});}else{if((_0==0)){return ({_id:98});}else{return ({_id:99});}}
}
var $63=$62("pan",(function(_0,_1,_2,_3,_4){
var _5=(function(){var sc__=$O2.__v;
var __sw;switch(sc__._id){
case 240:{var _6=sc__.a;__sw=_6($53(_0),_1,_2,_3,_4);break}
case 164:{__sw=false;break}
};return __sw}());
(((_0==2)?$43():null));
return _5;
})
)
var $73=$62("pinch",(function(_0,_1,_2,_3,_4){
var _5=(function(){var sc__=$P2.__v;
var __sw;switch(sc__._id){
case 240:{var _6=sc__.a;__sw=_6($53(_0),_1,_2,_3,_4);break}
case 164:{__sw=false;break}
};return __sw}());
(((_0==2)?$43():null));
return _5;
})
)
var $83=$62("swipe",(function(_0,_1,_2,_3,_4){
var sc__=$Q2.__v;
switch(sc__._id){
case 240:{var _5=sc__.a;return _5(_1,_2,_3,_4);}
case 164:{return false;}
}})
)
var $93=$72($52(),"mouseup",$43)
var $a3=((("?v="+$R(($h()*100.0)))+"_")+$R($i()))
var $b3={__v:$B()}
flow_main=function(){
return null;
}
if (typeof RenderSupportHx == 'undefined' && typeof RenderSupportJSPixi == 'undefined') flow_main();