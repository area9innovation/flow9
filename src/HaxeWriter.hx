import Flow;

typedef Struct = { id : Int, structname : String, args : FlowArray<MonoTypeDeclaration>};

class HaxeWriter {
	public function new(p : Program, o : haxe.io.Output, js : Bool)  {
		Profiler.get().profileStart("haXe export");
		this.p = p;
		this.o = o;
		
		//
		// First, build a map of reserved keywords that we have to rename
		//
		renamings = new Map();
		renamings.set("break", "break__");
		renamings.set("callback", "callback__");
		renamings.set("case", "case__");
		renamings.set("cast", "cast__");
		renamings.set("catch", "catch__");
		renamings.set("class", "class__");
		renamings.set("continue", "continue__");
		renamings.set("default", "default__");
		renamings.set("do", "do__");
		renamings.set("dynamic", "dynamic__");
		renamings.set("enum", "enum__");
		renamings.set("extends", "extends__");
		renamings.set("extern", "extern__");
		renamings.set("for", "for__");
		renamings.set("function", "function__");
		renamings.set("implements", "implements__");
		renamings.set("in", "in__");
		renamings.set("inline", "inline__");
		renamings.set("interface", "interface__");
		renamings.set("main", "main__");
		renamings.set("never", "never__");
		renamings.set("new", "new__");
		renamings.set("null", "null__");
		renamings.set("override", "override__");
		renamings.set("package", "package__");
		renamings.set("private", "private__");
		renamings.set("public", "public__");
		renamings.set("return", "return__");
		renamings.set("static", "static__");
		renamings.set("super", "super__");
		renamings.set("this", "this__");
		renamings.set("throw", "throw__");
		renamings.set("trace", "trace__");
		renamings.set("try", "try__");
		renamings.set("typedef", "typedef__");
		renamings.set("untyped", "untyped__");
		renamings.set("using", "using__");
		renamings.set("var", "var__");
		renamings.set("while", "while__");

		//	Next, prepare the native function renames, and keep track of which native classes are references
	
		nativeClasses = new Map();
		renameNatives = new Map();
		for (d in p.topdecs.keys()) {
			var c = p.topdecs.get(d);
			switch(c) {
				case Native(name, io, args, result, defbody, pos):
					// Some names, like Native and RenderSupport need a gentle extra renaming to avoid colliding
					// with other implementations of these natives
					var parts = name.split(".");
					var cl = parts[0];
					var cla = cl + if (cl == "Native"
									|| cl == "RenderSupport"
									|| cl == "SoundSupport"
									|| cl == "NotificationsSupport"
									|| cl == "HttpSupport"
									|| cl == "FlowFileSystem"
									|| cl == "GeolocationSupport"
									|| cl == "ServiceWorkerCache"
									|| cl == "WebSocketSupport") { "Hx"; } else "";
					nativeClasses.set(cla, true);
					var renamed = cla + "." + parts[1];

					if (js && renamed == "NativeHx.length") {
						// .length is a built-in property in JS, so we have to work around this haXe bug
						renamed = "NativeHx.length__";
					}

					//TODO: try to actually use the native
					if (defbody == null) {
						renameNatives.set(d, renamed);
					}
				default:
			}
		}
		
		// Next, number the structs
		structs = new Map();
		
		// We do this in alphabetical order in order to avoid random changes in the code just because of hash ordering differences
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
		
		var nstructs = 0;
		for (s in structsOrder) {
			structs.set(s.name, { id : nstructs, structname : s.name, args : s.args});
			nstructs++;
		}
		export();
	}
	
	var p : Program;
	var o : haxe.io.Output;
	var renamings : Map<String,String>;
	var renameNatives : Map<String,String>;
	var structs : Map<String,Struct>;
	var structsOrder : Array<{ name : String, args : FlowArray<MonoTypeDeclaration>}>;
	var nativeClasses : Map<String,Bool>;

	inline function wr(s : String) {
		o.writeString(s);
	}
	
	public function export() : Void {
		// Generate the imports
		wr("import HaxeRuntime;\n");
		for (k in nativeClasses.keys()) {
			wr("import " + k + ";\n");
		}

		wr("class FlowProgram {\n");

		// Main sets up all the structs
		wr("	static public var globals__ : Int = {
		HaxeRuntime._structnames_ = new Map();
		HaxeRuntime._structids_ = new Map();
		HaxeRuntime._structargs_ = new Map();
");
		for (s in structsOrder) {
			var st = structs.get(s.name);
			var id = st.id;
			wr('		HaxeRuntime._structnames_.set(' + id + ', \"' + s.name + '\");\n');
			wr('		HaxeRuntime._structids_.set(\"' + s.name + '\", ' + id + ');\n');
			wr('		HaxeRuntime._structargs_.set(' + id + ', [');
			var sep = "";
			for (a in st.args) {
				wr(sep + "\"" + a.name + "\"");
				sep = ",";
			}
			wr(']);\n');
		}
		
		if (nativeClasses.exists("RenderSupportHx")) {
			wr("		new RenderSupportHx();\n");
		}
		
		wr('
		0;
	};

	static public function main() {
		main__();
	}
		
');

		// A couple of needed functions to implement references
		
		// Generate all functions and values
		for (d in p.declsOrder) {
			var name = renameId(d);
			var c = p.topdecs.get(d);
			var code = compileToplevel(c, d, name);
			wr(code + "\n");
		}

		wr("}\n");
		Profiler.get().profileEnd("haXe export");
	}

	function compileToplevel(c : Flow, d : String, name : String) : String {
		return switch(c) {
			case Native(n_name, io, args, result, defbody, pos):
				if (defbody == null) "// native " + n_name;
				else compileToplevel(defbody, d, name); //TODO: try to actually use the native
			case Lambda(arguments, type, body, _, pos):
				var r = 'static public function '+ name;
				var type = FlowUtil.untyvar(FlowUtil.generalise(pos.type).type);

				if (type == null) {
					var typeDeclaration = p.userTypeDeclarations.get(name);
					if (typeDeclaration != null) {
						type = typeDeclaration.type.type;
					}
				}

				r += templatePars(type);

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
					if (argtypes != null) {
						var at = argtypes[i];
						if (at != null) {
							r += ' : ' + compileType(at);
						}
					}
					sep = ', ';
					++i;
				}
				r += ')';

				var d = compileType(returntype);
				r += ' : ' + d;
				r += "\n  ";
				if (returntype != TVoid) {
					r += 'return ';
				}
				var b = compile(body, "    ", false);
				if (b == "" && returntype == TVoid) b = "return ";
				r += b;
				r;
			default: {
				var t = FlowUtil.untyvar(FlowUtil.getPosition(c).type);
				var r = 'static var ' + name;
				if (t != null) {
					r += " : " + compileType(t);
				} else {
					r += " : Dynamic";
				}
				r += " = cast(" + compile(c, "  ", false) + ');';
				r;
			}
		}
	}

	function compile(code : Flow, indent : String = '', bracket : Bool = false) : String {
		return if (code == null) "" else 
		switch (code) {
		// case SyntaxError(s, pos) : 
		case ConstantVoid(pos): '';
		case ConstantBool(value, pos): '' + value;
		case ConstantI32(value, pos): if (I2i.compare(value, (0)) == -1) {
			// -- is no good
			'(' + value + ')';
		} else {
			'' + value;
		}
		case ConstantDouble(value, pos): 
			if (value == Math.NEGATIVE_INFINITY) {
				"Math.NEGATIVE_INFINITY";
			} else if (value == Math.POSITIVE_INFINITY) {
				"Math.POSITIVE_INFINITY";
			} else if (Math.isNaN(value)) {
				"Math.NaN";
			} else {
				var s = '' + value;
				// -- is no good
				if (s.indexOf(".") < 0 && s.indexOf("e") < 0) s += '.0';
				if (s.charAt(0) == '-') s = '(' + s + ')';
				s;
			}
		case ConstantString(value, pos):
			var s = StringTools.replace(value, "\\", "\\\\");
			s = StringTools.replace(s, "\"", "\\\"");
			s = StringTools.replace(s, "\n", "\\n");
			s = StringTools.replace(s, "\t", "\\t");
			'"' + s + '"';
		case ConstantArray(value, pos):
			var flow = if (pos.type != null) {
				switch(FlowUtil.untyvar(pos.type)) {
					case TArray(t): {
						if (FlowUtil.untyvar(t) == TFlow) {
							true;
						} else {
							false;
						}
					}
					default: false;
				}
			} else false;
			
			var r = 'cast([';
			var sep = '';
			for (v in value) {
				r += sep;
				if (flow) {
					r += "cast (";
				}
				r += compile(v, indent + ' ', false);
				if (flow) {
					r += ")";
				}
				sep = ', ';
			}
			var type = if (pos.type != null) {
				switch(FlowUtil.untyvar(pos.type)) {
					case TArray(t): {
						if (FlowUtil.untyvar(t) == TFlow) {
							', Array<Dynamic>';
						} else {
							'';
						}
					}
					default: '';
				}
			} else '';
			r + "]" + type + ')';
			
		case ConstantStruct(name, values, pos):
			var structDef = structs.get(name);
			var r = 'HaxeRuntime._s_({ _id: ' + structDef.id;
			if (values.length > 0) {
				var i = 0;
				for (v in values) {
					r += ', ' + rename(structDef.args[i].name) + ':' + compile(v, '', false);
					++i;
				}
			}
			r + ' })';
		case ArrayGet(array, index, pos):
			compile(array, indent, bracket) + '[' + compile(index, indent, false) + ']';
		case VarRef(name, pos): {
			renameId(name);
		}
		case RefTo(value, pos):
			'HaxeRuntime.ref__(' + compile(value, indent, true) + ')';
		case Pointer(pointer, pos):
			// This is wrong for the serializer in the interpreter, but too much trouble to fix
			'HaxeRuntime.pointer(' + pointer + ')';
		case Deref(pointer, pos):
			'HaxeRuntime.deref__(' + compile(pointer, indent, bracket) + ')';
		case SetRef(pointer, value, pos): 
			'HaxeRuntime.setref__(' + compile(pointer, indent, bracket) + ', ' + compile(value, indent, true) + ')';
		case Let(name, sigma, value, scope, pos):
			var type = FlowUtil.untyvar(pos.type2);
			var rt = compileType(type);
			var r = 
				'{ var ' + rename(name)
					+ ' : Dynamic'
					 // + (if (rt != "") ' : ' + rt else "")
					 + '=' + compile(value, indent, true) 
					 + '; ';
			var sc = compile(scope, indent, false);
			if (sc != "") {
				sc += ";";
			}
			r + sc + "}";
			
		case Lambda(arguments, type, body, _, pos):
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
			var r = '(function(';
			var sep = '';
			for (a in arguments) {
				r += sep + rename(a);
				if (argtypes != null && argtypes[i] != null) {
				r += ' : Dynamic';
				//	r += " : " + compileType(argtypes[i]);
				}
				sep = ', ';
				++i;
			}
			r += ')';
			var rt = compileType(returntype);
			// r += " : " + rt;
			if (FlowUtil.untyvar(returntype) != TVoid) {
				r += '\n' + indent + 'return';
			}
			var b = compile(body, indent + "  ", false);
			if (b == "") b = "\n" + indent + "return";
			r += " " + b + ")\n" + indent;
			r;
		case Closure(body, environment, pos):
			'TODO';
		case Call(closure, arguments, pos):
			var c = compile(closure, indent, true);
			var needCall = true;
			switch (closure) {
				case VarRef(n, p): {
					var s = structs.get(n);
					if (s != null) {
						c = 'HaxeRuntime._s_({ _id: ' + s.id;
						var i = 0;
						for (v in arguments) {
							c += ', ' + rename(s.args[i].name) + ':' + compile(v, '', false);
							++i;
						}
						c += '})';
						// Structs without values should not get parenthesis in haXe enum syntax
						needCall = false;
					}
				}
				default:
			}
			if (needCall) {
				c += '(';
				var sep = '';
				for (a in arguments) {
					c += sep + compile(a, indent, false);
					sep = ', ';
				}
				c += ')';
			}
			c;

		case Sequence(statements, pos):
			var r = '{\n' + indent;
			for (a in statements) {
				var code = compile(a, indent + '  ', false);
				if (code != "") code += ";";
				r += code + '\n' + indent;
			}
			r + '}';
		case If(condition, then, elseExp, pos): 
			var r = "if (" + compile(condition, indent, false) + ')\n';
			var thenCode = compile(then, "  " + indent, false);
			if (thenCode == "") thenCode = "HaxeRuntime.nop___()";
			r += indent + "  {" + thenCode + ";}";
			var elseCode = compile(elseExp, indent, bracket);
			if (elseCode == "") {
				r = "(" + r + ")";
			} else {
				r += '\n' + indent + 'else\n  ' +indent + elseCode;
			}
			r;
		case Not(e, pos): '!' + compile(e, indent, bracket);
		case Negate(e, pos): '-' + compile(e, indent, bracket);
		case Multiply(e1, e2, pos): wrapMath(pos, '*', e1, e2, indent);
		case Divide(e1, e2, pos): wrapMath(pos, '/', e1, e2, indent);
		case Modulo(e1, e2, pos): wrapMath(pos, '%', e1, e2, indent);
		case Plus(e1, e2, pos): wrapMath(pos, '+', e1, e2, indent);
		case Minus(e1, e2, pos): wrapMath(pos, '-', e1, e2, indent);
		case Equal(e1, e2, pos):  compare('== 0', e1, e2, indent);
		case NotEqual(e1, e2, pos):  compare('!= 0 ', e1, e2, indent);
		case LessThan(e1, e2, pos): compare('< 0', e1, e2, indent);
		case LessEqual(e1, e2, pos):  compare('<= 0', e1, e2, indent);
		case GreaterThan(e1, e2, pos):  compare('> 0', e1, e2, indent);
		case GreaterEqual(e1, e2, pos): compare('>= 0', e1, e2, indent);
		case And(e1, e2, pos):  binop('&&', e1, e2, indent);
		case Or(e1, e2, pos): binop('||', e1, e2, indent);
		case Field(call, name, pos): {
			if (name == "structname") {
				'(HaxeRuntime._structnames_.get(' + compile(call, indent, bracket) + '._id))';
			} else {
				'(' + compile(call, indent, bracket) + "." + rename(name) + ')';
			}
		};
		case SetMutable(call, name, value, pos): {
			'(' + compile(call, indent, bracket) + "." + rename(name) +
				') = (' + compile(value, indent, true) + ")";
		};
		case Cast(value, fromtype, totype, pos):
			var v = compile(value, '', false);
			switch (fromtype) {
			case TInt:
				switch (totype) {
				case TInt: v;
				case TDouble: "(1.0 * " + v + ")";
				case TString: "Std.string(" +v + ")";
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TDouble:
				switch (totype) {
				case TInt: "Std.int(" + v + ")";
				case TDouble: v;
				case TString: "Std.string(" +v + ")";
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			case TName(n1, args1):
				switch (totype) {
				case TName(n2, args2): v;
				default: throw "Not implemented: " + Prettyprint.print(value);
				}
			default: throw "Not implemented: " + Prettyprint.print(value);
			}
		case Switch(e0, type, cases, p):
				var r = '\n' + indent + '{ var sc__ : Dynamic = ' + compile(e0, indent, false) + ';';
				r += '\n' + indent + 'switch (sc__._id) {';
				var foundDefault = false;
				for (c in cases) {
					if (c.structname == "default") {
						foundDefault = true;
						r += '\n' + indent + 'default: {';
					} else {
						var structDef = structs.get(c.structname);
						r += '\n' + indent + 'case ' + structDef.id + ': {';
						var i = 0;
						for (a in c.args) {
							r += 'var ' + rename(a);
							var ty = structDef.args[i].type;
							if (templatePars(ty) == "") {
								r += ' : ' + compileType(ty);
							}
							r += ' = sc__.' + rename(structDef.args[i].name) + ';';
							++i;
						}
					}
					
					var body = compile(c.body, indent + '    ', false);
					if (body != "") body += ";";
				 	r += body + '}';
				}
				r += '\n' + indent + '}; }';
				r;
		case SimpleSwitch(e0, cases, p):
				var r = '\n' + indent + '(switch ((' + compile(e0, indent, false) + ')._id) {';
				var foundDefault = false;
				for (c in cases) {
					if (c.structname == "default") {
						foundDefault = true;
						r += '\n' + indent + 'default: {';
					} else {
						var structDef = structs.get(c.structname);
						r += '\n' + indent + 'case ' + structDef.id + ': {';
					}
					
					var body = compile(c.body, indent + '    ', false);
					if (body != "") body += ";";
				 	r += body + '}';
				}
				r += '\n' + indent + '})';
				r;
			
		case SyntaxError(e, p):
			'SYNTAX ERROR';
		case StackSlot(q0, q1, q2):
			'STACKSLOT';
		case NativeClosure(args, fn, pos):
			'NATIVECLOSURE';
		case Native(name, io, args, result, defbody, pos):
			'NATIVE';
		case ConstantNative(value, pos):
			'CONSTANTNATIVE';
		}
	}
	
	function rename(name : String) : String {
		// Check if we have to rename this id
		var renamed = renamings.get(name);
		return if (renamed == null) {
			if (name.indexOf("$") != -1) {
				StringTools.replace(name, "$", "_s_");
			} else {
				name;
			}
		} else {
			renamed;
		}
	}

	function renameId(name : String) : String {
		// Check if we have to rename this id
		var renamed = renameNatives.get(name);
		if (renamed != null) return renamed;
		if (structs.exists(name)) {
			return "{ _id:" + structs.get(name).id + "}";
		}
		return rename(name);
	}
	
	function binop(o : String, e1 : Flow, e2 : Flow, indent : String) : String {
		return '(' + compile(e1, indent, false) + o + compile(e2, indent, false) + ')';
	}
	
	function compare(c : String, e1 : Flow, e2 : Flow, indent : String) : String {
		// TODO: If we know that the type of e1 and e2 both are basic, then we can use the normal comparison
		return '(HaxeRuntime.compareByValue(' + compile(e1, indent, false) + ', ' + compile(e2, indent, false) + ')' + c + ')';
	}
	
	function wrapMath(pos : Position, o : String, e1 : Flow, e2 : Flow, indent : String) : String {
		var t = FlowUtil.untyvar(pos.type);
		if (t == null) throw 'math op without a type'; 
		var t1 = compile(e1, indent, false);
		var t2 = compile(e2, indent, false);
		return switch (t) {
			case TInt: 'Std.int(' + t1 + o + t2 + ')';
			case TDouble: '(cast(' + t1 + ', Float)' + o + 'cast(' + t2 + ', Float))';
			default: '(' + t1 + o + t2 + ')';
		}
	}
	
	function tuborg(b, s) : String {
		return if (b) '{' + s + '}' else s;
	}

	function compileType(type : FlowType, ?normalise : FlowType -> FlowType, ?bracket : Bool, ?fields: Bool = true) : String {
		return if (type == null) 'Dynamic' else
		switch (type) {
		case TVoid: "Void";
		case TBool: "Bool";
		case TInt: "Int";
		case TDouble: "Float";
		case TString: "String";
		case TReference(type): "{ v: " + compileType(type, normalise, true, fields) + " }";
		case TPointer(type): "TODO"+ compileType(type, normalise, true, fields);
		case TArray(type): "Array<" + compileType(type, normalise, false, fields) + ">";
		case TFunction(args, returns): 
			var r = '';
			var sep = '';
			for (a in args) {
				r += sep + compileType(a, normalise, args.length == 1, fields);
				sep = '-> ';
			}
			if (r == "") {
				r = "Void";
			}
			r += ' -> ' + compileType(returns, normalise, false, fields);
			r;
		case TStruct(structname, args, max): {
			var r = ' { _id : Int';
			for (a in args) {
				r += ", " + rename(a.name) + " : " + compileType(a.type);
			}
			r + "}";
		}
		case TUnion(min, max): "Dynamic"; //ppUnion(min, max, fields);
		case TTyvar(ref): if (ref.type == null) 'Dynamic' else compileType(ref.type, normalise, bracket, fields);
		case TBoundTyvar(i): ["T", "U", "V", "W", "X", "Y", "Z"][i];
		case TFlow: "Dynamic";
		case TNative : "Dynamic";
		case TName(name, args): 'Dynamic';
		}
	}
	
	function collectBoundTyvars(type : FlowType) : String { 
		return if (type == null) "" else
		switch (type) {
		case TVoid: "";
		case TBool: "";
		case TInt: "";
		case TDouble: "";
		case TString: "";
		case TReference(type): collectBoundTyvars(type);
		case TPointer(type): collectBoundTyvars(type);
		case TArray(type): collectBoundTyvars(type);
		case TFunction(args, returns): 
			var r = "";
			for (a in args) {
				r += collectBoundTyvars(a);
			}
			r += collectBoundTyvars(returns);
			r;
		case TStruct(structname, args, max): 
			var r = "";
			for (a in args) {
				r += collectBoundTyvars(a.type);
			}
			r;
		case TUnion(min, max): ""; //ppUnion(min, max, fields);
		case TTyvar(ref): if (ref.type == null) '' else collectBoundTyvars(ref.type);
		case TBoundTyvar(i): ["T", "U", "V", "W", "X", "Y", "Z"][i];
		case TFlow: "";
		case TNative : "";
		case TName(name, args): '';
	}}
	
	function templatePars(type : FlowType) : String {
		var tyvars = collectBoundTyvars(type);
		if (tyvars != "") {
			var r = "<";
			var s = "";
			
			var seen = new Map();
			
			for (i in 0...tyvars.length) {
				var l = tyvars.charAt(i);
				if (!seen.exists(l)) {
					r += s + l;
					seen.set(l, true);
					s = ", ";
				}
			}
			r += ">";
			return r;
		}
		return "";
	}
}
