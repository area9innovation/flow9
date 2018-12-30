import format.abc.Data;
import format.swf.Data;
import Flow;
import HaxeWriter;
import HaxeRuntime;

// For information about the VM, see

// http://www.adobe.com/content/dam/Adobe/en/devnet/actionscript/articles/avm2overview.pdf

// https://developer.mozilla.org/en/Tamarin

class Extra {
	public function new(names_ : SwfNames) {
		names = names_;
		needActivation = false;
		hasGlobalOrClosureReference = false;
		stacktop = 0;
		maxstack = 0;
		slotVars = new FlowArray();
	}
	public function stack(d : Int) {
		stacktop += d;
		if (stacktop > maxstack) {
			maxstack = stacktop;
		}
		if (stacktop < 0) {
			throw "Not possible!";
		}
		// trace("Stack += " + d + ". Max=" + maxstack);
	}
	var stacktop : Int;
	public var maxstack : Int;
	public var names : SwfNames;
	public var needActivation : Bool;
	public var hasGlobalOrClosureReference : Bool;
	// Variables that have to live in slots, rather than registers
	public var slotVars : FlowArray<{ name : String, resolution: SwfNameResolution }>;
}

enum SwfNameResolution {
	TopLevel(n : Int);
	Local(slot : Int, parameter : Bool);
	Closure(slot : Int);
	Struct(id : Int, structname : String, args : Int);
}

class SwfNames {
	public function new() {
		toplevelAndOuter = new Map();
		freeVariablesFound = new Map();
	    funName = null;
		nfree = 0;
		locals = new Map();
		nlocals = 0;
		nargs = 0;
		maxlocals = 0;
		structs = new Map();
		slots = new Map();
		nestedLambdas = new Map();
		localTypes = new Map();
	}
	public var toplevelAndOuter : Map<String, SwfNameResolution>;
	public var freeVariablesFound : Map<String, SwfNameResolution>;
    public var funName : String;
	public var nfree : Int;
	public var locals : Map<String, SwfNameResolution>;
	public var nlocals : Int;
	public var nargs : Int;
	public var maxlocals : Int;
	public var structs : Map<String, SwfNameResolution>;
	// Which locals are slot variables, and what number do they have?
	public var slots : Map<String, Int>;
	// Which nested lambdas exist?
	public var nestedLambdas : Map<String, Bool>;
	// Which types do local names have?
	public var localTypes : Map<String, String>;
	public function registerLocalType(name : String, type : String) {
		if (!localTypes.exists(name))
			localTypes.set(name, type);
		else if (localTypes.get(name) != type)
			localTypes.set(name, '*');
	}
}

typedef StructDef = { id : Int, structname : String, args : FlowArray<MonoTypeDeclaration>};

class SwfWriter {
	var program : Program;
	var ctx : ABCContext;
	var debug : Int;
    var optSimple : Bool; 
    var structClasses : Bool;

    public function new(debug : Int, optSimple : Bool) {
		this.debug = debug;
	    this.optSimple = optSimple;
	    structClasses = true;
	}
	
	public function compile(p : Program, debug_info : DebugInfo, names : SwfNames) : haxe.io.Bytes {
		program = p;

		nativeClasses = new Map();
		nativeNames = new Map();
		ctx = new ABCContext();
		functionIds = new Map();
		functionFreeVars = new Map();
		lambdaTree = new Map();
		var n = 0;
		for (d in p.declsOrder) {
			names.toplevelAndOuter.set(d, TopLevel(n++));
		}	

		structTypeName = structClasses ? "FSEmptyStruct" : "Object";

		// Find out how to number the structs. We collect all pure unions (that do not
		// include other unions) and sort by the length.
		var pureUnionsSorted = new FlowArray();
		var impureUnions = new Map();
		var struct2union = new Map();
		var structsOrder2 = new FlowArray();
		for (d in p.userTypeDeclarations) {
			switch (d.type.type) {
			case TUnion(min, max): {
				var pure = true;
				var length = 0;
				for (s in min.keys()) {
					var t = p.userTypeDeclarations.get(s);
					switch (t.type.type) {
						case TStruct(structname, cargs, max): {
							// Maintain a look from struct to what unions it appears in
							var l = struct2union.get(structname);
							if (l == null) l = [];
							l.push(d.name);
							struct2union.set(structname, l);
						}
						case TUnion(mi, ma): {
							pure = false;	
							var l = struct2union.get(s);
							if (l == null) l = [];
							l.push(d.name);
							struct2union.set(s, l);
						} 
						default:
					}
					++length;
				}
				if (pure) {
					pureUnionsSorted.push({ n: d.name, l : length, u : min});
				}
				impureUnions.set(d.name, { n: d.name, l : length, u : min});
			}
			case TStruct(structname, cargs, max):
				structsOrder2.push(d);
			default:
			}
		}	
		
		// Sort reversed
		pureUnionsSorted.sort(function(s1, s2) {
			return if (s1.l < s2.l) 1 else if (s1.l == s2.l) 0 else -1;
		});
		
		var handled = new Map();
		structDefs = new Map();
		var nstructs = 0;
		var structsOrder = [];
		var i = 0;
		while (i < pureUnionsSorted.length) {
			var u = pureUnionsSorted[i];
			if (!handled.get(u.n)) {
				// Sys.println(u.n + ":" + nstructs);
				var structunions = [];
				var localQueue = [];
				for (sn in u.u.keys()) {
					if (!handled.get(sn)) {
						handled.set(u.n, true);
						var s = p.userTypeDeclarations.get(sn);
						switch (s.type.type) {
						case TUnion(min, max): {
							// TODO: Find the length here
							localQueue.push({n : sn, l : 1, u: min});
						}
						case TStruct(structname, cargs, max):
							structsOrder.push(s);
							structDefs.set(s.name, { id : nstructs, structname : s.name, args : cargs});
							names.structs.set(s.name, Struct(nstructs, s.name, cargs.length));
							nstructs++;
							handled.set(sn, true);
							var us = struct2union.get(s.name);
							if (us != null) {
								structunions = structunions.concat(us);
							}
						default:
						}
					}
				}
				var unions = struct2union.get(u.n);
				if (unions != null) {
					structunions = structunions.concat(unions);
				}
				for (u in structunions) {
					if (!handled.get(u)) {
						var l = impureUnions.get(u);
						if (l != null) {
							localQueue.push(l);
						}
					}
				}
				localQueue.sort(function(s1, s2) {
					return if (s1.l < s2.l) 1 else if (s1.l == s2.l) 0 else -1;
				});
				
				// Now splice the queue into the general queue
				for (l in localQueue) {
					pureUnionsSorted.insert(i + 1, l);
				}
				
			}
			++i;
		}

		structsOrder2.sort(function(s1, s2) {
			return if (s1.name < s2.name) -1 else if (s1.name == s2.name) 0 else 1;
		});

		// Now handle structs not appearing in any unions
		for (s in structsOrder2) {
			if (!handled.get(s.name)) {
				switch (s.type.type) {
				case TStruct(structname, cargs, max): {
					structsOrder.push(s);
					structDefs.set(s.name, { id : nstructs, structname : s.name, args : cargs});
					names.structs.set(s.name, Struct(nstructs, s.name, cargs.length));
					nstructs++;
				}
				default:
				}
				handled.set(s.name, true);
			}
		}

		/*		for (s in structsOrder) {
			Sys.println(s.name + ":" + structDefs.get(s.name).id);
		}
	*/	

		if (structClasses)
		{
			var struct_super = ctx.type("FSEmptyStruct");
			var int_type = ctx.type("int");
			var any_type = ctx.type("*");
			var compare_fn = ctx.property("_compare");

			// Common superclass for all structs with _id field
			{
				var classDef = ctx.beginClass("FSEmptyStruct");

				classDef.isSealed = true;
				ctx.defineField("_id", int_type, false);

				var ctor = ctx.beginConstructor([ctx.type("int")]);
				ctor.maxStack = 2;
				ctx.op(OpCode.OThis);
				ctx.op(OpCode.OConstructSuper(0));
				ctx.op(OpCode.OThis);
				ctx.op(OpCode.OReg(1));
				ctx.op(OpCode.OInitProp(ctx.property("_id")));
				ctx.op(OpCode.ORetVoid);
				ctx.endMethod();

				// This class is only directly used for field-less structs
				var copy = ctx.beginMethod("_copy", [], struct_super, false, false, false);
				copy.maxStack = 1;
				ctx.op(OpCode.OThis);
				ctx.op(OpCode.ORet);
				ctx.endMethod();

				var cmpfields = ctx.beginMethod("_cmpfields", [struct_super], int_type, false, false, false);
				cmpfields.maxStack = 1;
				ctx.op(OpCode.OSmallInt(0));
				ctx.op(OpCode.ORet);
				ctx.endMethod();

				var compare = ctx.beginMethod("_compare", [any_type,any_type], int_type, true, false, true);
				compare.maxStack = 3;
				{
					// if (a == b) return 0;
					ctx.op(OReg(1));
					ctx.op(OReg(2));
					var jneq = ctx.jump(JumpStyle.JNeq);
					ctx.op(OSmallInt(0));
					ctx.op(ORet);
					jneq();
					// if (a == null) return 1;
					ctx.op(OReg(1));
					ctx.op(ONull);
					var jnnull1 = ctx.jump(JumpStyle.JNeq);
					ctx.op(OSmallInt(1));
					ctx.op(ORet);
					jnnull1();
					// if (b == null) return 1;
					ctx.op(OReg(2));
					ctx.op(ONull);
					var jnnull2 = ctx.jump(JumpStyle.JNeq);
					ctx.op(OSmallInt(1));
					ctx.op(ORet);
					jnnull2();
					// if (a is Array) {
					ctx.op(OReg(1));
					ctx.op(OIsType(ctx.type("Array")));
					var jnarr1 = ctx.jump(JumpStyle.JFalse);
					{
						// if (!(b is Array)) return 1;
						ctx.op(OReg(2));
						ctx.op(OIsType(ctx.type("Array")));
						var jarr2 = ctx.jump(JumpStyle.JTrue);
						ctx.op(OSmallInt(1));
						ctx.op(ORet);
						jarr2();
						// TODO: maybe implement arrays here too
						ctx.op(OpCode.OGetLex(ctx.property("HaxeRuntime")));
						ctx.op(OReg(1));
						ctx.op(OReg(2));
						ctx.op(OpCode.OCallProperty(ctx.property("compareByValue"),2));
						ctx.op(ORet);
					}
					jnarr1();
					// if (a is FSEmptyStruct) {
					ctx.op(OReg(1));
					ctx.op(OIsType(struct_super));
					var jnstruct1 = ctx.jump(JumpStyle.JFalse);
					{
						// if (!(b is FSEmptyStruct)) return 1;
						ctx.op(OReg(2));
						ctx.op(OIsType(struct_super));
						var jarr2 = ctx.jump(JumpStyle.JTrue);
						ctx.op(OSmallInt(1));
						ctx.op(ORet);
						jarr2();
						// if (a._id - b._id != 0) return it;
						ctx.op(OReg(1));
						ctx.op(OAsType(struct_super));
						ctx.op(OGetProp(ctx.property("_id")));
						ctx.op(OReg(2));
						ctx.op(OAsType(struct_super));
						ctx.op(OGetProp(ctx.property("_id")));
						ctx.op(OOp(Operation.OpISub));
						ctx.op(ODup);
						var jeqid = ctx.jump(JumpStyle.JFalse);
						ctx.op(ORet);
						jeqid();
						ctx.op(OPop);
						// compare fields
						ctx.op(OReg(1));
						ctx.op(OAsType(struct_super));
						ctx.op(OReg(2));
						ctx.op(OAsType(struct_super));
						ctx.op(OCallProperty(ctx.property("_cmpfields"), 1));
						ctx.op(ORet);
					}
					jnstruct1();
					// return (a < b) ? -1 : 1;
					ctx.op(OReg(1));
					ctx.op(OReg(2));
					var jlt = ctx.jump(JumpStyle.JLt);
					ctx.op(OSmallInt(1));
					ctx.op(ORet);
					jlt();
					ctx.op(OSmallInt(-1));
					ctx.op(ORet);
				}
				ctx.endMethod();

				ctx.endClass();
			}

			// Structs with fields
			for (s in structsOrder) {
				var st = structDefs.get(s.name);
				if (st.args.length == 0) continue;

				var classDef = ctx.beginClass("FS_"+s.name);
				var ct = ctx.type("FS_"+s.name);

				classDef.superclass = struct_super;
				classDef.isFinal = classDef.isSealed = true;

				var atypes = [];
				for (a in st.args) {
					var t = getType(a.type);
					ctx.defineFieldNoSlot(a.name, t, false);
					atypes.push(t);
				}

				var ctor = ctx.beginConstructor(atypes);
				ctor.maxStack = 2;
				ctx.op(OpCode.OThis);
				ctx.op(OpCode.OIntRef(ctx.int(st.id)));
				ctx.op(OpCode.OConstructSuper(1));
				for (i in 0...st.args.length) {
					ctx.op(OpCode.OThis);
					ctx.op(OpCode.OReg(i+1));
					ctx.op(OpCode.OInitProp(ctx.property(st.args[i].name)));
				}
				ctx.op(OpCode.ORetVoid);
				ctx.endMethod();

				var copy = ctx.beginMethod("_copy", [], struct_super, false, true, false);
				copy.maxStack = 2+st.args.length;
				ctx.op(OFindPropStrict(ct));
				for (i in 0...st.args.length) {
					ctx.op(OpCode.OThis);
					ctx.op(OpCode.OGetProp(ctx.property(st.args[i].name)));
				}
				ctx.op(OConstructProperty(ct,st.args.length));
				ctx.op(ORet);
				ctx.endMethod();

				var cmpfields = ctx.beginMethod("_cmpfields", [struct_super], int_type, false, true, false);
				cmpfields.maxStack = 3;
				for (i in 0...st.args.length) {
					var aname = ctx.property(st.args[i].name);
					if (comparableType(st.args[i].type)) {
						ctx.op(OThis);
						ctx.op(OGetProp(aname));
						ctx.op(OReg(1));
						ctx.op(OAsType(ct));
						ctx.op(OGetProp(aname));
						var skip = ctx.jump(JumpStyle.JEq);
						ctx.op(OThis);
						ctx.op(OGetProp(aname));
						ctx.op(OReg(1));
						ctx.op(OAsType(ct));
						ctx.op(OGetProp(aname));
						var jlt = ctx.jump(JumpStyle.JLt);
						ctx.op(OSmallInt(1));
						ctx.op(ORet);
						jlt();
						ctx.op(OSmallInt(-1));
						ctx.op(ORet);
						skip();
					} else {
						ctx.op(OFindPropStrict(compare_fn));
						ctx.op(OThis);
						ctx.op(OGetProp(aname));
						ctx.op(OReg(1));
						ctx.op(OAsType(ct));
						ctx.op(OGetProp(aname));
						ctx.op(OCallProperty(compare_fn, 2));
						ctx.op(ODup);
						var skip = ctx.jump(JumpStyle.JFalse);
						ctx.op(ORet);
						skip();
						ctx.op(OPop);
					}
				}
				ctx.op(OSmallInt(0));
				ctx.op(ORet);
				ctx.endMethod();

				ctx.endClass();
			}
		}

		var classDef = ctx.beginClass("Swf");

		// TODO: Spit out the definitions of the structs
		
		// First, reserve slots for all global variables 
		var extra = new Extra(names);
		for (d in p.declsOrder) {
			var decl = p.topdecs.get(d);
			writeTopDeclaration(d, decl);
		}

		for (s in structsOrder) {
			var st = structDefs.get(s.name);
			if (st.args.length > 0) continue;
			ctx.defineField(s.name, ctx.type(structTypeName), false);
		}

		// Write out all inline lambdas
		for (d in p.declsOrder) {
			var decl = p.topdecs.get(d);
			writeInlineLambda(d, decl, names);
		}
		
		// Initialize all the top-level variables, in a fake function
		{
			var init = [];
			var extraopcodes = [
				// Initialize the struct hashes
				OGetLex(ctx.type('HaxeRuntime')),
				ODup,
				ODup,
				ODup,
				ODup,
				OFindPropStrict(ctx.type('haxe.ds.IntMap')),
				OConstructProperty(ctx.type('haxe.ds.IntMap'),0),
				OInitProp(ctx.type('_structnames_')),
				OFindPropStrict(ctx.type('haxe.ds.StringMap')),
				OConstructProperty(ctx.type('haxe.ds.StringMap'),0),
				OInitProp(ctx.type('_structids_')),
				OFindPropStrict(ctx.type('haxe.ds.IntMap')),
				OConstructProperty(ctx.type('haxe.ds.IntMap'),0),
				OInitProp(ctx.type('_structargs_')),
				OFindPropStrict(ctx.type('haxe.ds.IntMap')),
				OConstructProperty(ctx.type('haxe.ds.IntMap'),0),
				OInitProp(ctx.type('_structargtypes_')),
				OFindPropStrict(ctx.type('haxe.ds.IntMap')),
				OConstructProperty(ctx.type('haxe.ds.IntMap'),0),
				OInitProp(ctx.type('_structtemplates_'))
			];

			var stackusage = 16;
			
			for (s in structsOrder) {
				var st = structDefs.get(s.name);
				var id = st.id;
				var name = s.name;
				var srgs = st.args;
				var code = [
					(OGetLex(ctx.type('HaxeRuntime'))),
					(OGetProp(ctx.type('_structnames_'))),
					(OGetProp(ctx.type('h'))),
					(OIntRef(ctx.int((id)))),
					(OString(ctx.string(name))),
					(OSetProp(ctx.arrayProp)),

					(OGetLex(ctx.type('HaxeRuntime'))),
					(OGetProp(ctx.type('_structids_'))),
					(OGetProp(ctx.type('h'))),
					(OString(ctx.string(name))),
					(OIntRef(ctx.int((id)))),
					(OSetProp(ctx.arrayProp)),

					OGetLex(ctx.type('HaxeRuntime')),
					OGetProp(ctx.type('_structargs_')),
					OGetProp(ctx.type('h')),
					OIntRef(ctx.int((id))),
				];
				for (a in st.args) {
					code.push(OString(ctx.string(a.name)));
					a.name;
				}
				if (4 + st.args.length > stackusage) {
					stackusage = 4 + st.args.length;
				}
				code.push(OArray(st.args.length));
				code.push(OSetProp(ctx.arrayProp));

				if (structClasses) {
					// Create struct object templates for natives
					code.push(OGetLex(ctx.type('HaxeRuntime')));
					code.push(OGetProp(ctx.type('_structtemplates_')));
					code.push(OGetProp(ctx.type('h')));
					code.push(OIntRef(ctx.int(id)));

					if (st.args.length == 0) {
						code.push(OFindPropStrict(ctx.type("FSEmptyStruct")));
						code.push(OIntRef(ctx.int(st.id)));
						code.push(OConstructProperty(ctx.type("FSEmptyStruct"),1));
						// Also store into a field for reuse
						code.push(ODup);
						code.push(OFindProp(ctx.property(s.name)));
						code.push(OSwap);
						code.push(OSetProp(ctx.property(s.name)));
					} else {
						code.push(OFindPropStrict(ctx.type("FS_"+s.name)));
						for (a in st.args) {
							switch (a.type) {
							case TBool: code.push(OFalse);
							case TInt: code.push(OSmallInt(0));
							case TDouble: code.push(OFloat(ctx.float(0.0)));
							case TString: code.push(OString(ctx.string("")));
							default: code.push(ONull);
							}
						}
						code.push(OConstructProperty(ctx.type("FS_"+s.name),st.args.length));
					}

					code.push(OSetProp(ctx.arrayProp));
				} else if (st.args.length == 0) {
					code.push(OpCode.OFindProp(ctx.property(s.name)));
					code.push(OpCode.OString(ctx.string("_id")));
					code.push(OpCode.OIntRef(ctx.int((id))));
					code.push(OpCode.OObject(1));
					code.push(OpCode.OSetProp(ctx.property(s.name)));
				}

				// Store types of struct fields
				var argTypesCode = [
					OGetLex(ctx.type('HaxeRuntime')),
					OGetProp(ctx.type('_structargtypes_')),
					OGetProp(ctx.type('h')),
					OIntRef(ctx.int((id))),
				];

				var getRuntimeTypeCode = function(type : FlowType) : Array<format.abc.OpCode> {return []; };
				getRuntimeTypeCode = function(type : FlowType) : Array<format.abc.OpCode> {
					switch (type) {
						case TVoid: return [OGetLex(ctx.type('RuntimeType')), OGetProp(ctx.type('RTVoid')) ];
						case TInt: return [OGetLex(ctx.type('RuntimeType')), OGetProp(ctx.type('RTInt')) ];
						case TDouble: return [OGetLex(ctx.type('RuntimeType')), OGetProp(ctx.type('RTDouble')) ];
						case TBool: return [OGetLex(ctx.type('RuntimeType')), OGetProp(ctx.type('RTBool')) ];
						case TString: return [OGetLex(ctx.type('RuntimeType')), OGetProp(ctx.type('RTString')) ];
						case TStruct(name, args, max): return [OGetLex(ctx.type('RuntimeType')), OpCode.OString(ctx.string(name)), OCallProperty(ctx.type('RTStruct'), 1)];
						case TArray(t): {
							#if typepos
								var at : FlowType = t.val;
							#else
								var at : FlowType = t;
							#end
							return [OGetLex(ctx.type('RuntimeType'))].concat(getRuntimeTypeCode(at)).concat([OCallProperty(ctx.type('RTArray'), 1)]);
						}
						case TReference(t): return [OGetLex(ctx.type('RuntimeType'))].concat(getRuntimeTypeCode(t)).concat([OCallProperty(ctx.type('RTRefTo'), 1)]);
						default: return [OGetLex(ctx.type('RuntimeType')), OGetProp(ctx.type('RTUnknown')) ];
					}
				};

				if (4 + st.args.length * 4 > stackusage) {
					stackusage = 4 + st.args.length * 4;
				}

				for (a in st.args) {
					for (ins in getRuntimeTypeCode(a.type))
						argTypesCode.push(ins);
				}

				argTypesCode.push(OArray(st.args.length));
				argTypesCode.push(OSetProp(ctx.arrayProp));
				
				for (ins in code)
					extraopcodes.push(ins);
				for (ins in argTypesCode)
					extraopcodes.push(ins);
			}
			
			for (d in p.declsOrder) {
				var decl = p.topdecs.get(d);
				switch (decl) {
					case Native(name, io, args, result, defbody, pos): {

						// Some names, like Native and RenderSupport need a gentle extra renaming to avoid colliding
						// with other implementations of these natives
						var parts = name.split(".");
						var cl = parts[0];
						var cla = cl + if (cl == "Native"
										|| cl == "RenderSupport" 
										|| cl == "SoundSupport"
										|| cl == "HttpSupport"
										|| cl == "Database"
										|| cl == "FlowFileSystem"
										|| cl == "LocalyticsSupport"
										|| cl == "NotificationsSupport"
										|| cl == "GeolocationSupport"
										|| cl == "WebSocketSupport") { "Hx"; } else "";
						nativeClasses.set(cla, true);

						// Find where to put the native reference
						extraopcodes.push(OpCode.OFindProp(ctx.property(d)));

						if (defbody != null) {
							// Push the fallback function on the stack like encode(Lambda)
							var name = getLambdaName(defbody);
							var id = functionIds.get(name);
							extraopcodes.push(OpCode.OFunction(id));

							// TODO: is this necessary? added here to get scanLambda
							// stuff done inside writeFunction below, but it also
							// produces unnecessary opcodes.
							init.push(defbody);
						}

						// Find and push the native function
						extraopcodes.push(OpCode.OGetLex(ctx.property(cla)));
						extraopcodes.push(OpCode.OGetProp(ctx.property(parts[1])));

						if (defbody != null) {
							// Pop off either the native (if null) or the fallback
							extraopcodes.push(OpCode.ODup);
							extraopcodes.push(OpCode.OJump(JumpStyle.JFalse,1));
							extraopcodes.push(OpCode.OSwap); // 1 byte to jump over
							extraopcodes.push(OpCode.OPop);
						}

						// Save the reference
						extraopcodes.push(OpCode.OSetProp(ctx.property(d)));
					}
					case Lambda(args, type, body, _, pos):
					default: {
						init.push(Let(d, null, decl, null, null));
					}
				}
			}
			if (nativeClasses.get("RenderSupportHx") != null) {
				// We have to construct this guy!
				extraopcodes.push(OFindPropStrict(ctx.type('RenderSupportHx')));
				extraopcodes.push(OConstructProperty(ctx.type('RenderSupportHx'),0));
				extraopcodes.push(OPop);
			}
			// Empty Sequence is invalid
			var body = if (init.length > 0) Sequence(init, null) else ConstantVoid(null);
			writeFunction("_init_flow_globals", [], TFunction([], TVoid), body, names, 
							false, false, extraopcodes, stackusage);
		}
		
		// Now, write all functions
		for (d in p.declsOrder) {
			var decl = p.topdecs.get(d);
			writeTopLambda(d, decl, names);
		}
		
		ctx.endClass();
		ctx.finalize();

		//default-script-limits 
		//max-recursion-depth 
		//max-execution-time		
		/*ctx.addMetadata({
		  name: ctx.string("default-script-limits"), 
			  data:[{n:ctx.string("max-recursion-depth"), v: ctx.string("10000")}]
			  });*/

		//ctx.dumpStat();
				
		// Compile all of it to ActionScript bytecode
        var abcOutput = new haxe.io.BytesOutput();
		var writer = new ABCWriter(abcOutput);
        writer.write(ctx.getData());
		var abcBytes:haxe.io.Bytes = abcOutput.getBytes();
		
		// Create an SWF with that bytecode
        var swfOutput : haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var swfFile = 
		{
			#if haxe3
				header: {version:10, compressed:false, width:800, height:600, fps:30, nframes:1},
			#else
				header: {version:10, compressed:false, width:800, height:600, fps:30.0, nframes:1},
			#end
			tags:
			[
				#if haxe3
					TSandBox(true, true, false, true, true), // 16 + 8
				#else
					TSandBox(16 + 8),	//TSandBox({useDirectBlit :false, useGPU:false, hasMetaData:false, actionscript3:true, useNetWork:false}),
				#end
				TActionScript3(abcBytes, { id : 1, label : "Swf" } ),
				TSymbolClass([{cid:0, className:"Swf"}]),
				TShowFrame
			]
		};
        // write SWF
        var writer : format.swf.Writer = new format.swf.Writer(swfOutput);
        writer.write(swfFile);
        return swfOutput.getBytes();
	}
	
	public function getImports() {
		// Generate the imports
		var imports = "";
		for (k in nativeClasses.keys()) {
			imports += "import " + k + ";\n";
		}
		return imports;
	}
	
	function writeTopDeclaration(n : String, decl : Flow) : Void {
		switch (decl) {
			case Native(name, io, args, result, defbody, pos): {
				var t = ctx.type("Function");
				ctx.defineField(n, t, false);
				nativeNames.set(n, name);
			}
			case Lambda(args, type, body, _, pos):
			default: {
				// TODO: Fix the type. Sometimes we do not have it
				var t = getType(FlowUtil.getPosition(decl).type);
				ctx.defineField(n, t, false);
			}
		}
	}

	function writeInlineLambda(n : String, decl : Flow, names : SwfNames) : Void {
		var spitLambdas = function(exp, nativeName : String = null) {
			FlowUtil.traverseExp3(exp, function (e) {
				switch (e) {
				case Lambda(args, type, body, _, pos): {
					// Capture the free variables so we can build a closure later
					var name = getLambdaName(e);
					var ns = writeFunction(name, args, pos.type, body, names, true, true, [], 0, nativeName);
					var freeVars = new FlowArray();
					for (k in ns.freeVariablesFound.keys()) {
						freeVars.push(k);
					}
					functionFreeVars.set(name, freeVars);
					var nested = new FlowArray();
					for (k in ns.nestedLambdas.keys()) {
						nested.push(k);
					}
                    Assert.check(!lambdaTree.exists(name), "!lambdaTree.exists(name)");
					lambdaTree.set(name, nested);
				}
				default:
				}
			});
		}
		
		switch (decl) {
			case Native(nn, io, args, result, defbody, pos):
				if (defbody != null) {
					//trace("Native fallback for " + nn);
					var parts = nn.split(".");
					var fnName = parts[parts.length - 1];
					if (StringTools.startsWith(fnName,"fast_")) {
						fnName = fnName.substr(5);
					}
					//trace(fnName);
					spitLambdas(defbody, fnName);
				};
			case Lambda(args, type, body, _, pos): spitLambdas(body);
			default: spitLambdas(decl);
		};
	}

	static var fileIdCache : Map<String, String> = new Map();
	static var UNDERSCORE = '_';

	static function getFileIdentifier(f : String) {
		var rv = fileIdCache.get(f);
		if (rv == null) {
			rv = f;
			rv = StringTools.replace(rv, "/", "_");
		    rv = StringTools.replace(rv, ".", "_");
			fileIdCache.set(f, rv);
		}
		return rv;
	}

	static function getLambdaName(e : Flow) : String {
                switch(e) {
                case Lambda(args, type, body, uniqNo, pos):
					var sb = new StringBuf();
					sb.add(UNDERSCORE);
					sb.add(getFileIdentifier(pos.f));
					sb.add(UNDERSCORE);
					sb.add(pos.s);
					sb.add(UNDERSCORE);
					sb.add(uniqNo);
					return sb.toString();
                default:
                        Assert.fail("getLambdaName");
                        return "";
                }
                  
	}
	
	function writeTopLambda(n : String, decl : Flow, names : SwfNames) : Void {
		switch (decl) {
			case Native(nn, io, args, result, defbody, pos):
			case Lambda(args, type, body, _, pos): {
				writeFunction(n, args, pos.type, body, names, false, false, [], 0);
			}
			default:
		}
	}
	
	function writeFunction(name : String, arguments : FlowArray<String>, type : FlowType, body : Flow, 
					names : SwfNames, lambda : Bool, needActivation : Bool, extraopcodes : Array<OpCode>,
					extrastack, nativeName : String = null) : SwfNames { 
		var newNames = new SwfNames();
		var scanNames = new SwfNames();
		newNames.toplevelAndOuter = names.toplevelAndOuter;
		scanNames.toplevelAndOuter = names.toplevelAndOuter;
		newNames.funName = if (nativeName != null) nativeName else name;
		newNames.structs = names.structs;
		scanNames.structs = names.structs;
		
		// Extract the types
		var resultType = null;
		var argTypes = null;
		switch (type) {
			case TFunction(args, returns): {
				resultType = returns;
				argTypes = args;
			}
			default: throw "Not a function!";
		}
		
		// If we have local variables that shadow globals, we have to
		// take those out so they become local closures correctly.
		var hiddenGlobals = new Map<String,SwfNameResolution>();
		for (l in names.locals.keys()) {
			var hiddenTop = newNames.toplevelAndOuter.get(l);
			if (hiddenTop != null) {
				hiddenGlobals.set(l, hiddenTop);
				newNames.toplevelAndOuter.remove(l);
				scanNames.toplevelAndOuter.remove(l);
			}
		}
		// First, enumerate the arguments
		var args = [];
		var n = 1; // Number 0 is reserved for this
		for (a in arguments) {
			newNames.locals.set(a, Local(n, true));
			scanNames.locals.set(a, Local(n, true));
			scanNames.registerLocalType(a, getTypeName(argTypes[n-1]));
			args.push(getType(argTypes[n - 1]));
			++n;
		}
		newNames.nargs = n;
		newNames.nlocals = n;
		newNames.maxlocals = n;
		scanNames.nlocals = n;
		scanNames.maxlocals = n;
		
		var extra = new Extra(scanNames);
		if (extraopcodes.length > 0) {
			extra.hasGlobalOrClosureReference = true;
		}
		
		// Now scan for free variables
		scan(body, extra);

		if (extra.names.nfree > 0) {
			extra.hasGlobalOrClosureReference = true;
		}

		var hasBlock = extra.needActivation;
		var extraMethod = {
			native : false,
			variableArgs : false,
			argumentsDefined : false,
			usesDXNS : false,
			newBlock : hasBlock,
			unused : false,
			debugName : null,
			defaultParameters : null,
			paramNames : null
		};

		var dynamicTypeName = getTypeName(resultType);
		var dynamicType = ctx.type(dynamicTypeName == "String" ? "*" : dynamicTypeName);
		var m;
		if (lambda) {
			m = ctx.beginFunction2(args, dynamicType, extraMethod);
			var id = m.type;
			functionIds.set(name, id);
		} else {
			 m = ctx.beginMethod2(name, args, dynamicType, false, false, true, extraMethod);
		}

		// Produce fields for all variables defined by us, that are used as free variables in some of our lambdas
		var fields = [];
		var numbering = 1;
		newNames.slots = new Map();
		for (slotVar in extra.slotVars) {
			switch (slotVar.resolution) {
				case Local(s, p): {
					var free = slotVar.name;
					var ltname = scanNames.localTypes.get(free);
					if (ltname == null) ltname = '*';
					var fld : format.abc.Field = { name: ctx.type(free), slot: numbering, kind: FVar(ctx.type(ltname)), metadatas : null };
					fields.push(fld);
					newNames.slots.set(free, numbering);
					numbering++;
				}
				default:
					// OK, it is not a local dude, so it must be owned by some other function
			}
		}
		m.locals = fields;
		
		
		var ms = 1 
				+ extra.maxstack + (extra.hasGlobalOrClosureReference ? 2 : 0) 
				+ (extra.slotVars.length > 0 ? 2 : 0);
		if (ms < extrastack) {
			ms = extrastack;
		}
		m.maxStack = ms;
		//Util.println("function " + name + " max stack = " + ms + "extrastack=" + extrastack + " extra.maxStack=" + extra.maxstack + " extra.hasGlobalOrClosureReference=" + extra.hasGlobalOrClosureReference + " extra.slotVars.length=" + extra.slotVars.length);
		m.initScope = 1;

		m.maxScope = 1 + (extra.hasGlobalOrClosureReference ? 1 : 0) + (hasBlock ? 1 : 0); // How many pushscopes are we using?

		var startPc = ctx.pc();
		
		// If we do not perform any global or closure variable lookup, we do not have to push the scope
		if (extra.hasGlobalOrClosureReference) {
			ctx.op(OpCode.OThis);
			ctx.op(OpCode.OScope);
		}
		
		if (extra.slotVars.length > 0) {
			ctx.op(OpCode.ONewBlock);
			ctx.op(OpCode.OScope);
		}

		// Initialize the slots that come from parameters
		var entryJump = ctx.backwardJump();
		var nr = 1;
		for (slotVar in extra.slotVars) {
			var r = slotVar.resolution;
			switch (r) {
				case Local(s, p): {
					if (p) {
						ctx.op(OpCode.OGetScope(1));
						ctx.op(OpCode.OReg(s));
						ctx.op(OpCode.OSetSlot(nr));
					}
					nr++;
				}
				default:
			}
		}
		
		if (extraopcodes.length > 0) {
			ctx.ops(extraopcodes);
		}
		
		var noRet = encode(body, newNames, function(){entryJump(JumpStyle.JAlways);}, true);

		// Define how many local variables we need here!
		m.nRegs = newNames.maxlocals;
		
		if (!noRet) {
           ctx.op(ORet);
		}
		ctx.endMethod();
		
		// Restore any hidden globals
		for (n in hiddenGlobals.keys()) {
			var v = hiddenGlobals.get(n);
			names.toplevelAndOuter.set(n, v);
		}
		return newNames;
	}
	
    function encode(v : Flow, names : SwfNames, entryJump : Void -> Void, tailcall : Bool, dropValue : Bool = false) : Bool {
		if (debug > 0) {
			var pos = FlowUtil.getPosition(v);
			if (pos != null && pos.f != null && pos.l != null) {
				ctx.op(ODebugFile(ctx.string(pos.f)));
				ctx.op(ODebugLine(pos.l));
			}
		}
		var ret = function(result) { 
		    if (dropValue) {
			     ctx.op(OPop);
			}
		    return result;
		}
		switch (v) {
		case SyntaxError(s, p): throw "Can not serialize syntax errors";
		case ConstantVoid(pos):
			ctx.op( OpCode.ONull );
		case ConstantBool(value, pos):
			ctx.op( if (value) OpCode.OTrue else OpCode.OFalse);
		case ConstantI32(value, pos):
			var i = I2i.toInt(value);
			if ( I2i.compare(value,(-128)) >= 0 
				&& I2i.compare(value, (128)) == -1) {
				ctx.op( OpCode.OSmallInt(i) );
			} else {
				ctx.op( OpCode.OIntRef( ctx.int( value ) ) );
			}
		case ConstantDouble(value, pos):
			ctx.op(OpCode.OFloat( ctx.float(value) ));
		case ConstantString(value, pos):
			Assert.check(value != null, "SWF write: ConstanString: value != null");
			ctx.op(OpCode.OString(ctx.string(value) ) );
		case ConstantArray(values, pos):
		  for (item in values) encode(item, names, entryJump, false);
			ctx.op( OArray(values.length) );
		case ConstantStruct(name, values, pos):
		  return ret (writeCall(VarRef(name, pos), values, names, entryJump, false));
		case ConstantNative(val, pos): 
			throw "Can not serialize native values";
		case ArrayGet(array, index, pos):
			encode(array, names, entryJump, false);
			encode(index, names, entryJump, false);
			ctx.op( OGetProp(ctx.arrayProp) );
		case VarRef(name, pos):
			if (structDefs.exists(name)) {
				ctx.op(OpCode.OGetLex(ctx.property(name)));
				return ret(false);
			}
			if (names.slots.exists(name)) {
				ctx.op(OpCode.OGetScope(1));
				ctx.op(OpCode.OGetSlot(names.slots.get(name)));
			} else {
				var local = names.locals.get(name);
				if (local != null) {
					// Local variable
					switch (local) {
					case Local(slot, parameter):
						ctx.op(OpCode.OReg(slot));
					default:
						throw "Not implemented varref 1";
					}
				} else {
					var free = names.freeVariablesFound.get(name);
					if (free != null) {
						// Closure
						switch (free) {
						case Closure(n):
							if (names.slots.exists(name)) {
								ctx.op(OpCode.OGetSlot(names.slots.get(name)));
							} else {
								ctx.op(OpCode.OGetLex(ctx.property(name)));
							}
						default:
							throw "Not implemented varref 2";
						}
					} else {
						var outer = names.toplevelAndOuter.get(name);
						if (outer == null) {
							var struct = names.structs.get(name);
							if (struct == null) {
								// This is a free variable
								var freen = names.nfree;
								names.freeVariablesFound.set(name, Closure(freen));
								names.nfree++;
								ctx.op(OpCode.OGetLex(ctx.property(name)));
							} else {
								// Construction of a Struct without a call
								switch (struct) {
								case Struct(id, name, args):
									trace("TODO: Struct: " + name);
									// output.writeInt31_16(id, 'struct names');
								default:
									throw "Not a struct";
								}
							}
						} else {
							switch (outer) {
							case TopLevel(n): // Top-level code.
								ctx.op(OpCode.OGetLex(ctx.property(name)));
							case Local(slot, parameter):
								// Insert in free variables found
								trace(name + " is stack, but should be closure " + outer);
							case Closure(slot):
								// Insert in free variables found
								trace(name + " is closure, but should be local closure " + outer);
							case Struct(id, name, n):
								throw "Not implemented varref 3";
							}
						}
					}
				}
			}
		case Field(call, name, pos):
			if (name == "structname") {
				ctx.op(OGetLex(ctx.type('HaxeRuntime')));
				ctx.op(OGetProp(ctx.type('_structnames_')));
				ctx.op(OGetProp(ctx.type('h')));
				encode(call, names, entryJump, false);
				if (structClasses)
					ctx.op(OpCode.OAsType(ctx.type(structTypeName)));
				ctx.op(OpCode.OGetProp(ctx.property("_id")));
				ctx.op(OpCode.OGetProp(ctx.arrayProp));
			} else {
				encode(call, names, entryJump, false);
				if (structClasses) {
					var n = structTypeName;
					var fields = FlowUtil.untyvar(FlowUtil.getPosition(call).type);
					if (fields != null) {
						switch (fields) {
							case TStruct(structname, cargs, max):
								if (cargs.length > 0)
									n = 'FS_'+structname;
							case TUnion(min, max):
								if (max != null) {
									var cnt = 0;
									var nn = null;
									for (m in max) {
										cnt++;
										switch (m) {
											case TStruct(structname, cargs, max):
												if (cargs.length > 0)
													nn = 'FS_'+structname;
											default:
										}
									}
									if (cnt == 1 && nn != null)
										n = nn;
								}
							default:
						}
					}
					ctx.op(OpCode.OAsType(ctx.type(n)));
				}
				ctx.op(OpCode.OGetProp(ctx.property(name)));
			}
			
		case RefTo(value, pos):
			ctx.op(OpCode.OFindPropStrict(ctx.type("FlowRefObject")));
			encode(value, names, entryJump, false);
			ctx.op(OpCode.OConstructProperty(ctx.type("FlowRefObject"),1));
		case Pointer(index, pos): throw "Not implemented: " + Prettyprint.print(v);
		case Deref(pointer, pos): {
			encode(pointer, names, entryJump, false);
			ctx.op(OpCode.OAsType(ctx.type("FlowRefObject")));
			ctx.op(OpCode.OGetProp(ctx.property("__v")));
		}
		case SetRef(pointer, value, pos): {
			encode(pointer, names, entryJump, false);
			ctx.op(OpCode.OAsType(ctx.type("FlowRefObject")));
			encode(value, names, entryJump, false);
			ctx.op(OpCode.OInitProp(ctx.property("__v")));
			// The result of this operation is null!
			ctx.op( OpCode.ONull );
		}
		case SetMutable(pointer, name, value, pos): {
			encode(pointer, names, entryJump, false);
			encode(value, names, entryJump, false);
			ctx.op(OpCode.OInitProp(ctx.property(name)));
			// The result of this operation is null!
			ctx.op( OpCode.ONull );
		}
		case Cast(value, fromtype, totype, pos):
			encode(value, names, entryJump, false);
			switch (fromtype) {
				case TInt:
					switch (totype) {
					case TInt: // NOP
					case TDouble: ctx.op(OpCode.OToNumber);
					case TString: ctx.op(OpCode.OToString);
					default: throw "Not implemented: " + Prettyprint.print(v);
					}
				case TDouble:
					switch (totype) {
					case TInt: ctx.op(OpCode.OToInt);
					case TDouble: // NOP
					case TString: ctx.op(OpCode.OToString);
					default: throw "Not implemented: " + Prettyprint.print(v);
					}
				case TName(n1, args1):
					switch (totype) {
					case TName(n2, args2): // NOP
					default: throw "Not implemented: " + Prettyprint.print(v);
					}
				default: throw "Not implemented: " + Prettyprint.print(v);
			}
		case Let(name, sigma, value, scope, pos):
			encodeLet(name, value, scope, names, entryJump, tailcall);
		case Lambda(arguments, type, body, _, pos): {
			var name = getLambdaName(v);
			// We just reference the global function

			names.nestedLambdas.set(name, true);
			
			var id = functionIds.get(name);
			ctx.op(OpCode.OFunction(id));
		}
		case Flow.Closure(body, environment, pos):
			throw "Not implemented: " + Prettyprint.print(v);
		case Call(closure, arguments, pos): {
		  return ret(writeCall(closure, arguments, names, entryJump, tailcall));
		}
		case Sequence(statements, pos):
		    var noRet = false;
			for (i in 0...statements.length) {
				var s = statements[i];
				var last = i == statements.length - 1;
				noRet = encode(s, names, entryJump, tailcall && last);
				if (!last) {
					ctx.op(OpCode.OPop);
				}
			}
			return ret(noRet);
		case If(condition, then, elseExp, pos):
		  var needAny = FlowUtil.untyvar(pos.type) == TVoid;
			encode(condition, names, entryJump, false);
			var j1 = ctx.jump(JumpStyle.JFalse);
			var thNoRet = encode(then, names, entryJump, tailcall, dropValue);
			var j2 = null;
			if (!thNoRet) {
				if (needAny && optSimple && !dropValue) {
					ctx.op(OpCode.OAsAny);
				}
				if (tailcall) {
				  ctx.op(ORet);
				  thNoRet = true;
				} else {
					j2 = ctx.jump(JumpStyle.JAlways);
				}
			}
			j1();
			
			var elNoRet = encode(elseExp, names, entryJump, tailcall, dropValue);
			if (!elNoRet && needAny && optSimple && !dropValue) {
				ctx.op(OpCode.OAsAny);
			}
			if (j2 != null) {
				j2();
			}
			return ret(thNoRet && elNoRet);
		case Not(e, pos): {
			encode(e, names, entryJump, false);
			ctx.op(OpCode.OOp(Operation.OpNot));
		}
		case Negate(e, pos): {
			encode(e, names, entryJump, false);
			if (FlowUtil.untyvar(pos.type) == TInt) {
				ctx.op(OpCode.OOp(Operation.OpINeg));
			} else {
				ctx.op(OpCode.OOp(Operation.OpNeg));
			}
		}
		case Multiply(e1, e2, pos): {
			encode(e1, names, entryJump, false);
			encode(e2, names, entryJump, false);
			if (FlowUtil.untyvar(pos.type) == TInt) {
				ctx.op(OpCode.OOp(Operation.OpIMul));
			} else {
				ctx.op(OpCode.OOp(Operation.OpMul));
			}
		}
		case Divide(e1, e2, pos): {
			encode(e1, names, entryJump, false);
			encode(e2, names, entryJump, false);
			if (FlowUtil.untyvar(pos.type) == TInt) {
				ctx.op(OpCode.OOp(Operation.OpDiv));
				ctx.op(OpCode.OToInt);
			} else {
				ctx.op(OpCode.OOp(Operation.OpDiv));
			}
		}
		case Modulo(e1, e2, pos): {
			encode(e1, names, entryJump, false);
			encode(e2, names, entryJump, false);
			if (FlowUtil.untyvar(pos.type) == TInt) {
				ctx.op(OpCode.OOp(Operation.OpMod));
				ctx.op(OpCode.OToInt);
			} else {
				ctx.op(OpCode.OOp(Operation.OpMod));
			}
		}
		case Plus(e1, e2, pos): {
			encode(e1, names, entryJump, false);
			encode(e2, names, entryJump, false);
			if (FlowUtil.untyvar(pos.type) == TInt) {
				ctx.op(OpCode.OOp(Operation.OpIAdd));
			} else {
				ctx.op(OpCode.OOp(Operation.OpAdd));
			}
		}
		case Minus(e1, e2, pos): {
			encode(e1, names, entryJump, false);
			encode(e2, names, entryJump, false);
			if (FlowUtil.untyvar(pos.type) == TInt) {
				ctx.op(OpCode.OOp(Operation.OpISub));
			} else {
				ctx.op(OpCode.OOp(Operation.OpSub));
			}
		}
		case Equal(e1, e2, pos): {
			compare(e1, e2, pos, names, entryJump);
			ctx.op(OpCode.OOp(Operation.OpEq));
		}
		case NotEqual(e1, e2, pos): {
			compare(e1, e2, pos, names, entryJump);
			ctx.op(OpCode.OOp(Operation.OpEq));
			ctx.op(OpCode.OOp(Operation.OpNot));
		}
		case LessThan(e1, e2, pos): {
			compare(e1, e2, pos, names, entryJump);
			ctx.op(OpCode.OOp(Operation.OpLt));
		}
		case LessEqual(e1, e2, pos): {
			compare(e1, e2, pos, names, entryJump);
			ctx.op(OpCode.OOp(Operation.OpLte));
		}
		case GreaterThan(e1, e2, pos): {
			compare(e1, e2, pos, names, entryJump);
			ctx.op(OpCode.OOp(Operation.OpGt));
		}
		case GreaterEqual(e1, e2, pos): {
			compare(e1, e2, pos, names, entryJump);
			ctx.op(OpCode.OOp(Operation.OpGte));
		}
		case And(e1, e2, pos): {
			encode(e1, names, entryJump, false);
			ctx.op(OpCode.OToBool);
			ctx.op(OpCode.ODup);
			var j1 = ctx.jump(JumpStyle.JFalse);
			ctx.op(OpCode.OPop);
			encode(e2, names, entryJump, false);
			ctx.op(OpCode.OToBool);
			j1();
		}
		case Or(e1, e2, pos): {
			encode(e1, names, entryJump, false);
			ctx.op(OpCode.OToBool);
			ctx.op(OpCode.ODup);
			var j1 = ctx.jump(JumpStyle.JTrue);
			ctx.op(OpCode.OPop);
			encode(e2, names, entryJump, false);
			ctx.op(OpCode.OToBool);
			j1();
		}
		case Switch(value, type, cases, pos):
		  return ret(encodeSwitch(value, names, cases, true, entryJump, tailcall, pos));
		case SimpleSwitch(value, cases, pos):
		    return ret(encodeSwitch(value, names, cases, false, entryJump, tailcall, pos));
		case Native(name, io, args, result, defbody, pos):
			throw "Not implemented: " + Prettyprint.print(v);
		case NativeClosure(nargs, fn, pos):
			throw "Not implemented: " + Prettyprint.print(v);
 		case StackSlot(q0, q1, q2):
			throw "Not implemented: " + Prettyprint.print(v);
		}
  	    return ret(false);
	}
	
  function compare(e1, e2, pos, names, entryJump) {
		if (comparableType(pos.type2)) {
			encode(e1, names, entryJump, false);
			encode(e2, names, entryJump, false);
		} else {
			if (structClasses)
				ctx.op(OpCode.OGetLex(ctx.property("FSEmptyStruct")));
			else
				ctx.op(OpCode.OGetLex(ctx.property("HaxeRuntime")));
			encode(e1, names, entryJump, false);
			encode(e2, names, entryJump, false);
			if (structClasses)
				ctx.op(OpCode.OCallProperty(ctx.property("_compare"),2));
			else
				ctx.op(OpCode.OCallProperty(ctx.property("compareByValue"),2));
			ctx.op(OpCode.OSmallInt(0));
		}
	}
	
	function encodeLet(name : String, value : Flow, scope : Flow, names : SwfNames, entryJump : Void -> Void, tailcall : Bool) {
		var oldLocal = names.locals.get(name);
		var toplevel = oldLocal == null && names.toplevelAndOuter.exists(name);
		var nlocals = names.nlocals;
		var slot = names.slots.exists(name);
		if (slot) {
			ctx.op(OGetScope(1));
		} else if (toplevel) {
			ctx.op(OpCode.OFindProp(ctx.property(name)));
		}
		 
		encode(value, names, entryJump, false);

		// Wild workaround! It seems all registers need strong typing
		// TODO: So to avoid this, we would have to initialize all locals at the top
		// of the function with the correct type
		//ctx.op(OAsAny);
		
		if (slot) {
			// A capture variable goes into a slot
			ctx.op(OSetSlot(names.slots.get(name)));
		} else if (toplevel) {
			// Special hack to allow initialization of top-level variables using let!
			// ctx.op(ODebugFile(ctx.string(FlowUtil.getPosition(value).f)));
			// ctx.op(ODebugLine(FlowUtil.getPosition(value).l));
			ctx.op(OpCode.OSetProp(ctx.property(name)));
		} else {
			// A normal local variable
			var localidx = names.nlocals;
			names.locals.set(name, Local(localidx, false));
			names.nlocals++;
			if (names.nlocals > names.maxlocals) names.maxlocals = names.nlocals;
			ctx.op(OSetReg(localidx));
		}

		if (scope != null) {
			encode(scope, names, entryJump, tailcall);
		} else {
			ctx.op( OpCode.ONull );
		}
		if (!slot && !toplevel) {
			if (oldLocal == null) {
				names.locals.remove(name);
			} else {
				names.locals.set(name, oldLocal);
			}
		}
		names.nlocals = nlocals;
	}
	
	function comparableType(t : FlowType) : Bool {
		var t = FlowUtil.untyvar(t);
		if (t == null) return false;
		return switch (t) {
		case TInt: true;
		case TDouble: true;
		case TBool: true;
		case TVoid: true;
		case TString: true;
		default: false;
		}
	}
	
  function encodeSwitch(value : Flow, names : SwfNames, cases : FlowArray<Dynamic>, fields : Bool, entryJump : Void -> Void, tailcall : Bool, pos : Position): Bool {
	var needAny = FlowUtil.untyvar(pos.type) == TVoid;
		encode(value, names, entryJump, false);

		// Now collect all cases
		var def = null;
		var real : Map<Int,SwitchCase> = new Map();
		var minimum = 100000;
		var maxi = -1;
	    var haveFields = false;
		for (c in cases) {
			if (c.structname == "default") {
				def = c;
			} else {
				var structDef = structDefs.get(c.structname);
				real.set(structDef.id, c);
				if (structDef.id < minimum) minimum = structDef.id;
				if (structDef.id > maxi) maxi = structDef.id;
				if (structDef.args.length != 0) haveFields = true;
			}
   		}
	    if (optSimple && !haveFields) {
		  fields = false;
		}

		if (structClasses)
			ctx.op(OpCode.OAsType(ctx.type(structTypeName)));

		// Make a duplicate of the struct in order to be able to extract the values from this guy!
		if (!optSimple || fields) ctx.op(OpCode.ODup);
		ctx.op(OpCode.OGetProp(ctx.property("_id")));
		ctx.op(OpCode.OToInt);
		
		var span = maxi - minimum;
		if (span > 255) {
			/* 
				var middleId = (maxi + minimum) / 2;

				1) switch(e) a b c default => if e <= b.id then switch(e) a b default else switch(e) c default
					
					or

				2) switch (e) {
					A(): a;
					default: {
						switch (e) {
						B(): b;
						default: d;
					}
				}
			*/	

			var ca = "";
			var sep = "";
			for (c in cases) {
				var structDef = structDefs.get(c.structname);
				ca += sep + c.structname + (if (structDef != null) "(id " + structDef.id + ")" else "");
				sep = ", ";
			}
			throw Prettyprint.position(pos) + ": Too wide a span in switch: " + span + " with cases " + ca + ". Sorry, you have to split your switch statement into more than one";
		}

		var delta = 0;
		if (minimum >= 5) {
			// Optimization: If the minimum is very high, we do not have to put null-entries all over the place
			// Instead, offset downwards and be more tight about it
			encode(ConstantI32(minimum, null), names, entryJump, false);
			ctx.op(OpCode.OOp(Operation.OpISub));
			delta = minimum;
		}

		// Sort the cases in numeric order
		var indices = new FlowArray();
		for (k in real.keys()) {
			indices.push(k);
		}
		indices.sort(function(a, b) { return if (a < b) -1 else if (a == b) 0 else 1; } );
		
		var deltas = new Array();
		var cases = new FlowArray();
		for (i in 0...maxi + 1 - delta) {
			deltas.push(0);
			cases.push(ctx.switchCase(i));
		}
		
		// Do the switch
		var swtdef = ctx.switchDefault();
		ctx.op(OSwitch(0, deltas));

		// The default code
		swtdef();
		for (i in 0...maxi + 1 - delta) {
			var c = real.get(i + delta);
			if (c == null) {
				cases[i]();
			}
		}
		
		var jumps = new FlowArray();
		var lastNoRet = false;
		// Throw away the duplicate value
		if (!optSimple || fields) ctx.op(OpCode.OPop);
		var defNoRet = def != null && encode(def.body, names, entryJump, !needAny && tailcall);
		if (!defNoRet) {
		  if (def == null) { 
			ctx.op(OpCode.OUndefined);
		  } else if (needAny || !optSimple) {
            ctx.op(OpCode.OAsAny);
          }
		  if (tailcall) {
			ctx.op(ORet);
		  } else {
		  	jumps.push(ctx.jump(JAlways));
		  }
	    }

		// Now, handle the values
		var localsNow = names.nlocals;
		// Code for the rest of the cases
		for (i in indices) {
			// case7();
			cases[i - delta]();
			var c = real.get(i);
			// ctx.op(OString(ctx.string('5')));

			var n = structDefs.get(c.structname);
			var caseNoRet = false;
			if (n == null) {
				trace(c.structname);
			} else {
				var id = n.id;
				var name = n.structname;
				var args = n.args;
				var oldLocals = new FlowArray();
				var code = c.body;
				if (fields) {
					var args : FlowArray<String> = c.args;
					for (a in args) {
						var slot = names.slots.exists(name);
						if (!slot) {
							var oldLocal = names.locals.get(a);
							var stackslot = names.nlocals;
							names.locals.set(a, Local(stackslot, false));
							names.nlocals++;
							oldLocals.push(oldLocal);
						}
					}
					if (structClasses && args.length > 0)
						ctx.op(OpCode.OAsType(ctx.type("FS_"+c.structname)));
					// We set the locals
					var nr = 0;
					for (name in args) {
					    if (!optSimple || nr != args.length-1) {
						  ctx.op(OpCode.ODup);
						}
						var fieldName = n.args[nr].name;
						ctx.op(OpCode.OGetProp(ctx.property(fieldName)));
						ctx.op(OAsAny);
						var slot = names.slots.exists(name);
						if (slot) {
							ctx.op(OGetScope(1));
							ctx.op(OSwap);
						}
						if (slot) {
							ctx.op(OSetSlot(names.slots.get(name)));
						} else {
							var localidx = names.locals.get(name);
							switch (localidx) {
								case Local(slot, par): {
									ctx.op(OSetReg(slot));
								}
								default: throw "Not supposed to happen!";
							}
						}
						++nr;
					}
					if (!optSimple || args.length == 0) {
					  ctx.op(OpCode.OPop);
					}
				} else { // !fields
				  if (!optSimple) ctx.op(OpCode.OPop);
				}
				caseNoRet = encode(c.body, names, entryJump, !needAny && tailcall);
				if (names.nlocals > names.maxlocals) names.maxlocals = names.nlocals;
				if (fields) {
					var args : FlowArray<String> = c.args;
					for (i in 0...args.length) {
						var name = args[i];
						var o = oldLocals[i];
						if (o == null) {
							names.locals.remove(name);
						} else {
							names.locals.set(name, o);
						}
					}
					names.nlocals = localsNow;
				}
			}
			if (!caseNoRet) {
				if (needAny) 
				  ctx.op(OpCode.OAsAny);
				if (tailcall) {
				  ctx.op(ORet);
				} else if (i != maxi) {
				  jumps.push(ctx.jump(JAlways));
			    }
			}
			if (i == maxi) {
				lastNoRet = caseNoRet;
		    }
		}
		
		for (j in jumps) {
			j();
		}
		return jumps.length == 0 && lastNoRet;
	}

	function scan(v : Flow, extra : Extra) : Void {
		var stackBefore = untyped extra.stacktop;
		doScan(v, extra);
		var stackAfter = untyped extra.stacktop;
		if (stackAfter - stackBefore != 1) {
			trace(Prettyprint.prettyprint(v));
			throw "Stack discipline violated: " + (stackAfter - stackBefore);
		}
	}
	function doScan(v : Flow, extra : Extra) : Void {
		switch (v) {
		case SyntaxError(s, p): throw "Can not serialize syntax errors";
		case ConstantVoid(pos): extra.stack(1);
		case ConstantBool(value, pos): extra.stack(1);
		case ConstantI32(value, pos): extra.stack(1);
		case ConstantDouble(value, pos): extra.stack(1);
		case ConstantString(value, pos): extra.stack(1);
		case ConstantArray(values, pos): {
			for (item in values) scan(item, extra);
			extra.stack(1);
			extra.stack( -values.length);
		}
		case ConstantStruct(name, values, pos):
			extra.stack(2);
			for (item in values) {
				extra.stack(1);
				scan(item, extra);
			}
			extra.stack(-2 * (values.length) - 1);
			
		case ConstantNative(val, pos): 
			throw "Can not serialize native values";
		case ArrayGet(array, index, pos):
			scan(array, extra);
			scan(index, extra);
			extra.stack(-1);
		case VarRef(name, pos):
			if (structDefs.exists(name)) {
				extra.hasGlobalOrClosureReference = true;
				extra.stack(1);
				return;
			}
			var names = extra.names;
			var local = names.locals.get(name);
			var free = names.freeVariablesFound.get(name);
			var outer = names.toplevelAndOuter.get(name);
			if (free != null || outer != null) {
				extra.hasGlobalOrClosureReference = true;
			}
			
			if (local == null && free == null && outer == null) {
				var struct = names.structs.get(name);
				if (struct == null) {
					// This is a free variable
					var freen = names.nfree;
					names.freeVariablesFound.set(name, Closure(freen));
					names.nfree++;
				}
			}
			extra.stack(1);
		case Field(call, name, pos):
			if (name == "structname") {
				extra.stack(2);
				scan(call, extra);
				extra.stack(-2);
			} else {
				scan(call, extra);
			}
		case RefTo(value, pos):
			extra.stack(1);
			scan(value, extra);
			extra.stack(-1);
		case Pointer(index, pos): throw "Not implemented: " + Prettyprint.print(v);
		case Deref(pointer, pos): {
			scan(pointer, extra);
		}
		case SetRef(pointer, value, pos): {
			scan(pointer, extra);
			scan(value, extra);
			extra.stack(-1);
		}
		case SetMutable(pointer, name, value, pos): {
			scan(pointer, extra);
			scan(value, extra);
			extra.stack(-1);
		}
		case Cast(value, fromtype, totype, pos):
			scan(value, extra);
		case Let(name, sigma, value, scope, pos):
			scan(value, extra);
			
			var names = extra.names;
			var toplevel = names.toplevelAndOuter.exists(name);
			
			var oldLocal = names.locals.get(name);
			var localidx = names.nlocals;
			if (!toplevel) {
				names.locals.set(name, Local(localidx, false));
				names.nlocals++;
				if (names.nlocals > names.maxlocals) names.maxlocals = names.nlocals;
				names.registerLocalType(name, getTypeName(pos.type2));
			}
			
			extra.stack(-1);
			
			if (scope != null) {
				scan(scope, extra);
			} else {
				extra.stack(1);
			}

			if (oldLocal == null) {
				names.locals.remove(name);
			} else {
				names.locals.set(name, oldLocal);
			}
			names.nlocals = localidx;
		case Lambda(arguments, type, body, _, pos): {
			var name = getLambdaName(v);
			extra.stack(1);
			scanLambda(name, extra);
		}
		case Flow.Closure(body, environment, pos):
			throw "Not implemented: " + Prettyprint.print(v);
		case Call(closure, arguments, pos): {
			// Structs require double the amount of space!
			switch (closure) {
			case VarRef(name, position): {
				var s = structDefs.get(name);
				if (s != null) {
					if (s.args.length == 0) {
						extra.hasGlobalOrClosureReference = true;
						extra.stack(1);
						return;
					}

					extra.stack(2);
					for (a in arguments) {
						extra.stack(1);
						scan(a, extra);
					}
					extra.stack( -2 * arguments.length - 1);
					return;
				}
			}
			default:
			}
			
			scan(closure, extra);
			extra.stack(1);
			for (a in arguments) {
				scan(a, extra);
			}
			extra.stack(-arguments.length - 1);
		}
		case Sequence(statements, pos):
			for (i in 0...statements.length) {
				var s = statements[i];
				scan(s, extra);
				extra.stack(-1);
			}
			extra.stack(1);
		case If(condition, then, elseExp, pos):
			scan(condition, extra);
			extra.stack(-1);
			scan(then, extra);
			extra.stack(-1);
			scan(elseExp, extra);
		case Not(e, pos): {
			scan(e, extra);
		}
		case Negate(e, pos): {
			scan(e, extra);
		}
		case Multiply(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case Divide(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case Modulo(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case Plus(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case Minus(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case Equal(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case NotEqual(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case LessThan(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case LessEqual(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case GreaterThan(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case GreaterEqual(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case And(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case Or(e1, e2, pos): {
			scan(e1, extra);
			scan(e2, extra);
			extra.stack(-1);
		}
		case Switch(value, type, cases, pos):
			scan(value, extra);
			extra.stack(1);
			var names = extra.names;
			var localsNow = names.nlocals;
			for (c in cases) {
				if (c.structname == "default") {
					scan(c.body, extra);
					extra.stack(-1);
				} else {
					var n = structDefs.get(c.structname);
					if (n == null) {
						throw "Crazy!";
					} else {
						extra.stack(1);
						var id = n.id;
						var name = n.structname;
						var args = n.args;
						var oldLocals = new FlowArray();
						var code = c.body;
						var args : FlowArray<String> = c.args;
						for (i in 0...args.length) {
							var a = args[i];
							var oldLocal = names.locals.get(a);
							var stackslot = names.nlocals;
							names.locals.set(a, Local(stackslot, false));
							names.nlocals++;
							names.registerLocalType(a, getTypeName(n.args[i].type));
							oldLocals.push(oldLocal);
						}
						var nr = 0;
						for (name in args) {
							extra.stack(1);
							if (names.slots.exists(name)) {
								extra.stack(1);
							}
							if (names.slots.exists(name)) {
								extra.stack(-1);
							}
							extra.stack(-1);
						}
						extra.stack(-1);
						scan(c.body, extra);
						extra.stack(-1);
						var args : FlowArray<String> = c.args;
						for (i in 0...args.length) {
							var name = args[i];
							var o = oldLocals[i];
							if (o == null) {
								names.locals.remove(name);
							} else {
								names.locals.set(name, o);
							}
						}
						if (names.nlocals > names.maxlocals) names.maxlocals = names.nlocals;
						names.nlocals = localsNow;
					}
				}
			}
			extra.stack(-1);

		case SimpleSwitch(value, cases, pos):
			scan(value, extra);
			for (c in cases) {
				scan(c.body, extra);
				extra.stack(-1);
			}
			// extra.stack(-1);
		case Native(name, io, args, result, defbody, pos):
			throw "Not implemented: " + Prettyprint.print(v);
		case NativeClosure(nargs, fn, pos):
			throw "Not implemented: " + Prettyprint.print(v);
 		case StackSlot(q0, q1, q2):
			throw "Not implemented: " + Prettyprint.print(v);
		}
	}
	
	function scanLambda(name, extra : Extra) {
		var free = functionFreeVars.get(name);
		extra.needActivation = extra.needActivation || (free.length > 0);
		extra.hasGlobalOrClosureReference = true;
		var names = extra.names;
		for (f in free) {
			var local = names.locals.get(f);
			var outer = names.toplevelAndOuter.get(f);
			var closure = names.freeVariablesFound.get(f);
			
			var resolution = if (local != null) local else if (outer != null) outer else closure;
			if (resolution != null) {
				var found = false;
				for (slotVar in extra.slotVars) {
					if (slotVar.name == f) {
						found = true;
						break;
					}
				}
				if (!found) {
					extra.slotVars.push( { name : f, resolution : resolution } );
				}
			}
		}
		
		var nested = lambdaTree.get(name);
		for (n in nested) {
			scanLambda(n, extra);
		}
	}
	
	function hasGlobalOrClosureReference(e : Flow, names : SwfNames) : Bool {
		var found = false;
		FlowUtil.traverseExp(e, function (e) {
			switch (e) {
			case VarRef(name, p): {
				var sdef = structDefs.get(name);
				var free = names.freeVariablesFound.get(name);
				var outer = names.toplevelAndOuter.get(name);
				if (free != null || outer != null || (sdef != null && sdef.args.length == 0)) {
					found = true;
				}
			}
			case Lambda(a, t, b, _, p):
				found = true;
			default:
			}
		});
		return found;
	}
	
  function writeCall(closure : Flow, arguments : FlowArray<Flow>, names : SwfNames, entryJump : Void ->  Void, tailcall : Bool) : Bool {
		switch (closure) {
		case VarRef(name, position): {
			var s = structDefs.get(name);
			if (s != null) {
				// Struct!
				if (s.args.length == 0) {
					ctx.op(OpCode.OGetLex(ctx.property(name)));
					return false;
				} else if (structClasses) {
					ctx.op(OFindPropStrict(ctx.type("FS_"+name)));
					for (v in arguments) {
						encode(v, names, entryJump, false);
					}
					ctx.op(OConstructProperty(ctx.type("FS_"+name),arguments.length));
					return false;
				}

				ctx.op(OpCode.OString(ctx.string("_id")));
				encode(ConstantI32(s.id, position), names, entryJump, false);
				
				var i = 0;
				for (v in arguments) {
					ctx.op(OpCode.OString(ctx.string(s.args[i].name)));
					encode(v, names, entryJump, false);
					++i;
				}
				ctx.op(OpCode.OObject(1 + arguments.length));
				return false;
			} else {
				var local = names.locals.get(name);
				var free = names.freeVariablesFound.get(name);
				var outer = names.toplevelAndOuter.get(name);
				if (local == null && free == null && outer != null) {
					// Global function call. We can optimize this!
					if (tailcall && name == names.funName) {
						var idxlist = [];

						for (i in 0...arguments.length) {
							var a = arguments[i];

							// Skip arguments that are passed through unchanged
							switch (a) {
							case VarRef(name, pos):
								var local = names.locals.get(name);
								if (local != null && !names.slots.exists(name)) {
									switch (local) {
									case Local(slot, parameter):
										if (slot == i+1)
											continue;
									default:
									}
								}
							default:
							}

							idxlist.push(i);
							encode(a, names, entryJump, false);
						}

						while (idxlist.length > 0)
							ctx.op(OSetReg(idxlist.pop()+1));

					  entryJump();
					  return true;
					}

					var nname = nativeNames.get(name);
					if ((nname == "Native.strlen" || nname == "Native.length") && arguments.length == 1) {
						encode(arguments[0], names, entryJump, false);
						ctx.op(OpCode.OGetProp(ctx.property("length")));
						return false;
					} else if (nname == "Native.getCharCodeAt" && arguments.length == 2) {
						encode(arguments[0], names, entryJump, false);
						encode(arguments[1], names, entryJump, false);
						ctx.op(OpCode.OCallProperty(ctx.type('http://adobe.com/AS3/2006/builtin.charCodeAt'), 1));
						return false;
					} else if (nname == "Native.substring" && arguments.length == 3) {
						encode(arguments[0], names, entryJump, false);
						encode(arguments[1], names, entryJump, false);
						encode(arguments[2], names, entryJump, false);
						ctx.op(OpCode.OCallProperty(ctx.type('http://adobe.com/AS3/2006/builtin.substr'), 2));
						return false;
					} else if (nname == "Native.concat" && arguments.length == 2) {
						encode(arguments[0], names, entryJump, false);
						encode(arguments[1], names, entryJump, false);
						ctx.op(OpCode.OCallProperty(ctx.type('http://adobe.com/AS3/2006/builtin.concat'), 1));
						return false;
					} else {
						ctx.op(OpCode.OFindProp(ctx.property(name)));
						for (a in arguments) {
						    encode(a, names, entryJump, false);
					    }
						ctx.op(OpCode.OCallProperty(ctx.property(name), arguments.length));
						return false;
					}
				}
			}
		}
		default: 
		}
		// Call with closure on the stack
		encode(closure, names, entryJump, false);
		ctx.op(OpCode.OGetGlobalScope);
		for (a in arguments) {
			encode(a, names, entryJump, false);
		}
		ctx.op(OpCode.OCallStack(arguments.length));
		return false;
	}
	
	function getType(t : FlowType) {
		return ctx.type(getTypeName(t));
	}
	
	function getTypeName(t : FlowType) : String {
		if (t == null ) return ("*");
		var ut = FlowUtil.untyvar(t);
		if (ut == null) return ("*");
		return switch (ut) {
			case TVoid: "*";
			case TBool: "Boolean";
			case TInt: "int";
			case TDouble: "Number";
			case TString: "String";
			case TFlow: "*";
			case TArray(t): "Array";
			case TReference(t): "FlowRefObject";
			case TName(n, a): structTypeName;
			case TFunction(a, r): "Function";
			case TUnion(min, max): structTypeName;
			case TStruct(s, a, m): structTypeName;
			default: "*";
		};
	}

	var structTypeName : String;
	var nativeClasses : Map<String,Bool>;
	var nativeNames : Map<String,String>;
	var functionIds : Map<String,Index<MethodType>>;
	var functionFreeVars : Map<String,FlowArray<String>>;
	// What lambdas are contained in what?
	var lambdaTree : Map<String,FlowArray<String>>;
	var structDefs : Map<String,StructDef>;
	var structsOrder : Array<{ name : String, args : FlowArray<MonoTypeDeclaration>}>;
}
