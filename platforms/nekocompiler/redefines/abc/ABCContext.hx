// We extent the context to get access to the "extra" parameter
import format.abc.Data;

class ABCContext extends format.abc.Context {
	public override function new() {
		nameCache = new Map();
		typeCache = new Map();
		super();
		opw = new ABCOpWriter(bytepos);
		uintHash = HashTable.int32Hash(data.uints);
		intHash = HashTable.int32Hash(data.ints);
		floatHash = HashTable.floatHash(data.floats);
		nameHash = new HashTable(hNames, eqNames, data.names);
		
	}

	public function beginMethod2( mname : String, targs, tret, ?isStatic, ?isOverride, ?isFinal, ?extra ) {
		var m = beginFunction(targs,tret,extra);
		var fl = if( isStatic ) curClass.staticFields else curClass.fields;
		fl.push({
			name : property(mname),
			slot : 0,
			kind : FMethod(curFunction.f.type,KNormal,isFinal,isOverride),
			metadatas : null,
		});
		return curFunction.f;
	}

    public function addMetadata(m : Metadata) {
	  data.metadatas.push(m);
    }

    public function pc() {
	  return bytepos.n;
    }

	public override function property(n, ?ns) {
		var ni : Index<Name> = nameCache.get(n);
		if (ni != null) {
			return ni;
		}
		ni = super.property(n, ns);
		nameCache.set(n, ni);
		return ni;
	}

	public static function eqNames(a : Name, b : Name) { return Type.enumEq (a,b); }
	private static function ih<T>(idx: Index<T>) {
		switch(idx) {
			case Idx(n): return n;
		}
	}
	public static function  hNames(n : Name) {
		return switch(n) {
			case NName( name, ns ): 1 + ih(name)*7 + ih(ns)*3;
			case NMulti( name, ns): 23 + ih(name)*3 + ih(ns)*11;
			case NRuntime( name ): 13 + ih(name)*5;
			case NRuntimeLate: 0;
			case NMultiLate( nset ): ih(nset) * 13;
			case NAttrib( n ): 13 + 2 * hNames(n);
			case NParams( n, params): 17 * ih(n);
		}
	}
 	
	override public function int(i: Int) {
		return Idx(intHash.puti(i) + 1);
	}

	override public function uint(i: Int) {
		return Idx(uintHash.puti(i) + 1);
	}

	override public function float(i: Float) {
		return Idx(floatHash.puti(i) + 1);
	}

	override public function name(n) {
		if (nameHash == null)
			return super.name(n);
		return Idx(nameHash.puti(n) + 1);
	}

	override public function type(n) {
		var rv = typeCache.get(n);
		if (rv == null)
			typeCache.set(n, rv = super.type(n));
		return rv;
	}

	var  uintHash : HashTable<Int>;
	var   intHash : HashTable<Int>;
	var floatHash : HashTable<Float>;
	var  nameHash : HashTable<Name>;

	var typeCache : Map<String,Index<Name>>;
	var nameCache : Map<String,Index<Name>>;
	
	public override function defineField(a, b, ?c : Bool) {
		// trace(a);
		return super.defineField(a, b, c);
	}

	public function defineFieldNoSlot(a, b, ?c : Bool) : Void {
		// Hack to avoid "Error #1053: Illegal override" for subclass fields.
		// Looking at the swf disassembly from haxe compiler, it uses nonzero slot id
		// only for static fields; instance fields use the 0 'auto-assign slot' code.
		// Explicitly assigning slots to subclass fields probably causes conflicts
		// by position with superclass fields.
		var cslot = fieldSlot;
		fieldSlot = 0;
		super.defineField(a, b, c);
		fieldSlot = cslot;
	}

	public override function beginMethod(a, b, c, ?d : Bool, ?e, ?f) {
		// trace(a);
		return super.beginMethod(a, b, c, d, e, f);
	}
	
	public function beginFunction2(args, ret, ?extra) {
		super.beginFunction(args, ret, extra);
		return curFunction.f;
	}
	
	public override function op(o) {
		// trace(o);
		super.op(o);
	}
	
	public function switchDefault()	{
		var ops = curFunction.ops;
		var pos = ops.length;
		
		var start = bytepos.n;
		return function() {
			ops[pos] = 
			switch(ops[pos]) {
				default: OSwitch(0, []);
				case OSwitch(def, cases): OSwitch(bytepos.n - start, cases);
			}
		};
	}
	
	public function switchCase(index) {
		var ops = curFunction.ops;
		var pos = ops.length;
		var start = bytepos.n;
		return function() {
			ops[pos] = switch(ops[pos]) {
				default:
				  OSwitch(0, []);
				case OSwitch(def, cases):
				  cases[index] = bytepos.n - start;
				  OSwitch(def, cases);
			}
		};
	}
	public function dumpStat() {
		Assert.trace("#ints=" + intHash.length);
		Assert.trace("#uints=" + uintHash.length);
		Assert.trace("#floats=" + data.floats.length);
		Assert.trace("#strings=" + data.strings.length);
		Assert.trace("#namespaces=" + data.namespaces.length);
		Assert.trace("#nsset=" + data.nssets.length);
		Assert.trace("#metadata=" + data.metadatas.length);
		Assert.trace("#methodType=" + data.methodTypes.length);
		Assert.trace("#names" + data.names.length);
		Assert.trace("#classes=" + data.classes.length);
		Assert.trace("#functions=" + data.functions.length);
	}
}
