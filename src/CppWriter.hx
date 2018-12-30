import Flow;
import HaxeWriter;
using Lambda;

enum CppTagType {
	TVoid;
	TBool;
	TInt;
	TDouble;
	TString;
	TArray;
	TStruct;
	TCodePointer;
	TNativeFn;
	TRefTo;
	TNative;
	TClosurePointer;
}

typedef StructOrderInfo = {
	compare_idx: Int,
	name: String,
	args: FlowArray<MonoTypeDeclaration>
};

typedef StructInfo = {
	id : Null<Int>, structname : String,
	args : FlowArray<MonoTypeDeclaration>,
	atypes : FlowArray<CppTagType>,
	empty_addr : Null<Int>
};

enum CppPlaceType {
	GlobalVar;
	Local;
	Argument;
	Temporary;
	SlotAlias(struct_var : CppPlaceInfo, idxvar : String);
	FieldAlias(struct_var : CppPlaceInfo, struct_info : StructInfo);
	GlobalFunction(nargs : Int, native : Null<String>);
	Struct(info : StructInfo);
	NoPlace(code : Flow, errormsg : String);
}

// Information about already performed type checks
typedef PlaceMetadata = {
	context : Int,
	dirty : Bool,
	tag : Null<CppTagType>,
	type : Null<FlowType>,
	struct_size : Null<Int>,
	struct_id : Null<Int>,
	known_fields : Null<List<String>>,
	known_compares : Null<List<CppPlaceInfo>>,
	struct_ptr_gcid : Null<Int>,
	struct_ptr_types : Null<List<String>>
}

// Information about a memory location allocated to store a specific value.
// The same location may be used for any number of places at different times.
class CppPlaceInfo {
	public var env: CppEnvironment;
	public var place: CppPlaceType;
	public var slot: Int;
	public var name : Null<String>;

	public var meta : PlaceMetadata;

	// Unique id for every distinct place in the environment.
	public var uid: Int;
	private static var next_guid: Int = 0;

	public function new(env: CppEnvironment, place: CppPlaceType, slot: Int, ?name : String = null) {
		this.env = env;
		this.place = place;
		this.slot = slot;
		this.name = name;
		this.meta = {
			context: if (env != null) env.cur_ctx.id else -1,
			dirty: false,

			tag: null,
			type: null,
			struct_size: null,
			struct_id: null,
			known_fields: null,
			known_compares: null,
			struct_ptr_gcid: null,
			struct_ptr_types: null
		};

		if (env != null)
			this.uid = env.next_uid++;
		else
			this.uid = next_guid++;
	}

	public static var meta_fields = [
		'tag', 'type', 'struct_size', 'struct_id',
		'known_fields', 'known_compares',
		'struct_ptr_gcid', 'struct_ptr_types'
	];
	public static var meta_merge_fn : Array<Dynamic> = [
		function(a:Dynamic,b:Dynamic) { return if (a == b) a else null; },
		function(a:Dynamic,b:Dynamic) { return if (a == b) a else null; },
		function(a:Null<Int>,b:Null<Int>) { return if (b == null) null else if (a > b) b else a; },
		function(a:Null<Int>,b:Null<Int>) { return if (a == b) a else null; },
		function(a : List<String>, b : Null<List<String>>) {
			return if (b == null) null
			else a.filter(function(v) { return b.has(v); });
		},
		function(a : List<CppPlaceInfo>,b : Null<List<CppPlaceInfo>>) {
			return if (b == null) null
			else a.filter(function(v) { return b.has(v); });
		},
		function(a:Null<Int>,b:Null<Int>) { return if (b == null) null else if (a > b) b else a; },
		function(a : List<String>, b : Null<List<String>>) {
			return if (b == null) null
			else a.filter(function(v) { return b.has(v); });
		},
	];

	public static function clearMeta(meta : PlaceMetadata) {
		for (fi in meta_fields)
			Reflect.setField(meta, fi, null);
	}
	public static function copyMeta(meta : PlaceMetadata) {
		var rv = Reflect.copy(meta);
		if (rv.known_fields != null)
			rv.known_fields = rv.known_fields.list();
		if (rv.known_compares != null)
			rv.known_compares = rv.known_compares.list();
		if (rv.struct_ptr_types != null)
			rv.struct_ptr_types = rv.struct_ptr_types.list();
		return rv;
	}

	public function isSame(info2 : CppPlaceInfo) {
		return slot == info2.slot && Type.enumEq(place, info2.place);
	}

	// Temporarily overwrite the actual location, retaining the uid and
	// meta identity. Returns a callback to restore the original state.
	public function substituteLocation(info2 : CppPlaceInfo) : Void->Void {
		var me = this;

		var cur_place = place;
		var cur_slot = slot;
		place = info2.place;
		slot = info2.slot;

		rvalue = lvalue = null;

		return function() {
			me.place = cur_place;
			me.slot = cur_slot;
			me.rvalue = me.lvalue = null;
		};
	}

	public function isStub() {
		return slot < 0;
	}

	private var lvalue : String;

	private static var GLOBALS = 'getSelf(RUNNER)->globals[';
	private static var LOCALS = 'locals[';
	private static var TEMPS = 'temps[';
	private static var RUNNER_ARG = 'RUNNER_ARG(';
	private static var CMSTART = '/*';
	private static var CMEND = '*/';
	private static var CMENDPR = '*/)';
	private static var CMENDBR = '*/]';
	private static var RPAREN = ')';

	public function getLValue() : String {
		if (lvalue != null)
			return lvalue;

		var sb = new StringBuf();

		switch (place) {
		case GlobalVar:
			sb.add(GLOBALS); sb.add(slot); sb.add(CMSTART); sb.add(name); sb.add(CMENDBR);
		case Local:
			sb.add(LOCALS); sb.add(slot); sb.add(CMSTART); sb.add(name); sb.add(CMENDBR);
		case Argument:
			env.args_used = true;
			if (slot < 0) sb.add('RUNNER_CLOSURE')
			else {
				sb.add(RUNNER_ARG); sb.add(slot); sb.add(CMSTART); sb.add(name); sb.add(CMENDPR);
			}
		case Temporary:
			sb.add(TEMPS); sb.add(slot); sb.add(RBRACE);
		case Struct(info): throw "no lvalue for struct "+info.structname;
		case SlotAlias(where,idx): throw "no lvalue for field alias";
		case FieldAlias(where,sinfo): throw "no lvalue for field alias";
		case GlobalFunction(_,_): throw "no lvalue for global function";
		case NoPlace(code, err): throw Prettyprint.getLocation(code)+': '+err;
		}

		return lvalue = sb.toString();
	}

	public function isClosureRef() : Bool {
		switch (place) {
		case Argument:
			return (slot < 0);
		default:
			return false;
		}
	}

	public function isLValue() : Bool {
		return switch (place) {
		case GlobalVar: true;
		case Local: true;
		case Argument: true;
		case Temporary: true;
		default: false;
		}
	}

	private var rvalue : String;

	private static var FUNCTIONS = 'getSelf(RUNNER)->functions[';
	private static var LBRACE = '[';
	private static var RBRACE = ']';

	public function getRValue(ctx : CppContext) : String {
		if (rvalue != null)
		{
			switch (place) {
				case SlotAlias(where,idxvar):
					ctx.ensureStructPtr(where, '');
				case FieldAlias(where,sinfo):
					ctx.ensureStructPtr(where, sinfo.structname);
				default:
			}

			return rvalue;
		}

		var sb = new StringBuf();

		switch (place) {
		case GlobalFunction(_,_):
			if (slot < 0) throw 'no assigned function slot';
			sb.add(FUNCTIONS); sb.add(slot); sb.add(CMSTART); sb.add(name); sb.add(CMENDBR);
		case SlotAlias(where,idxvar):
			sb.add(ctx.getStructPtr(where, ''));
			sb.add(LBRACE); sb.add(untyped idxvar==null?slot:idxvar);
			sb.add(CMSTART); sb.add(name); sb.add(CMENDBR);
		case FieldAlias(where,sinfo):
			var fname = sinfo.args[slot].name;
			sb.add(ctx.getStructField(where,sinfo.structname,fname,sinfo.atypes[slot]));
			if (name != null && name != fname) {
				sb.add(CMSTART); sb.add(name); sb.add(CMEND);
			}
		case Struct(info):
			if (info.args.length != 0)
				throw 'no rvalue for struct with parameters: '+info.structname;
			sb.add('StackSlot::MakeStruct(MakeFlowPtr('+info.empty_addr+'),'+slot+')');
		default:
			return rvalue = getLValue();
		}

		return rvalue = sb.toString();
	}

	public function getRawField(ctx : CppContext, type : CppTagType) : String {
		switch (place) {
		case FieldAlias(where,sinfo):
			if (sinfo.atypes[slot] == type)
				return ctx.getStructPtr(where,sinfo.structname)+'->fl_'+sinfo.args[slot].name;
		default:
		}

		return null;
	}

	public function getStructAddr(ctx : CppContext) : String {
		switch (place) {
		case FieldAlias(where,sinfo):
			if (sinfo.atypes[slot] == TStruct)
				return ctx.getStructPtr(where,sinfo.structname)+'->fl_'+sinfo.args[slot].name;
		default:
		}

		return getRValue(ctx)+'.GetRawStructPtr()';
	}

	public static function tagToString(tag : CppTagType) {
		return switch (tag) {
		case TVoid: "TVoid";
		case TBool: "TBool";
		case TInt: "TInt";
		case TDouble: 'TDouble';
		case TString: 'TString';
		case TArray: 'TArray';
		case TStruct: 'TStruct';
		case TCodePointer: 'TCodePointer';
		case TNativeFn: 'TNativeFn';
		case TRefTo: 'TRefTo';
		case TNative: 'TNative';
		case TClosurePointer: 'TClosurePointer';
		}
	}

	public static function getStructAType(t : FlowType) : Null<CppTagType> {
		return switch(t) {
			case TVoid: null;
			case TBool: TBool;
			case TInt: TInt;
			case TDouble: TDouble;
			case TString: TString;
			case TArray(type): TArray;
			case TStruct(name, args, max): TStruct;
			case TName(name,args): TStruct;
			case TReference(type): TRefTo;
			default: null;
		}
	}

	public static function isStructFieldTag(type : CppTagType) : Bool
	{
		if (type == null)
			return false;

		return switch (type) {
		case TBool: true;
		case TInt: true;
		case TDouble: true;
		case TString: true;
		case TArray: true;
		case TRefTo: true;
		case TStruct: true;
		default: false;
		}
	}

	public static function structFieldCode(type : CppTagType) : String
	{
		if (type == null)
			return 'slot';

		return switch (type) {
		case TBool: 'bool';
		case TInt: 'int';
		case TDouble: 'double';
		case TString: 'string';
		case TArray: 'array';
		case TRefTo: 'ref';
		case TStruct: 'struct';
		default: throw "impossible";
		}
	}

	public static function isNonGCFieldType(type : CppTagType) : Bool
	{
		if (type == null)
			return false;

		return switch (type) {
		case TBool: true;
		case TInt: true;
		case TDouble: true;
		default: false;
		}
	}
}

enum CppOutputLocation {
	OutputNone;
	OutputReturn;
	OutputVar(rv : CppPlaceInfo);
	OutputExpr(cb : CppContext -> String -> String);
	OutputScalar(name : String, tag : CppTagType);
}

// Contains current information about the function being compiled.
// Controls mapping of local variable names to places.
class CppEnvironment {
	public function new(parent : CppEnvironment, mname : String, vname : String) {
		this.parent = parent;
		this.mname = mname;
		this.vname = vname;

		lines = 0;
		line_str = new StringBuf();
		nlocals = ntemps = nargs = next_ctx = 0;
		upvalues = [];
		idxvars = new OrderedHash();
		args_used = tail_call = false;
		locals = new Map();
		local_reuse = [];
		meta_globals = new Map();

		if (parent != null)
			depth = parent.depth + 1;
		else
			depth = 1;

		next_uid = 1000000*depth;

		cur_ctx = new CppContext(this, '    ');
	}

	public var parent : CppEnvironment;
	public var mname : String;
	public var vname : String;
	public var depth : Int;

	public var next_uid : Int;
	public var next_ctx : Int;

	public var nlocals : Int;
	public var ntemps : Int;
	public var nargs : Int;

	private var local_reuse : Array<Int>;

	public var args_used : Bool;
	public var closure : CppPlaceInfo;
	public var closure_type : StructInfo;
	public var upvalues : Array<String>;
	public var idxvars : OrderedHash<String>;

	public var tail_call : Bool;

	public var lines : Int;
	public var line_str : StringBuf;
	public var cur_ctx : CppContext;

	public var locals : Map<String, CppPlaceInfo>;

	public var struct_list : Array<StructInfo>;

	public var meta_globals : Map<Int, { def : CppPlaceInfo, old: PlaceMetadata, my: PlaceMetadata }>;

	public function mktemp(id : Int) : CppPlaceInfo {
		if (id >= ntemps) ntemps = id+1;
		return new CppPlaceInfo(this, Temporary, id);
	}

	public function tempvar(base : String) : String {
		return base+(next_uid++);
	}

	public function mkupvalue(name : String, free : CppPlaceInfo) : CppPlaceInfo {
		if (closure == null) {
			closure = new CppPlaceInfo(this, Argument, -1);
			closure.meta.context = 0;

			closure_type = {
				id: null, structname: mname,
				args: new FlowArray<MonoTypeDeclaration>(),
				atypes: new FlowArray<CppTagType>(),
				empty_addr: null
			};
		}

		var id = upvalues.length;
		var info = new CppPlaceInfo(this, FieldAlias(closure, closure_type), id, name);

		var type = free.meta.type;
		if (type == null)
			type = TFlow;

		var ttag = CppPlaceInfo.getStructAType(type);
		var vtag = free.meta.tag;
		if (!CppPlaceInfo.isStructFieldTag(vtag))
			vtag = null;
		if (ttag != null)
			vtag = (vtag == null || vtag == ttag) ? ttag : null;

		closure_type.args.push({
			name: 'up_'+info.slot,
			type: type,
			position: null,
			is_mutable: false
		});
		closure_type.atypes.push(vtag);

		info.meta.context = 0;
		info.meta.dirty = true;
		info.meta.tag = vtag;
		info.meta.type = type;

		upvalues.push(name);
		locals.set(name, info);
		return info;
	}

	public function mklocal(name : String) : CppPlaceInfo {
		var id = if (local_reuse != null && local_reuse.length > 0) {
			local_reuse.pop();
		} else {
			nlocals++;
		};

		return new CppPlaceInfo(this, Local, id, name);
	}

	public function poplocal(name : String, olddef : CppPlaceInfo) {
		var curdef = locals.get(name);
		locals.set(name, olddef);

		if (curdef.place == Local)
			local_reuse.push(curdef.slot);
	}

	public function registerIdxVar(name : String, type : String) {
		if (idxvars.get(name) == null)
			idxvars.set(name, type);
	}

	public function stashGlobalMeta() {
		for (info in meta_globals.iterator()) {
			info.my = info.def.meta;
			info.def.meta = info.old;
		}
	}

	public function restoreGlobalMeta() {
		for (info in meta_globals.iterator())
			info.def.meta = info.my;
	}
}

// Tracks information specific to the current code flow branch,
// and implements its proper merging when flow converges.
class CppContext {
	public function new(env : CppEnvironment, indent : String) {
		this.env = env;
		this.prev = env.cur_ctx;
		this.indent = indent;
		this.id = env.next_ctx++;

		gc_index = (prev != null) ? prev.gc_index : 0;

		local_names = [];
		local_binds = [];
		meta = new Map();
	}

	public var env : CppEnvironment;
	public var prev : CppContext;
	public var id : Int;

	public var gc_index : Int;

	public var indent : String;

	private var local_names : Array<String>;
	private var local_binds : Array<CppPlaceInfo>;

	private var meta : Map<Int, { def : CppPlaceInfo, old: PlaceMetadata, my: PlaceMetadata }>;

	public function exit() {
		popdefs();

		for (mid in meta.iterator()) {
			mid.def.meta = mid.old;

			// Forget globals if restored
			if (mid.def.env == null && mid.old.context < 0)
				env.meta_globals.remove(mid.def.uid);
		}

		env.cur_ctx = prev;
	}

	private static var NEWLINE = '\n';

	public function wrbegin() : StringBuf {
		env.lines++;
		var line_str = env.line_str;
		line_str.add(indent);
		return line_str;
	}

	public function wr(s : String) {
		var line_str = wrbegin();
		line_str.add(s);
		line_str.add(NEWLINE);
	}

	public function wrsemi(str : String) {
		var line_str = wrbegin();
		line_str.add(str);
		line_str.add(SEMI_NL);
	}

	public function wrsemi2(str1 : String, str2 : String) {
		var line_str = wrbegin();
		line_str.add(str1);
		line_str.add(str2);
		line_str.add(SEMI_NL);
	}

	public function wrsemi3(str1 : String, str2 : String, str3 : String) {
		var line_str = wrbegin();
		line_str.add(str1);
		line_str.add(str2);
		line_str.add(str3);
		line_str.add(SEMI_NL);
	}

	public function wrsemi4(str1 : String, str2 : String, str3 : String, str4 : String) {
		var line_str = wrbegin();
		line_str.add(str1);
		line_str.add(str2);
		line_str.add(str3);
		line_str.add(str4);
		line_str.add(SEMI_NL);
	}

	public function enter(idelta : String) {
		return env.cur_ctx = new CppContext(env, indent + idelta);
	}

	public function localMeta(def : CppPlaceInfo) {
		var curmeta = def.meta;

		var meta = if (curmeta.context >= id) {
			curmeta;
		} else {
			var newmeta = CppPlaceInfo.copyMeta(curmeta);
			newmeta.context = id;
			meta.set(def.uid, { def: def, old: curmeta, my: newmeta });

			// Remember that a global was changed
			if (def.env == null && curmeta.context < 0)
				env.meta_globals.set(def.uid, { def: def, old: curmeta, my: newmeta });

			def.meta = newmeta;
		};

		meta.dirty = true;
		return meta;
	}

	public function join_one(child : CppContext) {
		if (child.gc_index > gc_index)
			gc_index = child.gc_index;
	}

	public function join(children : Array<CppContext>) {
		if (children.length == 0) return;

		for (child in children)
			join_one(child);

		var flist = CppPlaceInfo.meta_fields;

		for (mid in children[0].meta.iterator()) {
			var defid = mid.def.uid;

			var best = [];
			for (fn in flist)
				best.push(Reflect.field(mid.my, fn));
			var ok = true;

			for (i in 1...children.length) {
				var cur = children[i].meta.get(defid);
				if (cur == null) {
					ok = false;
					break;
				}
				for (fi in 0...flist.length) {
					if (best[fi] == null)
						continue;
					best[fi] = CppPlaceInfo.meta_merge_fn[fi](
						best[fi], Reflect.field(cur.my, flist[fi])
					);
				}
			}

			if (!ok)
				continue;

			ok = false;
			var cur = mid.def.meta;
			for (fi in 0...flist.length) {
				if (best[fi] == Reflect.field(cur, flist[fi]))
					continue;
				ok = true;
				break;
			}

			if (!ok)
				continue;

			var upd = localMeta(mid.def);
			var dirty = false;
			for (fi in 0...flist.length) {
				if (best[fi] != null) dirty = true;
				Reflect.setField(upd, flist[fi], best[fi]);
			}
			upd.dirty = dirty;
		}
	}

	public function pushdef(def : CppPlaceInfo) {
		local_names.push(def.name);
		local_binds.push(env.locals.get(def.name));
		env.locals.set(def.name, def);
	}

	public function defpos() { return local_names.length; }

	public function popdefs(?pos : Int = 0) {
		for (i in 0...(local_names.length - pos))
			env.poplocal(local_names.pop(), local_binds.pop());
	}

	private static var SPTR_ = 'sptr_';
	private static var UNDERSCORE = '_';
	private static var CMSTART = '/*';
	private static var CMEND = '*/';
	private static var GET_ASPTR = ' = RUNNER->GetArraySlotPtr(';
	private static var COMMA = ',';
	private static var EQ_LPAREN = ' = (';
	private static var GET_SPTR = '*)RUNNER->GetStructPtr(';
	private static var GET_CSPTR = '*)RUNNER->GetClosureStructPtr(';

	public function ensureStructPtr(sref : CppPlaceInfo, structname : String, init : Bool = true, sb : StringBuf = null)
	{
		var bad_gcid = sref.meta.struct_ptr_gcid == null || sref.meta.struct_ptr_gcid < gc_index;
		var stale = (bad_gcid ||
					 sref.meta.struct_ptr_types == null ||
					 !sref.meta.struct_ptr_types.has(structname));

		if (stale && sb == null)
			sb = new StringBuf();

		if (sb != null) {
			sb.add(SPTR_);
			sb.add(sref.uid);
			if (structname.length > 0)
			{
				sb.add(UNDERSCORE);
				sb.add(structname);
			}
		}

		if (stale)
		{
			var vname = sb.toString();

			if (structname == '') {
				env.registerIdxVar(vname, 'const StackSlot*');

				if (init) {
					var size = sref.meta.struct_size == null ? 1 : sref.meta.struct_size;
					var sb2 = wrbegin();
					sb2.add(vname); sb2.add(GET_ASPTR); sb2.add(sref.getRValue(this));
					sb2.add(COMMA); sb2.add(size<1?1:size); sb2.add(PAREN_SEMI_NL);
				}
			} else {
				var vtype = 'FS_'+structname;
				env.registerIdxVar(vname, vtype+'*');

				if (init) {
					var sb2 = wrbegin();
					sb2.add(vname); sb2.add(EQ_LPAREN); sb2.add(vtype);

					if (sref.isClosureRef()) {
						sb2.add(GET_CSPTR); sb2.add(sref.getRValue(this));
					} else {
						sb2.add(GET_SPTR); sb2.add(sref.getStructAddr(this));
					}

					sb2.add(PAREN_SEMI_NL);
				}
			}

			var lm = localMeta(sref);
			if (lm.struct_ptr_types == null || bad_gcid)
				lm.struct_ptr_types = new List();
			lm.struct_ptr_gcid = gc_index;
			lm.struct_ptr_types.push(structname);
		}
	}

	public function getStructPtr(sref : CppPlaceInfo, structname : String = '', init : Bool = true) : String
	{
		var sb = new StringBuf();
		ensureStructPtr(sref, structname, init, sb);

		if (sref.name != null) {
			sb.add(CMSTART); sb.add(sref.name); sb.add(CMEND);
		}

		return sb.toString();
	}

	public function getStructField(sref : CppPlaceInfo, structname : String, fname : String, ftype : CppTagType) : String
	{
		var ptr = getStructPtr(sref, structname);
		var vname = ptr+'->fl_'+fname;
		if (ftype == null)
			return vname;

		return switch (ftype) {
		case TBool: 'StackSlot::MakeBool('+vname+')';
		case TInt: 'StackSlot::MakeInt('+vname+')';
		case TDouble: 'StackSlot::MakeDouble('+vname+')';
		case TString: vname;
		case TArray: vname;
		case TRefTo: vname;
		case TStruct:
			'StackSlot::MakeStruct('+vname+',RUNNER->GetStructPtr('+vname+')->StructId)';
		default:
			throw "impossible";
		}
	}

	public function tempvar(base : String, tag : CppTagType, ?init : String = null) : String {
		var name = env.tempvar(base);
		var type = switch (tag) {
		case TInt: 'int';
		case TDouble: 'double';
		case TBool: 'bool';
		default: throw 'bad';
		}

		wrsemi4(type,SPACE,name, init!=null ? SPC_EQ_SPC+init : EMPTYSTR);
		return name;
	}

	public function inc_gc() {
		gc_index++;
	}

	private static var EMPTYSTR = '';
	private static var SPACE = ' ';
	private static var SPC_EQ_SPC = ' = ';
	private static var CHECK_ERROR = 'CHECK_ERROR(';
	private static var PAREN_SEMI_NL = ');\n';
	private static var SEMI_NL = ';\n';

	public function wrcheck(str : String, ?gc = false) {
		var line_str = wrbegin();
		line_str.add(CHECK_ERROR);
		line_str.add(str);
		line_str.add(PAREN_SEMI_NL);
		if (gc) gc_index++;
	}

	public function wrcheckopt(str : String, check : Bool, ?gc = false) {
		if (gc)
			inc_gc();
		if (check)
			wrcheck(str);
		else
		{
			var line_str = wrbegin();
			line_str.add(str);
			line_str.add(SEMI_NL);
		}
	}
}

typedef StackTop = {
	temp: Int
}

class CppWriter {
	public function new(includes : Array<String>, p : Program, debug : Bool, entry : String, outdir : String, extStructDefs : Bool)  {
		Profiler.get().profileStart("C++ export");
		this.p = p;
		this.extStructDefs = extStructDefs;
		this.entry = entry;
		this.includes = includes;

		// Allocate a buffer for the bytecode (to store constant strings in)
		bytecode = new BytesOutput(new DebugInfo());
		bytecode.writeByte(Bytecode.CLast);
		bytecode.writeByte(Bytecode.CLast);

		output_dir = outdir;
		file_table = new Map();

		method_names = [];
		function_table = [];
		function_map = new Map();
		global_names = [];
		global_map = new Map();
		field_index_table = [];
		field_index_list = [];
		field_index_map = new Map();
		const_strings = new Map();

		initNativeTables();

		// First, number the structs
		enumerateStructs();

		// Process natives, functions and globals
		enumerateToplevel();

		// Finally, assemble the output file
		emitOutput();

		for (f in file_table.iterator())
			f.close();
	}

	var p : Program;
	var extStructDefs : Bool;
	var entry : String;
	var includes : Array<String>;

	var output_dir : String;
	var file_table : Map<String, haxe.io.Output>;

	private function getOutputFile(name : String) {
		var f = file_table.get(name);
		if (f == null) {
			try {
				f = sys.io.File.write(output_dir+'/'+name, false);
			} catch (err: Dynamic) {
				trace(err);
				Sys.exit(1);
			}
			file_table.set(name, f);

			if (StringTools.endsWith(name, '.cpp'))
				f.writeString('#include "gen_common.h"\n');
		}
		return f;
	}

	var num_structs : Int;
	var init_count : Int;
	var struct_counts : Array<Int>; // by size
	var structs : Map<String, StructInfo>;
	var closure_structs : Map<String,StructInfo>;
	var structsOrder : Array<StructOrderInfo>;
	var struct_list : Array<StructInfo>;
	var struct_hdr_lines : Array<String>;
	var struct_def_lines : Array<String>;
	var struct_gcdef_lines : Array<String>;
	var struct_field_names : Array<String>;
	var struct_field_types : Array<Int>;
	var struct_info_refs : Array<{
		fld_idx : Null<Int>, type_idx : Null<Int>,
		def_idx : Null<Int>, gcdef_idx : Null<Int>,
		gcdef_cnt : Int, empty_addr : Int,
		name_addr : Int, name_sz : Int
	}>;

	var bytecode : BytesOutput;
	var const_strings : Map<String, { addr : Int, size : Int, rslot : String }>;

	var method_names : Array<String>;
	var function_table : Array<{name:String, native_name:Null<String>, nargs:Int, fn_name:Null<String>}>;
	var function_map : Map<String, Int>;

	var global_names : Array<String>;
	var global_map : Map<String, CppPlaceInfo>;

	// Table for fast lookup of fields by name; maps [name][structid] -> index
	var field_index_table : Array<Array<Int> >;
	var field_index_map : Map<String, Int>;
	var field_index_list : Array<String>;

	private function wrl(o : haxe.io.Output, lines : Array<String>) {
		for (ln in lines) {
			o.writeString(ln);
			o.writeString('\n');
		}
	}

	private function wrarray(o : haxe.io.Output, cnt : Int, per_line : Int, head : String, indent : String, tail : String, cb : StringBuf -> Int -> Void)
	{
		var buf = new StringBuf();
		bufarray(buf, cnt, per_line, head, indent, tail, cb);
		o.writeString(buf.toString());
	}

	private function bufarray(buf : StringBuf, cnt : Int, per_line : Int, head : String, indent : String, tail : String, cb : StringBuf -> Int -> Void)
	{
		if (cnt > 0)
			buf.add(head);

		var comma = ', ';
		var nl = ',\n';

		for (i in 0...cnt) {
			cb(buf, i);
			if (i < cnt-1) {
				if ((i+1)%per_line != 0)
					buf.add(comma);
				else {
					buf.add(nl);
					buf.add(indent);
				}
			} else {
				buf.add(tail);
			}
		}
	}

	private function emitOutput() {
		var bytes = bytecode.extractBytes();

		var h = getOutputFile('gen_common.h');
		var o = getOutputFile('gen_tables.cpp');

		o.writeString('#include "core/GarbageCollector.h"\n');

		wrl(h, ['#include "core/NativeProgram.h"',
				'#include "core/RunnerMacros.h"',
				'',
				'#include <limits>',
				'',
				'#pragma GCC diagnostic ignored "-Wunused-parameter"',
				'',
				'#ifndef FLOW_COMPACT_STRUCTS',
				'#error Runner built without compact structs is not supported',
				'#endif',
				'',
				'namespace flowgen_'+entry+' {',
				'    using namespace flowgen_common;',
				'',
				'    static const unsigned NUM_CODE_BYTES = '+bytes.length+';',
				'    static const unsigned NUM_FUNCTIONS = '+function_table.length+';',
				'    static const unsigned NUM_STRUCTS = '+num_structs+';',
				'    static const unsigned NUM_STRUCT_DEFS = '+structsOrder.length+';',
				'    static const unsigned NUM_FIELDS = '+field_index_table.length+';',
				'    static const unsigned NUM_GLOBALS = '+global_names.length+';']);

		if (struct_counts.length >= 1) {
			h.writeString('\n');
			for (i in 0...struct_counts.length) {
				h.writeString('    static const unsigned NUM_STRUCTS_'+i+
							' = '+struct_counts[i]+';\n');
			}
		}

		wrl(h, ['',
				'    class NativeProgramImpl : public NativeProgram {',
				'    public:',
				'        NativeProgramImpl() {}',
				'',
				'    protected:',
				'        virtual const char *getByteCode(int *length);',
				'        virtual void flowGCObject(GarbageCollectorFn fn);',
				'        virtual void onRunMain();',
				'',
				'    public:',
				'        StackSlot functions[NUM_FUNCTIONS];',
				'        StackSlot globals[NUM_GLOBALS];',
				'    };',
				'',
				'    extern const unsigned char bytecode_bytes[NUM_CODE_BYTES];',
				'    extern const NativeProgram::FunctionSpec function_specs[NUM_FUNCTIONS];',
				'    extern const NativeProgram::StructSpec struct_specs[NUM_STRUCT_DEFS];',
				'    extern const char field_index_table[NUM_FIELDS][NUM_STRUCTS_1];',
				'',
				'    __attribute__((always_inline)) inline NativeProgramImpl *getSelf(ByteCodeRunner *runner) {',
				'        return (NativeProgramImpl*)runner->getProgram();',
				'    }',
				'',
				'#pragma pack(push, 4)']);

		for (l in struct_hdr_lines)
			h.writeString('    '+l+'\n');

		wrl(h, ['#pragma pack(pop)',
				'']);

		for (name in method_names) {
			h.writeString('    DECLARE_NATIVE_METHOD('+name+')\n');
		}

		wrl(h, ['}']);

		wrl(o, ['',
				'using namespace flowgen_'+entry+';',
				'',
				'NativeProgram *load_'+entry+'() {',
				'    return new NativeProgramImpl();',
				'}',
				'',
				'const char *NativeProgramImpl::getByteCode(int *length) {',
				'    *length = NUM_CODE_BYTES;',
				'    return (const char*)bytecode_bytes;',
				'}',
				'',
				'void NativeProgramImpl::flowGCObject(GarbageCollectorFn fn) {',
				'    fn(globals, NUM_GLOBALS);',
				'}',
				'',
				'void NativeProgramImpl::onRunMain() {',
				'    RUNNER_VAR = getFlowRunner();',
				'',
				'    if (!InitStructTable(struct_specs, NUM_STRUCT_DEFS))',
				'        return;',
				'    if (!InitFunctionTable(functions, function_specs, NUM_FUNCTIONS))',
				'        return;',
				'',
				'    memset(globals, 0, sizeof(globals));',
				'    RUNNER->FreezeNativeFunctions(true);',
				'']);

		for (i in 0...init_count) {
			wrl(o, ['    aux_init'+i+'(RUNNER, NULL);',
					'    if (RUNNER->IsErrorReported()) return;']);
		}

		wrl(o, ['    fn_main(RUNNER, NULL);',
				'}',
				'',
				'const unsigned char flowgen_'+entry+'::bytecode_bytes[] = {']);

		wrarray(o, bytes.length, 20, '    ', '    ', '\n', function(buf,i) {
			buf.add(bytes.get(i));
		});

		wrl(o, ['};',
				'',
				'const NativeProgram::FunctionSpec flowgen_'+entry+'::function_specs[] = {']);

		wrarray(o, function_table.length, 1, '    ', '    ', '\n', function(buf,i) {
			var spec = function_table[i];
			buf.add('{ "'); buf.add(spec.name); buf.add('", ');
			if (spec.native_name != null) {
				buf.add('"'); buf.add(spec.native_name); buf.add('"');
			} else {
				buf.add('NULL');
			}
			buf.add(', '); buf.add(spec.nargs); buf.add(', ');
			if (spec.fn_name != null) {
				buf.add('&'); buf.add(spec.fn_name);
			} else {
				buf.add('NULL');
			}
			buf.add(' }');
		});

		wrl(o, ['};',
				'',
				'static const char *const struct_field_names[] = {']);

		wrarray(o, struct_field_names.length, 10, '    ', '    ', '\n', function(buf,i) {
			buf.add('"'); buf.add(struct_field_names[i]); buf.add('"');
		});

		wrl(o, ['};',
				'',
				'static const int struct_field_types[] = {']);

		wrarray(o, struct_field_types.length, 20, '    ', '    ', '\n', function(buf,i) {
			buf.add(struct_field_types[i]);
		});

		wrl(o, ['};',
				'',
				'static const FlowStructFieldDef struct_field_defs[] = {']);

		wrarray(o, struct_def_lines.length, 1, '    ', '    ', '\n', function(buf,i) {
			buf.add(struct_def_lines[i]);
		});

		wrl(o, ['};',
				'',
				'static const FlowStructFieldGCDef struct_field_gcdefs[] = {']);

		wrarray(o, struct_gcdef_lines.length, 1, '    ', '    ', '\n', function(buf,i) {
			buf.add(struct_gcdef_lines[i]);
		});

		wrl(o, ['};',
				'',
				'const NativeProgram::StructSpec flowgen_'+entry+'::struct_specs[] = {']);

		wrarray(o, structsOrder.length, 1, '    ', '    ', '\n', function(buf,i) {
			var s = structsOrder[i];
			var r = struct_info_refs[i];
			buf.add('{ '+s.args.length+', '+s.compare_idx+', '+
					r.name_sz+', '+r.name_addr+', '+
					(s.args.length > 0 ? 'sizeof(FS_'+s.name+')' : '4')+', '+
					r.empty_addr+', '+r.gcdef_cnt+', "'+s.name+'", ');
			if (r.fld_idx != null) {
				buf.add('&struct_field_names['+r.fld_idx+
						'], &struct_field_types['+r.type_idx+
						'], &struct_field_defs['+r.def_idx+
						'], &struct_field_gcdefs['+r.gcdef_idx+']');
			} else {
				buf.add('NULL, NULL, NULL, NULL');
			}
			buf.add(' }');
		});

		wrl(o, ['};',
				'',
				'const char flowgen_'+entry+'::field_index_table[NUM_FIELDS][NUM_STRUCTS_1] = {']);

		wrarray(o, field_index_table.length, 1, '    ', '    ', '\n', function(buf,i) {
			var ln = field_index_table[i];
			buf.add('// '); buf.add(field_index_list[i]); buf.add(':\n    { ');
			bufarray(buf, ln.length, 20, '', '      ', ' ', function(buf,j) {
				buf.add('(char)');
				buf.add(ln[j]);
			});
			buf.add('}');
		});

		wrl(o, ['};']);

		wrl(h, ['',
		        '#define CHECK_ERROR(cmd) \\',
				'    cmd; \\',
				'    if (unlikely(RUNNER->IsErrorReported())) RETVOID;',
				'#define CHECK_TAG(tag,slot,msg) \\',
				'    if (unlikely(!slot.Is##tag())) { \\',
				'        RUNNER->ReportTagError(slot, tag, msg, NULL); \\',
				'        RETVOID; \\',
				'    }',
				'#define CHECK_STRUCT(slot,fcnt,msg) \\',
				'    if (unlikely(!slot.IsStruct()) || unlikely(unsigned(slot.GetStructId()) >= NUM_STRUCTS_##fcnt)) { \\',
				'        RUNNER->ReportTagError(slot, TStruct, msg, NULL); \\',
				'        RETVOID; \\',
				'    }',
				'#define CHECK_STRUCT_TYPE(slot,id,msg) \\',
				'    if (unlikely(!slot.IsStruct()) || unlikely(unsigned(slot.GetStructId()) != id)) { \\',
				'        RUNNER->ReportStructError(slot, id, msg, NULL); \\',
				'        RETVOID; \\',
				'    }',
				'#define FIND_STRUCT_FIELD(ivar, slot, idx, name, func) \\',
				'    ivar = field_index_table[idx][slot.GetStructId()]; \\',
				'    if (unlikely(ivar < 0)) { \\',
				'        RUNNER->ReportFieldNameError(slot, name, func); \\',
				'        RETVOID; \\',
				'    }']);
	}

	private function enumerateStructs() {
		structs = new Map();
		closure_structs = new Map();

		// We do this in alphabetical order in order to avoid random changes in the
		// code just because of hash ordering differences; however, it is combined
		// with descending order by argument count to allow size checks just by
		// looking at the id range.
		structsOrder = [];
		struct_list = [];
		var nameOrder = [];
		var max_size = 0;

		for (d in p.userTypeDeclarations) {
			switch (d.type.type) {
			case TStruct(structname, cargs, max):
				var info = { compare_idx: 0, name: structname, args : cargs};
				structsOrder.push(info);
				nameOrder.push(info);
				if (cargs.length > max_size) max_size = cargs.length;
			default:
			}
		}
		structsOrder.sort(function(s1, s2) {
			return if (s1.args.length < s2.args.length) 1
			else if (s1.args.length > s2.args.length) -1
			else if (s1.name < s2.name) -1
			else if (s1.name == s2.name) 0 else 1;
		});

		// Assign compare indices
		nameOrder.sort(function(s1, s2) {
			return if (s1.name < s2.name) -1
			else if (s1.name == s2.name) 0 else 1;
		});
		for (i in 0...nameOrder.length)
			nameOrder[i].compare_idx = i;

		// Count structs and assign indices
		num_structs = 0;

		struct_counts = [];
		var last_size = max_size;
		for(i in 0...max_size+1) struct_counts.push(0);

		for (s in structsOrder) {
			var atypes = new FlowArray();

			var eaddr : Null<Int> = null;
			if (s.args.length == 0) {
				eaddr = bytecode.getPc();
				bytecode.writeInt31(num_structs);
			} else {
				for (arg in s.args) {
					var at = CppPlaceInfo.getStructAType(arg.type);
					atypes.push(at);
				}
			}

			var info = {
				id : num_structs, structname : s.name,
				args : s.args, atypes: atypes,
				empty_addr : eaddr
			};
			structs.set(s.name, info);
			struct_list.push(info);

			var place = new CppPlaceInfo(null, Struct(info), num_structs, s.name);
			if (s.args.length == 0) {
				place.meta.dirty = true;
				place.meta.tag = TStruct;
				place.meta.struct_id = num_structs;
			}
			global_map.set(s.name, place);

			var nargs = s.args.length;
			for (i in nargs+1...last_size+1)
				struct_counts[i] = num_structs;

			num_structs++;
			struct_counts[nargs] = num_structs;
			last_size = nargs;
		}

		// Build the argument info tables (uses indices from prev.loop)
		struct_field_names = [];
		struct_field_types = [];
		struct_info_refs = [];
		struct_hdr_lines = [];
		struct_def_lines = [];
		struct_gcdef_lines = [];

		for (s in structsOrder) {
			generateStructDef(s, structs.get(s.name));
		}
	}

	private function generateStructDef(s : StructOrderInfo, info : StructInfo) {
		var name = registerConstString(s.name);

		if (s.args.length == 0) {
			struct_info_refs.push({
				fld_idx: null, type_idx: null,
				def_idx: null, gcdef_idx: null,
				gcdef_cnt: 0, empty_addr: info.empty_addr,
				name_sz: name.size, name_addr: name.addr
			});
		} else {
			var refinfo = {
				fld_idx: struct_field_names.length,
				type_idx: struct_field_types.length,
				def_idx: struct_def_lines.length,
				gcdef_idx: struct_gcdef_lines.length,
				gcdef_cnt: 0, empty_addr: 0,
				name_sz: name.size, name_addr: name.addr
			};

			struct_info_refs.push(refinfo);

			struct_hdr_lines.push('struct FS_'+s.name+' {');
			struct_hdr_lines.push('    FlowStructHeader hdr;');

			for (i in 0...s.args.length) {
				var arg = s.args[i];
				struct_field_names.push(arg.name);

				if (arg.is_mutable)
					struct_field_types.push( Bytecode.CSetMutable );
				writeFlowTypeCode(arg.type);
				struct_field_types.push(-1);

				var tag = info.atypes[i];
				var fname = 'fl_'+arg.name;
				var off = '(int)offsetof(FS_'+s.name+','+fname+')';

				if (tag == null)
				{
					struct_def_lines.push('FLOW_FIELD_DEF(slot,'+off+')');
					struct_gcdef_lines.push('FLOW_FIELD_GC_DEF(slot,'+off+')');
					struct_hdr_lines.push('    StackSlot '+fname+';');
				}
				else {
					switch (tag) {
					case TBool:
						struct_def_lines.push('FLOW_FIELD_DEF(bool,'+off+')');
						struct_hdr_lines.push('    char '+fname+';');
					case TInt:
						struct_def_lines.push('FLOW_FIELD_DEF(int,'+off+')');
						struct_hdr_lines.push('    int '+fname+';');
					case TDouble:
						struct_def_lines.push('FLOW_FIELD_DEF(double,'+off+')');
						struct_hdr_lines.push('    double '+fname+';');
					case TString:
						struct_def_lines.push('FLOW_FIELD_DEF(string,'+off+')');
						struct_gcdef_lines.push('FLOW_FIELD_GC_DEF(string,'+off+')');
						struct_hdr_lines.push('    FlowStructString '+fname+';');
					case TArray:
						struct_def_lines.push('FLOW_FIELD_DEF(array,'+off+')');
						struct_gcdef_lines.push('FLOW_FIELD_GC_DEF(array,'+off+')');
						struct_hdr_lines.push('    FlowStructArray '+fname+';');
					case TRefTo:
						struct_def_lines.push('FLOW_FIELD_DEF(ref,'+off+')');
						struct_gcdef_lines.push('FLOW_FIELD_GC_DEF(ref,'+off+')');
						struct_hdr_lines.push('    FlowStructRef '+fname+';');
					case TStruct:
						struct_def_lines.push('FLOW_FIELD_DEF(struct,'+off+')');
						struct_gcdef_lines.push('FLOW_FIELD_GC_DEF(struct,'+off+')');
						struct_hdr_lines.push('    FlowPtr '+fname+';');
					default: throw "impossible";
					}
				}
			}

			struct_hdr_lines.push('};');

			refinfo.gcdef_cnt = struct_gcdef_lines.length - refinfo.gcdef_idx;
		}
	}

	private function writeFlowTypeCode(t : FlowType) {
		switch(t) {
			case TVoid: struct_field_types.push( Bytecode.CVoid );
			case TBool: struct_field_types.push( Bytecode.CBool );
			case TInt: struct_field_types.push( Bytecode.CInt );
			case TDouble: struct_field_types.push( Bytecode.CDouble );
			case TString: struct_field_types.push( Bytecode.CString );
			case TArray(type): {
				if (extStructDefs) {
					#if typepos
						struct_field_types.push( Bytecode.CTypedArray ); writeFlowTypeCode(type.val);
					#else
						struct_field_types.push( Bytecode.CTypedArray ); writeFlowTypeCode(type);
					#end
				} else {
					struct_field_types.push( Bytecode.CArray );
				}
			}
			case TStruct(name, args, max): {
				struct_field_types.push( Bytecode.CTypedStruct );
				struct_field_types.push( structs.get(name).id );
			}
			case TName(name,args): {
				struct_field_types.push( Bytecode.CStruct );
			}
			case TReference(type): {
				if (extStructDefs) {
					struct_field_types.push( Bytecode.CTypedRefTo );
					writeFlowTypeCode(type);
				} else {
					struct_field_types.push( Bytecode.CRefTo );
				}
			}
			default:
				struct_field_types.push(0xFF); // Flow
		}
	}

	private function getFieldLookupId(n : String) : Int {
		var fidx = field_index_map.get(n);

		if (fidx == null) {
			if (struct_counts.length <= 1)
				throw 'Cannot access field '+n+' - no structs have fields!';

			var table = [];

			for (i in 0...struct_counts[1]) {
				var args = structsOrder[i].args;
				var found = -1;

				for (j in 0...args.length) {
					if (args[j].name == n) {
						found = j;
						break;
					}
				}

				table.push(found);
			}

			fidx = field_index_table.length;
			field_index_table.push(table);
			field_index_list.push(n);
			field_index_map.set(n, fidx);
		}

		return fidx;
	}

	private function registerConstString(s : String) : { addr : Int, size : Int, rslot : String } {
		var cached = const_strings.get(s);

		if (cached == null) {
			var addr = bytecode.getPc();
			var size = bytecode.writeWideStringRaw(s);
			var rslot;

			if (size > 0xffff) {
				var raddr = bytecode.getPc();
				bytecode.writeInt31(size & 0xffff);
				bytecode.writeInt31(addr);
				rslot = 'StackSlot::InternalMakeString(MakeFlowPtr('+raddr+'),'+(size>>16)+',true)';
			}
			else {
				rslot = 'StackSlot::InternalMakeString(MakeFlowPtr('+addr+'),'+size+',false)';
			}

			const_strings.set(s, cached = { addr: addr, size: size, rslot: rslot });
		}

		return cached;
	}

	inline private function fn_method_name(n : String) : String {
		return 'fn_' + n;
	}
	inline private function closure_method_name(n : String, idx : Int) : String {
		return 'cl_' + idx + '_' + n;
	}

	private function enumerateToplevel() {
		// Index natives and globals
		for (g_name in p.declsOrder)
		{
			var code = p.topdecs.get(g_name);
			switch (code) {
			case Native(n_name, io, args, result, defbody, pos):
				// natives have mandatory external linkage
				var id = function_table.length;
				var info = new CppPlaceInfo(null,GlobalFunction(args.length,n_name),id,g_name);
				global_map.set(g_name, info);
				function_table.push({
					name: g_name, native_name: n_name, nargs: args.length,
					fn_name: if (defbody != null) fn_method_name(g_name) else null
				});
			case Lambda(args, type, body, _, pos):
				// will be added lazily
				var info = new CppPlaceInfo(null,GlobalFunction(args.length,null),-1,g_name);
				global_map.set(g_name, info);
			default:
				// assign id to global
				global_map.set(g_name, new CppPlaceInfo(null,GlobalVar,global_names.length,g_name));
				global_names.push(g_name);
			}
		}

		// Translate global functions
		var main_found = false;

		for (g_name in p.declsOrder)
		{
			var code = p.topdecs.get(g_name);

			switch (code) {
			case Native(n_name, io, args, result, defbody, pos):
				if (defbody != null)
					compileGlobalFn(g_name, defbody);
			case Lambda(arguments, type, body, _, pos):
				if (g_name == "main" || arguments.length != 0) main_found = true;
				compileGlobalFn(g_name, code);
			default:
				// nothing
			}
		}

		if (!main_found)
			throw "No main() function.";

		// Translate global var init
		var global_env : CppEnvironment = null;
		init_count = 0;

		for (g_name in global_names) {
			var expr = p.topdecs.get(g_name);
			var place = global_map.get(g_name);

			if (global_env == null || global_env.lines >= 1000) {
				endInitFunction(global_env);

				global_env = beginInitFunction();
			}

			global_env.vname = g_name+"$init";
			compileExpression(expr, global_env.cur_ctx, OutputVar(place), {temp:0});
		}

		endInitFunction(global_env);
	}

	private function beginInitFunction() : CppEnvironment {
		var global_env = new CppEnvironment(null, 'aux_init'+(init_count++), "$init");
		global_env.struct_list = struct_list;
		return global_env;
	}

	private function endInitFunction(global_env : CppEnvironment) {
		if (global_env == null) return;

		global_env.cur_ctx.wr('RETVOID;');
		global_env.cur_ctx.exit();
		emitLambdaCode(global_env, 'gen_init.cpp');
	}

	private var cur_global : String;
	private var next_closure_id : Int;

	private function compileGlobalFn(g_name : String, code : Flow) {
		cur_global = g_name;
		next_closure_id = 1;

		compileLambda(g_name, null, code, null);
	}

	private function compileLambda(
		name : String, idx : Null<Int>, code : Flow, upenv : CppEnvironment
	) : CppEnvironment {
		var args, type, body, pos;
		switch (code) {
		case Lambda(a, t, b, _, p):
			args = a; type = t; body = b; pos = p;
		default:
			throw "impossible";
		}
		var atypes = null;
		if (pos.type != null) {
			switch (pos.type) {
			case TFunction(at,r): atypes = at;
			default: throw "impossible";
			}
		}

		if (upenv != null)
			upenv.stashGlobalMeta();

		// Prepare environment
		var mname = if (idx == null) fn_method_name(name) else closure_method_name(name,idx);
		var vname = if (idx == null) name else name+'$'+idx;
		var env = new CppEnvironment(upenv, mname, vname);
		var ctx = env.cur_ctx;

		env.struct_list = struct_list;

		env.nargs = args.length;
		for (i in 0...args.length)
		{
			var place = new CppPlaceInfo(env, Argument, i, args[i]);
			if (atypes != null) {
				place.meta.context = 0;
				place.meta.dirty = true;
				place.meta.type = atypes[i];
			}
			env.locals.set(args[i], place);
		}

		// Process the body
		compileExpression(body, ctx, OutputReturn, {temp:0});
		ctx.exit();

		// Flush the code
		var t = pos.f;
		// Get rid of the absolute paths to our includes
		for (i in includes) {
			t = StringTools.replace(t, i + "/", "");
			t = StringTools.replace(t, i, "");
		}
		t = StringTools.replace(t, "/", "_");
		t = StringTools.replace(t, ".flow", "");
		t = StringTools.replace(t, ".", "_");
		emitLambdaCode(env, 'flow_'+t+'.cpp');

		if (upenv != null)
			upenv.restoreGlobalMeta();

		return env;
	}

	private function emitLambdaCode(env : CppEnvironment, file : String) {
		method_names.push(env.mname);

		var o = getOutputFile(file);

		if (env.closure_type != null) {
			var mask = '';
			for (at in env.closure_type.atypes)
				mask += CppPlaceInfo.structFieldCode(at)+';';

			var cs = closure_structs.get(mask);
			if (cs != null) {
				o.writeString('\ntypedef flowgen_native_program::FS_'+cs.structname+' FS_'+env.closure_type.structname+';\n');
				env.closure_type = cs;
			} else {
				closure_structs.set(mask, cs = env.closure_type);

				cs.id = structsOrder.length;
				var oinfo = {
					compare_idx: cs.id,
					name: cs.structname,
					args: cs.args
				};

				structsOrder.push(oinfo);
				generateStructDef(oinfo, cs);
			}
		}

		o.writeString('\nStackSlot flowgen_'+entry+'::'+env.mname+'(RUNNER_ARGS) {\n');

		if (env.nlocals > 0 || env.ntemps > 0) {
			o.writeString('    RUNNER_DefSlotArray(locals, '+env.nlocals+'+'+env.ntemps+');\n');
			if (env.ntemps > 0)
				o.writeString('    StackSlot *const temps = locals+'+env.nlocals+';\n');
		}

		for (id in env.idxvars.keys())
			o.writeString('    '+env.idxvars.get(id)+' '+id+';\n');

		if (env.tail_call)
			o.writeString('tail_call:\n');

		o.writeString(env.line_str.toString());

		o.writeString('}\n');
		/*o.close();
		file_table.remove(file);*/
	}

	static function getLambdaName(e : Flow) : String {
		switch(e) {
		case Lambda(args, type, body, uniqNo, pos):
			var t = "_" + pos.f + "_" + pos.s + "_" + uniqNo;
			t = StringTools.replace(t, "/", "_");
			t = StringTools.replace(t, ".", "_");
			return t;
		default:
			Assert.fail("getLambdaName");
			return "";
		}
	}

	private function resolveLocalName(env : CppEnvironment, name : String)
	{
		var binding = env.locals.get(name);
		if (binding != null)
			return binding;

		if (env.parent != null) {
			var free = resolveLocalName(env.parent, name);

			if (free != null)
				return env.mkupvalue(name, free);
		}

		return null;
	}

	private function resolveName(ctx : CppContext, name : String)
	{
		var local = resolveLocalName(ctx.env, name);
		if (local != null)
			return local;

		var global = global_map.get(name);
		if (global != null)
			return global;

		throw "Unknown variable: "+name;
	}

	private function reifyStub(ref : CppPlaceInfo, code : Flow) {
		switch (ref.place) {
			case GlobalFunction(nargs, native):
				ref.slot = function_table.length;
				function_table.push({
					name: ref.name, native_name: null,
					nargs: nargs, fn_name: fn_method_name(ref.name)
				});
			case Struct(info):
				throw 'Cannot use struct here: '+Prettyprint.print(code);
			default:
				throw 'Cannot reify stub: '+Prettyprint.print(code);
		}
	}

	private static var COMMA = ',';
	private static var LPAREN = '(';
	private static var RPAREN = ')';
	private static var SPC_EQ_SPC = ' = ';
	private static var STACKSLOT_MAKE = 'StackSlot::Make';
	private static var STACKSLOT_SET = 'StackSlot::Set';
	private static var STACKSLOT_INTERNAL_MAKE = 'StackSlot::InternalMake';
	private static var STACKSLOT_INTERNAL_SET = 'StackSlot::InternalSet';
	private static var CALL_WITH_RETSLOT = 'CALL_WITH_RETSLOT(';

	private function assignExpr(plv : String, expr : String, ?call : Bool = false) : String
	{
		var sb = new StringBuf();
		if (StringTools.startsWith(expr, STACKSLOT_MAKE)) {
			var i = expr.indexOf(LPAREN,15);
			sb.add(STACKSLOT_SET); sb.add(expr.substr(15,i-15));
			sb.add(LPAREN); sb.add(plv);
			if (expr.charAt(i+1) != ')')
				sb.add(COMMA);
			sb.add(expr.substr(i+1));
		} else if (StringTools.startsWith(expr, STACKSLOT_INTERNAL_MAKE)) {
			var i = expr.indexOf(LPAREN,23);
			sb.add(STACKSLOT_INTERNAL_SET); sb.add(expr.substr(23,i-23));
			sb.add(LPAREN); sb.add(plv);
			if (expr.charAt(i+1) != ')')
				sb.add(COMMA);
			sb.add(expr.substr(i+1));
		} else if (call) {
			sb.add(CALL_WITH_RETSLOT); sb.add(plv); sb.add(COMMA); sb.add(expr); sb.add(RPAREN);
		} else {
			sb.add(plv); sb.add(SPC_EQ_SPC); sb.add(expr);
		}
		return sb.toString();
	}

	private static var RETURN = 'return ';

	private function emitValue(ctx : CppContext, out : CppOutputLocation, expr : String, tag : Null<CppTagType>, ?io : Bool = false, ?check : Bool = false, ?gc : Bool = false) : CppPlaceInfo
	{
		var rv = null;

		switch (out) {
		case OutputNone:
			if (!io)
				return null;
		case OutputReturn:
			ctx.wrsemi2(RETURN,expr);
			return null;
		case OutputVar(place):
			rv = place;
			expr = assignExpr(place.getLValue(), expr, io||check||gc);
			if (tag != null)
				ctx.localMeta(place).tag = tag;
		case OutputExpr(cb):
			expr = cb(ctx, expr);
		case OutputScalar(name,tag2):
			if (tag != tag2) {
				ctx.env.registerIdxVar('unbox_tmp','StackSlot');
				ctx.wrcheckopt(assignExpr('unbox_tmp',expr,io||check||gc), check, gc);
				ctx.wr('CHECK_TAG('+CppPlaceInfo.tagToString(tag2)+
					   ',unbox_tmp,"'+ctx.env.vname+'");');
				expr = 'unbox_tmp';
				check = gc = false;
			}
			var sb = new StringBuf();
			sb.add(name); sb.add(SPC_EQ_SPC); sb.add(expr);
			sb.add(switch (tag2) {
			case TBool: '.GetBool()';
			case TInt: '.GetInt()';
			case TDouble: '.GetDouble()';
			default: throw 'impossible';
			});
			expr = sb.toString();
		}

		ctx.wrcheckopt(expr, check, gc);

		return rv;
	}

	private function copyValue(ctx : CppContext, out : CppOutputLocation, inv: CppPlaceInfo) : CppPlaceInfo
	{
		switch (out) {
		case OutputNone:
		case OutputReturn:
			ctx.wrsemi2(RETURN, inv.getRValue(ctx));
		case OutputVar(place):
			if (!place.isSame(inv)) {
				ctx.wrsemi(assignExpr(place.getLValue(), inv.getRValue(ctx)));
				if (inv.meta.dirty || place.meta.dirty) {
					var tm = ctx.localMeta(place);
					CppPlaceInfo.clearMeta(tm);
					tm.tag = inv.meta.tag;
					tm.struct_size = inv.meta.struct_size;
					tm.struct_id = inv.meta.struct_id;
				}
			}
			return place;
		case OutputExpr(cb):
			ctx.wrsemi(cb(ctx, inv.getRValue(ctx)));
		case OutputScalar(name,tag2):
			verifyTag(inv, tag2, ctx);
			var expr = inv.getRawField(ctx, tag2);
			if (expr == null) {
				expr = inv.getRValue(ctx) + switch (tag2) {
				case TBool: '.GetBool()';
				case TInt: '.GetInt()';
				case TDouble: '.GetDouble()';
				default: throw 'impossible';
				}
			}
			ctx.wrsemi3(name,SPC_EQ_SPC,expr);
		}

		return null;
	}

	private function getValueRef(code : Flow, ctx : CppContext, ?lvalue : Bool = false) : CppPlaceInfo {
		switch (code) {
		case VarRef(n, pos): {
			var ref = resolveName(ctx, n);
			if (lvalue && !ref.isLValue())
				return null;
			if (ref.isStub())
				reifyStub(ref, code);
			return ref;
		} 
		default:
			return null;
		}
	}

	private function verifyTag(ref : CppPlaceInfo, tag : CppTagType, ctx : CppContext) : Bool {
		var tstr = CppPlaceInfo.tagToString(tag);

		if (ref.meta.tag == tag)
			return true;
		else if (ref.meta.tag != null)
			throw "Cannot verify tag "+tstr+" - already "+CppPlaceInfo.tagToString(ref.meta.tag);

		var rv = ref.getRValue(ctx);
		var sb = ctx.wrbegin();
		sb.add('CHECK_TAG(');
		sb.add(tstr);
		sb.add(COMMA);
		sb.add(rv);
		sb.add(',"');
		sb.add(ctx.env.vname);
		sb.add('");\n');

		var lm = ctx.localMeta(ref);
		lm.tag = tag;
		return false;
	}

	private function verifyStruct(ref : CppPlaceInfo, size : Int, ctx : CppContext) {
		if (ref.meta.tag == TStruct &&
			ref.meta.struct_size != null &&
			ref.meta.struct_size >= size)
			return true;
		if (ref.meta.tag != null && ref.meta.tag != TStruct)
			throw "Cannot verify struct - already "+CppPlaceInfo.tagToString(ref.meta.tag);

		ctx.wr('CHECK_STRUCT('+ref.getRValue(ctx)+','+size+',"'+ctx.env.vname+'");');

		var lm = ctx.localMeta(ref);
		lm.tag = TStruct;
		lm.struct_size = size;
		return false;
	}

	private function verifyStructId(ref : CppPlaceInfo, id : Int, ctx : CppContext) {
		if (ref.meta.tag == TStruct &&
			ref.meta.struct_id == id)
			return true;
		if (ref.meta.tag != null && ref.meta.tag != TStruct)
			throw "Cannot verify struct - already "+CppPlaceInfo.tagToString(ref.meta.tag);

		ctx.wr('CHECK_STRUCT_TYPE('+ref.getRValue(ctx)+','+id+',"'+ctx.env.vname+'");');

		var lm = ctx.localMeta(ref);
		lm.tag = TStruct;
		lm.struct_size = struct_list[id].args.length;
		lm.struct_id = id;
		return false;
	}

	private function findFieldIndex(ref : CppPlaceInfo, name : String, ctx : CppContext) {
		verifyStruct(ref, 1, ctx);

		var ivar = 'fidx_'+ref.uid+'_'+name;

		if (ref.meta.known_fields == null || !ref.meta.known_fields.has(name))
		{
			ctx.env.registerIdxVar(ivar, 'int');

			var fidx = getFieldLookupId(name);
			ctx.wr('FIND_STRUCT_FIELD('+ivar+','+ref.getRValue(ctx)+','+fidx+
				   ',"'+name+'","'+ctx.env.vname+'");');

			var lm = ctx.localMeta(ref);
			if (lm.known_fields == null)
				lm.known_fields = new List();
			lm.known_fields.push(name);
		}

		return ivar;
	}

	private function getAddrPair(ref : CppPlaceInfo, tag : CppTagType, ctx : CppContext) {
		verifyTag(ref, tag, ctx);

		var lv = ref.getRawField(ctx, tag);
		if (lv != null)
			return lv+'.addr,'+lv+'.size';
		else {
			var lrv = ref.getRValue(ctx);
			return lrv+'.PtrValue,'+lrv+'.IntValue2';
		}
	}

	private function emitComparisonExpr(
		op : String, expr1 : Flow, expr2 : Flow, epos : Position,
		ctx : CppContext, top : StackTop
	) : String {
		// Check for number comparisons
		var type = getPrimitiveTag(epos, true);

		var top2 = mktop(top);

		if (type == TInt || type == TDouble) {
			var val1 = emitNumericExpr(expr1, ctx, top2, type);
			var val2 = emitNumericExpr(expr2, ctx, top2, type);
			return ctx.tempvar('btmp', TBool, val1+op+val2);
		} else if (type == TBool && (op == '==' || op == '!=')) {
			var val1 = emitConditionExpr(expr1, ctx, top2);
			var val2 = emitConditionExpr(expr2, ctx, top2);
			return ctx.tempvar('btmp', TBool, val1+op+val2);
		}

		var ref1 = fetchToRef(expr1, ctx, top2, false);
		var ref2 = fetchToRef(expr2, ctx, top2, false);

		// Check if already compared in reverse order
		var swap = false;

		if (ref2.meta.known_compares != null && ref2.meta.known_compares.has(ref1))
		{
			swap = true;
			var c = ref1; ref1 = ref2; ref2 = c;
		}

		// Call compare if needed
		var cvar = 'cmp_'+ref1.uid+'_'+ref2.uid;

		if (ref1.meta.known_compares == null || !ref1.meta.known_compares.has(ref2))
		{
			ctx.env.registerIdxVar(cvar, 'int');

			/*if (type == TString) {
				ctx.wr(cvar+' = RUNNER->CompareString('+getAddrPair(ref1,TString,ctx)+
					   ','+getAddrPair(ref2,TString,ctx)+');');
			} else {*/
				ctx.wr(cvar+' = RUNNER->Compare('+ref1.getRValue(ctx)+','+ref2.getRValue(ctx)+');');
			//}

			var lm = ctx.localMeta(ref1);
			if (lm.known_compares == null)
				lm.known_compares = new List();
			lm.known_compares.push(ref2);
		}

		var cexpr = (swap ? '(0'+op+cvar+')' : '('+cvar+op+'0)');
		return ctx.tempvar('btmp', TBool, cexpr);
	}

	private function emitConditionExpr(code : Flow, ctx : CppContext, top : StackTop) : String {
		switch (code) {
			case ConstantBool(value, pos):
				return ''+value;

			case Equal(e1, e2, pos):
				return emitComparisonExpr('==', e1, e2, pos, ctx, top);
			case NotEqual(e1, e2, pos):
				return emitComparisonExpr('!=', e1, e2, pos, ctx, top);
			case LessThan(e1, e2, pos):
				return emitComparisonExpr('<', e1, e2, pos, ctx, top);
			case LessEqual(e1, e2, pos):
				return emitComparisonExpr('<=', e1, e2, pos, ctx, top);
			case GreaterThan(e1, e2, pos):
				return emitComparisonExpr('>', e1, e2, pos, ctx, top);
			case GreaterEqual(e1, e2, pos):
				return emitComparisonExpr('>=', e1, e2, pos, ctx, top);
			case Not(e1, pos):
				return '!'+emitConditionExpr(e1, ctx, top);

			case And(e1, e2, pos):
				var a1expr = emitConditionExpr(e1, ctx, mktop(top));
				var tmp = ctx.tempvar('btmp', TBool, a1expr);
				ctx.wr('if ('+tmp+') {');
				var subctx = ctx.enter('    ');
				var a2expr = emitConditionExpr(e2, subctx, mktop(top));
				subctx.wrsemi3(tmp,SPC_EQ_SPC,a2expr);
				subctx.exit();
				ctx.wr('}');
				ctx.join_one(subctx);
				return tmp;

			case Or(e1, e2, pos):
				var a1expr = emitConditionExpr(e1, ctx, mktop(top));
				var tmp = ctx.tempvar('btmp', TBool, a1expr);
				ctx.wr('if (!'+tmp+') {');
				var subctx = ctx.enter('    ');
				var a2expr = emitConditionExpr(e2, subctx, mktop(top));
				subctx.wrsemi3(tmp,SPC_EQ_SPC,a2expr);
				subctx.exit();
				ctx.wr('}');
				ctx.join_one(subctx);
				return tmp;

			default:
				return fetchToScalar(code, ctx, top, TBool);
		}
	}

	// A hack: copy a rvalue place into a temporary, and then change the
	// fields of the original place to point to the new location.
	private function makeLValueCopy(ctx : CppContext, place : CppPlaceInfo, top : StackTop) : Void->Void {
		var tref = ctx.env.mktemp(top.temp++);

		ctx.wrsemi3(tref.getLValue(), SPC_EQ_SPC, place.getRValue(ctx));

		return place.substituteLocation(tref);
	}

	private function compileCondition(code : Flow, ctx : CppContext, out : CppOutputLocation, top : StackTop) {
		var cexpr = emitConditionExpr(code, ctx, top);

		switch (out) {
		case OutputScalar(name,tag):
			if (tag == TBool) {
				ctx.wrsemi3(name, SPC_EQ_SPC, cexpr);
				return;
			}
		default:
		}

		emitValue(ctx, out, 'StackSlot::MakeBool('+cexpr+')', TBool);
	}

	private static var int_80000000 = (1 << 31);

	private function compileExpression(code : Flow, ctx : CppContext, out : CppOutputLocation, top : StackTop) {
		var output = function(expr, tag) {
			return emitValue(ctx, out, expr, tag);
		}
		var eval_tmp = function(arg) {
			return evalToTmp(arg, ctx, top);
		}
		var fetch_ref = function(arg, lvalue) {
			return fetchToRef(arg, ctx, top, lvalue);
		}

		switch (code) {
		// case SyntaxError(s, pos) :
		case ConstantVoid(pos):
			output('FLOWVOID', TVoid);
		case ConstantBool(value, pos):
			output('StackSlot::MakeBool('+value+')', TBool);
		case ConstantI32(value, pos):
			var str = emitNumericExpr(code, ctx, top, TInt);
			output('StackSlot::MakeInt('+str+')', TInt);
		case ConstantDouble(value, pos):
			var expr = emitNumericExpr(code, ctx, top, TDouble);
			output('StackSlot::MakeDouble('+expr+')', TDouble);
		case ConstantString(value, pos):
			try {
				var ref = registerConstString(value);
				output(ref.rslot, TString);
			} catch (e : Dynamic) {
				Errors.report(Prettyprint.position(pos) + ': Error generating C++ code for string constant.');
				throw e;
			}

		case ConstantArray(values, pos):
			compileConstructor(values, ctx, out, top, TArray, function(cnt,ptr) {
				return if (cnt == 0)
					'StackSlot::MakeEmptyArray()';
				else
					'RUNNER->AllocateArray('+cnt+','+ptr+')';
			});
		case ConstantStruct(name, values, pos):
			var structDef = structs.get(name);
			if (structDef.args.length != values.length)
				throw "Wrong arg count for constant struct "+name;
			compileNewStruct(structDef, values, ctx, out, top);
			return;
		case RefTo(value, pos):
			var ref = fetch_ref(value, true);
			emitValue(ctx, out, 'RUNNER->AllocateRef('+ref.getLValue()+')', TRefTo, false, true, true);

		case VarRef(n, pos):
			copyValue(ctx, out, getValueRef(code, ctx));
		case ArrayGet(array, index, pos):
			var arr = fetch_ref(array, false);
			var idx = emitNumericExpr(index, ctx, top, TInt);
			verifyTag(arr, TArray, ctx);
			var expr = 'DerefArray(RUNNER,'+arr.getRValue(ctx)+','+idx+')';
			emitValue(ctx, out, expr, null, false, true, false);
		case Pointer(pointer, pos):
			throw "Not supposed to happen";
		case Deref(pointer, pos):
			var ref = fetch_ref(pointer, false);
			verifyTag(ref, TRefTo, ctx);
			output('RUNNER->GetRefTarget('+ref.getRValue(ctx)+')', null);
		case SetRef(pointer, value, pos):
			var ref = fetch_ref(pointer, false);
			var value = fetch_ref(value, false);
			verifyTag(ref, TRefTo, ctx);
			ctx.wr('RUNNER->SetRefTarget('+ref.getRValue(ctx)+','+value.getRValue(ctx)+');');
			copyValue(ctx, out, value);

		case Call(fn, args, pos):
			compileCall(code, fn, args, ctx, out, top);
		case Lambda(args, type, body, _, pos):
			compileClosure(code, ctx, out, top);

		case Field(call, name, pos):
			var ref = fetch_ref(call, false);
			var sref = ref.getRValue(ctx);
			if (name == "structname") {
				verifyStruct(ref, 0, ctx);
				var specs = 'struct_specs['+sref+'.GetStructId()]';
				output('StackSlot::InternalMakeString(MakeFlowPtr('+
					   specs+'.name_addr),'+specs+'.name_size,false)', TString);
			} else {
				var v = fieldSetInfo(call, ref, name);
				if (v.stype != null) {
					var info = struct_list[v.stype];
					verifyStructId(ref, v.stype, ctx);
					var at = info.atypes[v.index];

					switch (out) {
					case OutputScalar(sname,tag):
						if (tag == at)
						{
							var rf = ctx.getStructField(ref,structsOrder[v.stype].name,name,null);
							ctx.wrsemi3(sname,SPC_EQ_SPC,rf);
							return;
						}
					default:
					}

					output(ctx.getStructField(ref,structsOrder[v.stype].name,name,at), at);
				} else if (v.index != null && v.index >= 0) {
					verifyStruct(ref, v.minsize, ctx);
					output('RUNNER->GetStructSlot('+sref+','+v.index+'/*'+name+'*/)', null);
				} else {
					// Dynamic lookup
					var ivar = findFieldIndex(ref, name, ctx);
					output('RUNNER->GetStructSlot('+sref+','+ivar+')', null);
				}
			}

		case SetMutable(call, name, value, pos):
			var ref = fetch_ref(call, false);
			var val = fetch_ref(value, false);
			var sref = ref.getRValue(ctx);
			if (name != "structname") {
				var v = fieldSetInfo(call, ref, name);
				if (v.stype != null) {
					var info = struct_list[v.stype];
					verifyStructId(ref, v.stype, ctx);
					var at = info.atypes[v.index];
					if (at != null)
						verifyTag(val, at, ctx);
					var ptr = ctx.getStructPtr(ref,structsOrder[v.stype].name);
					if (!CppPlaceInfo.isNonGCFieldType(at))
						ctx.wrsemi3('RUNNER->RegisterWrite(&',ptr,'->hdr)');
					if (at == TStruct)
						ctx.wrsemi4(ptr,'->fl_'+name,SPC_EQ_SPC,val.getStructAddr(ctx));
					else
						ctx.wr('flow_struct::set_'+CppPlaceInfo.structFieldCode(at)+
							   '('+ptr+'->fl_'+name+','+val.getRValue(ctx)+');');
				} else if (v.index != null && v.index >= 0) {
					verifyStruct(ref, v.minsize, ctx);
					ctx.wrcheck('RUNNER->SetStructSlot('+sref+','+
								v.index+'/*'+name+'*/,'+val.getRValue(ctx)+')', null);
				} else {
					// Dynamic lookup
					var ivar = findFieldIndex(ref, name, ctx);
					ctx.wrcheck('RUNNER->SetStructSlot('+sref+','+
								ivar+','+val.getRValue(ctx)+')', null);
				}
			}
			output('FLOWVOID', null);

		case Sequence(statements, pos):
			var last = statements.length-1;
			for (i in 0...last)
				compileExpression(statements[i], ctx, OutputNone, mktop(top));
			compileExpression(statements[last], ctx, out, top);
		case Let(name, sigma, value, scope, pos):
			if (scope != null) {
				var cpos = ctx.defpos();
				var def = ctx.env.mklocal(name);
				compileExpression(value, ctx, OutputVar(def), mktop(top));
				ctx.localMeta(def).type = pos.type2;
				ctx.pushdef(def);
				compileExpression(scope, ctx, out, top);
				ctx.popdefs(cpos);
			} else {
				compileExpression(value, ctx, OutputNone, mktop(top));
				output('FLOWVOID', TVoid);
			}
		case If(condition, then, elseExp, pos):
			var cexpr = emitConditionExpr(condition, ctx, mktop(top));
			ctx.wr('if ('+cexpr+') {');
			var cif = ctx.enter('    ');
			compileExpression(then, cif, out, mktop(top));
			cif.exit();
			ctx.wr('} else {');
			var celse = ctx.enter('    ');
			compileExpression(elseExp, celse, out, mktop(top));
			celse.exit();
			ctx.wr('}');
			ctx.join([cif, celse]);
		case Switch(e0, type, cases, p):
			var vexpr = getValueRef(e0, ctx, false);
			var restore_cb = null;
			if (vexpr == null) {
				// avoid using the same temporary for out and copy
				getOutputPlace(out, top);
				vexpr = evalToTmp(e0, ctx, top);
			} else if (!vexpr.isLValue()) {
				// Copy the struct into a temporary if not lvalue, to make FieldAlias efficient.
				getOutputPlace(out, top);
				restore_cb = makeLValueCopy(ctx, vexpr, top);
			}
			verifyTag(vexpr, TStruct, ctx);
			ctx.wr('switch ('+vexpr.getLValue()+'.GetStructId()) {');
			var branches = [];
			var foundDefault = false;
			for (c in cases) {
				var subctx = ctx.enter('    ');
				if (c.structname == "default") {
					foundDefault = true;
					ctx.wr('default: {');
				} else {
					var structDef = structs.get(c.structname);
					ctx.wr('case ' + structDef.id + '/*'+c.structname+'*/: {');
					var loc = subctx.localMeta(vexpr);
					loc.tag = TStruct;
					loc.struct_size = structDef.args.length;
					loc.struct_id = structDef.id;
					for (i in 0...c.args.length) {
						var def = new CppPlaceInfo(
							ctx.env, FieldAlias(vexpr,structDef), i, c.args[i]
						);
						if (structDef.args[i].is_mutable)
						{
							if (c.used_args != null && c.used_args[i]) {
								var def2 = subctx.env.mklocal(c.args[i]);
								subctx.wrsemi3(def2.getLValue(), SPC_EQ_SPC, def.getRValue(subctx));
								def = def2;
							} else {
								def.place = NoPlace(code, "Switch var "+def.name+" not marked as used.");
							}
						}
						def.meta.dirty = true;
						def.meta.type = structDef.args[i].type;
						if (structDef.atypes[i] != null) {
							def.meta.tag = structDef.atypes[i];
						}
						subctx.pushdef(def);
					}
				}
				branches.push(subctx);
				compileExpression(c.body, subctx, out, mktop(top));
				if (out != OutputReturn)
					subctx.wr('break;');
				subctx.exit();
				ctx.wr('}');
			}
			if (!foundDefault) {
				ctx.wr('default:');
				ctx.wr('    RUNNER->ReportError(UncaughtSwitch, "Unexpected case in switch in '+
					   ctx.env.vname+'");');
				ctx.wr('    RETVOID;');
			}
			ctx.wr('}');
			ctx.join(branches);
			if (restore_cb != null) restore_cb();
		case SimpleSwitch(e0, cases, p):
			var vexpr = fetch_ref(e0, false);
			verifyTag(vexpr, TStruct, ctx);
			ctx.wr('switch ('+vexpr.getLValue()+'.GetStructId()) {');
			var branches = [];
			var foundDefault = false;
			for (c in cases) {
				var subctx = ctx.enter('    ');
				if (c.structname == "default") {
					foundDefault = true;
					ctx.wr('default: {');
				} else {
					var structDef = structs.get(c.structname);
					var loc = subctx.localMeta(vexpr);
					loc.tag = TStruct;
					loc.struct_size = structDef.args.length;
					loc.struct_id = structDef.id;
					ctx.wr('case ' + structDef.id + '/*'+c.structname+'*/: {');
					// TODO: assign known struct type in context
				}
				branches.push(subctx);
				compileExpression(c.body, subctx, out, mktop(top));
				if (out != OutputReturn)
					subctx.wr('break;');
				subctx.exit();
				ctx.wr('}');
			}
			if (!foundDefault) {
				ctx.wr('default:');
				ctx.wr('    RUNNER->ReportError(UncaughtSwitch, "Unexpected case in switch in '+
					   ctx.env.vname+'");');
				ctx.wr('    RETVOID;');
			}
			ctx.wr('}');
			ctx.join(branches);

		case Plus(e1, e2, pos): compileMath(code, pos, ctx, out, top);
		case Minus(e1, e2, pos): compileMath(code, pos, ctx, out, top);
		case Multiply(e1, e2, pos): compileMath(code, pos, ctx, out, top);
		case Divide(e1, e2, pos): compileMath(code, pos, ctx, out, top);
		case Modulo(e1, e2, pos): compileMath(code, pos, ctx, out, top);
		case Negate(e1, pos): compileMath(code, pos, ctx, out, top);

		case And(e1, e2, pos): compileCondition(code, ctx, out, top);
		case Or(e1, e2, pos): compileCondition(code, ctx, out, top);
		case Not(e1, pos): compileCondition(code, ctx, out, top);

		case Equal(e1, e2, pos): compileCondition(code, ctx, out, top);
		case NotEqual(e1, e2, pos): compileCondition(code, ctx, out, top);
		case GreaterThan(e1, e2, pos): compileCondition(code, ctx, out, top);
		case GreaterEqual(e1, e2, pos): compileCondition(code, ctx, out, top);
		case LessThan(e1, e2, pos): compileCondition(code, ctx, out, top);
		case LessEqual(e1, e2, pos): compileCondition(code, ctx, out, top);

		case Cast(value, fromtype, totype, pos):
			var ref = fetch_ref(value, false);
			var rexpr = ref.getRValue(ctx);
			switch (fromtype) {
			case FlowType.TInt:
				verifyTag(ref, TInt, ctx);
				switch (totype) {
				case FlowType.TInt:
					copyValue(ctx, out, ref);
				case TDouble:
					output("StackSlot::MakeDouble("+rexpr+".GetInt())",TDouble);
				case TString:
					emitValue(ctx,out,'ByteCodeRunner::DoInt2String(RUNNER,'+rexpr+')',TString,false,true,true);
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TDouble:
				switch (totype) {
				case TInt:
					verifyTag(ref, TDouble, ctx);
					output("StackSlot::MakeInt("+rexpr+".GetDouble())",TInt);
				case TDouble:
					verifyTag(ref, TDouble, ctx);
					copyValue(ctx, out, ref);
				case TString:
					emitValue(ctx,out,'ByteCodeRunner::DoDouble2String(RUNNER,'+rexpr+')',TString,false,true,true);
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TName(n1, args1):
				switch (totype) {
				case TName(n2, args2):
					copyValue(ctx, out, ref);
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TBoundTyvar(__): {
				copyValue(ctx, out, ref);
			}
			case TFlow: {
				copyValue(ctx, out, ref);
			}
			default: throw "Not implemented: " + Prettyprint.print(value);
			}

		default:
			trace("Not implemented: " + Prettyprint.print(code));
			output('FLOWVOID', null);
		}
	}

	private function fieldSetInfo(call : Flow, ref : CppPlaceInfo, name : String)
		: { index : Null<Int>, minsize : Null<Int>, stype : Null<Int> }
	{
		var fields = FlowUtil.untyvar(FlowUtil.getPosition(call).type);
		var index : Null<Int> = null;
		var minsize : Null<Int> = null;
		var stype : Null<Int> = null;
		if (ref != null && ref.meta.struct_id != null) {
			var info = structsOrder[ref.meta.struct_id];
			var args = info.args;
			minsize = args.length;
			for (i in 0...args.length) {
				if (args[i].name == name) {
					index = i;
					break;
				}
			}
			if (index == null)
				throw 'No field '+name+' in struct '+info.name;
			stype = ref.meta.struct_id;
		} else if (fields != null) {
			switch (fields) {
			case TStruct(structname, cargs, max):
				minsize = cargs.length;
				index = fieldIndex(fields, name);
				stype = structs.get(structname).id;
			case TUnion(min, max):
				if (max != null) {
					// If all in the union have the same int index, we are fine
					// even if it is polymorphic
					var first = true;
					for (m in max) {
						stype = first ? structTypeId(m) : null;
						var sz = structTypeSize(m);
						if (minsize == null || minsize > sz)
							minsize = sz;
						var i2 = fieldIndex(m, name);
						if (index == null || i2 == index) {
							index = i2;
						} else {
							index = minsize = stype = null;
							break;
						}
						first = false;
					}
				}
			default:
			}
		}
		return { index : index, minsize : minsize, stype : stype }
	}

	private function compileClosure(code : Flow, ctx : CppContext, out : CppOutputLocation, top : StackTop)
	{
		var me = this;
		var id = next_closure_id++;
		var cenv = compileLambda(cur_global, id, code, ctx.env);
		var fidx = function_table.length;

		function_table.push({
			name: cenv.vname, native_name: null, nargs: cenv.nargs, fn_name: cenv.mname
		});

		var fslot = 'getSelf(RUNNER)->functions['+fidx+'/*'+cenv.vname+'*/]';
		var csize = cenv.upvalues.length;

		if (csize == 0) {
			emitValue(ctx, out, fslot, TNativeFn, false, false);
		} else {
			var args = [];
			for (n in cenv.upvalues)
				args.push(VarRef(n, null));

			compileNewStruct(cenv.closure_type, args, ctx, out, top, fslot);
		}
	}

	private function compileConstructor(args : FlowArray<Flow>, ctx : CppContext, out : CppOutputLocation, top : StackTop, tag : CppTagType, expr_cb : Int->String->String, ?zero_allocs : Bool = false) : CppPlaceInfo
	{
		var csize = args.length;
		if (csize == 0)
			return emitValue(ctx, out, expr_cb(0, 'NULL'), tag, false, zero_allocs, zero_allocs);

		var refs = [];
		var fast = true;
		for (i in 0...csize) {
			var ref = getValueRef(args[i], ctx, false);
			refs.push(ref);

			if (ref != null && ref.isLValue() &&
				(i == 0 || (ref.place == refs[i-1].place && ref.slot == refs[i-1].slot+1)))
				continue;

			fast = false;
			break;
		}

		var place;
		if (fast) {
			place = refs[0].getLValue();
		} else if (csize <= 20) {
			var start = top.temp;

			for (i in 0...csize) {
				var atop = mktop(top);
				var tmp = ctx.env.mktemp(top.temp++);
				compileExpression(args[i], ctx, OutputVar(tmp), atop);
			}

			place = 'temps['+start+']';
		} else {
			// If a constructor is too long, instead of declaring lots of
			// temporaries, allocate an empty array and fill it destructively.
			var tmp = ctx.env.mktemp(top.temp++);
			var tstr = tmp.getLValue();

			ctx.wrcheck(tstr + ' = ' + expr_cb(csize, 'NULL'), true);

			tmp.meta.tag = tag;

			for (i in 0...csize) {
				compileExpression(args[i], ctx, OutputExpr(function(ictx,aexpr) {
					return 'RUNNER->SetArraySlot('+tstr+','+i+','+aexpr+')';
				}), mktop(top));
			}

			return copyValue(ctx, out, tmp);
		};

		return emitValue(ctx, out, expr_cb(csize, '&'+place), tag, false, true, true);
	}

	private function compileNewStruct(info : StructInfo, args : FlowArray<Flow>, ctx : CppContext, out : CppOutputLocation, top : StackTop, closure : String = null)
	{
		if (info.args.length != args.length)
			throw "Invalid struct field count";

		if (args.length == 0)
			return copyValue(ctx, out, global_map.get(info.structname));

		var otmp = getOutputOrTemp(ctx, out, top);
		var sout = otmp.getLValue();

		var refs = [];
		var vals = [];
		for (i in 0...args.length) {
			var tt = info.atypes[i];

			if (tt == TDouble || tt == TInt) {
				refs.push(null);
				vals.push(emitNumericExpr(args[i], ctx, top, tt));
			} else if (tt == TBool) {
				refs.push(null);
				vals.push(emitConditionExpr(args[i], ctx, top));
			} else {
				var ref = fetchToRef(args[i], ctx, top, false);
				refs.push(ref);
				vals.push(null);

				if (info.atypes[i] != null)
					verifyTag(ref, info.atypes[i], ctx);
			}
		}

		var ptr = ctx.getStructPtr(otmp, info.structname, false);

		if (closure != null) {
			ctx.wrcheck(ptr+' = RUNNER->AllocateRawClosure<FS_'+info.structname+
						'>(&'+sout+','+info.id+','+closure+'.slot_private.IntValue)', true);

			var lm = ctx.localMeta(otmp);
			lm.tag = TNativeFn;
		} else {
			ctx.wrcheck(ptr+' = RUNNER->AllocateRawStruct<FS_'+info.structname+
						'>(&'+sout+','+info.id+')', true);

			var lm = ctx.localMeta(otmp);
			lm.tag = TStruct;
			lm.struct_id = info.id;
			lm.struct_size = args.length;
		}

		for (i in 0...args.length)
		{
			var fname = ptr+'->fl_'+info.args[i].name;
			if (vals[i] != null)
				ctx.wrsemi3(fname, SPC_EQ_SPC, vals[i]);
			else if (info.atypes[i] == TStruct)
				ctx.wrsemi3(fname, SPC_EQ_SPC, refs[i].getStructAddr(ctx));
			else
			{
				switch (refs[i].place) {
				case FieldAlias(where,sinfo):
					if (sinfo.atypes[refs[i].slot] == info.atypes[i])
					{
						ctx.wrsemi4(fname, SPC_EQ_SPC,
									ctx.getStructPtr(where,sinfo.structname),
									'->fl_'+sinfo.args[refs[i].slot].name);
						continue;
					}
				default:
				}

				ctx.wr('flow_struct::set_'+CppPlaceInfo.structFieldCode(info.atypes[i])+
					   '('+fname+','+refs[i].getRValue(ctx)+');');
			}
		}

		return copyValue(ctx, out, otmp);
	}

	private function callNativeName(fn : Flow, ctx : CppContext) : String {
		switch (fn) {
		case VarRef(n, pos):
			var ref = resolveName(ctx, n);
			switch (ref.place) {
				case GlobalFunction(nargs, native):
					return native;
				default:
					return null;
			}

		default:
			return null;
		}
	}

	private function compileCall(code : Flow, fn : Flow, args : FlowArray<Flow>, ctx : CppContext, out : CppOutputLocation, top : StackTop)
	{
		var direct_call = null;
		var allocs = true;

		switch (fn) {
		case VarRef(n, pos):
			var ref = resolveName(ctx, n);
			switch (ref.place) {
				case GlobalFunction(nargs, native):
					if (args.length != nargs)
						throw "Argument count mismatch in call to "+n;
					if (n == cur_global) {
						if (ctx.env.parent == null && out == OutputReturn)
						{
							ctx.env.tail_call = true;

							// first compute new arguments
							var arefs = [];
							var avals = [];
							for (i in 0...args.length)
							{
								var ref = getValueRef(args[i], ctx, false);
								var sval = null;

								if (ref == null || (ref.place == Argument && ref.slot < i))
								{
									sval = emitPrimitiveWrap(args[i], ctx, top);

									if (sval == null)
										ref = evalToTmp(args[i], ctx, top, out);
									else
										ref = null;
								}

								arefs.push(ref);
								avals.push(sval);
							}

							// now compute strings, so that struct pointers get computed
							var astrings = [];
							for (i in 0...args.length)
								astrings.push(avals[i]!=null ? avals[i] : arefs[i].getRValue(ctx));

							// finally assign
							for (i in 0...args.length) {
								if (arefs[i] != null &&
									arefs[i].place == Argument && arefs[i].slot == i)
									continue;
								ctx.wrsemi(assignExpr('RUNNER_ARG('+i+')',astrings[i]));
							}

							// and jump
							ctx.wr('goto tail_call;');
							return;
						}
						else {
							// allow even if optional native
							direct_call = fn_method_name(n);
						}
					} else if (native == null) {
						direct_call = fn_method_name(n);
					} else {
						var rnative = known_natives.get(native);
						if (rnative != null && rnative.nargs == nargs) {
							if (inlineNative(code, native, args, ctx, out, top))
								return;
							direct_call = 'ByteCodeRunner::'+rnative.cname;
							if (rnative.noalloc)
								allocs = false;
						}
					}

				case Struct(info):
					if (info.args.length != args.length)
						throw "Wrong argument count for struct "+info.structname;

					compileNewStruct(info, args, ctx, out, top);
					return;

				default: //
			}
		default: //
		}

		// Allocate an output lvalue if necessary
		var out_ref = if (out == OutputReturn || out == OutputNone)
			null;
		else
			getOutputOrTemp(ctx, out, top);

		// Compute index of the start of arguments. Allow the
		// function reference intersect with the output slot,
		// but not the actual arguments.
		var aidx = if (direct_call == null)
			(out_ref != null &&
			 out_ref.place == Temporary &&
			 out_ref.slot == top.temp-1) ? out_ref.slot : top.temp++;
		else
			top.temp;

		for (arg in args)
		{
			var ctop = mktop(top);
			var tmp = ctx.env.mktemp(top.temp++);
			compileExpression(arg, ctx, OutputVar(tmp), ctop);
		}

		var expr = if (direct_call == null) {
			var ftmp = ctx.env.mktemp(aidx);
			compileExpression(fn, ctx, OutputVar(ftmp), mktop(top));
			'RUNNER->FastEvalFunction(&temps['+aidx+'], '+args.length+')';
		} else {
			if (args.length > 0) {
				direct_call+'(RUNNER, &temps['+aidx+'])';
			} else {
				direct_call+'(RUNNER, NULL)';
			}
		}

		if (out_ref != null) {
			ctx.wrcheck('CALL_WITH_RETSLOT('+out_ref.getLValue()+','+expr+')', allocs);
			copyValue(ctx, out, out_ref);
		} else {
			emitValue(ctx, out, expr, null, true, true, allocs);
		}
	}

	var known_natives : Map<String, { nargs: Int, noalloc: Bool, cname: String }>;

	function initNativeTables() {
		var known_runner_natives : Array<Dynamic> = [
			// Removed because CGI mode needs to override it at runtime
			//{ name: 'println', nargs: 1, noalloc: true },
			{ name: 'mapi', nargs: 2 },
			{ name: 'map', nargs: 2 },
			{ name: 'iter', nargs: 2 },
			{ name: 'iteri', nargs: 2 },
			{ name: 'fold', nargs: 3 },
			{ name: 'foldi', nargs: 3 },
			{ name: 'filter', nargs: 2 },
			{ name: 'elemIndex', nargs: 3, noalloc: true },
			{ name: 'exists', nargs: 2 },
			{ name: 'find', nargs: 2 },
			{ name: 'subrange', nargs: 3 },
			{ name: 'length', nargs: 1, noalloc: true },
			{ name: 'strlen', nargs: 1, noalloc: true, cname: 'NativeStrlen' },
			{ name: 'strIndexOf', nargs: 2, noalloc: true },
			{ name: 'substring', nargs: 3, noalloc: true },
			{ name: 'concat', nargs: 2 },
			{ name: 'replace', nargs: 3 },
			{ name: 'bitXor', nargs: 2, noalloc: true },
			{ name: 'bitOr', nargs: 2, noalloc: true },
			{ name: 'bitAnd', nargs: 2, noalloc: true },
			{ name: 'bitNot', nargs: 1, noalloc: true },
		];

		known_natives = new Map();

		for (obj in known_runner_natives) {
			if (obj.noalloc == null)
				obj.noalloc = false;
			if (obj.cname == null)
				obj.cname = obj.name;
			known_natives.set('Native.'+obj.name, obj);
		}
	}

	private function inlineNative(code : Flow, fn : String, args : FlowArray<Flow>, ctx : CppContext, out : CppOutputLocation, top : StackTop) : Bool
	{
		var eval_tmp = function(arg, ?allow_out = false) {
			return evalToTmp(arg, ctx, top, allow_out?out:null);
		}
		var fetch_ref = function(arg, lvalue, ?allow_out = false) {
			return fetchToRef(arg, ctx, top, lvalue, allow_out?out:null);
		}

		switch (fn) {
		case 'Native.length', 'Native.strlen',
		     'Native.bitXor', 'Native.bitOr', 'Native.bitAnd', 'Native.bitNot':
		    compileNumericExpr(code, ctx, out, top, TInt);

		case 'Native.substring':
			var str = eval_tmp(args[0], true);
			verifyTag(str, TString, ctx);
			var idx = emitNumericExpr(args[1], ctx, top, TInt);
			var len = emitNumericExpr(args[2], ctx, top, TInt);
			ctx.wr('if (unlikely(!RUNNER->DoSubstring(&'+str.getLValue()+','+idx+','+len+'))) RETVOID;');
			copyValue(ctx, out, str);

		case 'Native.map':
			switch (args[1]) {
			case Lambda(largs, type, body, _, pos):
				if (largs.length != 1)
					return false;
				inlineMapNative(args[0], null, null, null, largs[0], body, ctx, out, top, false);
			default:
				return false;
			}

		case 'Native.mapi':
			switch (args[1]) {
			case Lambda(largs, type, body, _, pos):
				if (largs.length != 2)
					return false;
				inlineMapNative(args[0], null, largs[0], null, largs[1], body, ctx, out, top, false);
			default:
				return false;
			}

		case 'Native.iter':
			switch (args[1]) {
			case Lambda(largs, type, body, _, pos):
				if (largs.length != 1)
					return false;
				inlineMapNative(args[0], null, null, null, largs[0], body, ctx, out, top, true);
			default:
				return false;
			}

		case 'Native.iteri':
			switch (args[1]) {
			case Lambda(largs, type, body, _, pos):
				if (largs.length != 2)
					return false;
				inlineMapNative(args[0], null, largs[0], null, largs[1], body, ctx, out, top, true);
			default:
				return false;
			}

		case 'Native.fold':
			switch (args[2]) {
			case Lambda(largs, type, body, _, pos):
				if (largs.length != 2)
					return false;
				inlineMapNative(args[0], args[1], null, largs[0], largs[1], body, ctx, out, top, false);
			default:
				return false;
			}

		case 'Native.foldi':
			switch (args[2]) {
			case Lambda(largs, type, body, _, pos):
				if (largs.length != 3)
					return false;
				inlineMapNative(args[0], args[1], largs[0], largs[1], largs[2], body, ctx, out, top, false);
			default:
				return false;
			}

		default:
			return false;
		}

		return true;
	}

	private function inlineMapNative(
		arr : Flow, init : Flow,
		iarg : String, farg : String, varg : String, body : Flow,
		ctx : CppContext, out : CppOutputLocation, top : StackTop,
		iter : Bool = false
	) {
		if (out == OutputNone)
			iter = true;

		var rvs = null, rv = null;
		if (!iter && farg == null) {
			// map output array
			rv = getOutputOrTemp(ctx, out, top);
			rvs = rv.getLValue();
		}

		var iv = fetchToRef(arr, ctx, top, true);
		var ivs = iv.getLValue();
		verifyTag(iv, TArray, ctx);

		var arrsize = ctx.tempvar('isz', TInt, 'RUNNER->GetArraySize('+ivs+')');

		if (farg != null) {
			// fold init value
			rv = evalToTmp(init, ctx, top);
			rvs = rv.getLValue();

			rv.name = farg;
			// Invalidate cached type info
			CppPlaceInfo.clearMeta(ctx.localMeta(rv));
		} else if (!iter) {
			ctx.wrcheck(assignExpr(rvs, 'RUNNER->AllocateArray('+arrsize+')',true),true);
			ctx.localMeta(rv).tag = TArray;
		}

		var subtop = mktop(top);

		// Index var as slot if used in closure
		var idx = null, idxvar;
		if (iarg != null) {
			idx = ctx.env.mktemp(subtop.temp++);
			ctx.wrsemi3('StackSlot::SetInt(',idx.getLValue(),',0)');
			idxvar = idx.getLValue()+'.slot_private.IntValue';
			idx.name = iarg;
			ctx.localMeta(idx).tag = TInt;
		}
		else
			idxvar = ctx.tempvar('i', TInt, '0');

		// Invalidate all pointer caches
		ctx.inc_gc();

		ctx.wr('for (; '+idxvar+' < '+arrsize+'; '+idxvar+'++) {');

		var subctx = ctx.enter('    ');
		if (iarg != null)
			subctx.pushdef(idx);
		if (farg != null)
			subctx.pushdef(rv);
		subctx.pushdef(new CppPlaceInfo(ctx.env, SlotAlias(iv, idxvar), 0, varg));

		// Emit body
		if (farg != null)
			compileExpression(body, subctx, OutputExpr(function(ctx,val) {
				return (val == rvs) ? '/*NOP*/' : assignExpr(rvs, val);
			}), subtop);
		else if (iter)
			compileExpression(body, subctx, OutputNone, subtop);
		else
			compileExpression(body, subctx, OutputExpr(function(ctx,val) {
				return 'RUNNER->SetArraySlot('+rvs+','+idxvar+','+val+')';
			}), subtop);

		subctx.exit();
		ctx.wr('}');
		ctx.join_one(subctx);

		if (iter)
			emitValue(ctx, out, 'FLOWVOID', null);
		else
			copyValue(ctx, out, rv);
	}

	function fieldIndex(struct : FlowType, name : String) : Int {
		switch (struct) {
			case TStruct(structname, cargs, max): {
				var index = 0;
				for (c in cargs) {
					if (c.name == name) {
						return index;
					}
					++index;
				}
			}
			default:
		}
		throw "Can not find the field " + name + " in " + Prettyprint.prettyprintType(struct);
		return 0;
	}

	function structTypeId(struct : FlowType) : Int {
		return switch (struct) {
			case TStruct(structname, cargs, max): structs.get(structname).id;
			default: throw "Not a struct: " + Prettyprint.prettyprintType(struct);
		}
	}

	function structTypeSize(struct : FlowType) : Int {
		return switch (struct) {
			case TStruct(structname, cargs, max): cargs.length;
			default: throw "Not a struct: " + Prettyprint.prettyprintType(struct);
		}
	}

	inline function mktop(top : StackTop) : StackTop {
		return { temp: top.temp };
	}

	function getOutputPlace(out : CppOutputLocation, ?top : StackTop = null) : CppPlaceInfo {
		if (out == null)
			return null;

		return switch (out) {
			case OutputVar(place):
				if (top != null && place.place == Temporary && place.slot >= top.temp)
					top.temp = place.slot+1;
				place;
			default:
				null;
		}
	}

	function getOutputOrTemp(ctx : CppContext, out : CppOutputLocation, top : StackTop) : CppPlaceInfo {
		var tmp = getOutputPlace(out, top);
		if (tmp == null)
			tmp = ctx.env.mktemp(top.temp++);
		return tmp;
	}

	function evalToTmp(
		arg : Flow, ctx : CppContext, top : StackTop,
		out : Null<CppOutputLocation> = null
	) : CppPlaceInfo {
		var atmp = mktop(top);
		var tmp = getOutputOrTemp(ctx, out, top);
		compileExpression(arg, ctx, OutputVar(tmp), atmp);
		return tmp;
	}

	function fetchToRef(
		arg : Flow, ctx : CppContext, top : StackTop,
		lvalue : Bool, ?out : Null<CppOutputLocation> = null
	) : CppPlaceInfo {
		var ref = getValueRef(arg, ctx, lvalue);
		if (ref != null) return ref;
		return evalToTmp(arg, ctx, top, out);
	}

	function fetchToScalar(
		arg : Flow, ctx : CppContext, top : StackTop, tag : CppTagType
	) : String {
		var tmp = ctx.tempvar('xtmp', tag);
		compileExpression(arg, ctx, OutputScalar(tmp, tag), mktop(top));
		return tmp;
	}

	function emitNumericExpr(expr : Flow, ctx : CppContext, top : StackTop, tag : CppTagType) : String
	{
		var simple_binary = function(e1,e2,op) {
			var v1 = emitNumericExpr(e1, ctx, top, tag);
			var v2 = emitNumericExpr(e2, ctx, top, tag);
			return ctx.tempvar('ntmp', tag, v1+op+v2);
		}

		switch (expr) {
		case ConstantI32(value, pos):
			var str = (I2i.ucompare(value, int_80000000) == 0) ? 'int(0x80000000U)' : ''+value;
			return str;

		case ConstantDouble(value, pos):
			var expr = if (value == Math.NEGATIVE_INFINITY) {
				"(-std::numeric_limits<double>::infinity())";
			} else if (value == Math.POSITIVE_INFINITY) {
				"std::numeric_limits<double>::infinity()";
			} else if (Math.isNaN(value)) {
				"std::numeric_limits<double>::quiet_NaN()";
			} else {
				var sv = ''+value;
				(sv.indexOf(".") == -1 && sv.indexOf("e") == -1) ? sv + '.0' : sv;
			};
			return expr;

		case Plus(e1, e2, pos):
			return simple_binary(e1,e2,'+');
		case Minus(e1, e2, pos):
			return simple_binary(e1,e2,'-');
		case Multiply(e1, e2, pos):
			return simple_binary(e1,e2,'*');
		case Divide(e1, e2, pos):
			return simple_binary(e1,e2,'/');

		case Modulo(e1, e2, pos):
			if (tag == TDouble) {
				var v1 = emitNumericExpr(e1, ctx, top, tag);
				var v2 = emitNumericExpr(e2, ctx, top, tag);
				return ctx.tempvar('ntmp', tag, 'fmod('+v1+','+v2+')');
			} else {
				return simple_binary(e1,e2,'%');
			}

		case Negate(e1, pos):
			return '(-'+emitNumericExpr(e1, ctx, top, tag)+')';

		case Cast(value, fromtype, totype, pos):
			switch (totype) {
			case FlowType.TInt:
			case FlowType.TDouble:
			default: throw "Not implemented: " + Prettyprint.print(expr);
			}
			switch (fromtype) {
			case FlowType.TInt:
				var arg = emitNumericExpr(value, ctx, top, CppTagType.TInt);
				return (tag == TDouble) ? 'double('+arg+')' : arg;
			case TDouble:
				var arg = emitNumericExpr(value, ctx, top, CppTagType.TDouble);
				return (tag == TDouble) ? 'int('+arg+')' : arg;
			default: throw "Not implemented: " + Prettyprint.print(expr);
			}

		case Call(fn, args, pos):
			var nname = callNativeName(fn, ctx);
			if (nname != null) {
				switch (nname) {
				case 'Native.length':
					var arg = fetchToRef(args[0], ctx, mktop(top), false);
					verifyTag(arg, TArray, ctx);
					var valstr = 'RUNNER->GetArraySize('+arg.getRValue(ctx)+')';
					return ctx.tempvar('len', TInt, valstr);
				case 'Native.strlen':
					var arg = fetchToRef(args[0], ctx, mktop(top), false);
					verifyTag(arg, TString, ctx);
					var valstr = 'RUNNER->GetStringSize('+arg.getRValue(ctx)+')';
					return ctx.tempvar('len', TInt, valstr);

				case 'Native.bitXor':
					tag = TInt;
					return simple_binary(args[0], args[1], '^');
				case 'Native.bitOr':
					tag = TInt;
					return simple_binary(args[0], args[1], '|');
				case 'Native.bitAnd':
					tag = TInt;
					return simple_binary(args[0], args[1], '&');
				case 'Native.bitNot':
					return '(~'+emitNumericExpr(args[0], ctx, top, TInt)+')';

				default:
				}
			}
			return fetchToScalar(expr, ctx, top, tag);

		default:
			return fetchToScalar(expr, ctx, top, tag);
		}
	}

	function compileNumericExpr(expr : Flow, ctx : CppContext,
						 out : CppOutputLocation, top : StackTop, ttag : CppTagType)
	{
		var cexpr = emitNumericExpr(expr, ctx, top, ttag);

		switch (out) {
		case OutputScalar(name,tag):
			if (tag == ttag) {
				ctx.wrsemi3(name, SPC_EQ_SPC, cexpr);
				return;
			}
		default:
		}

		if (ttag == TDouble)
			emitValue(ctx, out, 'StackSlot::MakeDouble('+cexpr+')', TDouble);
		else
			emitValue(ctx, out, 'StackSlot::MakeInt('+cexpr+')', TInt);
	}

	function compileMath(expr : Flow, pos : Position, ctx : CppContext,
						 out : CppOutputLocation, top : StackTop)
	{
		var ttag = getPrimitiveTag(pos);

		if (ttag == TDouble || ttag == TInt) {
			compileNumericExpr(expr, ctx, out, top, ttag);
			return;
		}

		var out_ref = null;

		var eval_tmp = function(arg, ?allow_out = false) {
			return evalToTmp(arg, ctx, top, allow_out?out:null);
		}
		var fetch_ref = function(arg, lvalue, ?allow_out = false) {
			return fetchToRef(arg, ctx, top, lvalue, allow_out?out:null);
		}

		var simple_binary = function(e1, e2, cmd) {
			var a1 = out_ref = eval_tmp(e1, true);
			var a2 = fetch_ref(e2, false);
			ctx.wrcheck('RUNNER->'+cmd+'('+a1.getLValue()+', '+a2.getRValue(ctx)+')');
		}

		switch (expr) {
		case Plus(e1, e2, pos):
			var a1 = out_ref = eval_tmp(e1, true);
			var a2 = fetch_ref(e2, true);
			if (ttag == TString) {
				verifyTag(a1, ttag, ctx);
				verifyTag(a2, ttag, ctx);
				ctx.wrcheck('RUNNER->DoPlusString('+a1.getLValue()+', '+a2.getLValue()+')',true);
			} else {
				ctx.wrcheck('RUNNER->DoPlus('+a1.getLValue()+', '+a2.getLValue()+')',true);
			}

		case Minus(e1, e2, pos): simple_binary(e1, e2, 'DoMinus');
		case Multiply(e1, e2, pos): simple_binary(e1, e2, 'DoMultiply');
		case Divide(e1, e2, pos): simple_binary(e1, e2, 'DoDivide');
		case Modulo(e1, e2, pos): simple_binary(e1, e2, 'DoModulo');

		case Negate(e1, pos):
			var a1 = out_ref = eval_tmp(e1, true);
			ctx.wrcheck('RUNNER->DoNegate('+a1.getLValue()+')');

		default: throw 'impossible';
		}

		copyValue(ctx, out, out_ref);
	}

	function emitPrimitiveWrap(expr : Flow, ctx : CppContext, top : StackTop) : String
	{
		var numbers = function(pos) {
			var ttag = getPrimitiveTag(pos);
			if (ttag != TInt && ttag != TDouble)
				return null;

			var cexpr = emitNumericExpr(expr, ctx, top, ttag);
			if (ttag == TDouble)
				return 'StackSlot::MakeDouble('+cexpr+')';
			else
				return 'StackSlot::MakeInt('+cexpr+')';
		}

		var boolean = function() {
			var cexpr = emitConditionExpr(expr, ctx, top);
			return 'StackSlot::MakeBool('+cexpr+')';
		}

		return switch (expr) {
			case Plus(e1, e2, pos): numbers(pos);
			case Minus(e1, e2, pos): numbers(pos);
			case Multiply(e1, e2, pos): numbers(pos);
			case Divide(e1, e2, pos): numbers(pos);
			case Modulo(e1, e2, pos): numbers(pos);
			case Negate(e1, pos): numbers(pos);

			case And(e1, e2, pos): boolean();
			case Or(e1, e2, pos): boolean();
			case Not(e1, pos): boolean();

			case Equal(e1, e2, pos): boolean();
			case NotEqual(e1, e2, pos): boolean();
			case GreaterThan(e1, e2, pos): boolean();
			case GreaterEqual(e1, e2, pos): boolean();
			case LessThan(e1, e2, pos): boolean();
			case LessEqual(e1, e2, pos): boolean();

			case Field(call, name, pos):
				var ttag = getPrimitiveTag(pos);
				if (ttag == TBool)
					boolean();
				else
					numbers(pos);

			default: null;
		}
	}

	function getPrimitiveTag(pos : Position, ?type2 : Bool = false) : Null<CppTagType> {
		var fields = FlowUtil.untyvar(type2 ? pos.type2 : pos.type);
		if (fields == null)
			return null;

		switch (fields) {
			case FlowType.TInt: return TInt;
			case FlowType.TDouble: return TDouble;
			case FlowType.TBool: return TBool;
			case FlowType.TString: return TString;
			default: return null;
		}
	}
}
