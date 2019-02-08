import Flow;
import HaxeWriter;
import sys.io.File;
import sys.FileSystem;

class JsOverlayGroup {
	public var debug : Bool;

	var js_target : String;
	var baseName : String;

	public var isOverlay : Bool;
	public var noverlays : Int;
	public var reportSizes : Bool;
	public var nativeClasses : Map<String, Bool>;

	public var nglobals : Int;
	public var renamings : Map<String, String>;
	public var mainGlobals : Map<String, Bool>;
	public var nfields : Int;
	public var fieldRenamings : Map<String, String>;

	public var nstructs : Int;
	public var nMainStructs : Int;
	public var structs : Map<String, Struct>;

	private var fontconfig : {urls: Array<String>, styles: Dynamic};

	private var flowJSProgramHaxeFile : String;
	private var flowNativesJSFile : String;
	private var flowJSFile : String;

	public function new(debug : Bool, js_target : String, reportSizes : Bool) {
		this.debug = debug;
		this.js_target = js_target;
		this.reportSizes = reportSizes;

		baseName = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(js_target));
		baseName = (baseName.charAt(0).toUpperCase()) + baseName.substr(1);

		flowJSProgramHaxeFile = baseName + "FlowJsProgram.hx";
		flowNativesJSFile = baseName + "flownatives.js";
		flowJSFile = baseName + "FlowJs.js";

		isOverlay = false;
		noverlays = 0;
		nativeClasses = new Map();

		nglobals = 0;
		renamings = new Map();
		mainGlobals = new Map();
		nfields = 0;
		fieldRenamings = new Map();

		nstructs = nMainStructs = 0;
		structs = new Map();
	}

	private function deleteTempFile(name : String) {
		if (!debug) {
			try {
				FileSystem.deleteFile(name);
			} catch (e : Dynamic) {
				Errors.report("Internal error: failed to delete " + name);
			}
		}
	}

	public function compileMain(p : Program) {
		if (isOverlay)
			throw "Trying to compile second main js file";

		var output = File.write(flowJSFile, true);
		var hw = new JsWriter(p, debug, baseName, output, this);
		output.close();

		isOverlay = true;
		nMainStructs = nstructs;
	}

	public function compileOverlay(p : Program, ovl_js_target : String) {
		if (!isOverlay)
			throw "Trying to compile overlay without main js file";

		var output = File.write(ovl_js_target, true);
		var hw = new JsWriter(p, debug, baseName, output, this);
		output.close();

		noverlays++;
	}

	public function link(extra_args : Array<String>) {
		var o2 = File.write(flowJSProgramHaxeFile, true);

		o2.writeString("import HaxeRuntime;\n");
		for (k in nativeClasses.keys()) {
			o2.writeString("import " + k + ";\n");
		}

		o2.writeString("class "+baseName+"FlowJsProgram {
	static public var globals__ = {
		HaxeRuntime._structnames_ = new haxe.ds.IntMap();
		HaxeRuntime._structids_ = new haxe.ds.StringMap();
		HaxeRuntime._structargs_ = new haxe.ds.IntMap();
		HaxeRuntime._structargtypes_ = new haxe.ds.IntMap();
");

		if (nativeClasses.exists("RenderSupportHx")) {
			o2.writeString("\t\tnew RenderSupportHx();\n");
		}

		o2.writeString("\t}\n}\n");
		o2.close();

		Profiler.get().profileStart("Compile haXe");

		var args = ["-js", flowNativesJSFile, flowJSProgramHaxeFile, "-D", "jsruntime", "-cp", "src", "-lib", "pixijs", "-D", "js-classic"];
		for (a in extra_args)
			args.push(a);

		Sys.command("haxe", args);

		Profiler.get().profileEnd("Compile haXe");

		var result = File.getContent(flowNativesJSFile) + "\n" + File.getContent(flowJSFile);
		var output3 = File.write(js_target, false);
		output3.writeString(result);
		output3.close();

		deleteTempFiles();
	}

	private function deleteTempFiles() {
		deleteTempFile(flowNativesJSFile);
		deleteTempFile(flowJSFile);
		deleteTempFile(flowJSProgramHaxeFile);
	}
}

class JsWriter {
	public function new(p : Program, debug : Bool, basename : String, o : haxe.io.Output, ovl : JsOverlayGroup)  {
		Profiler.get().profileStart("Js export");
		this.p = p;
		this.o = o;
		this.ovl = ovl;
		this.debug = debug;

		if (debug) {
			this.indent_inc1 = ' ';
			this.indent_inc2 = '  ';
			this.indent_inc4 = '    ';
		} else {
			this.indent_inc1 = this.indent_inc2 = this.indent_inc4 = '';
		}

		//
		// First, build a map of reserved keywords that we have to rename
		//
		fieldRenamings = ovl.fieldRenamings;
		renamings = ovl.renamings;
		if (ovl.isOverlay)
			renamings = FlowUtil.copyhash(renamings);

		keywords = new Map();
		// https://developer.mozilla.org/en/JavaScript/Reference/Reserved_Words
		var reserved = [ 
			"break", "case", "catch", "continue", "debugger", "default", "delete", 
			"do", "else", "finally", "for", "function", "if", "in", "instanceof", "new", "return", 
			"switch", "this", "throw", "try", "typeof", "var", "void", "while", "with",

			"class", "const", "enum", "export", "extends", "import", "super", "implements", 
			"interface", "let", "null", "package", "private", "protected", "public", "static", "yield",
		];
		for (r in reserved) {
			keywords.set(r, true);
			if (debug)
				fieldRenamings.set(r, r + "__");
		}

		var reserved2 = [ 
			"arguments",

			// Built in methods on functions
			"arity", "caller", "constructor", "length", "name",

			// Built in name of a library
			"js", 

			// Names that google closure compiler does not like
			"char", "byte",

			// And some of our shortcuts
			"OTC", "CMP"
		];
		for (r in reserved2) {
			if (debug)
				keywords.set(r, true);
		}

		// In release build instead of renaming some fields, we obfuscate them all

		if (!debug && !ovl.isOverlay) {
			// This list of fields is guaranteed to get single-letter names:
			var common = [
				'value', 'first', 'second', 'third', 'fourth',
				'key', 'form',  'x', 'y', 'width', 'height',
				'style', 'name', 'color', 'text', 'size',
				'left', 'right', 'top', 'bottom', 'widthHeight',
				'alpha', 'layers', 'path', 'op', 'args',
				'id', 'type', 'a', 'b', 'l', 'r', 'v', 'f', 'fn'
			];
			for (name in common)
				fieldRenamings.set(name, formatIdSmall(ovl.nfields++));

			// These are used by natives and must not be obfuscated:
			var native = [
				'head', 'tail' // List
			];
			for (name in native)
				fieldRenamings.set(name, name);
		}

		//	Next, prepare the native function renames, and keep track of which native classes are references
	
		renameNatives = new Map();

		var rename_global;
		if (debug) {
			var pfix = ovl.isOverlay ? '$o'+ovl.noverlays+'_' : '';
			rename_global = function(name : String) {
				// in order to avoind names collistion we prefix all names with common prefix
				// we don't use true namespace because of possible performance drops and general complexitivenes of the implementation
				var r = 'A9__' + pfix+name;
				return keywords.exists(r) ? r+'__' : r;
			}
		} else {
			rename_global = function(name : String) {
				return formatId('$', ovl.nglobals++);
			}
		}

		for (d in p.declsOrder) {
			if (!ovl.mainGlobals.exists(d)) {
				renamings.set(d, rename_global(d));
				if (!ovl.isOverlay && d != 'main')
					ovl.mainGlobals.set(d, true);
			}
		}

		for (d in p.topdecs.keys()) {
			var c = p.topdecs.get(d);
			if (c != null) // It may be with DCE
			{
				switch(c) {
					case Native(name, io, args, result, defbody, pos):
						// Must call so that the natives are included in build
						var renamed = mangleNativeName(name);
						if (defbody == null && debug)
							renameNatives.set(d, renamed);
					default:
				}
				if (!renamings.exists(d))
					renamings.set(d, rename_global(d));
			}
		}
		
		// Next, number the structs
		structs = ovl.structs;
		
		// We do this in alphabetical order in order to avoid random changes in the code just because 
		// of hash ordering differences
		structsOrder = [];
		for (d in p.userTypeDeclarations) {
			switch (d.type.type) {
			case TStruct(structname, cargs, max):
				structsOrder.push({ name: structname, args : cargs});
			default:
			}
		}
		structsOrder.sort(function(s1, s2) {
			return if (s1.name < s2.name) -1 else if (s1.name == s2.name) 0 else 1;
		});

		for (s in structsOrder) {
			var def = structs.get(s.name);
			if (def == null) {
				structs.set(s.name, def = { id : ovl.nstructs++, structname : s.name, args : s.args});
			}
			renameNatives.set(s.name, "{_id:" + def.id + "}");
			if (!debug) {
				for (arg in s.args)
					if (!fieldRenamings.exists(arg.name))
						fieldRenamings.set(arg.name, formatIdSmall(ovl.nfields++));
			}
		}
		export(basename);
	}
	
	private function mangleNativeName(name : String) {
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
						|| cl == "Thread"
						|| cl == "NotificationsSupport"
						|| cl == "GeolocationSupport"
						|| cl == "ServiceWorkerCache"
						|| cl == "WebSocketSupport") { "Hx"; } else "";
		ovl.nativeClasses.set(cla, true);
		var renamed = cla + "." + parts[1];
		if (renamed == "NativeHx.length") {
			renamed = "NativeHx.length__";
		}
		return renamed;
	}

	var p : Program;
	var debug : Bool;
	var indent_inc1 : String;
	var indent_inc2 : String;
	var indent_inc4 : String;
	var o : haxe.io.Output; // For the JS file
	var ovl : JsOverlayGroup;
	var renamings : Map<String, String>;
	var localRenamings : Map<String, String>;
	var nextLocalVarId : Int;
	var renameNatives : Map<String, String>;
	var fieldRenamings : Map<String, String>;
	var keywords : Map<String, Bool>;
	var structs : Map<String, Struct>;
	var structsOrder : Array<{ name : String, args : FlowArray<MonoTypeDeclaration>}>;

	inline function wr(s : String) {
		o.writeString(s);
	}

	private function flowType2RTString(type : FlowType) : String {
		switch (type) {
			case TVoid: return "RuntimeType.RTVoid";
			case TBool: return "RuntimeType.RTBool";
			case TInt:  return "RuntimeType.RTInt";
			case TDouble: return "RuntimeType.RTDouble";
			case TString: return "RuntimeType.RTString";
			case TArray(at): {
					#if typepos
						return "RuntimeType.RTArray(" + flowType2RTString(at.val) + ")";
					#else
						return "RuntimeType.RTArray(" + flowType2RTString(at) + ")";
					#end
			}
			case TStruct(name, args, max): return "RuntimeType.RTStruct(" + name + ")";
			case TReference(t): return "RuntimeType.RTRefTo(" + flowType2RTString(t) + ")";
			default: return "RuntimeType.RTUnknown";
		};
	}
	
	public function export(basename : String) : Void {
		// Main sets up all the structs
		wr("(function() {\n");
		wr("\tvar S = HaxeRuntime.initStruct;\n");

		var typevars = new Map();
		var nextTypeId = 0;
		for (s in structsOrder) {
			var st = structs.get(s.name);
			var id = st.id;
			if (id < ovl.nMainStructs)
				continue;

			var l = new StringBuf();
			l.add('\tS('); l.add(id); l.add(',"'); l.add(s.name); l.add('",[');

			var sep = "";
			for (a in st.args) {
				l.add(sep); l.add('"'); l.add(renameFieldId(a.name)); l.add('"');
				sep = ",";
			}

			l.add('],[');

			sep = "";
			for (a in st.args) {
				var tn = flowType2RTString(a.type);
				var tv = typevars.get(tn);
				if (tv == null) {
					typevars.set(tn, tv = 't'+(nextTypeId++));
					wr("\tvar "+tv+" = "+tn+";\n");
				}
				l.add(sep); l.add(tv);
				sep = ",";
			}

			l.add(']);\n');

			wr(l.toString());
		}
		
		wr('}());\n');

		// A couple of needed functions to implement references

		// Write OptimizeTailCall 
		if (!ovl.isOverlay) {
			wr("var CMP = HaxeRuntime.compareByValue;
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
}\n");
		}

		var sizes = new Map();

		// Errors.print(Std.string(neko.vm.Gc.stats()));
		// Generate all functions and values
		for (d in p.declsOrder) {
			if (ovl.isOverlay && ovl.mainGlobals.exists(d))
				continue;
			var name = renameId(d);
			var c = p.topdecs.get(d);
			localRenamings = new Map();
			nextLocalVarId = 0;
			var code = compileToplevel(c, d, name);
			wr(code);

			if (ovl.reportSizes) {
				// Keep track of file sizes
				var codelength = code.length;
				var pos = FlowUtil.getPosition(c);
				var file = if (pos != null) pos.f else d;
				var filesize = sizes.get(file);
				filesize = if (filesize == null) codelength else filesize + codelength;
				sizes.set(file, filesize);
			}
			wr("\n");
		}
		localRenamings = null;
		// Errors.print(Std.string(neko.vm.Gc.stats()));

		if (ovl.reportSizes) {
			for (k in sizes.keys()) {
				var size = sizes.get(k);
				Sys.println(StringTools.lpad("" + size, "0", 6) + ":" + k);
			}
		}

		// main is started after all resources are loaded
		// by RenderSupportJSPixi.
		wr("if (typeof RenderSupportHx == 'undefined' && typeof RenderSupportJSPixi == 'undefined') " +
				renameId("main") + "();");
		
		Profiler.get().profileEnd("Js export");
	}
	
	function compileToplevel(c : Flow, d : String, name : String, ?prefix : String = "") {
		var buf = new StringBuf();
		compileToplevel2(c, d, name, prefix, buf);
		return buf.toString();
	}

	private var currentTopLevelLambdaName : String;
	private var topLevelTailCall : Bool;
	private var topLevelNonTailCall : Bool;
	function compileToplevel2(c : Flow, d : String, name : String, prefix : String, buf : StringBuf) : Void {
		switch(c) {
			case Native(n_name, io, args, result, defbody, pos):
				buf.add(if (defbody == null) {
					if (debug) "// native " + n_name;
					else name+"="+mangleNativeName(n_name)+";";
				} else {
					compileToplevel(defbody, d, name, mangleNativeName(n_name) + "||");
				});
			case Lambda(arguments, type, body, _, pos):
				currentTopLevelLambdaName = name;
				topLevelTailCall = topLevelNonTailCall = false; // Reset tailcall flags
				var r = ""; // The header is written after tailcall test
				var type = FlowUtil.untyvar(FlowUtil.generalise(pos.type).type);
				
				if (type == null) {
					var typeDeclaration = p.userTypeDeclarations.get(name);
					if (typeDeclaration != null) {
						type = typeDeclaration.type.type;
					}
				}
				
				r += '(';
				
				var argtypes = if (type != null) switch(type) {
					case TFunction(args, returns): args;
					default: null;
				} else null;
				var returntype = if (type != null) switch(type) {
					case TFunction(args, returns): FlowUtil.untyvar(returns);
					default: null;
				} else null;
				
				var sep = '';
				var i = 0;
				for (a in arguments) {
					r += sep + rename(a);
					sep = ',';
					++i;
				}
				r += '){\n';


				var bodyBuf = new StringBuf();
				compileToReturn2(body, indent_inc2, bodyBuf);
				bodyBuf.add("\n}");

				if (topLevelTailCall && !topLevelNonTailCall) {
					r = (arguments.length == 1 ? 'OTC1' : 'OTC') + '('+ prefix + 'function' + r;
					buf.add(r);
					buf.add(indent_inc2);
					var bodyBufStr = bodyBuf.toString();
					bodyBufStr = StringTools.replace(bodyBufStr, name + "(", "sc_" + name + "("); // Patch selfcalls
					buf.add(bodyBufStr);
					buf.add(", '" + name + "' )");
				} else {
					r = name + '=' + prefix + 'function' + r;
					buf.add(r);
					buf.add(indent_inc2);
					buf.add(bodyBuf.toString());
				}
			default: {
				var t = FlowUtil.untyvar(FlowUtil.getPosition(c).type);
				buf.add("var " + name + "=");
				compileToExpr2(c, indent_inc2, buf);
			}
		}
	}

	function compileToExpr(code : Flow, indent : String, ?isReturn : Bool = false) : String {
		var buf = new StringBuf();
		compileToExpr2(code, indent, buf, isReturn);
		return buf.toString();
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
	private static var STR_RPAR = ')';
	private static var STR_LBRAC = '[';
	private static var STR_RBRAC = ']';
	private static var STR_DZERO = '.0';
	private static var STR_DOT = '.';
	private static var STR_E = 'e';
	private static var STR_EMPTY = '';
	private static var STR_CSPACE = ',';
	private static var STR_LET_FN = '(function(){\n';
	private static var STR_LET_VAR = 'var ';
	private static var STR_SPC_EQ_SPC = '=';
	private static var STR_SEMI_NL = ';\n';
	private static var STR_LET_END = '}())';
	private static var STR_CALL_STRUCTID = '({_id:';
	private static var STR_END_CALL_STRUCT = '})';
	private static var STR_COLON = ':';
	private static var STR_SPC_QUEST_SPC = '?';
	private static var STR_SPC_COLON_SPC = ':';

	private var lambdaLevel = 0;
	function compileToExpr2(code : Flow,  indent : String, buf : StringBuf, ?isReturn : Bool = false) : Void {
		switch (code) {
		// case SyntaxError(s, pos) : 
		case ConstantVoid(pos): buf.add('null');
		case ConstantBool(value, pos):
			buf.add(value);
		case ConstantI32(value, pos):
			if (I2i.compare(value, 0) == -1) {
				buf.add(STR_LPAR);
				buf.add(value);
				buf.add(STR_RPAR);
			} else {
				buf.add(value);
			}
		case ConstantDouble(value, pos): 
			if (value == Math.NEGATIVE_INFINITY) {
				buf.add("Math.NEGATIVE_INFINITY");
			} else if (value == Math.POSITIVE_INFINITY) {
				buf.add("Math.POSITIVE_INFINITY");
			} else if (Math.isNaN(value)) {
				buf.add("Math.NaN");
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
						// We can keep unicode chars as unicoide chars, just encoded in UTF-8
						#if neko
							buf.addChar(c);
						#else
							buf.add(value.charAt(i));
						#end
						}
					}
				} else {
					// If it is not UTF-8 compatible, we print each char one at a time, escaping those that are not compatible
					for (i in 0...value.length) {
						var c = value.charCodeAt(i);
						switch (c) {
						case '\\'.code: buf.add(STR_BSLASH);
						case '\"'.code: buf.add(STR_BSQUOTE);
						case '\n'.code: buf.add(STR_BSN);
						case '\t'.code: buf.add(STR_BST);
						case '\r'.code: buf.add(STR_BSR);
						default:
							if (c < 0x20 || c > 0x7f) {
								if (c < 0x100) {
									buf.add("\\x");
									buf.add(StringTools.hex(c, 2));
								} else {
									buf.add(STR_UNIPFX);
									buf.add(StringTools.hex(c, 4));
								}
							} else {
								#if neko
									buf.addChar(c);
								#else
									buf.add(value.charAt(i));
								#end
							}
						}
					}
				}
				buf.add(STR_QUOTE);
			} catch (e : Dynamic) {
				Errors.report(Prettyprint.position(pos) + ': Error generating JS for string constant.');
				Errors.report("Call stack: "  + Assert.callStackToString(haxe.CallStack.exceptionStack()));
				throw e;
			}
		case ConstantArray(value, pos):
			buf.add(STR_LBRAC);
			var sep = STR_EMPTY;
			for (v in value) {
				buf.add(sep);
				compileToExpr2(v, indent + indent_inc1, buf);
				sep = STR_CSPACE;
			}
			buf.add(STR_RBRAC);
		case ConstantStruct(name, values, pos):
			var structDef = structs.get(name);
			buf.add('({_id:' + structDef.id);
			if (values.length > 0) {
				var i = 0;
				for (v in values) {
					var val = compileToExpr(v, indent + indent_inc1, isReturn);
					if (val == "") val = "null";
					buf.add(',' + renameFieldId(structDef.args[i].name) + ':' + val);
					++i;
				}
			}
			buf.add('})');
		case ArrayGet(array, index, pos):
			compileToExpr2(array, indent, buf);
			buf.add(STR_LBRAC);
			compileToExpr2(index, indent, buf);
			buf.add(STR_RBRAC);
		case VarRef(name, pos): {
			buf.add(renameId(name));
		}
		case RefTo(value, pos):
			buf.add('{__v:');
			compileToExpr2(value, indent, buf);
			buf.add('}');
		case Pointer(pointer, pos):
			// This is wrong for the serializer in the interpreter, but too much trouble to fix
			throw "Not supposed to happen";
		case Deref(pointer, pos):
			compileToExpr2(pointer, indent, buf);
			buf.add('.__v');
		case SetRef(pointer, value, pos): 
			buf.add(STR_LPAR);
			compileToExpr2(pointer, indent, buf);
			buf.add('.__v=');
			compileToExpr2(value, indent, buf);
			buf.add(STR_RPAR);
		case SetMutable(pointer, name, value, pos):
			buf.add(STR_LPAR);
			compileToExpr2(pointer, indent, buf);
			buf.add('.' + renameFieldId(name) + '=');
			compileToExpr2(value, indent, buf);
			buf.add(STR_RPAR);
		case Let(name, sigma, value, scope, pos):
			// TODO: If the name is globally unique, we can use the comma operator instead
			buf.add(STR_LET_FN);
			var subindent = indent + indent_inc2;
			buf.add(subindent);
			buf.add(STR_LET_VAR); buf.add(rename(name)); buf.add(STR_SPC_EQ_SPC);
			compileToExpr2(value, subindent, buf);
			buf.add(STR_SEMI_NL);
			if (scope != null) {
				buf.add(subindent);
				compileToReturn2(scope, subindent, buf, isReturn);
			}
			buf.add(STR_LET_END);
		case Lambda(arguments, type, body, _, pos):
			++lambdaLevel;
			var type = FlowUtil.untyvar(pos.type);
			var argtypes = if (type != null) switch(type) {
				case TFunction(args, returns): args;
				default: null;
			} else null;
			var returntype = if (type != null) switch(type) {
				case TFunction(args, returns): returns;
				default: null;
			} else null;
			if (returntype == null) {
				throw "Unknown result type!";
			}

			var i = 0;
			buf.add('(function(');
			var sep = STR_EMPTY;
			var unused = 0;
			for (a in arguments) {
				if (a == "__") a = "$_" + unused++;
				buf.add(sep);
				buf.add(rename(a));
				sep = STR_CSPACE;
				++i;
			}
			var subindent = indent + indent_inc2;
			buf.add('){\n'); buf.add(subindent);
			compileToReturn2(body, subindent, buf);
			buf.add("})\n"); buf.add(indent);
			--lambdaLevel;
		case Call(closure, arguments, pos):
			var needCall = 
				switch (closure) {
					case VarRef(n, p): {
						var s = structs.get(n);
						if (s != null) {
							buf.add(STR_CALL_STRUCTID);
							buf.add(s.id);
							var i = 0;
							for (v in arguments) {
								buf.add(STR_CSPACE);
								buf.add(renameFieldId(s.args[i].name));
								buf.add(STR_COLON);
								compileToExpr2(v, STR_EMPTY, buf);
								++i;
							}
							buf.add(STR_END_CALL_STRUCT);
							// Structs without values should not get parenthesis in haXe enum syntax
							false;
						} else {
							if (renameId(n) == currentTopLevelLambdaName) {
								if (isReturn && lambdaLevel == 0) { 
									topLevelTailCall = true;
								} else {
									topLevelNonTailCall = true;
								}
							}
							true;
						}
					}
					default: true;
				};
			if (needCall) {
				compileToExpr2(closure, indent, buf);
				buf.add(STR_LPAR);
				var sep = STR_EMPTY;
				for (a in arguments) {
					buf.add(sep);
					compileToExpr2(a, indent, buf);
					sep = STR_CSPACE;
				}
				buf.add(STR_RPAR);
			}
		case Sequence(statements, pos): {
			buf.add(STR_LPAR);
			var sep = STR_EMPTY;
			var sep2 = ",\n" + indent;
			var subindent = indent + indent_inc2;
			for (a in statements) {
				var code = compileToExpr(a, subindent, isReturn);
				if (code != STR_EMPTY) {
					buf.add(sep);
					buf.add(code);
					sep = sep2;
				}
			}
			buf.add(STR_RPAR);
		}
		case If(condition, then, elseExp, pos): 
			buf.add(STR_LPAR);
			compileToExpr2(condition, indent, buf);
			buf.add(STR_SPC_QUEST_SPC);
			var subindent = indent + indent_inc2;
			var thenCode = compileToExpr(then, subindent, isReturn);
			if (thenCode == STR_EMPTY) thenCode = "HaxeRuntime.nop___()";
			buf.add(thenCode);
			buf.add(STR_SPC_COLON_SPC);
			var elseCode = compileToExpr(elseExp, subindent, isReturn);
			if (elseCode == "") elseCode = "HaxeRuntime.nop___()";
			buf.add(elseCode);
			buf.add(STR_RPAR);
		case Not(e, pos): {
			buf.add('!');
			compileToExpr2(e, indent, buf);
		}
		case Negate(e, pos): {
			var t = FlowUtil.untyvar(pos.type);
			if (t == TInt) {
				buf.add('(-(');
				compileToExpr2(e, indent, buf);
				buf.add(')|0)');
			} else {
				buf.add('-');
				compileToExpr2(e, indent, buf);
			}
		}
		case Multiply(e1, e2, pos): wrapMath(pos, '*', e1, e2, indent, buf);
		case Divide(e1, e2, pos): wrapMath(pos, '/', e1, e2, indent, buf);
		case Modulo(e1, e2, pos): wrapMath(pos, '%', e1, e2, indent, buf);
		case Plus(e1, e2, pos): wrapMath(pos, '+', e1, e2, indent, buf);
		case Minus(e1, e2, pos): wrapMath(pos, '-', e1, e2, indent, buf);
		case Equal(e1, e2, pos):  compare('==', e1, e2, indent, buf, pos);
		case NotEqual(e1, e2, pos):  compare('!=', e1, e2, indent, buf, pos);
		case LessThan(e1, e2, pos): compare('<', e1, e2, indent, buf, pos);
		case LessEqual(e1, e2, pos):  compare('<=', e1, e2, indent, buf, pos);
		case GreaterThan(e1, e2, pos):  compare('>', e1, e2, indent, buf, pos);
		case GreaterEqual(e1, e2, pos): compare('>=', e1, e2, indent, buf, pos);
		case And(e1, e2, pos):  binop('&&', e1, e2, indent, buf);
		case Or(e1, e2, pos): binop('||', e1, e2, indent, buf);
		case Field(call, name, pos): {
			if (name == "structname") {
				buf.add('(HaxeRuntime._structnames_.get(');
				compileToExpr2(call, indent, buf);
				buf.add('._id))');
			} else {
				buf.add(STR_LPAR);
				compileToExpr2(call, indent, buf);
				buf.add(STR_DOT);
				buf.add(renameFieldId(name));
				buf.add(STR_RPAR);
			};
		};
		case Cast(value, fromtype, totype, pos):
			var v = compileToExpr(value, '', isReturn);
			buf.add(switch (fromtype) {
			case TInt:
				switch (totype) {
				case TInt: v;
				case TDouble: "(1.0*" + v + ")";
				case TString: "Std.string(" +v + ")";
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TDouble:
				switch (totype) {
				case TInt: "((" + v + ")|0)";
				case TDouble: v;
				case TString: "Std.string(" +v + ")";
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TName(n1, args1):
				switch (totype) {
				case TName(n2, args2): v;
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TFlow: v;
			case TBoundTyvar(__): v;
            case TArray(fa): {
                switch (totype) {
                    case TArray(ta): {
                        switch (fa) {
                            case TName(n1, args1):
                                switch (totype) {
                                // Array of named types are OK 
                                case TName(n2, args2): v;
                                default: throw "Not implemented: " + Prettyprint.print(value);
                            }
                            default: throw "Not implemented: " + Prettyprint.print(value);
                        }
                    }
    				default: throw "Not implemented: " + Prettyprint.print(value);
                }
            }
			default: throw "Not implemented: " + Prettyprint.print(value);
			});
		case Switch(e0, type, cases, p):
			buf.add('(function(){var sc__=');
			compileToExpr2(e0, indent, buf);
			buf.add(";\n" + indent + "var __sw;switch(sc__._id){");
			var foundDefault = false;
			for (c in cases) {
				var r = "";
				if (c.structname == "default") {
					foundDefault = true;
					r += '\n' + indent + 'default:{';
				} else {
					var structDef = structs.get(c.structname);
					r += '\n' + indent + 'case ' + structDef.id + ':{';
					var i = 0;
					for (a in c.args) {
						if (a != '__' && (c.used_args == null || c.used_args[i])) {
							r += 'var ' + rename(a);
							var ty = structDef.args[i].type;
							r += '=sc__.' + renameFieldId(structDef.args[i].name) + ';';
						}
						++i;
					}
				}
				
				var body = compileToExpr(c.body, indent + indent_inc4, isReturn);
				if (body != "") {
				 	r += "__sw=" + body + ';break}';
				} else {
				 	r += 'break}';
				}
				buf.add(r);
			}
			buf.add("\n" + indent + "};return __sw}())");
		case SimpleSwitch(e0, cases, p):
			var r = '(function(){var __ss;switch((' + compileToExpr(e0, indent, isReturn) + ')._id){';
			var foundDefault = false;
			for (c in cases) {
				if (c.structname == "default") {
					foundDefault = true;
					r += '\n' + indent + 'default:{';
				} else {
					var structDef = structs.get(c.structname);
					r += '\n' + indent + 'case ' + structDef.id + ':{';
				}
				
				var body = compileToExpr(c.body, indent + indent_inc4, isReturn);
				if (body != "") {
					body += ";";
			 		r += "__ss=" + body + ';break}';
			 	} else {
			 		r += 'break}';
			 	}
			}
			r += '\n' + indent + '};return __ss}())';
			buf.add(r);
		
		case SyntaxError(e, p):
			throw "Not supposed to happen";
		case StackSlot(q0, q1, q2):
			throw "Not supposed to happen";
		case NativeClosure(args, fn, pos):
			throw "Not supposed to happen";
		case Native(name, io, args, result, defbody, pos):
			throw "Not supposed to happen";
		case ConstantNative(value, pos):
			throw "Not supposed to happen";
		case Closure(body, environment, pos):
			throw "Not supposed to happen";
		}
	}

	function compileToVoidStatement(code : Flow,  indent : String, buf : StringBuf) : Void {
		switch (code) {
			case Switch(e0, type, cases, p): {
				buf.add('var sc__=');
				compileToExpr2(e0, indent, buf);
				buf.add(";\n" + indent + "switch(sc__._id){");
				var foundDefault = false;
				for (c in cases) {
					var r = "";
					if (c.structname == "default") {
						foundDefault = true;
						r += '\n' + indent + 'default:{';
					} else {
						var structDef = structs.get(c.structname);
						r += '\n' + indent + 'case ' + structDef.id + ':{';
						var i = 0;
						for (a in c.args) {
							if (a != '__' && (c.used_args == null || c.used_args[i])) {
								r += 'var ' + rename(a);
								var ty = structDef.args[i].type;
								r += '=sc__.' + renameFieldId(structDef.args[i].name) + ';';
							}
							++i;
						}
					}
					
					var body = compileToExpr(c.body, indent + indent_inc4, false);
					if (body != "") {
					 	r += body + ';break}';
					} else {
					 	r += 'break}';
					}
					buf.add(r);
				}
				buf.add("\n" + indent + "};");
			}
			default: {
				buf.add(STR_LPAR);
				compileToExpr2(code, indent, buf);
				buf.add(');');

			}
		}
	}

	function compileToReturn(code : Flow, indent : String, ?isReturn : Bool = true) : String {
		var buf = new StringBuf();
		compileToReturn2(code, indent, buf, isReturn);
		return buf.toString();
	}

	function compileToReturn2(code : Flow,  indent : String, buf : StringBuf, ?isReturn : Bool = true) : Void {
		switch (code) {
		default: {
			buf.add('return ');
			compileToExpr2(code, indent, buf, isReturn);
			buf.add(";");
		}
		case Call(closure, arguments, pos):
			buf.add('return ');
			compileToExpr2(code, indent, buf, isReturn);
			buf.add(";");
		case Let(name, sigma, value, scope, pos):
			buf.add('var ' + rename(name) + '=');
			compileToExpr2(value, indent + indent_inc2, buf);
			if (scope != null) {
				buf.add(';\n' + indent);
				compileToReturn2(scope, indent, buf, isReturn);
			} else {
				buf.add(";return null;");
			}
		case Sequence(statements, pos): {
			var i = 0;
			var l = statements.length;
			for (a in statements) {
				++i;
				if (i != l) {
					compileToVoidStatement(a, indent, buf);
				} else {
					compileToReturn2(a, indent, buf, isReturn);
				}
				buf.add("\n" + indent);
			}
		}
		case If(condition, then, elseExp, pos): 
			buf.add("if(");
			compileToExpr2(condition, indent, buf, isReturn);
			buf.add('){');
			var subindent = indent + indent_inc2;
			compileToReturn2(then, subindent, buf, isReturn);
			buf.add("}else{");
			compileToReturn2(elseExp, subindent, buf, isReturn);
			buf.add("}");

		case Switch(e0, type, cases, p):
			buf.add('var sc__=');
			compileToExpr2(e0, indent, buf, isReturn);
			buf.add(';\n' + indent + 'switch(sc__._id){');
			var foundDefault = false;
			for (c in cases) {
				if (c.structname == "default") {
					foundDefault = true;
					buf.add('\n' + indent + 'default:{');
				} else {
					var structDef = structs.get(c.structname);
					buf.add('\n' + indent + 'case ' + structDef.id + ':{');
					var i = 0;
					for (a in c.args) {
						if (a != '__' && (c.used_args == null || c.used_args[i])) {
							buf.add('var ' + rename(a));
							var ty = structDef.args[i].type;
							buf.add('=sc__.' + renameFieldId(structDef.args[i].name) + ';');
						}
						++i;
					}
				}
				
				compileToReturn2(c.body, indent + indent_inc2, buf, isReturn);
				buf.add('}');
			}
			buf.add('\n' + indent + '}');
		case SimpleSwitch(e0, cases, p):
			var r = 'switch((' + compileToExpr(e0, indent) + ')._id){';
			var foundDefault = false;
			for (c in cases) {
				if (c.structname == "default") {
					foundDefault = true;
					r += '\n' + indent + 'default:{';
				} else {
					var structDef = structs.get(c.structname);
					r += '\n' + indent + 'case ' + structDef.id + ':{';
				}
				
				r += compileToReturn(c.body, indent + indent_inc2, isReturn);
				r += "}";
			}
			r += '\n' + indent + '}';
			buf.add(r);
		}
	}

	private static var identifier_chars1 = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

	private function formatIdSmall(id : Int) {
		var factor = identifier_chars1.length;
		var char = identifier_chars1.charAt(id % factor);
		var out = id >= factor ? formatId(char, Std.int(id/factor)-1) : char;

		return keywords.get(out) ? out+'_' : out;
	}

	private static var identifier_chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

	private static function formatId(prefix : String, id : Int) {
		var sb = new StringBuf();
		sb.add(prefix);

		var factor = identifier_chars.length;
		do {
			sb.addChar(identifier_chars.charCodeAt(id % factor));
			id = Std.int(id / factor);
		} while (id > 0);

		return sb.toString();
	}

	function rename(name : String) : String {
		if (name == "main") return "flow_main";
		// Check if we have to rename this id
		if (localRenamings != null) {
			var local = localRenamings.get(name);
			if (local != null)
				return local;
		}
		var renamed = renamings.get(name);
		if (renamed == null) {
			if (localRenamings != null) {
				if (debug)
					renamed = keywords.exists(name) ? name+'__' : name;
				else
					renamed = formatId('_', nextLocalVarId++);
				localRenamings.set(name, renamed);
				return renamed;
			}
			renamed = if (name.indexOf("$") != -1) {
				StringTools.replace(name, "$", "_s_");
			} else {
				name;
			}
			renamings.set(name, renamed);
		}
		return renamed;
	}

	function renameId(name : String) : String {
		// Check if we have to rename this id
		var renamed = renameNatives.get(name);
		if (renamed == null)
			return rename(name);
		return renamed;
	}

	function renameFieldId(name : String) : String {
		// Check if we have to rename this id
		var renamed = fieldRenamings.get(name);
		if (renamed != null) return renamed;
		return name;
	}
	
	function binop(o : String, e1 : Flow, e2 : Flow, indent : String, buf : StringBuf) : Void {
		buf.add(STR_LPAR);
		compileToExpr2(e1, indent, buf);
		buf.add(o);
		compileToExpr2(e2, indent, buf);
		buf.add(STR_RPAR);
	}
	
	function compare(c : String, e1 : Flow, e2 : Flow, indent : String, buf : StringBuf, pos : Position) : Void {
		var argtype = FlowUtil.untyvar(pos.type2);
		if (argtype != null) {
			switch (argtype) {
			case FlowType.TInt, FlowType.TDouble, FlowType.TBool, FlowType.TString:
				buf.add(STR_LPAR);
				compileToExpr2(e1, indent, buf);
				buf.add(c);
				compileToExpr2(e2, indent, buf);
				buf.add(STR_RPAR);
				return;
			default:
			}
		}

		buf.add('(CMP(');
		compileToExpr2(e1, indent, buf);
		buf.add(STR_CSPACE);
		compileToExpr2(e2, indent, buf);
		buf.add(STR_RPAR); buf.add(c); buf.addChar('0'.code); buf.add(STR_RPAR);
	}

	private static var STR_LPAR2 = '((';
	private static var STR_RPAR_OR_0 = ')|0)';

	function wrapMath(pos : Position, o : String, e1 : Flow, e2 : Flow, indent : String, buf : StringBuf) : Void {
		var t = FlowUtil.untyvar(pos.type);
		if (t == null) throw 'math op without a type'; 
		var t1 = compileToExpr(e1, indent);
		var t2 = compileToExpr(e2, indent);
		switch (t) {
			case TInt: {
				if (o == "*") {
					// 32 bit integer multiplication does not fit in double multiplication
					buf.add('HaxeRuntime.mul_32('); buf.add(t1);
					buf.add(STR_CSPACE); buf.add(t2); buf.add(STR_RPAR);
				} else {
					buf.add(STR_LPAR2); buf.add(t1); buf.add(o); buf.add(t2); buf.add(STR_RPAR_OR_0);
				}
			}
			case TDouble:
				buf.add(STR_LPAR); buf.add(t1); buf.add(o); buf.add(t2); buf.add(STR_RPAR);
			default:
				buf.add(STR_LPAR); buf.add(t1); buf.add(o); buf.add(t2); buf.add(STR_RPAR);
		}
	}
}
