import Flow;
import HaxeWriter;
import Position;

import sys.io.File;
import sys.io.FileOutput;

typedef JavaStructInfo = {
	name: String, id : Int,
	args : FlowArray<MonoTypeDeclaration>,
	atypes : Array<String>, ftypes : Array<String>
};

typedef JavaGlobalNameInfo = {
	name : String,
	type : FlowType,
	module : JavaModuleFile
};

typedef JavaLocalNameInfo = {
	name : String,
	type : FlowType,
	is_final : Bool,
	is_obj : Bool
};

typedef JavaModuleFile = {
	fname : String,
	id : String,
	globals : Array<String>,
	vars : StringBuf
};

typedef JavaLocalBackup = Array<{name:String,old:JavaLocalNameInfo}>;

enum JavaReturnLocation {
	IgnoreValue();
	LocalVar(name : String, type : FlowType);
	Return(type : FlowType);
}

class JavaContext {
	public var sb : StringBuf;
	public var parent_ctx : JavaContext;
	public var locals : Map<String, JavaLocalNameInfo>;
	public var has_tail_call : Bool;
	public var can_tail_call : String;
	public var local_id : Int;

	public var arg_names : FlowArray<String>;
	public var arg_types : FlowArray<FlowType>;
	public var cur_indent : String;

	public var stmt_trf : JavaStatementTransform;

	public inline function isClosure() {
		return parent_ctx != null;
	}

	public function new(parent : JavaContext) {
		this.sb = new StringBuf();
		this.parent_ctx = parent;
		this.locals = new Map();
		this.has_tail_call = false;

		local_id = 0;

		stmt_trf = new JavaStatementTransform(this);
	}

	public function newLocalName(n : String) {
		return 'l'+(local_id++)+'_'+n;
	}

	public function bindLocal(save : JavaLocalBackup, name : String, info : JavaLocalNameInfo) {
		var irec = { name: name, old: locals.get(name) };
		save.push(irec);
		locals.set(name, info);
	}

	public function popLocals(save : JavaLocalBackup) {
		for (v in save) {
			if (v.old == null)
				locals.remove(v.name);
			else
				locals.set(v.name, v.old);
		}
	}
}

class JavaWriter {
	public function new(p : Program, debug : Bool, package_name : String, outdir : String, extStructDefs : Bool)  {
		Profiler.get().profileStart("Java export");
		this.p = p;
		this.extStructDefs = extStructDefs;
		this.package_name = package_name;
		this.output_dir = outdir;

		modules = new Map<String, JavaModuleFile>();
		module_by_id = new Map<String, JavaModuleFile>();
		module_list = [];

		usesHost = new Map<String, Bool>();

		// Officially optional natives that are known to exist in this target
		knownNatives = new Map();
		knownNatives.set('Native.strRangeIndexOf', true);

		indexStructs();

		main_file = sys.io.File.write(output_dir+'/Main.java', false);

		main_file.writeString('package '+package_name+';\n\n');
		main_file.writeString('import com.area9innovation.flow.*;\n\n');
		main_file.writeString('@SuppressWarnings("unchecked")\n');
		main_file.writeString('public final class Main extends FlowRuntime {\n');

		init_code = new StringBuf();

		indexGlobals();
		initStructs();
		writeFunctions();

		writeStructs();

		main_file.writeString('\tprivate void init() {\n');
		main_file.writeString(init_code.toString());
		main_file.writeString('\t}\n');
		main_file.writeString('\tprotected void main() {\n');
		main_file.writeString('\t\tinit();\n');

		var main_fn = globalFuncs.get('main');
		if (main_fn == null)
			throw "No 'main' function";
		main_file.writeString('\t\t'+wrapModule(main_fn.name, main_fn.module)+'();\n');
		main_file.writeString('\t}\n');

		main_file.writeString('\tpublic static void main(String[] args) {\n');
		main_file.writeString('\t\tMain runner = new Main(args);\n');
		main_file.writeString('\t\trunner.start(null);\n');
		main_file.writeString('\t}\n');

		main_file.writeString('}\n');
		main_file.close();
	}

	var p : Program;
	var extStructDefs : Bool;
	var package_name : String;
	var output_dir : String;

	var structs : Map<String, JavaStructInfo>;
	var structsOrder : Array<JavaStructInfo>;

	var hasFieldAccessor : Map<String, Bool>;
	var usesHost : Map<String, Bool>;
	var knownNatives : Map<String, Bool>;

	var globals : Map<String, JavaGlobalNameInfo>;
	var globalFuncs : Map<String, JavaGlobalNameInfo>;

	var modules : Map<String, JavaModuleFile>;
	var module_by_id : Map<String, JavaModuleFile>;
	var module_list : Array<JavaModuleFile>;

	var main_file : FileOutput;
	var init_code : StringBuf;

	private function indexStructs() {
		// Next, number the structs
		structs = new Map();
		hasFieldAccessor = new Map();

		// We do this in alphabetical order in order to avoid random changes in the code just because 
		// of hash ordering differences
		structsOrder = [];
		for (d in p.userTypeDeclarations) {
			switch (d.type.type) {
			case TStruct(structname, cargs, max):
				structsOrder.push({ name: structname, id: -1, args : cargs, atypes: [], ftypes: [] });
			default:
			}
		}
		structsOrder.sort(function(s1, s2) {
			return if (s1.name < s2.name) -1 else if (s1.name == s2.name) 0 else 1;
		});

		var nstructs = 0;

		for (s in structsOrder) {
			s.id = nstructs;
			structs.set(s.name, s);
			/*for (a in s.args)
				requireAccessor(a.name);*/
			nstructs++;
		}

		for (s in structsOrder) {
			for (a in s.args) {
				s.atypes.push(flowType2objType(a.type));
				s.ftypes.push(flowType2fieldType(a.type));
			}
		}
	}

	private function requireAccessor(name : String) {
		if (hasFieldAccessor.exists(name))
			return;

		hasFieldAccessor.set(name, true);

		var f = sys.io.File.write(output_dir+'/Field_'+name+'.java', false);

		f.writeString('package '+package_name+';\n\n');
		f.writeString('import com.area9innovation.flow.*;\n\n');
		f.writeString('interface Field_'+name+'<T> {\n');
		f.writeString('\tT get_'+name+'();\n');
		f.writeString('\tvoid set_'+name+'(T value);\n');
		f.writeString('}\n');

		f.close();
	}

	private function writeStructs() {
		for (s in structsOrder) {
			var args = s.args;

			if (args.length == 0)
				continue;

			var id = s.id;
			var atypes = s.atypes;
			var ftypes = s.ftypes;

			var f = sys.io.File.write(output_dir+'/Struct_'+s.name+'.java', false);

			f.writeString('package '+package_name+';\n\n');
			f.writeString('import com.area9innovation.flow.*;\n\n');
			f.writeString('class Struct_'+s.name+' extends Struct');

			var pfix = ' implements ';

			for (i in 0...args.length) {
				if (!hasFieldAccessor.exists(args[i].name))
					continue;

				f.writeString(pfix+'Field_'+args[i].name+'<'+atypes[i]+'>');
				pfix = ', ';
			}

			f.writeString(' {\n');

			for (i in 0...args.length)
				f.writeString('\tpublic '+ftypes[i]+' f_'+args[i].name+';\n');

			f.writeString('\n\tpublic Struct_'+s.name+'() {}\n');
			f.writeString('\tpublic Struct_'+s.name+'(');

			pfix = '';

			for (i in 0...args.length) {
				f.writeString(pfix+ftypes[i]+' a_'+args[i].name);
				pfix = ', ';
			}

			f.writeString(') {\n');
			for (a in args)
				f.writeString('\t\tf_'+a.name+' = a_'+a.name+';\n');
			f.writeString('\t}\n');

			for (i in 0...args.length) {
				var name = args[i].name;
				if (!hasFieldAccessor.exists(name))
					continue;

				f.writeString('\tpublic '+atypes[i]+' get_'+name+'() { return f_'+name+'; }\n');
				f.writeString('\tpublic void set_'+name+'('+atypes[i]+' value) { f_'+name+' = value; }\n');
			}

			f.writeString('\n\tpublic int getTypeId() { return '+id+'; }\n');
			f.writeString('\tpublic String getTypeName() { return "'+s.name+'"; }\n');

			f.writeString('\n\tprivate static final String[] field_names = new String[] {\n\t\t');

			pfix = '';
			for (a in args) {
				f.writeString(pfix + '"' + a.name + '"');
				pfix = ', ';
			}

			f.writeString('\n\t};\n\tprivate static final RuntimeType[] field_types = new RuntimeType[] {\n\t\t');

			pfix = '';
			for (a in args) {
				f.writeString(pfix + flowType2runtimeType(a.type));
				pfix = ', ';
			}

			f.writeString('\n\t};\n\tpublic String[] getFieldNames() { return field_names; }\n');
			f.writeString('\tpublic RuntimeType[] getFieldTypes() { return field_types; }\n');

			f.writeString('\n\tpublic Object[] getFields() {\n\t\treturn new Object[] {\n\t\t\t');

			pfix = '';
			for (a in args) {
				f.writeString(pfix + 'f_' + a.name);
				pfix = ', ';
			}

			f.writeString('\n\t\t};\n\t}\n');

			f.writeString('\t@SuppressWarnings("unchecked")\n');
			f.writeString('\tpublic void setFields(Object[] values) {\n');
			f.writeString('\t\tif (values.length != '+args.length+')\n');
			f.writeString('\t\t\tthrow new IndexOutOfBoundsException("Invalid field count in '+s.name+'");\n');

			for (i in 0...args.length) {
				f.writeString('\t\tf_'+args[i].name+' = ('+atypes[i]+')values['+i+'];\n');
			}

			f.writeString('\t}\n\n');

			f.writeString('\tpublic int compareTo(Struct other_gen) {\n');
			f.writeString('\t\tif (other_gen == this) return 0;\n');
			f.writeString('\t\tint tmp = other_gen.getTypeId();\n');
			f.writeString('\t\tif (tmp != '+id+') return '+id+'-tmp;\n');
			f.writeString('\t\tStruct_'+s.name+' other = (Struct_'+s.name+')other_gen;\n');

			var tmp = false;

			for (i in 0...args.length) {
				var name = args[i].name;
				if (tmp)
					f.writeString('\t\tif (tmp != 0) return tmp;\n');
				tmp = true;
				switch (args[i].type) {
					case TBool:
						f.writeString('\t\tif (f_'+name+' != other.f_'+name+')\n');
						f.writeString('\t\t\treturn f_'+name+' ? 1 : -1;\n');
						tmp = false;
					case TInt, TDouble:
						f.writeString('\t\tif (f_'+name+' != other.f_'+name+')\n');
						f.writeString('\t\t\treturn (f_'+name+' > other.f_'+name+') ? 1 : -1;\n');
						tmp = false;
					case TString, TName(_,_), TStruct(_,_,_), TReference(_):
						f.writeString('\t\ttmp = f_'+name+'.compareTo(other.f_'+name+');\n');
					default:
						f.writeString('\t\ttmp = FlowRuntime.compareByValue(f_'+name+', other.f_'+name+');\n');
				}
			}

			if (tmp)
				f.writeString('\t\treturn tmp;\n\t}\n');
			else
				f.writeString('\t\treturn 0;\n\t}\n');

			f.writeString('}\n');
			f.close();
		}
	}

	private function flowType2objType(type : FlowType, no_args : Bool = false) : String {
		if (type == null)
			return 'Object';
		switch (type) {
			case TBool: return "Boolean";
			case TInt:  return "Integer";
			case TDouble: return "Double";
			case TString: return "String";
			case TArray(at): return "Object[]";
			case TUnion(min,max): return "Struct";
			case TName(name, args):
				var info = structs.get(name);
				if (info == null)
					return "Struct";
				else if (info.args.length > 0)
					return "Struct_"+name;
				else
					return "SingletonStruct";
			case TStruct(name, args, max):
				return args.length > 0 ? "Struct_"+name : "SingletonStruct";
			case TReference(t):
				return no_args ? "Reference" : "Reference<"+flowType2objType(t)+">";
			case TFunction(args,ret):
				if (args == null)
					return 'Function';
				var str = new StringBuf();
				str.add('Func'); str.add(args.length);
				if (no_args)
					return str.toString();
				str.add('<');
				str.add(flowType2objType(ret));
				for (a in args) {
					str.add(','); str.add(flowType2objType(a));
				}
				str.add('>');
				return str.toString();
			case TTyvar(tv):
				return flowType2objType(tv.type, no_args);
			default: return "Object";
		};
	}

	private function flowType2runtimeType(type : FlowType) : String {
		switch (type) {
			case TBool: return "RuntimeType.BOOL";
			case TInt:  return "RuntimeType.INT";
			case TDouble: return "RuntimeType.DOUBLE";
			case TString: return "RuntimeType.STRING";
			case TArray(at): return "RuntimeType.ARRAY";
			case TName(name, args): return "RuntimeType.STRUCT";
			case TStruct(name, args, max): return "RuntimeType.STRUCT";
			case TReference(t): return "RuntimeType.REF";
			default: return "RuntimeType.UNKNOWN";
		};
	}

	private function flowType2fieldType(type : FlowType, no_args : Bool = false) : String {
		if (type == null)
			return 'Object';
		switch (type) {
			case TBool: return "boolean";
			case TInt:  return "int";
			case TDouble: return "double";
			default: return flowType2objType(type, no_args);
		};
	}

	private function emitCallWrapper(sb : StringBuf, indent : String, tgt : String, cpfix : String, type : FlowType, before : String = null, after : String = null) {
		switch (type) {
		case TFunction(args, ret):
			var tstr = flowType2objType(type);
			sb.add('new ');
			sb.add(tstr); sb.add('() {\n');
			sb.add(indent); sb.add('\tfinal public '); sb.add(flowType2objType(ret)); sb.add(' invoke(');
			var pfix = '';
			for (i in 0...args.length) {
				sb.add(pfix); sb.add(flowType2objType(args[i])); sb.add(' a'); sb.add(i);
				pfix = ', ';
			}
			sb.add(') {\n');
			sb.add(indent); sb.add('\t\t');
			if (before != null)
				sb.add(before);
			sb.add('return '); sb.add(tgt);
			pfix = cpfix;
			for (i in 0...args.length) {
				sb.add(pfix); sb.add('a'); sb.add(i); pfix = ', ';
			}
			sb.add(');');
			if (after != null)
				sb.add(after);
			sb.add('\n');
			sb.add(indent); sb.add('\t}\n');
			sb.add(indent); sb.add('}');
		default:
			throw "invalid type";
		}
	}

	private function emitClosureWrapper(name : String, tgt : String, type : FlowType, module : JavaModuleFile) {
		var tstr = flowType2objType(type);
		var sb = new StringBuf();
		sb.add('\tfinal '); sb.add(tstr); sb.add(' ');
		sb.add(name);
		sb.add(' = ');
		if (module != null)
			tgt = 'm_'+module.id+'.'+tgt;
		emitCallWrapper(sb, '\t', tgt+'(', '', type);
		sb.add(';\n');
		main_file.writeString(sb.toString());
	}

	private function initStructs() {
		main_file.writeString('\tstatic final Object[] arr_empty = new Object[0];\n');

		var inits = new StringBuf();
		inits.add('\tpublic Main(String[] args) {\n');
		inits.add('\t\tsuper(new Struct[] {\n');

		var l = structsOrder.length;
		for (i in 0...l) {
			var s = structsOrder[i];
			if (s.args.length == 0) {
				inits.add('\t\t\tstr_'); inits.add(s.name);
				main_file.writeString('\tstatic final SingletonStruct str_'+s.name+' = SingletonStruct.make('+s.id+',"'+s.name+'");\n');
			} else {
				inits.add('\t\t\tnew Struct_'); inits.add(s.name); inits.add('()');
			}
			if (i < l-1)
				inits.add(',');
			inits.add('\n');
		}

		inits.add('\t\t}, args);\n');

		for (host in usesHost.keys()) {
			main_file.writeString('\t'+host+' h_'+host+';\n');
			init_code.add('\t\th_'+host+' = super.getNativeHost('+host+'.class);\n');
		}

		for (m in module_list) {
			main_file.writeString('\tfinal Module_'+m.id+' m_'+m.id+';\n');
			inits.add('\t\tm_'+m.id+' = new Module_'+m.id+'(this);\n');
		}

		inits.add('\t}\n');

		main_file.writeString(inits.toString());
	}

	private function getModule(pos : Position) : JavaModuleFile {
		var mod = modules.get(pos.f);
		if (mod == null) {
			var t = pos.f;
			var i = t.lastIndexOf('/');
			if (i >= 0)
				t = t.substr(i+1);
			t = StringTools.replace(t, ".flow", "");
			t = StringTools.replace(t, ".", "_");

			if (module_by_id.get(t) != null) {
				var i = 2;
				while (module_by_id.get(t+i) != null)
					i++;
				t = t + i;
			}

			mod = {
				fname: pos.f,
				id: t,
				globals: [],
				vars: new StringBuf()
			};
			module_list.push(mod);
			modules.set(pos.f, mod);
			module_by_id.set(t, mod);
		}
		return mod;
	}

	private function indexGlobals() {
		globalFuncs = new Map();
		globals = new Map();

		for (d in p.declsOrder) {
			var c = p.topdecs.get(d);
			if (c == null) // It may be with DCE
				continue;

			switch(c) {
				case Native(name, io, args, result, defbody, pos):
					var parts = name.split('.');
					if (parts.length != 2)
						throw "Invalid native identifier: "+name;
					usesHost.set(parts[0], true);
					if (defbody == null || knownNatives.exists(name)) {
						var rtype = result;
						if (structTypeName(rtype) != null)
							rtype = TUnion(null,null);
						var type = TFunction(args, rtype);
						globalFuncs.set(d, {name:'h_'+name, type:type, module:null});
					} else {
						var module = getModule(pos);
						var type = TFunction(args, result);
						var tstr = flowType2objType(type);
						module.globals.push(d);
						emitClosureWrapper('nw_'+d, 'nf_'+d, type, module);
						main_file.writeString('\t'+tstr+' n_'+d+' = nw_'+d+';\n');
						globals.set(d, { name: 'n_'+d, type: type, module: null });

						init_code.add('\t\ttry {\n');
						init_code.add('\t\t\tfinal java.lang.reflect.Method method = '+
						              parts[0]+'.class.getMethod("'+parts[1]+'"');
						for (a in args)
							init_code.add(', '+flowType2objType(a, true)+'.class');
						init_code.add(');\n');
						init_code.add('\t\t\tn_'+d+' = ');
						emitCallWrapper(init_code, '\t\t\t',
										'('+flowType2objType(result)+')method.invoke(h_'+parts[0], ', ', type,
										'try { ',
										' } catch (ReflectiveOperationException e) { throw new RuntimeException(e); }');
						init_code.add(';\n\t\t} catch (ReflectiveOperationException e) {};\n');
					}
				case Lambda(arguments, type, body, _, pos):
					var module = getModule(pos);
					module.globals.push(d);
					globalFuncs.set(d, {name:'f_'+d, type:getPosType(pos), module:module});
				default:
					var pos = FlowUtil.getPosition(c);
					var module = getModule(pos);
					var type = getPosType(pos);
					var tstr = flowType2fieldType(type);
					module.vars.add('\t'+tstr+' g_'+d+';\n');
					module.globals.push(d);
					globals.set(d, { name: 'g_'+d, type: type, module: module });
			}
		}
	}

	private var cur_global : String;
	private var cur_module : JavaModuleFile;

	private function writeFunctions() {
		var inits = new Map<String, JavaModuleFile>();

		for (m in modules) {
			cur_module = m;

			var module_file = File.write(output_dir+'/Module_'+m.id+'.java', false);

			module_file.writeString('package '+package_name+';\n\n');
			module_file.writeString('import com.area9innovation.flow.*;\n\n');
			module_file.writeString('/* '+m.fname+' */\n');
			module_file.writeString('@SuppressWarnings("unchecked")\n');
			module_file.writeString('final class Module_'+m.id+' {\n');
			module_file.writeString('\tfinal Main runtime;\n');
			module_file.writeString('\tModule_'+m.id+'(Main runtime) {\n');
			module_file.writeString('\t\tthis.runtime = runtime;\n');
			module_file.writeString('\t}\n');
			module_file.writeString(m.vars.toString());

			writeModuleFunctions(module_file, m, inits);

			module_file.writeString('}\n');
			module_file.close();
		}

		cur_module = null;

		for (d in p.declsOrder) {
			var init = inits.get(d);
			if (init != null)
				init_code.add('\t\tm_'+init.id+'.init_'+d+'();\n');
		}
	}

	private function writeModuleFunctions(file : FileOutput, m : JavaModuleFile, inits : Map<String, JavaModuleFile>) {
		for (d in m.globals) {
			var c = p.topdecs.get(d);
			if (c == null) // It may be with DCE
				continue;

			cur_global = d;

			switch(c) {
				case Native(name, io, args, result, defbody, pos):
					if (defbody == null || knownNatives.exists(name))
						continue;
					emitGlobalFunction(file, 'nf_'+d, defbody, args, result);
				case Lambda(arguments, type, body, _, pos):
					emitGlobalFunction(file, 'f_'+d, c, null, null);
				default:
					var pos = FlowUtil.getPosition(c);
					var type = getPosType(pos);
					var ctx = new JavaContext(null);
					emitStatement(c, ctx, LocalVar('g_'+d, type), '\t\t');
					file.writeString('\t/* '+Prettyprint.position(pos)+' */\n');
					file.writeString('\tvoid init_'+d+'() {\n');
					file.writeString(ctx.sb.toString());
					file.writeString('\t}\n');
					inits.set(d, m);
			}
		}
	}

	private function emitGlobalFunction(file : FileOutput, name : String, tree : Flow, atypes : FlowArray<FlowType>, rtype : FlowType) {
		var ctx = emitFunction(name, tree, atypes, rtype, null, '\t');

		file.writeString('\t/* '+Prettyprint.position(FlowUtil.getPosition(tree))+' */\n');
		file.writeString(ctx.sb.toString());
	}

	private function splitFunctionType(type : FlowType) {
		switch (type) {
			case TFunction(args,ret):
				return { args: args, ret: ret };
			case TFlow: {
				// This is speculative
				return { args: new FlowArray(), ret : type };
			}
			default: {
				trace(type);
				throw "invalid function type";
			}
		}
	}

	private function emitFunction(name : String, tree : Flow, atypes : FlowArray<FlowType>, rtype : FlowType, parent : JavaContext, indent : String) : JavaContext {
		var largs, ltype, lbody, lpos;
		switch(tree) {
			case Lambda(arguments, type, body, _, pos):
				largs = arguments;
				ltype = type;
				lbody = body;
				lpos = pos;
			default:
				throw "invalid function node";
		}

		var ltype = getPosType(lpos);
		if (ltype != null) {
			var info = splitFunctionType(ltype);
			if (atypes == null)
				atypes = info.args;
			if (rtype == null)
				rtype = info.ret;
		}

		var ctx = new JavaContext(parent);
		var is_closure = ctx.isClosure();
		var type_fn = is_closure ? flowType2objType : flowType2fieldType;

		if (!is_closure)
			ctx.can_tail_call = cur_global;

		ctx.arg_names = largs;
		ctx.arg_types = atypes;

		var sb = new StringBuf();
		sb.add(indent);
		if (is_closure)
			sb.add('public ');
		sb.add(type_fn(rtype)); sb.add(' '); sb.add(name); sb.add('(');
		var pfix = '';
		for (i in 0...largs.length) {
			var aname = (largs[i] == '__') ? 'a'+i : 'a'+largs[i];
			sb.add(pfix);
			if (is_closure)
				sb.add('final ');
			sb.add(type_fn(atypes[i])); sb.add(' '); sb.add(aname);
			ctx.locals.set(largs[i], {
				name: aname, type: atypes[i], is_final: is_closure, is_obj: is_closure
			});
			pfix = ', ';
		}
		sb.add(') {\n');

#if false
		try {
			emitStatement(lbody, ctx, Return(rtype), indent + '\t');
		} catch (e : Dynamic) {
			trace(ctx.sb.toString());
			throw e;
		}
#else
		emitStatement(lbody, ctx, Return(rtype), indent + '\t');
#end

		if (ctx.has_tail_call) {
			sb.add(indent); sb.add(' TAIL_CALL: for(;;) {\n');
		}

		sb.add(ctx.sb.toString());

		if (ctx.has_tail_call) {
			sb.add(indent); sb.add(' }\n');
		}

		sb.add(indent); sb.add('}\n');

		ctx.sb = sb;
		return ctx;
	}

	private function unfoldStatements(code : Flow, ctx : JavaContext, indent : String, vars : JavaLocalBackup, allow_stmt : Bool = false) : Flow
	{
		if (code == null)
			return null;

		var sb = ctx.sb;

		switch (code) {
		case Sequence(statements, pos): {
			var l = statements.length;
			for (i in 0...l-1) {
				emitStatement(statements[i], ctx, IgnoreValue, indent);
			}
			return unfoldStatements(statements[l-1], ctx, indent, vars, allow_stmt);
		}
		case Let(name, sigma, value, scope, pos): {
			var save_inner = [];
			var value_body = unfoldStatements(value, ctx, indent, save_inner, true);

			var ln = ctx.newLocalName(name);
			var type = getPosType2(pos);
			var stmt = false;

			if (isLambda(value_body)) {
				var rexpr = 'final '+flowType2fieldType(type)+' '+ln+' = ';
				emitClosure(value_body, ctx, rexpr, type, indent);
			} else {
				stmt = JavaStatementTransform.isStatement(value_body, true);

				sb.add(indent);
				if (!stmt)
					sb.add('final ');
				sb.add(flowType2fieldType(type)); sb.add(' '); sb.add(ln);

				if (stmt) {
					sb.add(';\n');
					emitStatement(value_body, ctx, LocalVar(ln, type), indent);
				} else {
					sb.add(' = ');
					sb.add(emitExpression(value_body, ctx, type));
					sb.add(';\n');
				}
			}

			ctx.popLocals(save_inner);
			ctx.bindLocal(vars, name, { name: ln, type: type, is_final: !stmt, is_obj: false });

			return unfoldStatements(scope, ctx, indent, vars, allow_stmt);
		}
		default:
			if (!allow_stmt || !JavaStatementTransform.isStatement(code, true)) {
				var code2 = ctx.stmt_trf.transform(code);
				if (code2 != code)
					return unfoldStatements(code2, ctx, indent, vars);
			}

			return code;
		}
	}

	private function emitStatement(code0 : Flow, ctx : JavaContext, rloc : JavaReturnLocation, indent : String)
	{
		var sb = ctx.sb;

		var top_vars = [];
		var code = unfoldStatements(code0, ctx, indent, top_vars, true);

		switch (code) {
		case If(condition, then, elseExp, pos): {
			var vars = [];
			var cond_body = unfoldStatements(condition, ctx, indent, vars);
			sb.add(indent); sb.add("if (");
			sb.add(emitExpression(cond_body, ctx, TBool));
			sb.add(') {\n');
			ctx.popLocals(vars);

			var subindent = indent + '\t';
			emitStatement(then, ctx, rloc, subindent);
			sb.add(indent); sb.add("} else {\n");
			emitStatement(elseExp, ctx, rloc, subindent);
			sb.add(indent); sb.add("}\n");
		}
		case SimpleSwitch(e0, cases, p): {
			var vars = [];
			var expr_body = unfoldStatements(e0, ctx, indent, vars);

			var tmpvar = ctx.newLocalName('_tmp');
			sb.add(indent); sb.add('final Struct '); sb.add(tmpvar); sb.add(' = (Struct)');
			sb.add(emitExpression(expr_body, ctx, null));
			sb.add(';\n');
			ctx.popLocals(vars);

			sb.add(indent); sb.add("switch ("); sb.add(tmpvar); sb.add('.getTypeId()) {\n');

			var subindent = indent + '\t';
			var foundDefault = false;
			for (c in cases) {
				if (c.structname == "default") {
					foundDefault = true;
					sb.add(indent); sb.add('default: {\n');
				} else {
					var structDef = structs.get(c.structname);
					sb.add(indent); sb.add('case '); sb.add(structDef.id);
					sb.add('/*'); sb.add(c.structname); sb.add('*/: {\n');
				}
				emitStatement(c.body, ctx, rloc, subindent);
				if (!isReturn(rloc)) {
					sb.add(subindent); sb.add('break;\n');
				}
				sb.add(indent); sb.add('}\n');
			}
			if (!foundDefault) {
				sb.add(indent); sb.add('default:\n');
				sb.add(subindent);
				sb.add('throw new RuntimeException("Unexpected struct in switch: "+');
				sb.add(tmpvar); sb.add('.getTypeName());\n');
			}
			sb.add(indent); sb.add("}\n");
		}
		case Switch(e0, type, cases, p): {
			var vars = [];
			var expr_body = unfoldStatements(e0, ctx, indent, vars);

			var tmpvar = ctx.newLocalName('_tmp');
			sb.add(indent); sb.add('final Struct '); sb.add(tmpvar); sb.add(' = (Struct)');
			sb.add(emitExpression(expr_body, ctx, null));
			sb.add(';\n');
			ctx.popLocals(vars);

			sb.add(indent); sb.add("switch ("); sb.add(tmpvar); sb.add('.getTypeId()) {\n');

			var subindent = indent + '\t';
			var tmpvar2 = ctx.newLocalName('_tmp');

			var foundDefault = false;
			for (c in cases) {
				var cvars = [];
				if (c.structname == "default") {
					foundDefault = true;
					sb.add(indent); sb.add('default: {\n');
				} else {
					var structDef = structs.get(c.structname);
					sb.add(indent); sb.add('case '); sb.add(structDef.id);
					sb.add('/*'); sb.add(c.structname); sb.add('*/: {\n');

					var has_args = false;
					for (i in 0...c.args.length) {
						if (c.args[i] != '__' && (c.used_args == null || c.used_args[i])) {
							has_args = true;
							break;
						}
					}

					if (has_args) {
						sb.add(subindent); sb.add('final Struct_'); sb.add(c.structname);
						sb.add(' '); sb.add(tmpvar2); sb.add(' = (Struct_'); sb.add(c.structname);
						sb.add(')'); sb.add(tmpvar); sb.add(';\n');

						for (i in 0...c.args.length) {
							if (c.args[i] != '__' && (c.used_args == null || c.used_args[i])) {
								var aname = ctx.newLocalName(c.args[i]);
								var ty = structDef.args[i].type;
								sb.add(subindent); sb.add('final '); sb.add(flowType2fieldType(ty));
								sb.add(' '); sb.add(aname); sb.add(' = '); sb.add(tmpvar2);
								sb.add('.f_'); sb.add(structDef.args[i].name); sb.add(';\n');
								ctx.bindLocal(cvars, c.args[i], {
									name: aname, type: ty, is_final: true, is_obj: false
								});
							}
						}
					}
				}
				emitStatement(c.body, ctx, rloc, subindent);
				ctx.popLocals(cvars);
				if (!isReturn(rloc)) {
					sb.add(subindent); sb.add('break;\n');
				}
				sb.add(indent); sb.add('}\n');
			}
			if (!foundDefault) {
				sb.add(indent); sb.add('default:\n');
				sb.add(subindent);
				sb.add('throw new RuntimeException("Unexpected struct in switch: "+');
				sb.add(tmpvar); sb.add('.getTypeName());\n');
			}
			sb.add(indent); sb.add("}\n");
		}

		case SetRef(pointer, value, pos):
			var vars1 = [];
			var vtype = getPosType(FlowUtil.getPosition(value));
			var pointer_body = unfoldStatements(pointer, ctx, indent, vars1);
			var pointer_str = emitExpression(pointer_body, ctx, TReference(vtype));
			ctx.popLocals(vars1);

			var vars2 = [];
			var value_body = unfoldStatements(value, ctx, indent, vars2);
			var value_str = emitExpression(value_body, ctx, vtype);
			ctx.popLocals(vars2);

			sb.add(indent);
			sb.add(pointer_str);
			sb.add('.value = ');
			sb.add(value_str);
			sb.add(';\n');

			returnNull(ctx, indent, rloc);

		case SetMutable(pointer, field, value, pos):
			var ptype = getPosType(FlowUtil.getPosition(pointer));
			var stype = structTypeName(ptype);
			var sinfo = (stype != null) ? structs.get(stype) : null;
			var pftype = (sinfo != null) ? TName(stype,[]) : ptype;
			var vtype = getPosType(FlowUtil.getPosition(value));

			if (sinfo != null) {
				var arg = findArgByName(sinfo, field);
				if (arg == null)
					throw 'Struct '+stype+' has no field '+field+' at '+Prettyprint.position(pos);
				vtype = arg.type;
			}

			var vars1 = [];
			var pointer_body = unfoldStatements(pointer, ctx, indent, vars1);
			var pointer_str = emitExpression(pointer_body, ctx, pftype);
			ctx.popLocals(vars1);

			var vars2 = [];
			var value_body = unfoldStatements(value, ctx, indent, vars2);
			var value_str = emitExpression(value_body, ctx, vtype);
			ctx.popLocals(vars2);

			if (sinfo != null) {
				sb.add(indent); sb.add(pointer_str); sb.add('.f_'); sb.add(field);
				sb.add(STR_SPC_EQ_SPC); sb.add(value_str); sb.add(';\n');
			} else {
				requireAccessor(field);
				sb.add(indent); sb.add('((Field_'); sb.add(field); sb.add('<');
				sb.add(flowType2objType(vtype));
				sb.add('>)'); sb.add(pointer_str); sb.add(').set_'); sb.add(field);
				sb.add('('); sb.add(value_str); sb.add(');\n');
			}

			returnNull(ctx, indent, rloc);

		default: {
			var eexpr, etype;
			var emit = true;

			switch (rloc) {
				case IgnoreValue:
					eexpr = '';
					etype = null;
					if (isVoid(code))
						emit = false;
					else if (!isSafeStatement(code))
						eexpr = 'Object '+ctx.newLocalName('_unused')+STR_SPC_EQ_SPC;

				case LocalVar(name, type):
					etype = type;
					eexpr = name+STR_SPC_EQ_SPC;
				case Return(type):
					etype = type;
					eexpr = 'return ';

					if (ctx.can_tail_call != null && emitTailCall(code, ctx, type, indent))
						emit = false;
			}

			if (emit) {
				if (isLambda(code)) {
					emitClosure(code, ctx, eexpr, etype, indent);
				} else {
					sb.add(indent); sb.add(eexpr); sb.add(emitExpression(code, ctx, etype));
					sb.add(';\n');
				}
			}
		}
		}

		ctx.popLocals(top_vars);
	}

	private static function isReturn(rloc : JavaReturnLocation) : Bool {
		switch (rloc) {
			case Return(type):
				return true;
			default:
				return false;
		}
		return false;
	}

	private static function returnNull(ctx : JavaContext, indent : String, rloc : JavaReturnLocation) {
		var sb = ctx.sb;

		switch (rloc) {
			case IgnoreValue:
			case LocalVar(name, type):
				sb.add(indent); sb.add(name); sb.add(STR_SPC_EQ_SPC); sb.add('null;\n');
			case Return(type):
				sb.add(indent); sb.add('return null;\n');
		}
	}

	private static function isLambda(code : Flow) : Bool {
		switch (code) {
		case Lambda(arguments, type, body, _, pos):
			return true;
		default:
			return false;
		}
	}

	private function structTypeName(struct : FlowType) : String {
		if (struct == null)
			return null;
		switch (FlowUtil.untyvar(struct)) {
			case TStruct(structname, cargs, max):
				return structname;
			case TName(name, args):
				var info = structs.get(name);
				if (info != null && info.args.length > 0)
					return name;
				return null;
			case TUnion(min, max):
				var stype = null;
				if (max != null) {
					var first = true;
					for (m in max) {
						var mtype = structTypeName(m);
						stype = (first || stype == mtype) ? mtype : null;
						first = false;
					}
				}
				return stype;
			default:
				return null;
		}
	}

	private static function findArgByName(info : JavaStructInfo, name : String) {
		for (a in info.args)
			if (a.name == name)
				return a;
		return null;
	}

	private function emitTailCall(code : Flow, ctx : JavaContext, rtype : FlowType, indent : String) {
		var args, cpos;

		switch (code) {
			case Call(closure, arguments, pos): {
				args = arguments;
				cpos = pos;
				switch (closure) {
					case VarRef(name, pos):
						if (ctx.can_tail_call != name)
							return false;
					default:
						return false;
				}
			}
			default:
				return false;
		}

		var sb = ctx.sb;
		var subindent = indent+'\t';

		ctx.has_tail_call = true;

		sb.add(indent); sb.add('{\n');

		var avars = [];
		for (i in 0...ctx.arg_names.length) {
			switch (args[i]) {
				case VarRef(name, pos):
					if (name == ctx.arg_names[i]) {
						avars.push(null);
						continue;
					}
				default:
			}

			var vars = [];
			var expr_body = unfoldStatements(args[i], ctx, subindent, vars);
			var vname = ctx.newLocalName('__tmp');
			var vtype = flowType2fieldType(ctx.arg_types[i]);
			sb.add(subindent); sb.add('final '); sb.add(vtype); sb.add(' '); sb.add(vname);
			sb.add(' = '); sb.add(emitExpression(expr_body, ctx, ctx.arg_types[i]));
			sb.add(';\n');

			avars.push(vname);
		}

		for (i in 0...ctx.arg_names.length) {
			if (avars[i] == null)
				continue;

			sb.add(subindent); sb.add('a'+ctx.arg_names[i]); sb.add(' = ');
			sb.add(avars[i]); sb.add(';\n');
		}

		sb.add(subindent); sb.add('continue TAIL_CALL;\n');
		sb.add(indent); sb.add('}\n');

		return true;
	}

	private function emitClosure(code : Flow, ctx : JavaContext, rloc : String, rtype : FlowType, indent : String)
	{
		ctx.cur_indent = indent;

		var sb = ctx.sb;
		var subctx = emitFunction('invoke', code, null, null, ctx, indent+'\t');

		var pos = FlowUtil.getPosition(code);
		sb.add(indent); sb.add(rloc);
		var ftype = flowType2objType(getPosType(pos));
		if (rtype != null) {
			var rstype = flowType2objType(rtype);
			if (rstype != ftype) {
				sb.add(STR_LPAR); sb.add(rstype); sb.add(')(');
				sb.add(flowType2objType(rtype,true)); sb.add(STR_RPAR);
			}
		}
		sb.add('new '); sb.add(ftype);
		sb.add('() {\n');
		sb.add(subctx.sb.toString());
		sb.add(indent); sb.add('};\n');
	}

	private static var STR_QUOTE = '"';
	private static var STR_UNIPFX = '\\u';
	private static var STR_BSLASH = '\\\\';
	private static var STR_BSQUOTE = '\\"';
	private static var STR_BSN = '\\n';
	private static var STR_BST = '\\t';
	private static var STR_BSR = '\\r';
	private static var STR_BSNULL = '\\u0000';
	private static var STR_BSFF = '\\xff';
	private static var STR_LPAR = '(';
	private static var STR_LPAR2 = '((';
	private static var STR_RPAR = ')';
	private static var STR_RPAR2 = '))';
	private static var STR_LBRAC = '[';
	private static var STR_RBRAC = ']';
	private static var STR_DZERO = '.0';
	private static var STR_DOT = '.';
	private static var STR_E = 'e';
	private static var STR_EMPTY = '';
	private static var STR_CSPACE = ',';
	private static var STR_SPC_EQ_SPC = '=';
	private static var STR_SEMI_NL = ';\n';
	private static var STR_COLON = ':';
	private static var STR_SPC_QUEST_SPC = '?';
	private static var STR_SPC_COLON_SPC = ':';

	private function isVoid(code : Flow) : Bool {
		switch (code) {
		case ConstantVoid(pos):
			return true;
		default:
			return false;
		}
	}

	private function isSafeStatement(code : Flow) : Bool {
		switch (code) {
		case Call(closure, arguments, pos):
			return true;
		default:
			return false;
		}
	}

	private function wrapModule(name : String, module : JavaModuleFile) {
		if (module == cur_module)
			return name;

		var sb = new StringBuf();
		if (cur_module != null) {
			sb.add('runtime.');
		}
		if (module != null) {
			sb.add('m_'); sb.add(module.id); sb.add('.');
		}
		sb.add(name);

		return sb.toString();
	}

	private function emitExpression(code : Flow, ctx : JavaContext, type : FlowType) : String {
		var buf = new StringBuf();
		var rtype = null;

		switch (code) {
		case ConstantVoid(pos):
			return 'null';
		case ConstantBool(value, pos):
			rtype = TBool;
			buf.add(value);
		case ConstantI32(value, pos):
			rtype = TInt;
			if (value < 0) {
				buf.add(STR_LPAR);
				buf.add(value);
				buf.add(STR_RPAR);
			} else {
				buf.add(value);
			}
		case ConstantDouble(value, pos):
			rtype = TDouble;
			if (value == Math.NEGATIVE_INFINITY) {
				return "Double.NEGATIVE_INFINITY";
			} else if (value == Math.POSITIVE_INFINITY) {
				return "Double.POSITIVE_INFINITY";
			} else if (Math.isNaN(value)) {
				return "Double.NaN";
			} else {
				var s = '' + value;
				// -- is no good
				var dot = (s.indexOf(STR_DOT) < 0 && s.indexOf(STR_E) < 0);
				if (s.charCodeAt(0) == '-'.code) {
					buf.add(STR_LPAR);
					buf.add(s);
					if (dot) buf.add(STR_DZERO);
					buf.add(STR_RPAR);
				} else {
					buf.add(s);
					if (dot) buf.add(STR_DZERO);
				}
			}
		case ConstantString(value, pos):
			rtype = TString;
			try {
				buf.add(STR_QUOTE);
				if (HaxeRuntime.wideStringSafe(value)) {
					for (i in 0...value.length) {
						var c = value.charCodeAt(i);
						switch (c) {
						case '\\'.code: buf.add(STR_BSLASH);
						case '\"'.code: buf.add(STR_BSQUOTE);
						case '\n'.code: buf.add(STR_BSN);
						case '\t'.code: buf.add(STR_BST);
						case '\r'.code: buf.add(STR_BSR);
						case 0x00:      buf.add(STR_BSNULL);
						case 0xff:      buf.add(STR_BSFF);
						default:
						#if neko
							buf.addChar(c);
						#else
							buf.add(value.charAt(i));
						#end
						}
					}
				} else {
					#if neko
						haxe.Utf8.iter(value, function(c : Int) {
							if (c <= 0x7f) {
								buf.addChar(c);
							} else {
								buf.add(STR_UNIPFX);
								buf.add(StringTools.hex(c, 4));
							}
						});
					#else
						for (i in 0...value.length) {
							var c = value.charCodeAt(i);
							if (c <= 0x7f) {
								buf.add(value.charAt(i));
							} else {
								buf.add(STR_UNIPFX);
								buf.add(StringTools.hex(c, 4));
							}
						}
					#end
				}
				buf.add(STR_QUOTE);
			} catch (e : Dynamic) {
				Errors.report(Prettyprint.position(pos) + ': Error generating JS for string constant.');
				throw e;
			}
		case ConstantArray(value, pos):
			rtype = TArray(null);
			if (value.length == 0) {
				buf.add(wrapModule('arr_empty',null));
			} else {
				buf.add('(new Object[] { ');
				var sep = STR_EMPTY;
				for (v in value) {
					buf.add(sep);
					buf.add(emitExpression(v, ctx, null));
					sep = STR_CSPACE;
				}
				buf.add(' })');
			}
		case ConstantStruct(name, values, pos):
			rtype = TName(name,[]);
			var structDef = structs.get(name);
			if (values.length == 0) {
				buf.add(wrapModule('str_'+name,null));
			} else {
				buf.add('(new Struct_'); buf.add(name); buf.add('(');
				var sep = STR_EMPTY;
				for (i in 0...values.length) {
					buf.add(sep);
					buf.add(emitExpression(values[i], ctx, structDef.args[i].type));
					sep = STR_CSPACE;
				}
				buf.add(STR_RPAR2);
			}
		case Sequence(statements, pos):
			if (statements.length != 1) {
				trace(code);
				throw "unexpected Sequence in expression at "+Prettyprint.position(pos);
			}
			return emitExpression(statements[0], ctx, type);
		case VarRef(name, pos): {
			var local = resolveLocal(ctx, name);
			if (local != null)
				return wrapCast(local.name, local.type, type, local.is_obj);

			var global = globals.get(name);
			if (global != null) {
				return wrapCast(wrapModule(global.name, global.module), global.type, type);
			}

			var gfunc = globalFuncs.get(name);
			if (gfunc != null) {
				emitClosureWrapper('gfw_'+name, gfunc.name, gfunc.type, gfunc.module);
				globals.set(name, { name: 'gfw_'+name, type: gfunc.type, module: null });
				return wrapCast('runtime.gfw_'+name, gfunc.type, type);
			}

			var structDef = structs.get(name);
			if (structDef != null && structDef.args.length == 0)
				return wrapCast(wrapModule('str_'+name,null), TName(name,[]), type);

			return "$UNKNOWN_NAME_"+name+"$";
		}
		case Call(closure, arguments, pos):
			var global = null;
			switch (closure) {
				case VarRef(n, p): {
					var s = structs.get(n);
					if (s != null)
						return emitExpression(ConstantStruct(n, arguments, pos), ctx, type);
					global = globalFuncs.get(n);
				}
				default:
			};
			var ftype;
			if (global != null) {
				ftype = global.type;
				buf.add(wrapModule(global.name, global.module));
				buf.add(STR_LPAR);
			} else {
				ftype = getPosType(FlowUtil.getPosition(closure));
				buf.add(emitExpression(closure, ctx, ftype));
				buf.add('.invoke(');
			}
			if (ftype == null) trace(code);
			var ftypeinfo = splitFunctionType(ftype);
			rtype = ftypeinfo.ret;
			var sep = STR_EMPTY;
			for (i in 0...arguments.length) {
				buf.add(sep);
				buf.add(emitExpression(arguments[i], ctx, ftypeinfo.args[i]));
				sep = STR_CSPACE;
			}
			buf.add(STR_RPAR);
		case RefTo(value, pos):
			var vtype = getPosType(FlowUtil.getPosition(value));
			rtype = TReference(vtype);
			buf.add('(new Reference<');
			buf.add(flowType2objType(vtype));
			buf.add('>(');
			buf.add(emitExpression(value, ctx, vtype));
			buf.add('))');
		case Deref(pointer, pos):
			rtype = getPosType(pos);
			buf.add(emitExpression(pointer, ctx, TReference(rtype)));
			buf.add('.value');
		case ArrayGet(array, index, pos):
			rtype = type;
			buf.add('((');
			buf.add(flowType2objType(type==null?getPosType(pos):type));
			buf.add(')(');
			buf.add(emitExpression(array, ctx, TArray(null)));
			buf.add('[');
			buf.add(emitExpression(index, ctx, TInt));
			buf.add(']))');
		case Field(pointer, field, pos):
			var ptype = getPosType(FlowUtil.getPosition(pointer));
			var stype = structTypeName(ptype);
			var sinfo = (stype != null) ? structs.get(stype) : null;
			var pftype = (sinfo != null) ? TName(stype,[]) : ptype;
			var vtype = getPosType(pos);

			if (field == 'structname') {
				vtype = TString;
			} else if (sinfo != null) {
				var arg = findArgByName(sinfo, field);
				if (arg == null)
					throw 'Struct '+stype+' has no field '+field+' at '+Prettyprint.position(pos);
				vtype = arg.type;
			}

			var pointer_str = emitExpression(pointer, ctx, pftype);

			rtype = vtype;

			if (field == 'structname') {
				buf.add('((Struct)');
				buf.add(pointer_str); buf.add(').getTypeName()');
			} else if (sinfo != null) {
				buf.add(pointer_str); buf.add('.f_'); buf.add(field);
			} else {
				requireAccessor(field);
				buf.add('((Field_'); buf.add(field); buf.add('<');
				buf.add(flowType2objType(vtype));
				buf.add('>)'); buf.add(pointer_str); buf.add(').get_'); buf.add(field);
				buf.add('()');
			}
		case If(condition, then, elseExp, pos):
			rtype = type;
			buf.add(STR_LPAR);
			buf.add(emitExpression(condition, ctx, TBool));
			buf.add(STR_SPC_QUEST_SPC);
			buf.add(emitExpression(then, ctx, type));
			buf.add(STR_SPC_COLON_SPC);
			buf.add(emitExpression(elseExp, ctx, type));
			buf.add(STR_RPAR);
		case Cast(value, fromtype, totype, pos):
			rtype = totype;
			var v = emitExpression(value, ctx, fromtype);
			buf.add(switch (fromtype) {
			case TInt:
				switch (totype) {
				case TInt: v;
				case TDouble: "((double)" + v + ")";
				case TString: "Integer.toString(" +v + ")";
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TDouble:
				switch (totype) {
				case TInt: "((int)" + v + ")";
				case TDouble: v;
				case TString: "FlowRuntime.doubleToString(" +v + ")";
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TName(n1, args1):
				switch (totype) {
				case TName(n2, args2):
					wrapCast(v, fromtype, totype);
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TFlow: {
				wrapCast(v, fromtype, totype);
			}
			case TBoundTyvar(__): {
				// ? -> something
				wrapCast(v, fromtype, totype);
			}
			case TArray(fa): {
				switch (totype) {
					case TArray(ta): {
						switch (fa) {
							case TName(n1, args1):
								switch (ta) {
								// Array of named types are OK 
								case TName(n2, args2): wrapCast(v, fromtype, totype);
								default: throw "Not implemented: " + Prettyprint.print(code);
							}
							default: throw "Not implemented: " + Prettyprint.print(code);
						}
					}
					default: throw "Not implemented: " + Prettyprint.print(code);
				}
			}
			default: {
				throw "Not implemented: " + Prettyprint.print(value) + " " + fromtype;
			}
			});
		case And(e1, e2, pos):
			rtype = TBool;
			buf.add(STR_LPAR);
			buf.add(emitExpression(e1, ctx, TBool));
			buf.add('&&');
			buf.add(emitExpression(e2, ctx, TBool));
			buf.add(STR_RPAR);
		case Or(e1, e2, pos):
			rtype = TBool;
			buf.add(STR_LPAR);
			buf.add(emitExpression(e1, ctx, TBool));
			buf.add('||');
			buf.add(emitExpression(e2, ctx, TBool));
			buf.add(STR_RPAR);
		case Negate(e1, pos):
			var ptype = getPosType(pos);
			if (ptype == TInt || ptype == TDouble) {
				rtype = ptype;
				buf.add('(-');
				buf.add(emitExpression(e1, ctx, ptype));
				buf.add(STR_RPAR);
			} else {
				buf.add('FlowRuntime.negate(');
				buf.add(emitExpression(e1, ctx, null));
				buf.add(STR_RPAR);
			}
		case Not(e1, pos):
			rtype = TBool;
			buf.add('!');
			buf.add(emitExpression(e1, ctx, TBool));
		case Plus(e1, e2, pos): return arith('+', 'FlowRuntime.add', e1, e2, ctx, type, pos);
		case Minus(e1, e2, pos): return arith('-', 'FlowRuntime.sub', e1, e2, ctx, type, pos);
		case Multiply(e1, e2, pos): return arith('*', 'FlowRuntime.mul', e1, e2, ctx, type, pos);
		case Divide(e1, e2, pos): return arith('/', 'FlowRuntime.div', e1, e2, ctx, type, pos);
		case Modulo(e1, e2, pos): return arith('%', 'FlowRuntime.mod', e1, e2, ctx, type, pos);
		case Equal(e1, e2, pos): return compare('==', e1, e2, ctx, type, pos);
		case NotEqual(e1, e2, pos): return compare('!=', e1, e2, ctx, type, pos);
		case LessThan(e1, e2, pos): return compare('<', e1, e2, ctx, type, pos);
		case LessEqual(e1, e2, pos): return compare('<=', e1, e2, ctx, type, pos);
		case GreaterThan(e1, e2, pos): return compare('>', e1, e2, ctx, type, pos);
		case GreaterEqual(e1, e2, pos): return compare('>=', e1, e2, ctx, type, pos);
		default:
			return "$$$/*"+Prettyprint.prettyprint(code)+"*/";
		}

		return wrapCast(buf.toString(), rtype, type);
	}

	private function wrapCast(expr : String, srct : FlowType, dstt : FlowType, ?obj : Bool = false) {
		if (dstt == null)
			return expr;

		var fn = obj ? flowType2objType : flowType2fieldType;
		var dsts = fn(dstt);
		var srcs = srct == null ? 'Object' : fn(srct);
		if (dsts != srcs && dsts != 'Object') {
			var sb = new StringBuf();
			sb.add(STR_LPAR2);
			sb.add(dsts);
			var dsts2 = fn(dstt,true);
			if (dsts2 != dsts) {
				sb.add(')(');
				sb.add(dsts2);
			}
			sb.add(STR_RPAR);
			sb.add(expr);
			sb.add(STR_RPAR);
			return sb.toString();
		}

		return expr;
	}

	private function arith(op : String, fn : String, e1 : Flow, e2 : Flow, ctx : JavaContext, type : FlowType, pos : Position) : String {
		var buf = new StringBuf();
		var rtype = null;

		var ptype = getPosType(pos);
		if (ptype == TInt || ptype == TDouble || (ptype == TString && op == '+')) {
			rtype = ptype;
			buf.add(STR_LPAR);
			buf.add(emitExpression(e1, ctx, ptype));
			buf.add(op);
			buf.add(emitExpression(e2, ctx, ptype));
			buf.add(STR_RPAR);
		} else {
			buf.add(fn);
			buf.add(STR_LPAR);
			buf.add(emitExpression(e1, ctx, null));
			buf.add(STR_CSPACE);
			buf.add(emitExpression(e2, ctx, null));
			buf.add(STR_RPAR);
		}

		return wrapCast(buf.toString(), rtype, type);
	}

	private function compare(cmp : String, e1 : Flow, e2 : Flow, ctx : JavaContext, type : FlowType, pos : Position) : String {
		var buf = new StringBuf();
		buf.add(STR_LPAR);
		var ptype = getPosType2(pos);
		if (ptype == TInt || ptype == TDouble) {
			var ts = flowType2fieldType(ptype);
			buf.add(STR_LPAR2); buf.add(ts); buf.add(STR_RPAR);
			buf.add(emitExpression(e1, ctx, ptype));
			buf.add(STR_RPAR);
			buf.add(cmp);
			buf.add(STR_LPAR2); buf.add(ts); buf.add(STR_RPAR);
			buf.add(emitExpression(e2, ctx, ptype));
			buf.add(STR_RPAR);
		} else if (ptype == TString && (cmp == '==' || cmp == '!=')) {
			if (cmp == '!=')
				buf.add('!');
			buf.add(emitExpression(e1, ctx, ptype));
			buf.add('.equals(');
			buf.add(emitExpression(e2, ctx, ptype));
			buf.add(STR_RPAR);
		} else if (ptype == TString) {
			buf.add(emitExpression(e1, ctx, ptype));
			buf.add('.compareTo(');
			buf.add(emitExpression(e2, ctx, ptype));
			buf.add(STR_RPAR);
			buf.add(cmp);
			buf.add('0');
		} else {
			buf.add('FlowRuntime.compareByValue(');
			buf.add(emitExpression(e1, ctx, null));
			buf.add(STR_CSPACE);
			buf.add(emitExpression(e2, ctx, null));
			buf.add(STR_RPAR);
			buf.add(cmp);
			buf.add('0');
		}
		buf.add(STR_RPAR);
		return buf.toString();
	}

	private function resolveLocal(ctx : JavaContext, name : String) {
		var info = ctx.locals.get(name);
		if (info != null)
			return info;

		if (ctx.parent_ctx != null) {
			var pctx = ctx.parent_ctx;
			info = resolveLocal(pctx, name);

			if (info != null && !info.is_final) {
				var lname = pctx.newLocalName(name);

				pctx.sb.add(pctx.cur_indent); pctx.sb.add('final ');
				pctx.sb.add(flowType2fieldType(info.type));
				pctx.sb.add(' '); pctx.sb.add(lname);
				pctx.sb.add(' = '); pctx.sb.add(info.name); pctx.sb.add(';\n');

				info = { name: lname, type: info.type, is_obj: false, is_final: true };
				ctx.locals.set(name, info);
			}
		}

		return info;
	}

	private inline static function getPosType(pos : Position) {
		return pos == null ? null : FlowUtil.untyvar(pos.type);
	}
	private inline static function getPosType2(pos : Position) {
		return pos == null ? null : FlowUtil.untyvar(pos.type2);
	}
}

typedef BindingInfo = { name: String, value: Flow, pos : Position };

class JavaStatementTransform {
	private var ctx : JavaContext;

	public function new(ctx : JavaContext) {
		this.ctx = ctx;
	}

	public function transform(code : Flow) : Flow {
		var binds = [];
		var rv = recurse(code, binds);

		if (rv != code && binds.length == 0)
			throw "result changed without binds";

		var l = binds.length;
		var pos = FlowUtil.getPosition(rv);

		for (i in 0...l) {
			var info = binds[l-1-i];
			info.pos.type = pos.type;
			rv = Let(info.name, null, info.value, rv, info.pos);
		}

		return rv;
	}

	public static function isStatement(code : Flow, ?if_stmt : Bool = false) : Bool {
		switch (code) {
		case Sequence(statements, pos):
			return statements.length != 1;
		case Let(name, sigma, value, scope, pos):
			return true;
		case Lambda(arguments, type, body, _, pos):
			return true;
		case Switch(e0, type, cases, p):
			return true;
		case SimpleSwitch(e0, cases, p):
			return true;
		case SetRef(pointer, value, pos):
			return true;
		case SetMutable(pointer, field, value, pos):
			return true;
		case If(e0, e1, e2, pos):
			return if_stmt;
		default:
			return false;
		}
	}

	public static function isAtomic(code : Flow) : Bool {
		switch (code) {
		case ConstantVoid(_), ConstantBool(_, _), ConstantI32(_, _),
		     ConstantDouble(_, _), ConstantString(_, _), VarRef(_, _):
			return true;
		default:
			return false;
		}
	}

	private function rebind(code : Flow, binds : Array<BindingInfo>) : Flow {
		var pos = FlowUtil.getPosition(code);
		var newpos = PositionUtil.copy(pos);
		newpos.type2 = pos.type;

		var name = '$'+ctx.local_id++;
		binds.push({ name:name, value:code, pos:newpos });
		return VarRef(name, pos);
	}

	private function recurseArgs(args : Array<Flow>, binds : Array<BindingInfo>) : Bool {
		var changed = false;
		var last_pos = 0;

		for (i in 0...args.length) {
			var sub_binds = [];
			var arv = recurse(args[i], sub_binds);

			if (sub_binds.length > 0) {
				changed = true;
				// Flush previous nodes to preserve evaluation order
				for (j in last_pos...i) {
					if (!isAtomic(args[j]))
						args[j] = rebind(args[j], binds);
				}
				// Commit the new bindings
				for (b in sub_binds)
					binds.push(b);
				last_pos = i+1;
			} else if (arv != args[i]) {
				changed = true;
			}

			args[i] = arv;
		}

		return changed;
	}

	  // Map in pre-order
	private function recurse(e : Flow, binds : Array<BindingInfo>) : Flow {
		if (isStatement(e))
			return rebind(e, binds);

		return switch (e) {
			case ConstantVoid(pos): e;
			case ConstantString(value, pos): e;
			case ConstantDouble(value, pos): e;
			case ConstantBool(value, pos): e;
			case ConstantI32(value, pos): e;
			case ConstantNative(value, pos): e;
			case VarRef(name, pos): e;
			// statement except in a degenerate case
			case Sequence(statements, pos):
				if (statements.length != 1) throw 'invalid';
				return recurse(statements[0], binds);
			// unexpected values
			case Lambda(_, _, _, _, _), Switch(_, _, _, _), SimpleSwitch(_, _, _),
			     SetRef(_, _, _), SetMutable(_, _, _, _), Let(_, _, _, _, _),
			     Native(_, _, _, _, _, _), NativeClosure(_, _, _), StackSlot(_, _, _),
			     Pointer(_, _), Closure(_, _, _), SyntaxError(_, _):
				throw 'invalid';
			// expressions
			case ConstantArray(values, pos): {
				var a = values.copy();
				if (!recurseArgs(a, binds)) e else Flow.ConstantArray(a, pos);
			}
			case ConstantStruct(name, args, pos): {
				var a = args.copy();
				if (!recurseArgs(a, binds)) e else Flow.ConstantStruct(name, a, pos);
			}
			case ArrayGet(array, index, pos): {
				var a = [array, index];
				if (!recurseArgs(a, binds)) e else Flow.ArrayGet(a[0], a[1], pos);
			}
			case Field(call, name, pos): {
				var c = recurse(call, binds);
				if (c == call) e else Field(c, name, pos);
			}
			case RefTo(value, pos): {
				var v = recurse(value, binds);
				if (v == value) e else RefTo(v, pos);
			}
			case Deref(pointer, pos): {
				var p = recurse(pointer, binds);
				if (p == pointer) e else Deref(p, pos);
			}
			case Cast(value, fromtype, totype, pos): {
				var v = recurse(value, binds);
				if (v == value) e else Cast(v, fromtype, totype, pos);
			}
			case Call(e0, es, pos): {
				var a = es.copy();
				a.push(e0);
				if (!recurseArgs(a, binds)) e else {
					var e00 = a.pop();
					Call(e00, a, pos);
				}
			}
			case If(e0, e1, e2, pos): {
				var e0b = recurse(e0, binds);
				var sbb = [];
				var e1b = recurse(e1, sbb);
				var e2b = recurse(e2, sbb);
				if (e1b != e1 || e2b != e2 || sbb.length > 0)
					rebind(If(e0b, e1, e2, pos), binds)
				else if (e0b == e0)
					e
				else
					Flow.If(e0b, e1, e2, pos);
			}
			case Not(e0, pos): {
				var e00 = recurse(e0, binds);
				if (e00 == e0) e else Not(e00, pos);
			}
			case Negate(e0, pos): {
				var e00 = recurse(e0, binds);
				if (e00 == e0) e else Negate(e00, pos);
			}
			case Multiply(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.Multiply(a[0], a[1], pos);
			}
			case Divide(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.Divide(a[0], a[1], pos);
			}
			case Modulo(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.Modulo(a[0], a[1], pos);
			}
			case Plus(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.Plus(a[0], a[1], pos);
			}
			case Minus(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.Minus(a[0], a[1], pos);
			}
			case Equal(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.Equal(a[0], a[1], pos);
			}
			case NotEqual(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.NotEqual(a[0], a[1], pos);
			}
			case LessThan(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.LessThan(a[0], a[1], pos);
			}
			case LessEqual(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.LessEqual(a[0], a[1], pos);
			}
			case GreaterThan(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.GreaterThan(a[0], a[1], pos);
			}
			case GreaterEqual(e1, e2, pos): {
				var a = [e1, e2];
				if (!recurseArgs(a, binds)) e else Flow.GreaterEqual(a[0], a[1], pos);
			}
			case And(e1, e2, pos): {
				var e1b = recurse(e1, binds);
				var sbb = [];
				var e2b = recurse(e2, sbb);
				if (e2b != e2 || sbb.length > 0)
					rebind(Flow.If(e1b, e2, ConstantBool(false,pos), pos), binds)
				else if (e1b == e1)
					e
				else
					Flow.And(e1b, e2, pos);
			}
			case Or(e1, e2, pos): {
				var e1b = recurse(e1, binds);
				var sbb = [];
				var e2b = recurse(e2, sbb);
				if (e2b != e2 || sbb.length > 0)
					rebind(Flow.If(e1b, ConstantBool(true,pos), e2, pos), binds)
				else if (e1b == e1)
					e
				else
					Flow.Or(e1b, e2, pos);
			}
		};
	}
}
