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
	Errors.print(text);
	Errors.addToLog(text);
};
Errors.warning = function(text) {
	Errors.get().add(text);
	Errors.print(text);
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
var FlowArrayUtil = function() { };
FlowArrayUtil.__name__ = true;
FlowArrayUtil.fromArray = function(a) {
	return a;
};
FlowArrayUtil.toArray = function(a) {
	var v = [];
	var _g = 0;
	while(_g < a.length) {
		var e = a[_g];
		++_g;
		v.push(e);
	}
	return v;
};
FlowArrayUtil.one = function(e) {
	return [e];
};
FlowArrayUtil.two = function(e1,e2) {
	return [e1,e2];
};
FlowArrayUtil.three = function(e1,e2,e3) {
	return [e1,e2,e3];
};
var FlowFileSystemHx = function() { };
FlowFileSystemHx.__name__ = true;
FlowFileSystemHx.createDirectory = function(dir) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.deleteDirectory = function(dir) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.deleteFile = function(file) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.renameFile = function(old,newName) {
	try {
		return "";
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return Std.string(e);
	}
};
FlowFileSystemHx.fileExists = function(file) {
	try {
		return false;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return false;
	}
};
FlowFileSystemHx.isDirectory = function(dir) {
	try {
		return false;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return false;
	}
};
FlowFileSystemHx.readDirectory = function(dir) {
	var d = [];
	try {
		return d;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return d;
	}
};
FlowFileSystemHx.fileSize = function(file) {
	try {
		return 0.0;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return 0.0;
	}
};
FlowFileSystemHx.fileModified = function(file) {
	try {
		return 0.0;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return 0.0;
	}
};
FlowFileSystemHx.resolveRelativePath = function(dir) {
	try {
		return dir;
	} catch( e ) {
		haxe_CallStack.lastException = e;
		if (e instanceof js__$Boot_HaxeError) e = e.val;
		return dir;
	}
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
	if(HaxeRuntime.isArray(o1)) {
		if(!HaxeRuntime.isArray(o2)) return 1;
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
	return !HaxeRuntime.isArray(o1) && !HaxeRuntime.isArray(o2) && Object.prototype.hasOwnProperty.call(o1,"_id") && Object.prototype.hasOwnProperty.call(o2,"_id") && o1._id == o2._id;
};
HaxeRuntime.toString = function(value) {
	if(value == null) return "{}";
	if(!Reflect.isObject(value)) return Std.string(value);
	if(HaxeRuntime.isArray(value)) {
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
			if(t == RuntimeType.RTDouble) r1 += s2 + Std.string(v1) + (Std["int"](v1) == v1?".0":""); else r1 += s2 + HaxeRuntime.toString(v1);
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
		if(!HaxeRuntime.isArray(value)) return false;
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
		if(HaxeRuntime.isArray(value)) return RuntimeType.RTArray(RuntimeType.RTUnknown);
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
	return (high << 16) + al * bl;
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
		;
		return "";
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
		;
		return 0.0;
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
	add: function(x) {
		this.b += Std.string(x);
	}
	,addChar: function(c) {
		this.b += String.fromCharCode(c);
	}
	,addSub: function(s,pos,len) {
		if(len == null) this.b += HxOverrides.substr(s,pos,null); else this.b += HxOverrides.substr(s,pos,len);
	}
	,__class__: StringBuf
};
var NativeHx = function() { };
NativeHx.__name__ = true;
NativeHx.println = function(arg) {
	var s = HaxeRuntime.toString(arg);
	Errors.report(s);
	return null;
};
NativeHx.hostCall = function(name,args) {
	var result = null;
	try {
		var name_parts = name.split(".");
		var fun = window[name_parts[0]];
		var _g1 = 1;
		var _g = name_parts.length;
		while(_g1 < _g) {
			var i = _g1++;
			fun = fun[name_parts[i]];
		}
		result = fun(args[0],args[1],args[2],args[3],args[4]);
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
NativeHx.setClipboard = function(text) {
};
NativeHx.getClipboard = function() {
	return NativeHx.clipboardData;
};
NativeHx.toString = function(value) {
	return HaxeRuntime.toString(value);
};
NativeHx.gc = function() {
};
NativeHx.addHttpHeader = function(data) {
};
NativeHx.subrange = function(arr,start,len) {
	if(start < 0 || len < 1) return []; else return arr.slice(start,start + len);
};
NativeHx.isArray = function(a) {
	return HaxeRuntime.isArray(a);
};
NativeHx.isSameStructType = function(a,b) {
	return !HaxeRuntime.isArray(a) && !HaxeRuntime.isArray(b) && Object.prototype.hasOwnProperty.call(a,"_id") && Object.prototype.hasOwnProperty.call(b,"_id") && a._id == b._id;
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
	var result = new StringBuf();
	while(Object.prototype.hasOwnProperty.call(h,"head")) {
		var s = Std.string(h.head);
		var a1 = s.split("");
		a1.reverse();
		result.add(a1.join(""));
		h = h.tail;
	}
	var a = result.b.split("");
	a.reverse();
	return a.join("");
};
NativeHx.list2array = function(h) {
	var result = [];
	while(Object.prototype.hasOwnProperty.call(h,"head")) {
		result.unshift(h.head);
		h = h.tail;
	}
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
	if(arr == null || i < 0) return [];
	var new_arr = arr.slice(0,arr.length);
	new_arr[i] = v;
	return new_arr;
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
NativeHx.timestamp = function() {
	return NativeTime.timestamp();
};
NativeHx.getCurrentDate = function() {
	var date = new Date();
	return NativeHx.makeStructValue("Date",[date.getFullYear(),date.getMonth() + 1,date.getDate()],HaxeRuntime.makeStructValue("IllegalStruct",[],null));
};
NativeHx.timer = function(ms,cb) {
	haxe_Timer.delay(function() {
		try {
			cb();
		} catch( e ) {
			haxe_CallStack.lastException = e;
			if (e instanceof js__$Boot_HaxeError) e = e.val;
			NativeHx.println("FATAL ERROR: timer callback: " + Std.string(e));
			NativeHx.callFlowCrashHandlers("[Timer Handler]: " + Std.string(e));
		}
	},ms);
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
NativeHx.getUrlParameter = function(name) {
	var value = Util.getParameter(name);
	if(value != null) return value; else return "";
};
NativeHx.isTouchScreen = function() {
	return ((('ontouchstart' in window) || window.DocumentTouch && document instanceof DocumentTouch) && window.matchMedia('(pointer: coarse)').matches) || navigator.userAgent.match(/iPad/i) || navigator.userAgent.match(/iPhone/i) || navigator.userAgent.match(/Android/i);
};
NativeHx.getTargetName = function() {
	if(!NativeHx.isTouchScreen()) return "js,pixi"; else return "js,pixi,mobile";
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
NativeHx.profileStart = function(n) {
};
NativeHx.profileEnd = function(n) {
};
NativeHx.profileCount = function(n,c) {
};
NativeHx.profileDump = function(n) {
};
NativeHx.profileReset = function() {
};
NativeHx.clearTrace = function() {
};
NativeHx.printCallstack = function() {
	NativeHx.println(Assert.callStackToString(haxe_CallStack.callStack()));
};
NativeHx.captureCallstack = function() {
	return null;
};
NativeHx.captureCallstackItem = function(index) {
	return null;
};
NativeHx.impersonateCallstackItem = function(item,index) {
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
NativeHx.startProcess = function(command,args,cwd,stdIn,onExit) {
	return false;
};
NativeHx.fromCharCode = function(c) {
	return String.fromCharCode(c);
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
	return string;
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
var NativeTime = function() { };
NativeTime.__name__ = true;
NativeTime.timestamp = function() {
	var t = new Date().getTime();
	return t;
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
	var regexS = "[\\?&]" + name + "=([^&#]*)";
	var regex = new EReg(regexS,"");
	if(regex.match(href)) return StringTools.urlDecode(regex.matched(1)); else return null;
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
		Errors.report("Warning: unknow message source");
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
		if(key == "role") setClipRole(value); else if(key == "tooltip") clip.setAttribute("title",value); else if(key == "tabindex" && value >= 0) {
			if(clip.input) clip.children[0].setAttribute("tabindex",value); else clip.setAttribute("tabindex",value);
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
RenderSupportHx.makeTextField = function() {
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
RenderSupportHx.setTextAndStyle = function(textfield,text,fontfamily,fontsize,fillcolour,fillopacity,letterspacing,backgroundcolour,backgroundopacity,forTextinput) {
	fontsize = fontsize * 0.97;
	var style;
	if(textfield.input) style = textfield.children[0].style; else style = textfield.style;
	RenderSupportHx.setStyleByFlowFont(style,fontfamily);
	style.fontSize = "" + Math.floor(fontsize) + "px";
	style.opacity = "" + fillopacity;
	style.color = "#" + StringTools.hex(fillcolour,6);
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
		var s = "";
		if(e.which == 13) {
			var active = window.document.activeElement;
			if(active != null && RenderSupportHx.isAriaClip(active)) return;
			s = "enter";
		} else if(e.which == 27) s = "esc"; else if(e.which == 9) s = "tab"; else if(e.which == 16) s = "shift"; else if(e.which == 17) s = "ctrl"; else if(e.which == 18) s = "alt"; else if(e.which == 37) s = "left"; else if(e.which == 38) s = "up"; else if(e.which == 39) s = "right"; else if(e.which == 40) s = "down"; else if(e.which >= 112 && e.which <= 123) s = "F" + (e.which - 111); else s = String.fromCharCode(e.which);
		fn(s,ctrl,shift,alt,e.keyCode);
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
RenderSupportHx.setCursor = function(clip,cursor) {
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
RenderSupportHx.getCursor = function(clip) {
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
	return null;
};
RenderSupportHx.makeBlur = function(radius,spread) {
	return "blur(" + radius + "px)";
	return null;
};
RenderSupportHx.makeDropShadow = function(angle,distance,radius,spread,color,alpha,inside) {
	return "drop-shadow(" + Math.cos(angle) * distance + "px " + Math.sin(angle) * distance + "px " + radius + "px " + spread + "px " + Std.string(RenderSupportHx.makeCSSColor(color,alpha)) + ")";
	return null;
};
RenderSupportHx.makeGlow = function(radius,spread,color,alpha,inside) {
	return "";
	return null;
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
	return null;
};
RenderSupportHx.bitmapDraw = function(bitmap,clip,width,height) {
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
	null;
	return;
};
RenderSupportHx.resetFullScreenTarget = function() {
};
RenderSupportHx.toggleFullScreen = function() {
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
RenderSupportHx.takeSnapshot = function(path) {
};
RenderSupportHx.getScreenPixelColor = function(x,y) {
	return 0;
};
RenderSupportHx.makeWebClip = function(url,domain,useCache,reloadBlock,cb,ondone) {
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
	return null;
};
RenderSupportHx.webClipHostCall = function(clip,name,args) {
	return clip.iframe.contentWindow[name].apply(clip.iframe.contentWindow,args);
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
RenderSupportHx.cameraTakePhoto = function(cameraId,additionalInfo,desiredWidth,desiredHeight,compressQuality,fileName) {
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
		window.removeEventListener("hashchanged",wrapper);
	};
	return function() {
	};
};
RenderSupportHx.setGlobalZoomEnabled = function(enabled) {
};
RenderSupportHx.prototype = {
	__class__: RenderSupportHx
};
var FontLoader = function() { };
FontLoader.__name__ = true;
FontLoader.LoadFonts = function(use_dfont,on_done) {
	if(use_dfont) FontLoader.loadDFonts(function() {
		FontLoader.loadWebFonts(on_done);
	}); else FontLoader.loadWebFonts(on_done);
};
FontLoader.loadWebFonts = function(onDone) {
	if(typeof(WebFont) != "undefined") {
		var webfontconfig = JSON.parse(haxe_Resource.getString("webfontconfig"));
		if(webfontconfig != null) {
			webfontconfig.active = onDone;
			webfontconfig.inactive = onDone;
			webfontconfig.loading = function() {
				Errors.print("Loading web fonts...");
			};
			WebFont.load(webfontconfig);
		}
	} else {
		Errors.print("WebFont is not defined");
		onDone();
	}
};
FontLoader.loadDFonts = function(onDone) {
	var dfonts = [];
	var uniqueDFonts = [];
	var dfontsResource = haxe_Resource.getString("dfonts");
	if(dfontsResource != null) {
		dfonts = JSON.parse(dfontsResource);
		var _g = 0;
		while(_g < dfonts.length) {
			var dfont = dfonts[_g];
			++_g;
			if(dfont.url == null) dfont.url = "dfontjs/" + Std.string(dfont.name) + "/index.json";
		}
	} else if(dfonts.length == 0) Errors.print("Warning: No dfonts resource!");
	var fontnamesStr = window.dfontnames;
	if(fontnamesStr != null) {
		var fontnames;
		var _g1 = [];
		var _g11 = 0;
		var _g2 = fontnamesStr.split("\n");
		while(_g11 < _g2.length) {
			var fn = _g2[_g11];
			++_g11;
			_g1.push(StringTools.trim(fn));
		}
		fontnames = _g1;
		fontnames = fontnames.filter(function(s) {
			return s != "";
		});
		var extraDFonts;
		var _g12 = [];
		var _g21 = 0;
		while(_g21 < fontnames.length) {
			var fn1 = fontnames[_g21];
			++_g21;
			_g12.push({ name : fn1, url : "dfontjs/" + fn1 + "/index.json"});
		}
		extraDFonts = _g12;
		if(window.dfonts_override != null) dfonts = extraDFonts; else dfonts = dfonts.concat(extraDFonts);
	}
	var fontURLs;
	var _g3 = new haxe_ds_StringMap();
	var _g13 = 0;
	while(_g13 < dfonts.length) {
		var f = dfonts[_g13];
		++_g13;
		var key = f.name;
		var value = f.url;
		if(__map_reserved[key] != null) _g3.setReserved(key,value); else _g3.h[key] = value;
	}
	fontURLs = _g3;
	Errors.print("Loading dfield fonts...");
	var loader = new PIXI.loaders.Loader();
	var $it0 = fontURLs.keys();
	while( $it0.hasNext() ) {
		var name = $it0.next();
		loader.add(name,__map_reserved[name] != null?fontURLs.getReserved(name):fontURLs.h[name]);
	}
	loader.once("complete",onDone);
	loader.load();
};
var _$RenderSupportJSPixi_NativeWidgetClip = function() {
	PIXI.Container.call(this);
};
_$RenderSupportJSPixi_NativeWidgetClip.__name__ = true;
_$RenderSupportJSPixi_NativeWidgetClip.__super__ = PIXI.Container;
_$RenderSupportJSPixi_NativeWidgetClip.prototype = $extend(PIXI.Container.prototype,{
	getWidth: function() {
		return 0.0;
	}
	,getHeight: function() {
		return 0.0;
	}
	,onStageMouseDown: function(global_mouse_pos) {
	}
	,updateNativeWidget: function() {
		if(this.parent == null && this.nativeWidget.parentNode != null) this.deleteNativeWidget(); else {
			if(this.worldVisible) {
				var lt = this.toGlobal(new PIXI.Point(0.0,0.0));
				this.nativeWidget.style.left = "" + lt.x + "px";
				this.nativeWidget.style.top = "" + lt.y + "px";
				var rb = this.toGlobal(new PIXI.Point(this.getWidth(),this.getHeight()));
				this.nativeWidget.style.width = "" + (rb.x - lt.x) + "px";
				this.nativeWidget.style.height = "" + (rb.y - lt.y) + "px";
				this.nativeWidget.style.opacity = this.worldAlpha;
			}
			if(this.worldVisible) this.nativeWidget.style.display = ""; else this.nativeWidget.style.display = "none";
		}
	}
	,createNativeWidget: function(node_name) {
		this.nativeWidget = window.document.createElement(node_name);
		window.document.body.appendChild(this.nativeWidget);
		this.nativeWidget.style.position = "fixed";
		RenderSupportJSPixi.registerNativeWidgetClip(this);
	}
	,deleteNativeWidget: function() {
		window.document.body.removeChild(this.nativeWidget);
		RenderSupportJSPixi.unregisterNativeWidgetClip(this);
		this.nativeWidget = null;
	}
	,addNativeEventListener: function(event,fn) {
		var _g = this;
		this.nativeWidget.addEventListener(event,fn);
		return function() {
			_g.nativeWidget.removeEventListener(event,fn);
		};
	}
	,setFocus: function(focus) {
		var _g = this;
		haxe_Timer.delay(function() {
			if(_g.nativeWidget != null) {
				if(focus) _g.nativeWidget.focus(); else _g.nativeWidget.blur();
			}
		},500);
	}
	,getFocus: function() {
		return this.nativeWidget != null && window.document.activeElement == this.nativeWidget;
	}
	,requestFullScreen: function() {
		if(this.nativeWidget != null) {
			if(this.nativeWidget.requestFullscreen != null) this.nativeWidget.requestFullscreen(); else if(this.nativeWidget.mozRequestFullScreen != null) this.nativeWidget.mozRequestFullScreen(); else if(this.nativeWidget.webkitRequestFullscreen != null) this.nativeWidget.webkitRequestFullscreen();
		}
	}
	,exitFullScreen: function() {
		if(this.nativeWidget != null) {
			if(this.nativeWidget.exitFullScreen != null) this.nativeWidget.exitFullScreen(); else if(this.nativeWidget.mozExitFullScreen != null) this.nativeWidget.mozExitFullScreen(); else if(this.nativeWidget.webkitExitFullScreen != null) this.nativeWidget.webkitExitFullScreen();
		}
	}
	,__class__: _$RenderSupportJSPixi_NativeWidgetClip
});
var _$RenderSupportJSPixi_TextField = function() {
	this.TextInputFiltersInitialized = false;
	this.TextInputFilters = [];
	this.background = null;
	this.init_text = null;
	this.type = "text";
	this.multiline = false;
	this.fillOpacity = 1.0;
	this.backgroundOpacity = 0.0;
	this.backgroundColor = 0;
	this.fontSize = 16.0;
	this.fieldWidth = null;
	this.fieldHeight = null;
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
};
_$RenderSupportJSPixi_TextField.__name__ = true;
_$RenderSupportJSPixi_TextField.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_TextField.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	updateNativeWidget: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this);
		if(this.nativeWidget != null && this.worldVisible) {
			var one = this.toGlobal(_$RenderSupportJSPixi_TextField.One);
			var zerro = this.toGlobal(_$RenderSupportJSPixi_TextField.Zerro);
			var scale_y = one.y - zerro.y;
			this.nativeWidget.style.fontSize = "" + this.fontSize * scale_y + "px";
		}
	}
	,getDescription: function() {
		if(this.nativeWidget != null) return "TextField (text = \"" + Std.string(this.nativeWidget.value) + "\")"; else return "TextField (text = \"" + this.init_text + "\")";
	}
	,isInput: function() {
		return this.nativeWidget != null;
	}
	,onStageMouseDown: function(global_mouse_pos) {
		var local = this.toLocal(global_mouse_pos);
		if(local.x > 0.0 && local.y > 0.0 && local.x < this.getWidth() && local.y < this.getHeight()) this.setFocus(true);
	}
	,setTextAndStyle: function(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity) {
		this.fontSize = fontsize;
		this.init_text = text;
		this.backgroundColor = backgroundcolour;
		this.backgroundOpacity = backgroundopacity;
		this.fillOpacity = fillopacity;
		if(this.nativeWidget != null) {
			this.nativeWidget.value = text;
			this.nativeWidget.style.fontSize = "" + fontsize + "px";
			var style = FlowFontStyle.fromFlowFont(fontfamily);
			this.nativeWidget.style.fontFamily = style.family;
			this.nativeWidget.style.fontWeight = style.weight;
			this.nativeWidget.style.fontStyle = style.style;
			if(backgroundopacity > 0.0) this.nativeWidget.style.backgroundColor = "#" + StringTools.hex(backgroundcolour,6);
		}
	}
	,setGLText: function(text) {
	}
	,hideGLText: function() {
		this.setRectMask(0.0,0.0);
	}
	,showGLText: function() {
		this.setRectMask(this.getWidth(),this.getHeight());
	}
	,setRectMask: function(width,height) {
		if(this.mask != null) this.removeChild(this.mask);
		this.mask = new PIXI.Graphics();
		this.mask.beginFill(16777215);
		this.mask.drawRect(0.0,0.0,width,height);
		this.mask.endFill();
		this.addChild(this.mask);
	}
	,setTextInput: function() {
		var _g = this;
		this.createNativeWidget("input");
		this.nativeWidget.style.zIndex = -1;
		this.nativeWidget.onfocus = function(e) {
			RenderSupportJSPixi.PixiStageChanged = true;
			_g.hideGLText();
			_g.nativeWidget.style.zIndex = 1;
		};
		this.nativeWidget.onblur = function(e1) {
			RenderSupportJSPixi.PixiStageChanged = true;
			if(_g.nativeWidget.type == "password") _g.setGLText(_g.getBulletsString(_g.nativeWidget.value.length)); else _g.setGLText(_g.nativeWidget.value);
			_g.showGLText();
			_g.nativeWidget.style.zIndex = -1;
		};
		var old_cursor = "auto";
		this.on("mouseover",function() {
			old_cursor = window.document.body.style.cursor;
			window.document.body.style.cursor = "text";
		});
		this.on("mouseout",function() {
			window.document.body.style.cursor = old_cursor;
		});
	}
	,setTextInputType: function(type) {
		this.nativeWidget.type = type;
	}
	,setMultiline: function() {
		if(this.multiline) return;
		this.multiline = true;
		var textarea = window.document.createElement("textarea");
		textarea.style.zIndex = -1;
		textarea.style.resize = "none";
		textarea.style.wordWrap = "normal";
		textarea.style.lineHeight = this.fontSize + "px";
		textarea.style.fontSize = this.nativeWidget.style.fontSize;
		textarea.value = this.nativeWidget.value;
		textarea.onfocus = this.nativeWidget.onfocus;
		textarea.onblur = this.nativeWidget.onblur;
		this.setWordWrap();
		window.document.body.removeChild(this.nativeWidget);
		this.nativeWidget = textarea;
		window.document.body.appendChild(this.nativeWidget);
	}
	,setWordWrap: function() {
	}
	,setWordWrapWidth: function(width) {
	}
	,getWidth: function() {
		if(this.fieldWidth != null) return this.fieldWidth;
		return this.getLocalBounds().width;
	}
	,getHeight: function() {
		if(this.fieldHeight != null) return this.fieldHeight;
		return this.getLocalBounds().height;
	}
	,setWidth: function(w) {
		this.fieldWidth = w;
		if(this.fieldHeight != null && this.nativeWidget != null) this.setRectMask(this.fieldWidth,this.fieldHeight);
		this.setWordWrapWidth(this.fieldWidth);
	}
	,setHeight: function(h) {
		this.fieldHeight = h;
		if(this.fieldWidth != null && this.nativeWidget != null) this.setRectMask(this.fieldWidth,this.fieldHeight);
	}
	,setAutoAlign: function(align) {
		switch(align) {
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
	}
	,setTabIndex: function(index) {
		this.nativeWidget.tabIndex = index;
	}
	,getContent: function() {
		if(this.nativeWidget != null) return this.nativeWidget.value; else return this.init_text;
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
		var _g = this;
		haxe_Timer.delay(function() {
			if(window.document.activeElement == _g.nativeWidget) try {
				_g.nativeWidget.setSelectionRange(start,end);
			} catch( e ) {
				haxe_CallStack.lastException = e;
				if (e instanceof js__$Boot_HaxeError) e = e.val;
			}
		},120);
	}
	,setReadOnly: function(read_only) {
		this.nativeWidget.disabled = read_only;
	}
	,setMaxChars: function(max_charts) {
		this.nativeWidget.maxLength = max_charts;
	}
	,addTextInputFilter: function(filter) {
		var _g = this;
		this.TextInputFilters.push(filter);
		this.initTextInputFilters();
		return function() {
			HxOverrides.remove(_g.TextInputFilters,filter);
		};
	}
	,initTextInputFilters: function() {
		var _g = this;
		if(this.TextInputFiltersInitialized) return;
		this.TextInputFiltersInitialized = true;
		var old_value = this.nativeWidget.value;
		var oninput = function(e) {
			var new_value = _g.nativeWidget.value;
			var _g1 = 0;
			var _g2 = _g.TextInputFilters;
			while(_g1 < _g2.length) {
				var f = _g2[_g1];
				++_g1;
				if(!f(new_value)) {
					_g.nativeWidget.value = old_value;
					return;
				}
			}
			old_value = new_value;
		};
		this.nativeWidget.addEventListener("input",oninput);
	}
	,getTextMetrics: function() {
		var ascent = 0.9 * this.fontSize;
		var descent = 0.1 * this.fontSize;
		var leading = 0.15 * this.fontSize;
		return [ascent,descent,leading];
	}
	,getBulletsString: function(l) {
		var bullet = String.fromCharCode(8226);
		var i = 0;
		var ret = "";
		var _g = 0;
		while(_g < l) {
			var i1 = _g++;
			ret += bullet;
		}
		return ret;
	}
	,setTextBackground: function() {
		if(this.background != null) {
			this.removeChild(this.background);
			this.background = null;
		}
		if(this.backgroundOpacity > 0.0) {
			var rect = new PIXI.Graphics();
			var text_bounds = this.getLocalBounds();
			rect.beginFill(this.backgroundColor,this.backgroundOpacity);
			rect.drawRect(0.0,0.0,text_bounds.width,text_bounds.height);
			rect.endFill();
			this.addChildAt(rect,0);
			this.background = rect;
		}
	}
	,__class__: _$RenderSupportJSPixi_TextField
});
var _$RenderSupportJSPixi_VideoClip = function(width,height,metricsFn,durationFn) {
	this.StartPaused = false;
	this.SpriteCreated = false;
	this.videoHeight = 0;
	this.videoWidth = 0;
	var _g = this;
	_$RenderSupportJSPixi_NativeWidgetClip.call(this);
	this.createNativeWidget("video");
	var strict_size = width > 0.0 && height > 0.0;
	if(strict_size) {
		this.videoWidth = width;
		this.nativeWidget.width = this.videoWidth;
		this.videoHeight = height;
		this.nativeWidget.height = this.videoHeight;
		metricsFn(this.videoWidth,this.videoHeight);
	}
	this.nativeWidget.addEventListener("loadedmetadata",function(e) {
		durationFn(_g.nativeWidget.duration);
		if(!strict_size) {
			_g.videoWidth = _g.nativeWidget.videoWidth;
			_g.videoHeight = _g.nativeWidget.videoHeight;
			metricsFn(_g.videoWidth,_g.videoHeight);
			_g.updateNativeWidget();
		}
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures && !_g.SpriteCreated) {
			var video_texture = PIXI.Texture.fromVideo(_g.nativeWidget);
			var video_sprite = new PIXI.Sprite(video_texture);
			video_sprite.width = _g.videoWidth;
			video_sprite.height = _g.videoHeight;
			_g.addChild(video_sprite);
			_g.SpriteCreated = true;
			if(_g.StartPaused) video_texture.baseTexture.on("loaded",function() {
				_g.pauseVideo();
			});
		}
	},false);
};
_$RenderSupportJSPixi_VideoClip.__name__ = true;
_$RenderSupportJSPixi_VideoClip.NeedsDrawing = function() {
	return _$RenderSupportJSPixi_VideoClip.UsePixiTextures && _$RenderSupportJSPixi_VideoClip.VideosOnStage > 0;
};
_$RenderSupportJSPixi_VideoClip.__super__ = _$RenderSupportJSPixi_NativeWidgetClip;
_$RenderSupportJSPixi_VideoClip.prototype = $extend(_$RenderSupportJSPixi_NativeWidgetClip.prototype,{
	updateNativeWidget: function() {
		if(!_$RenderSupportJSPixi_VideoClip.UsePixiTextures) _$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this); else if(this.parent == null && this.nativeWidget.parentNode != null) this.deleteNativeWidget();
	}
	,createNativeWidget: function(node) {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.createNativeWidget.call(this,node);
		if(_$RenderSupportJSPixi_VideoClip.UsePixiTextures) this.nativeWidget.style.display = "none";
		++_$RenderSupportJSPixi_VideoClip.VideosOnStage;
	}
	,deleteNativeWidget: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.deleteNativeWidget.call(this);
		--_$RenderSupportJSPixi_VideoClip.VideosOnStage;
	}
	,getDescription: function() {
		return "VideoClip (url = " + Std.string(this.nativeWidget.url) + ")";
	}
	,setVolume: function(volume) {
		this.nativeWidget.volume = volume;
	}
	,playVideo: function(filename,startPaused) {
		this.nativeWidget.src = filename;
		this.StartPaused = startPaused;
		if(!this.StartPaused) this.nativeWidget.play();
	}
	,setCurrentTime: function(time) {
		this.nativeWidget.currentTime = time;
	}
	,getCurrentTime: function() {
		return this.nativeWidget.currentTime;
	}
	,pauseVideo: function() {
		this.nativeWidget.pause();
	}
	,resumeVideo: function() {
		this.nativeWidget.play();
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
		this.nativeWidget.addEventListener("loadeddata",on_start);
		this.nativeWidget.addEventListener("ended",on_stop);
		this.nativeWidget.addEventListener("error",on_not_found);
		return function() {
			_g.nativeWidget.removeEventListener("loadeddata",on_start);
			_g.nativeWidget.removeEventListener("ended",on_stop);
			_g.nativeWidget.removeEventListener("error",on_not_found);
		};
	}
	,getWidth: function() {
		return this.videoWidth;
	}
	,getHeight: function() {
		return this.videoHeight;
	}
	,__class__: _$RenderSupportJSPixi_VideoClip
});
var _$RenderSupportJSPixi_DebugClipsTree = function() {
	this.UpdateTimer = null;
	this.ClipBoundsRect = null;
	this.DebugWin = null;
	this.TreeDiv = null;
	var _g = this;
	this.DebugWin = window.open("","","width=800,height=500");
	var expandall_button = window.document.createElement("button");
	expandall_button.innerHTML = "Expand All";
	expandall_button.onclick = function(e) {
		_g.expandAll(_g.TreeDiv.firstChild);
	};
	this.DebugWin.document.body.appendChild(expandall_button);
	var collapseall_button = window.document.createElement("button");
	collapseall_button.innerHTML = "Collapse All";
	collapseall_button.onclick = function(e1) {
		_g.collapseAll(_g.TreeDiv.firstChild);
	};
	this.DebugWin.document.body.appendChild(collapseall_button);
	this.TreeDiv = window.document.createElement("div");
	this.DebugWin.document.body.appendChild(this.TreeDiv);
	this.ClipBoundsRect = window.document.createElement("div");
	this.ClipBoundsRect.style.position = "fixed";
	this.ClipBoundsRect.style.backgroundColor = "rgba(255, 0, 0, 0.5)";
	window.document.body.appendChild(this.ClipBoundsRect);
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
		if(item.getDescription) description.innerHTML = item.getDescription(); else if(item.graphicsData) description.innerHTML = "Graphics"; else description.innerHTML = "Clip";
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
var RenderSupportJSPixi = function() { };
RenderSupportJSPixi.__name__ = true;
RenderSupportJSPixi.isFirefox = function() {
	var useragent = window.navigator.userAgent.toLowerCase();
	return useragent.indexOf("firefox") >= 0;
};
RenderSupportJSPixi.defer = function(fn,time) {
	if(time == null) time = 10;
	haxe_Timer.delay(fn,time);
};
RenderSupportJSPixi.registerNativeWidgetClip = function(clip) {
	RenderSupportJSPixi.NativeWidgetClips.push(clip);
};
RenderSupportJSPixi.unregisterNativeWidgetClip = function(clip) {
	HxOverrides.remove(RenderSupportJSPixi.NativeWidgetClips,clip);
};
RenderSupportJSPixi.registerAccessWidgetClip = function(clip) {
	RenderSupportJSPixi.AccessWidgetClips.push(clip);
};
RenderSupportJSPixi.unregisterAccessWidgetClip = function(clip) {
	HxOverrides.remove(RenderSupportJSPixi.AccessWidgetClips,clip);
};
RenderSupportJSPixi.init = function() {
	if(Util.getParameter("oldjs") != "1") RenderSupportJSPixi.initPixiRenderer(); else RenderSupportJSPixi.defer(RenderSupportJSPixi.StartFlowMain);
	return true;
};
RenderSupportJSPixi.printOptionValues = function() {
	if(RenderSupportJSPixi.DebugMode) Errors.print("Flow Pixi renderer DEBUG mode is turned on");
	if(RenderSupportJSPixi.CacheTextsAsBitmap) Errors.print("Caches all textclips as bitmap is turned on");
};
RenderSupportJSPixi.initPixiRenderer = function() {
	var options = { antialias : RenderSupportJSPixi.Antialias, transparent : false, backgroundColor : 16777215, preserveDrawingBuffer : false};
	if(RenderSupportJSPixi.RendererType == "auto") RenderSupportJSPixi.PixiRenderer = PIXI.autoDetectRenderer(window.innerWidth,window.innerHeight,options); else if(RenderSupportJSPixi.RendererType == "webgl") RenderSupportJSPixi.PixiRenderer = new PIXI.WebGLRenderer(window.innerWidth,window.innerHeight,options); else RenderSupportJSPixi.PixiRenderer = new PIXI.CanvasRenderer(window.innerWidth,window.innerHeight,options);
	window.document.body.appendChild(RenderSupportJSPixi.PixiRenderer.view);
	RenderSupportJSPixi.initPixiStageEventListeners();
	RenderSupportJSPixi.initBrowserWindowEventListeners();
	FontLoader.LoadFonts(RenderSupportJSPixi.UseDFont,RenderSupportJSPixi.StartFlowMain);
	RenderSupportJSPixi.initClipboardListeners();
	_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap = RenderSupportJSPixi.CacheTextsAsBitmap;
	_$RenderSupportJSPixi_VideoClip.UsePixiTextures = RenderSupportJSPixi.UseVideoTextures;
	RenderSupportJSPixi.printOptionValues();
	if(RenderSupportJSPixi.PixiRenderer.plugins != null && RenderSupportJSPixi.PixiRenderer.plugins.accessibility != null) {
		RenderSupportJSPixi.PixiRenderer.plugins.accessibility.destroy();
		RenderSupportJSPixi.PixiRenderer.plugins.accessibility = null;
	}
	window.requestAnimationFrame(RenderSupportJSPixi.animate);
};
RenderSupportJSPixi.initBrowserWindowEventListeners = function() {
	RenderSupportJSPixi.WindowTopHeight = window.screen.height - window.innerHeight;
	window.addEventListener("resize",RenderSupportJSPixi.onBrowserWindowResize);
	window.addEventListener("message",RenderSupportJSPixi.receiveWindowMessage);
};
RenderSupportJSPixi.initClipboardListeners = function() {
	var handler;
	var handlePaste = function(e) {
		if(window.clipboardData && window.clipboardData.getData) NativeHx.clipboardData = window.clipboardData.getData("Text"); else if(e.clipboardData && e.clipboardData.getData) NativeHx.clipboardData = e.clipboardData.getData("text/plain"); else NativeHx.clipboardData = "";
	};
	handler = handlePaste;
	window.document.addEventListener("paste",handler,false);
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
	Errors.report("Warning: unknow message source");
};
RenderSupportJSPixi.onBrowserWindowResize = function(e) {
	RenderSupportJSPixi.PixiStageChanged = true;
	RenderSupportJSPixi.PixiStageSizeChanged = true;
	if(RenderSupportJSPixi.isAndroid) RenderSupportJSPixi.PixiRenderer.resize(window.screen.width,window.screen.height - RenderSupportJSPixi.WindowTopHeight); else RenderSupportJSPixi.PixiRenderer.resize(window.innerWidth,window.innerHeight);
	var _g = 0;
	var _g1 = RenderSupportJSPixi.PixiStageEventListeners.get("resize");
	while(_g < _g1.length) {
		var l = _g1[_g];
		++_g;
		l();
	}
};
RenderSupportJSPixi.dropCurrentFocus = function() {
	if(window.document.activeElement != null) window.document.activeElement.blur();
};
RenderSupportJSPixi.nativeWidgetsOnMouseDown = function() {
	var _g = 0;
	var _g1 = RenderSupportJSPixi.NativeWidgetClips;
	while(_g < _g1.length) {
		var c = _g1[_g];
		++_g;
		c.onStageMouseDown(RenderSupportJSPixi.MousePos);
	}
};
RenderSupportJSPixi.initPixiStageEventListeners = function() {
	RenderSupportJSPixi.PixiStageEventListeners = new haxe_ds_StringMap();
	var mdl = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("mousedown",mdl);
	var mml = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("mousemove",mml);
	var mul = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("mouseup",mul);
	var value = [];
	RenderSupportJSPixi.PixiStageEventListeners.set("resize",value);
	if(NativeHx.isTouchScreen()) {
		RenderSupportJSPixi.setStagePointerHandler("touchstart",mdl);
		RenderSupportJSPixi.setStagePointerHandler("touchmove",mml);
		RenderSupportJSPixi.setStagePointerHandler("touchend",mul);
	} else {
		RenderSupportJSPixi.setStagePointerHandler("mousedown",mdl);
		RenderSupportJSPixi.setStagePointerHandler("mousemove",mml);
		RenderSupportJSPixi.setStagePointerHandler("mouseup",mul);
		RenderSupportJSPixi.setStagePointerHandler("mouseout",mul);
	}
	mdl.push(function() {
		RenderSupportJSPixi.MouseUpReceived = false;
	});
	mul.push(function() {
		RenderSupportJSPixi.MouseUpReceived = true;
	});
	mdl.push(RenderSupportJSPixi.nativeWidgetsOnMouseDown);
	mdl.push(RenderSupportJSPixi.dropCurrentFocus);
};
RenderSupportJSPixi.setStagePointerHandler = function(event,listeners) {
	var cb;
	switch(event) {
	case "touchstart":case "touchmove":
		cb = function(e) {
			if(e.touches.length == 1) {
				RenderSupportJSPixi.MousePos.x = e.touches[0].pageX;
				RenderSupportJSPixi.MousePos.y = e.touches[0].pageY;
				var _g = 0;
				while(_g < listeners.length) {
					var l = listeners[_g];
					++_g;
					l();
				}
			}
		};
		break;
	case "touchend":
		cb = function(e1) {
			if(e1.touches.length == 0) {
				var _g1 = 0;
				while(_g1 < listeners.length) {
					var l1 = listeners[_g1];
					++_g1;
					l1();
				}
			}
		};
		break;
	case "mouseout":
		cb = function(e2) {
			if(RenderSupportJSPixi.MouseUpReceived) return;
			var _g2 = 0;
			while(_g2 < listeners.length) {
				var l2 = listeners[_g2];
				++_g2;
				l2();
			}
		};
		break;
	default:
		cb = function(e3) {
			RenderSupportJSPixi.MousePos.x = e3.pageX;
			RenderSupportJSPixi.MousePos.y = e3.pageY;
			var _g3 = 0;
			while(_g3 < listeners.length) {
				var l3 = listeners[_g3];
				++_g3;
				l3();
			}
		};
	}
	RenderSupportJSPixi.PixiRenderer.view.addEventListener(event,cb);
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
RenderSupportJSPixi.emulateMouseClickOnClip = function(clip) {
	var b = clip.getBounds();
	RenderSupportJSPixi.MousePos = clip.toGlobal(new PIXI.Point(b.width / 2.0,b.height / 2.0));
	RenderSupportJSPixi.defer(function() {
		var _g = 0;
		var _g1 = RenderSupportJSPixi.PixiStageEventListeners.get("mousemove");
		while(_g < _g1.length) {
			var l = _g1[_g];
			++_g;
			l();
		}
	});
	RenderSupportJSPixi.defer(function() {
		RenderSupportJSPixi.emitForInteractives(clip,"mouseover");
	},100);
	RenderSupportJSPixi.defer(function() {
		var _g2 = 0;
		var _g11 = RenderSupportJSPixi.PixiStageEventListeners.get("mousedown");
		while(_g2 < _g11.length) {
			var l1 = _g11[_g2];
			++_g2;
			l1();
		}
	},400);
	RenderSupportJSPixi.defer(function() {
		var _g3 = 0;
		var _g12 = RenderSupportJSPixi.PixiStageEventListeners.get("mouseup");
		while(_g3 < _g12.length) {
			var l2 = _g12[_g3];
			++_g3;
			l2();
		}
	},500);
	RenderSupportJSPixi.defer(function() {
		RenderSupportJSPixi.emitForInteractives(clip,"mouseout");
	},600);
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
RenderSupportJSPixi.StartFlowMain = function() {
	Errors.print("Starting flow main.");
	window.flow_main();
};
RenderSupportJSPixi.animate = function(timestamp) {
	window.requestAnimationFrame(RenderSupportJSPixi.animate);
	if(RenderSupportJSPixi.PixiStageChanged && RenderSupportJSPixi.StageChangedTimestamp < 0) RenderSupportJSPixi.StageChangedTimestamp = timestamp;
	if(RenderSupportJSPixi.PixiStageChanged && timestamp - RenderSupportJSPixi.StageChangedTimestamp >= 40.0 || _$RenderSupportJSPixi_VideoClip.UsePixiTextures && _$RenderSupportJSPixi_VideoClip.VideosOnStage > 0 || RenderSupportJSPixi.PixiStageSizeChanged) {
		RenderSupportJSPixi.PixiStageChanged = false;
		RenderSupportJSPixi.StageChangedTimestamp = -1.0;
		if(RenderSupportJSPixi.isAndroid && RenderSupportJSPixi.PixiStageSizeChanged) RenderSupportJSPixi.PixiStage.y = 0.0;
		RenderSupportJSPixi.PixiRenderer.render(RenderSupportJSPixi.PixiStage);
		RenderSupportJSPixi.updateNativeWidgets();
		if(RenderSupportJSPixi.DebugMode) {
			RenderSupportJSPixi.updateAccessWidgets();
			RenderSupportJSPixi.updatePixiCanvasAccessElements();
		}
		if(RenderSupportJSPixi.isAndroid && RenderSupportJSPixi.PixiStageSizeChanged) RenderSupportJSPixi.ensureCurrentInputVisible();
		RenderSupportJSPixi.PixiStageSizeChanged = false;
		if(RenderSupportJSPixi.ShowDebugClipsTree) _$RenderSupportJSPixi_DebugClipsTree.getInstance().updateTree(RenderSupportJSPixi.PixiStage);
	}
};
RenderSupportJSPixi.updateNativeWidgets = function() {
	var len = RenderSupportJSPixi.NativeWidgetClips.length;
	var _g = 0;
	while(_g < len) {
		var i = _g++;
		RenderSupportJSPixi.NativeWidgetClips[len - 1 - i].updateNativeWidget();
	}
};
RenderSupportJSPixi.updateAccessWidgets = function() {
	var len = RenderSupportJSPixi.AccessWidgetClips.length;
	var _g = 0;
	while(_g < len) {
		var i = _g++;
		RenderSupportJSPixi.AccessWidgetClips[len - 1 - i].updateAccessWidget();
	}
};
RenderSupportJSPixi.updatePixiCanvasAccessElements = function() {
	RenderSupportJSPixi.PixiRenderer.view.innerHTML = "";
	if(RenderSupportJSPixi.UpdatePixiCanvasAccessElementsTimer != null) RenderSupportJSPixi.UpdatePixiCanvasAccessElementsTimer.stop();
	RenderSupportJSPixi.UpdatePixiCanvasAccessElementsTimer = haxe_Timer.delay(function() {
		RenderSupportJSPixi.doUpdatePixiCanvasAccessElements(RenderSupportJSPixi.PixiStage);
	},1000);
};
RenderSupportJSPixi.doUpdatePixiCanvasAccessElements = function(clip) {
	if(clip.isInput != null && clip.isInput() == false) {
		var p = window.document.createElement("p");
		p.innerHTML = clip.getContent();
		RenderSupportJSPixi.PixiRenderer.view.appendChild(p);
		return;
	}
	if(clip.children != null && clip.children.length > 0) {
		var childs = clip.children;
		var _g = 0;
		while(_g < childs.length) {
			var c = childs[_g];
			++_g;
			RenderSupportJSPixi.doUpdatePixiCanvasAccessElements(c);
		}
	}
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
			if(val == "button" || val == "checkbox") {
				window.document.body.removeChild(clip.accessWidget);
				var old_access_widget = clip.accessWidget;
				clip.accessWidget = window.document.createElement("button");
				clip.accessWidget.style.backgroundColor = "transparent";
				clip.accessWidget.style.position = "fixed";
				clip.accessWidget.style.borderStyle = "none";
				clip.accessWidget.style.pointerEvents = "none";
				clip.accessWidget.onclick = function() {
					if(clip.accessCallback != null) clip.accessCallback(); else RenderSupportJSPixi.emulateMouseClickOnClip(clip);
				};
				clip.accessWidget.onfocus = function() {
					clip.accessWidget.style.borderStyle = "solid";
				};
				clip.accessWidget.onblur = function() {
					clip.accessWidget.style.borderStyle = "none";
				};
				window.document.body.appendChild(clip.accessWidget);
				clip.accessWidget.tabIndex = old_access_widget.tabIndex;
				var old_label = old_access_widget.getAttribute("aria-label");
				if(old_label != "" && old_label != null) clip.setAttribute("aria-label",old_label);
			}
			clip.accessWidget.setAttribute("role",val);
			break;
		case "description":
			if(val != "") clip.accessWidget.setAttribute("aria-label",val);
			break;
		case "tabindex":
			if(clip.accessWidget.tabIndex != val) clip.accessWidget.tabIndex = val;
			break;
		case "callback":
			clip.accessCallback = val;
			break;
		}
	}
};
RenderSupportJSPixi.setAccessAttributes = function(clip,attributes) {
	if(!RenderSupportJSPixi.DebugMode) return;
	if(clip.accessWidget == null) {
		RenderSupportJSPixi.PixiStageChanged = true;
		var accessWidget = window.document.createElement("div");
		accessWidget.style.pointerEvents = "none";
		accessWidget.style.position = "fixed";
		clip.accessWidget = accessWidget;
		window.document.body.appendChild(accessWidget);
		clip.updateAccessWidget = function() {
			if(clip.parent == null) {
				window.document.body.removeChild(clip.accessWidget);
				RenderSupportJSPixi.unregisterAccessWidgetClip(clip);
			} else if(clip.worldVisible) {
				var bounds = clip.getBounds();
				clip.accessWidget.style.display = "block";
				clip.accessWidget.style.left = "" + bounds.x + "px";
				clip.accessWidget.style.top = "" + bounds.y + "px";
				clip.accessWidget.style.width = "" + bounds.width + "px";
				clip.accessWidget.style.height = "" + bounds.height + "px";
			} else clip.accessWidget.style.display = "none";
		};
		RenderSupportJSPixi.registerAccessWidgetClip(clip);
	}
	RenderSupportJSPixi.addAccessAttributes(clip,attributes);
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
	return RenderSupportJSPixi.PixiRenderer.width;
};
RenderSupportJSPixi.getStageHeight = function() {
	return RenderSupportJSPixi.PixiRenderer.height;
};
RenderSupportJSPixi.makeTextField = function() {
	if(RenderSupportJSPixi.UseDFont) return new _$RenderSupportJSPixi_DFontText(); else return new _$RenderSupportJSPixi_PixiText();
};
RenderSupportJSPixi.setTextAndStyle = function(textfield,text,fontfamily,fontsize,fillcolor,fillopacity,letterspacing,backgroundcolour,backgroundopacity,forTextinput) {
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setTextAndStyle(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity);
};
RenderSupportJSPixi.setAdvancedText = function(textfield,sharpness,antialiastype,gridfittype) {
};
RenderSupportJSPixi.makeVideo = function(width,height,metricsFn,durationFn) {
	var vc = new _$RenderSupportJSPixi_VideoClip(width,height,metricsFn,durationFn);
	return [vc,vc];
};
RenderSupportJSPixi.setVideoVolume = function(str,volume) {
	str.setVolume(volume);
};
RenderSupportJSPixi.setVideoLooping = function(str,loop) {
};
RenderSupportJSPixi.setVideoControls = function(str,controls) {
};
RenderSupportJSPixi.setVideoSubtitle = function(str,text,size,color) {
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
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setWidth(width);
};
RenderSupportJSPixi.getTextFieldHeight = function(textfield) {
	return textfield.getHeight();
};
RenderSupportJSPixi.setTextFieldHeight = function(textfield,height) {
	RenderSupportJSPixi.PixiStageChanged = true;
	if(height > 0.0) textfield.setHeight(height);
};
RenderSupportJSPixi.setAutoAlign = function(textfield,autoalign) {
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setAutoAlign(autoalign);
};
RenderSupportJSPixi.setTextInput = function(textfield) {
	RenderSupportJSPixi.PixiStageChanged = true;
	textfield.setTextInput();
};
RenderSupportJSPixi.setTextInputType = function(textfield,type) {
	textfield.setTextInputType(type);
};
RenderSupportJSPixi.setTabIndex = function(textfield,index) {
	textfield.setTabIndex(index);
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
RenderSupportJSPixi.setFocus = function(textfield,focus) {
	textfield.setFocus(focus);
};
RenderSupportJSPixi.setMultiline = function(textfield,multiline) {
	if(multiline) {
		RenderSupportJSPixi.PixiStageChanged = true;
		textfield.setMultiline();
	}
};
RenderSupportJSPixi.setWordWrap = function(textfield,wordWrap) {
	textfield.setWordWrap();
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
RenderSupportJSPixi.addChild = function(parent,child) {
	RenderSupportJSPixi.PixiStageChanged = true;
	parent.addChild(child);
};
RenderSupportJSPixi.removeChild = function(parent,child) {
	RenderSupportJSPixi.PixiStageChanged = true;
	parent.removeChild(child);
};
RenderSupportJSPixi.makeClip = function() {
	return new PIXI.Container();
};
RenderSupportJSPixi.setClipCallstack = function(clip,callstack) {
};
RenderSupportJSPixi.setClipX = function(clip,x) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.x = x;
};
RenderSupportJSPixi.setClipY = function(clip,y) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.y = y;
};
RenderSupportJSPixi.setClipScaleX = function(clip,scale_x) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.scale.x = scale_x;
};
RenderSupportJSPixi.setClipScaleY = function(clip,scale_y) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.scale.y = scale_y;
};
RenderSupportJSPixi.setClipRotation = function(clip,r) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.rotation = r * 0.0174532925;
};
RenderSupportJSPixi.setClipAlpha = function(clip,a) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.alpha = a;
};
RenderSupportJSPixi.getDisplayObjectGraphics = function(clip) {
	if(clip.graphics != null) return clip.graphics;
	if(clip.children == null) return null;
	var _g = 0;
	var _g1 = clip.children;
	while(_g < _g1.length) {
		var c = _g1[_g];
		++_g;
		var g = RenderSupportJSPixi.getDisplayObjectGraphics(c);
		if(g != null) return g;
	}
	return null;
};
RenderSupportJSPixi.setClipMask = function(clip,mask) {
	RenderSupportJSPixi.PixiStageChanged = true;
	clip.mask = RenderSupportJSPixi.getDisplayObjectGraphics(mask);
	if(clip.mask == null) mask.visible = false;
};
RenderSupportJSPixi.getStage = function() {
	return RenderSupportJSPixi.PixiStage;
};
RenderSupportJSPixi.addKeyEventListener = function(clip,event,fn) {
	var keycb = function(e) {
		var shift = e.shiftKey;
		var alt = e.altKey;
		var ctrl = e.ctrlKey;
		var s = "";
		if(e.which >= 112 && e.which <= 123) s = "F" + (e.which - 111); else {
			var _g = e.which;
			switch(_g) {
			case 13:
				s = "enter";
				break;
			case 27:
				s = "esc";
				break;
			case 9:
				s = "tab";
				break;
			case 16:
				s = "shift";
				break;
			case 17:
				s = "ctrl";
				break;
			case 18:
				s = "alt";
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
			default:
				s = String.fromCharCode(e.which);
			}
		}
		fn(s,ctrl,shift,alt,e.keyCode);
	};
	window.addEventListener(event,keycb);
	return function() {
		window.removeEventListener(event,keycb);
	};
};
RenderSupportJSPixi.addStreamStatusListener = function(clip,fn) {
	return clip.addStreamStatusListener(fn);
};
RenderSupportJSPixi.addEventListener = function(clip,event,fn) {
	if(event == "resize" || event == "mousedown" || event == "mousemove" || event == "mouseup") {
		RenderSupportJSPixi.PixiStageEventListeners.get(event).push(fn);
		return function() {
			var _this = RenderSupportJSPixi.PixiStageEventListeners.get(event);
			HxOverrides.remove(_this,fn);
		};
	} else if(event == "rollover") {
		clip.interactive = true;
		var on_mouseover = function(d) {
			fn();
		};
		clip.on("mouseover",on_mouseover);
		return function() {
			clip.off("mouseover",on_mouseover);
		};
	} else if(event == "rollout") {
		clip.interactive = true;
		var on_mouseout = function(d1) {
			fn();
		};
		clip.on("mouseout",on_mouseout);
		return function() {
			clip.off("mouseout",on_mouseout);
		};
	} else if(event == "scroll") return clip.addNativeEventListener("scroll",fn); else if(event == "change") return clip.addNativeEventListener("input",fn); else if(event == "focusin") return clip.addNativeEventListener("focus",fn); else if(event == "focusout") return clip.addNativeEventListener("blur",fn); else {
		Errors.report("Unknown event: " + event);
		return function() {
		};
	}
};
RenderSupportJSPixi.addMouseWheelEventListener = function(clip,fn) {
	var wheel_cb = function(event) {
		var delta = 0.0;
		if(event.wheelDelta != null) delta = event.wheelDelta / 120; else if(event.detail != null) delta = -event.detail / 3;
		if(event.preventDefault != null) event.preventDefault();
		fn(delta);
	};
	if(!RenderSupportJSPixi.isFirefox()) {
		window.addEventListener("mousewheel",wheel_cb);
		return function() {
			window.removeEventListener("mousewheel",wheel_cb);
		};
	} else {
		window.addEventListener("DOMMouseScroll",wheel_cb);
		return function() {
			window.removeEventListener("DOMMouseScroll",wheel_cb);
		};
	}
};
RenderSupportJSPixi.addFinegrainMouseWheelEventListener = function(clip,f) {
	return RenderSupportJSPixi.addMouseWheelEventListener(clip,function(delta) {
		f(delta,0);
	});
};
RenderSupportJSPixi.getMouseX = function(clip) {
	if(clip == RenderSupportJSPixi.PixiStage) return RenderSupportJSPixi.MousePos.x; else return clip.toLocal(RenderSupportJSPixi.MousePos).x;
};
RenderSupportJSPixi.getMouseY = function(clip) {
	if(clip == RenderSupportJSPixi.PixiStage) return RenderSupportJSPixi.MousePos.y; else return clip.toLocal(RenderSupportJSPixi.MousePos).y;
};
RenderSupportJSPixi.hittestGraphics = function(g,global) {
	var graphicsData = g.graphicsData;
	var local = g.toLocal(global);
	var _g = 0;
	while(_g < graphicsData.length) {
		var data = graphicsData[_g];
		++_g;
		if(data.fill && data.shape != null && data.shape.contains(local.x,local.y)) return true;
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
RenderSupportJSPixi.getGraphics = function(clip) {
	var g = new PIXI.Graphics();
	RenderSupportJSPixi.moveTo(g,0.0,0.0);
	clip.addChild(g);
	clip.graphics = g;
	return g;
};
RenderSupportJSPixi.setLineStyle = function(graphics,width,color,opacity) {
	graphics.lineStyle(width,color,opacity);
};
RenderSupportJSPixi.setLineStyle2 = function(graphics,width,color,opacity,pixelHinting) {
	RenderSupportJSPixi.setLineStyle(graphics,width,color,opacity);
};
RenderSupportJSPixi.beginFill = function(graphics,color,opacity) {
	graphics.beginFill(color,opacity);
};
RenderSupportJSPixi.beginGradientFill = function(graphics,colors,alphas,offsets,matrix,type) {
	RenderSupportJSPixi.beginFill(graphics,colors[0],alphas[0]);
};
RenderSupportJSPixi.setLineGradientStroke = function(graphics,colours,alphas,offsets,matrix) {
	RenderSupportJSPixi.setLineStyle(graphics,1.0,colours[0],alphas[0]);
};
RenderSupportJSPixi.makeMatrix = function(width,height,rotation,xOffset,yOffset) {
	return null;
};
RenderSupportJSPixi.moveTo = function(graphics,x,y) {
	graphics.moveTo(x,y);
	graphics.pen_x = x;
	graphics.pen_y = y;
};
RenderSupportJSPixi.lineTo = function(graphics,x,y) {
	graphics.lineTo(x,y);
	graphics.pen_x = x;
	graphics.pen_y = y;
};
RenderSupportJSPixi.curveTo = function(graphics,cx,cy,x,y) {
	x += 0.01;
	y += 0.01;
	var qcx1 = graphics.pen_x + 0.66666666666666663 * (cx - graphics.pen_x);
	var qcy1 = graphics.pen_y + 0.66666666666666663 * (cy - graphics.pen_y);
	var qcx2 = x + 0.66666666666666663 * (cx - x);
	var qcy2 = y + 0.66666666666666663 * (cy - y);
	graphics.bezierCurveTo(qcx1,qcy1,qcx2,qcy2,x,y);
	graphics.pen_x = x;
	graphics.pen_y = y;
};
RenderSupportJSPixi.endFill = function(graphics) {
	graphics.endFill();
};
RenderSupportJSPixi.makePicture = function(url,cache,metricsFn,errorFn,onlyDownload) {
	if(StringTools.endsWith(url,".swf")) url = StringTools.replace(url,".swf",".png");
	var texture = PIXI.Texture.fromImage(url);
	var sprite = new PIXI.Sprite(texture);
	var report_metrics = function() {
		var bounds = sprite.getLocalBounds();
		metricsFn(bounds.width,bounds.height);
	};
	if(texture.baseTexture.hasLoaded) report_metrics(); else texture.on("update",report_metrics);
	return sprite;
};
RenderSupportJSPixi.setCursor = function(clip,cursor) {
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
RenderSupportJSPixi.getCursor = function(clip) {
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
	filters = filters.filter(function(f) {
		return f != null;
	});
	if(filters.length > 0) clip.filters = filters; else clip.filters = null;
};
RenderSupportJSPixi.makeBevel = function(angle,distance,radius,spread,color1,alpha1,color2,alpha2,inside) {
	return null;
};
RenderSupportJSPixi.makeBlur = function(radius,spread) {
	var b = new PIXI.filters.BlurFilter();
	b.blur = spread;
	return b;
};
RenderSupportJSPixi.makeDropShadow = function(angle,distance,radius,spread,color,alpha,inside) {
	var ds = new PIXI.filters.DropShadowFilter();
	ds.angle = angle;
	ds.distance = distance;
	ds.color = color;
	ds.alpha = alpha;
	ds.blur = spread;
	return ds;
};
RenderSupportJSPixi.makeGlow = function(radius,spread,color,alpha,inside) {
	var glow = new PIXI.AbstractFilter(_$RenderSupportJSPixi_Shaders.VertexSrc.join("\n"),_$RenderSupportJSPixi_Shaders.GlowFragmentSrc.join("\n"),{ });
	return glow;
};
RenderSupportJSPixi.setScrollRect = function(clip,left,top,width,height) {
};
RenderSupportJSPixi.makeGraphicsRect = function(width,height) {
	var g = new PIXI.Graphics();
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
RenderSupportJSPixi.setFullScreenTarget = function(clip) {
	if(js_Boot.__instanceof(clip,_$RenderSupportJSPixi_VideoClip)) RenderSupportJSPixi.FullScreenTargetClip = clip;
};
RenderSupportJSPixi.setFullScreenRectangle = function(x,y,w,h) {
};
RenderSupportJSPixi.resetFullScreenTarget = function() {
	RenderSupportJSPixi.FullScreenTargetClip = null;
};
RenderSupportJSPixi.toggleFullScreen = function() {
	if(RenderSupportJSPixi.FullScreenTargetClip != null) {
		if(RenderSupportJSPixi.IsFullScreen) RenderSupportJSPixi.FullScreenTargetClip.exitFullScreen(); else RenderSupportJSPixi.FullScreenTargetClip.requestFullScreen();
		RenderSupportJSPixi.IsFullScreen = !RenderSupportJSPixi.IsFullScreen;
	}
};
RenderSupportJSPixi.onFullScreen = function(fn) {
	return function() {
	};
};
RenderSupportJSPixi.isFullScreen = function() {
	return RenderSupportJSPixi.IsFullScreen;
};
RenderSupportJSPixi.setWindowTitle = function(title) {
	window.document.title = title;
};
RenderSupportJSPixi.takeSnapshot = function(path) {
};
RenderSupportJSPixi.getScreenPixelColor = function(x,y) {
	return 0;
};
RenderSupportJSPixi.makeWebClip = function(url,domain,useCache,reloadBlock,cb,ondone) {
	return new _$RenderSupportJSPixi_WebClip(url,domain,useCache,reloadBlock,cb,ondone);
};
RenderSupportJSPixi.webClipHostCall = function(clip,name,args) {
	return clip.hostCall(name,args);
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
RenderSupportJSPixi.cameraTakePhoto = function(cameraId,additionalInfo,desiredWidth,desiredHeight,compressQuality,fileName) {
};
RenderSupportJSPixi.addGestureListener = function(event,cb) {
	return function() {
	};
};
RenderSupportJSPixi.setWebClipZoomable = function(clip,zoomable) {
};
RenderSupportJSPixi.setInterfaceOrientation = function(orientation) {
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
		window.removeEventListener("hashchanged",wrapper);
	};
};
RenderSupportJSPixi.setGlobalZoomEnabled = function(enabled) {
};
var _$RenderSupportJSPixi_WebClip = function(url,domain,useCache,reloadBlock,cb,ondone) {
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
	if(_$RenderSupportJSPixi_WebClip.isIOS()) {
		this.nativeWidget.style.webkitOverflowScrolling = "touch";
		this.nativeWidget.style.overflowY = "scroll";
	}
	this.iframe = window.document.createElement("iframe");
	this.iframe.src = url;
	this.iframe.allowFullscreen = true;
	this.iframe.frameBorder = "no";
	this.iframe.callflow = cb;
	this.nativeWidget.appendChild(this.iframe);
	if(reloadBlock) this.appendReloadBlock();
	this.iframe.onload = function() {
		try {
			ondone("OK");
			if(_$RenderSupportJSPixi_WebClip.isIOS() && (url.indexOf("flowjs") >= 0 || url.indexOf("lslti_provider") >= 0)) _g.iframe.scrolling = "no";
			_g.iframe.contentWindow.callflow = cb;
			if(_g.iframe.contentWindow.pushCallflowBuffer) _g.iframe.contentWindow.pushCallflowBuffer();
			if(_$RenderSupportJSPixi_WebClip.isIOS() && _g.iframe.contentWindow.setSplashScreen != null) _g.iframe.scrolling = "no";
		} catch( e1 ) {
			haxe_CallStack.lastException = e1;
			if (e1 instanceof js__$Boot_HaxeError) e1 = e1.val;
			Errors.report(e1);
		}
	};
};
_$RenderSupportJSPixi_WebClip.__name__ = true;
_$RenderSupportJSPixi_WebClip.isIOS = function() {
	var ua = window.navigator.userAgent;
	return ua.indexOf("iPhone") != -1 || ua.indexOf("iPad") != -1 || ua.indexOf("iPod") != -1;
};
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
	,updateNativeWidget: function() {
		_$RenderSupportJSPixi_NativeWidgetClip.prototype.updateNativeWidget.call(this);
		if(this.worldVisible && this.nativeWidget != null) {
			this.iframe.style.width = this.nativeWidget.style.width;
			this.iframe.style.height = this.nativeWidget.style.height;
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
		return null;
	}
	,__class__: _$RenderSupportJSPixi_WebClip
});
var FlowFontStyle = function() { };
FlowFontStyle.__name__ = true;
FlowFontStyle.fromFlowFont = function(name) {
	if(FlowFontStyle.flowFontStyles == null) FlowFontStyle.flowFontStyles = JSON.parse(haxe_Resource.getString("fontstyles"));
	var style = Reflect.field(FlowFontStyle.flowFontStyles,name.toLowerCase());
	if(style != null) return style; else return { family : name, weight : "", size : 0.0, style : "normal"};
};
var _$RenderSupportJSPixi_PixiText = function() {
	this.pixi_text = null;
	_$RenderSupportJSPixi_TextField.call(this);
	this.pixi_text = new PIXI.Text("");
	if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) this.pixi_text.cacheAsBitmap = true;
	this.addChild(this.pixi_text);
};
_$RenderSupportJSPixi_PixiText.__name__ = true;
_$RenderSupportJSPixi_PixiText.__super__ = _$RenderSupportJSPixi_TextField;
_$RenderSupportJSPixi_PixiText.prototype = $extend(_$RenderSupportJSPixi_TextField.prototype,{
	setTextAndStyle: function(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity) {
		_$RenderSupportJSPixi_TextField.prototype.setTextAndStyle.call(this,text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity);
		var style = { font : this.getFontString(fontfamily,fontsize < 0.6?0.6:fontsize), fill : "#" + StringTools.hex(fillcolor,6)};
		this.pixi_text.text = text;
		this.pixi_text.style = style;
		this.pixi_text.alpha = this.fillOpacity;
		this.setTextBackground();
	}
	,setGLText: function(t) {
		this.pixi_text.text = t;
	}
	,getFontString: function(fontfamily,fontsize) {
		var style = FlowFontStyle.fromFlowFont(fontfamily);
		style.size = fontsize;
		return "" + style.weight + " " + style.style + " " + style.size + "px " + style.family;
	}
	,setWordWrap: function() {
		this.pixi_text.style.wordWrap = true;
	}
	,setWordWrapWidth: function(wrap_width) {
		this.pixi_text.style.wordWrapWidth = wrap_width;
	}
	,__class__: _$RenderSupportJSPixi_PixiText
});
var _$RenderSupportJSPixi_DFontText = function() {
	this.fontfamily = "Book";
	this.clipWidth = 0.0;
	this.baseline = 14.4;
	this.style = { font : "16px Book", tint : 65793};
	this.text = "";
	this.wordWrapWidth = -1.0;
	this.wordWrap = false;
	_$RenderSupportJSPixi_TextField.call(this);
};
_$RenderSupportJSPixi_DFontText.__name__ = true;
_$RenderSupportJSPixi_DFontText.getDFontInfo = function(fontfamily) {
	return DFontText.dfont_table[fontfamily];
};
_$RenderSupportJSPixi_DFontText.__super__ = _$RenderSupportJSPixi_TextField;
_$RenderSupportJSPixi_DFontText.prototype = $extend(_$RenderSupportJSPixi_TextField.prototype,{
	setTextAndStyle: function(text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity) {
		_$RenderSupportJSPixi_TextField.prototype.setTextAndStyle.call(this,text,fontfamily,fontsize,fillcolor,fillopacity,backgroundcolour,backgroundopacity);
		if(_$RenderSupportJSPixi_DFontText.getDFontInfo(fontfamily) == null) {
			var met = _$RenderSupportJSPixi_DFontText.getDFontInfo("Book");
			if(met != null) {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded. Will use default font");
				DFontText.dfont_table[fontfamily] = met;
				fontfamily = "Book";
			} else {
				Errors.print("Trying to render DFont " + fontfamily + " which is not loaded yet. Default font is not loaded yet too");
				return;
			}
		}
		var metrics = _$RenderSupportJSPixi_DFontText.getDFontInfo(fontfamily);
		this.style.font = this.getFontString(fontfamily,fontsize);
		if(fillcolor != 0) this.style.tint = fillcolor; else this.style.tint = 65793;
		if(this.nativeWidget != null && this.nativeWidget.type == "password") this.text = this.getBulletsString(text.length); else this.text = text;
		this.baseline = metrics.ascender * fontsize;
		this.fontfamily = fontfamily;
		this.layoutText();
	}
	,getFontString: function(fontfamily,fontsize) {
		return fontsize + "px " + fontfamily;
	}
	,getTextMetrics: function() {
		var metrics = _$RenderSupportJSPixi_DFontText.getDFontInfo(this.fontfamily);
		if(metrics == null) return _$RenderSupportJSPixi_TextField.prototype.getTextMetrics.call(this);
		return [metrics.ascender * this.fontSize,metrics.descender * this.fontSize,0.15 * this.fontSize];
	}
	,getWidth: function() {
		if(this.fieldWidth != null) return this.fieldWidth;
		return this.clipWidth;
	}
	,setGLText: function(t) {
		this.text = t;
		this.layoutText();
	}
	,setWordWrap: function() {
		this.wordWrap = true;
		if(this.wordWrap && this.wordWrapWidth > 0.0) this.layoutText();
	}
	,setWordWrapWidth: function(wrap_width) {
		this.wordWrapWidth = wrap_width;
		if(this.wordWrap && this.wordWrapWidth > 0.0) this.layoutText();
	}
	,layoutText: function() {
		if(this.nativeWidget != null && this.mask != null) this.children = [this.mask]; else this.children = [];
		if(this.wordWrapWidth > 0.0 && this.wordWrap) {
			var x = 0.0;
			var y = 0.0;
			this.clipWidth = 0.0;
			var _g = 0;
			var _g1 = this.text.split("\n");
			while(_g < _g1.length) {
				var para = _g1[_g];
				++_g;
				var line_width = 0.0;
				var _g2 = 0;
				var _g3 = para.split(" ");
				while(_g2 < _g3.length) {
					var word = _g3[_g2];
					++_g2;
					var clip = new DFontText(word,this.style);
					if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) {
						clip.cacheAsBitmap = true;
						clip.children = _$RenderSupportJSPixi_DFontText.emptyChilds;
					}
					var word_width = clip.getTextDimensions().width;
					if(x > 0.0 && x + word_width > this.wordWrapWidth) {
						y += this.fontSize;
						x = 0.0;
					}
					clip.y = y + this.baseline;
					clip.x = x;
					clip.alpha = this.fillOpacity;
					this.addChild(clip);
					x += word_width + 0.2 * this.fontSize;
					line_width += word_width + 0.2 * this.fontSize;
				}
				y += this.fontSize;
				x = 0.0;
				this.clipWidth = Math.max(this.clipWidth,line_width - 0.2 * this.fontSize);
			}
		} else {
			var c = new DFontText(this.text,this.style);
			if(_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap) {
				c.cacheAsBitmap = true;
				c.children = _$RenderSupportJSPixi_DFontText.emptyChilds;
			}
			c.y = this.baseline;
			c.alpha = this.fillOpacity;
			this.clipWidth = c.getTextDimensions().width;
			this.addChild(c);
		}
		this.setTextBackground();
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
	,__class__: haxe_ds_StringMap
};
var Test40602FlowJsProgram = function() { };
Test40602FlowJsProgram.__name__ = true;
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
if(Array.prototype.indexOf) HxOverrides.indexOf = function(a,o,i) {
	return Array.prototype.indexOf.call(a,o,i);
};
NativeHx.initBinarySerialization();
haxe_Resource.content = [{ name : "dfonts", data : "W3sibmFtZSI6IkJvb2sifSx7Im5hbWUiOiJJdGFsaWMifSx7Im5hbWUiOiJEZW1pIn0seyJuYW1lIjoiTWVkaXVtIn0seyJuYW1lIjoiTWVkaXVtSXRhbGljIn0seyJuYW1lIjoiQ29uZGVuc2VkIn0seyJuYW1lIjoiRGVqYVZ1U2FucyJ9LHsibmFtZSI6IkRlamFWdVNhbnNPYmxpcXVlIn0seyJuYW1lIjoiRGVqYVZ1U2VyaWYifSx7Im5hbWUiOiJGZWx0VGlwUm9tYW4ifSx7Im5hbWUiOiJNaW5pb24ifSx7Im5hbWUiOiJNaW5pb25JdGFsaWNzIn0seyJuYW1lIjoiTUhFZWxlbXNhbnNSZWd1bGFyIn0seyJuYW1lIjoiTm90b1NhbnMifSx7Im5hbWUiOiJQcm94aW1hU2VtaUJvbGQifSx7Im5hbWUiOiJQcm94aW1hRXh0cmFCb2xkIn0seyJuYW1lIjoiUHJveGltYVNlbWlJdGFsaWMifSx7Im5hbWUiOiJQcm94aW1hRXh0cmFJdGFsaWMifSx7Im5hbWUiOiJHb3RoYW1Cb2xkIn0seyJuYW1lIjoiR290aGFtQm9vayJ9LHsibmFtZSI6IkdvdGhhbUJvb2tJdGFsaWMifSx7Im5hbWUiOiJHb3RoYW1IVEZCb29rIn1d"},{ name : "fontstyles", data : "eyJib29rIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy11cnciLCJ3ZWlnaHQiOjQwMCwic3R5bGUiOiJub3JtYWwifSwiZGVtaSI6eyJmYW1pbHkiOiJmcmFua2xpbi1nb3RoaWMtdXJ3Iiwid2VpZ2h0Ijo3MDAsInN0eWxlIjoibm9ybWFsIn0sInByb3hpbWFleHRyYWJvbGQiOnsiZmFtaWx5IjoicHJveGltYS1ub3ZhIiwid2VpZ2h0Ijo3MDAsInN0eWxlIjoibm9ybWFsIn0sInByb3hpbWFzZW1pYm9sZCI6eyJmYW1pbHkiOiJwcm94aW1hLW5vdmEiLCJ3ZWlnaHQiOjYwMCwic3R5bGUiOiJub3JtYWwifSwibWVkaXVtIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy11cnciLCJ3ZWlnaHQiOjUwMCwic3R5bGUiOiJub3JtYWwifSwibWluaW9uaXRhbGljcyI6eyJmYW1pbHkiOiJtaW5pb24tcHJvIiwid2VpZ2h0Ijo0MDAsInN0eWxlIjoiaXRhbGljIn0sIml0YWxpYyI6eyJmYW1pbHkiOiJmcmFua2xpbi1nb3RoaWMtdXJ3Iiwid2VpZ2h0Ijo0MDAsInN0eWxlIjoibm9ybWFsIn0sImRlamF2dXNhbnMiOnsiZmFtaWx5IjoidmVyYS1zYW5zIiwic3R5bGUiOiJub3JtYWwifSwiY29uZGVuc2VkIjp7ImZhbWlseSI6ImZyYW5rbGluLWdvdGhpYy1leHQtY29tcC11cnciLCJ3ZWlnaHQiOjcwMCwic3R5bGUiOiJub3JtYWwifX0"},{ name : "webfontconfig", data : "eyJ0eXBla2l0Ijp7ImlkIjoiaGZ6NnVmeiJ9fQ"}];
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
Md5.inst = new Md5();
NativeHx.clipboardData = "";
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
_$RenderSupportJSPixi_TextField.cacheTextsAsBitmap = false;
_$RenderSupportJSPixi_TextField.Zerro = new PIXI.Point(0.0,0.0);
_$RenderSupportJSPixi_TextField.One = new PIXI.Point(1.0,1.0);
_$RenderSupportJSPixi_VideoClip.UsePixiTextures = false;
_$RenderSupportJSPixi_VideoClip.VideosOnStage = 0;
RenderSupportJSPixi.PixiStage = new PIXI.Container();
RenderSupportJSPixi.NativeWidgetClips = [];
RenderSupportJSPixi.AccessWidgetClips = [];
RenderSupportJSPixi.MousePos = new PIXI.Point(0.0,0.0);
RenderSupportJSPixi.PixiStageChanged = true;
RenderSupportJSPixi.PixiStageSizeChanged = false;
RenderSupportJSPixi.DebugMode = Util.getParameter("rendebug") == "1" && !NativeHx.isTouchScreen() || Util.getParameter("rendebug") == "2";
RenderSupportJSPixi.UseDFont = Util.getParameter("dfont") != "0" && Util.getParameter("lang") != "zh";
RenderSupportJSPixi.ShowDebugClipsTree = Util.getParameter("clipstree") == "1";
RenderSupportJSPixi.CacheTextsAsBitmap = Util.getParameter("cachetext") == "1";
RenderSupportJSPixi.Antialias = Util.getParameter("antialias") != null?Util.getParameter("antialias") == "1":!NativeHx.isTouchScreen();
RenderSupportJSPixi.RendererType = Util.getParameter("renderer") != null?Util.getParameter("renderer"):window.useRenderer;
RenderSupportJSPixi.UseVideoTextures = Util.getParameter("videotexture") != "0";
RenderSupportJSPixi.isAndroid = window.navigator.userAgent.toLowerCase().indexOf("android") >= 0;
RenderSupportJSPixi.RenderSupportJSPixiInitialised = RenderSupportJSPixi.init();
RenderSupportJSPixi.MouseUpReceived = false;
RenderSupportJSPixi.FlowMainFunction = "flow_main";
RenderSupportJSPixi.StageChangedTimestamp = -1.0;
RenderSupportJSPixi.sharedText = new PIXI.Text("");
RenderSupportJSPixi.IsFullScreen = false;
_$RenderSupportJSPixi_DFontText.defaultFontFamily = "Book";
_$RenderSupportJSPixi_DFontText.emptyChilds = [];
_$RenderSupportJSPixi_Shaders.GlowFragmentSrc = ["precision lowp float;","varying vec2 vTextureCoord;","varying vec4 vColor;","uniform sampler2D uSampler;","void main() {","vec4 sum = vec4(0);","vec2 texcoord = vTextureCoord;","for(int xx = -4; xx <= 4; xx++) {","for(int yy = -3; yy <= 3; yy++) {","float dist = sqrt(float(xx*xx) + float(yy*yy));","float factor = 0.0;","if (dist == 0.0) {","factor = 2.0;","} else {","factor = 2.0/abs(float(dist));","}","sum += texture2D(uSampler, texcoord + vec2(xx, yy) * 0.002) * factor;","}","}","gl_FragColor = sum * 0.025 + texture2D(uSampler, texcoord);","}"];
_$RenderSupportJSPixi_Shaders.VertexSrc = ["attribute vec2 aVertexPosition;","attribute vec2 aTextureCoord;","attribute vec4 aColor;","uniform mat3 projectionMatrix;","varying vec2 vTextureCoord;","varying vec4 vColor;","void main(void)","{","gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);","vTextureCoord = aTextureCoord;","vColor = vec4(aColor.rgb * aColor.a, aColor.a);","}"];
Test40602FlowJsProgram.globals__ = (function($this) {
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
