import Flow;
import FlowUtil;
import Lexer;
import FlowArray;
import Position;
import RulesProto;

/**
 * This implements a parser for flow.
 *
 * program ::= [import] declaration*
 * declaration ::= [ let | fun | type ] ;
 * let ::= id = exp
 * fun ::= id (args) = factor
 * type ::= id : type-exp
 *  
 * type-exp ::= bool | int | double | [type-exp] | string | ^ type-exp | flow | (args) -> type-exp | void
 *  
 * exp ::= assign-exp
 * assign-exp ::= id [: type] = exp | pipe-exp := exp | pipe-exp
 * pipe-exp ::= or-exp |> ... |> or-exp
 * or-exp ::= and-exp OR ... OR and-exp
 * and-exp ::= cmp-exp AND ... AND cmp-exp
 * cmp-exp ::= rnd-exp cmp-op rnd-exp
 * cmp-op ::= != | == | < | <= | > | >= | ... | != | == | < | <= | > | >=
 * rnd-exp ::= add-exp
 * add-exp ::= term +|- ... +|- term 
 * term ::= fcall mulop ... mulop fcall
 * mulop ::= * | / | %
 * fcall ::= dot-exp [ ( exp , ... , exp ) ]
 * dot-exp ::= array-index '.' ... '.' array-index 
 * array-index ::= factor [ exp ] ... [ exp ]
 * factor ::= ! fcall | - fcall | \ arg , ... , arg -> exp | ^atom | atom
 * arg ::= id [: type]
 * atom ::= id | 1.0 | 1 | "foo" | ( exp ) | '{' brace '}' | '[' exp , ... , exp ']'
 * name ::= true | false | if ( exp ) exp else exp | ref exp | switch | cast ( pipe-exp : type -> type ) | name
 * switch ::= switch ( pipe-exp : type ) { cases }
 *
 * Expressions after 'switch' & 'cast' are pipe-exp rather than exp, because the 'x : type
 * = ..' allowed in assign-exp causes a parsing ambiguity.  In other words, you can no
 * longer have a let or := inside a switch or cast - something you are not likely to miss
 * much.
 */

class Parser {
	public function new() {
		specialNameParsers = new Map();
		specialNameParsers.set("true", parseNameTrue);
		specialNameParsers.set("false", parseNameFalse);
		specialNameParsers.set("switch", parseSwitch);
		specialNameParsers.set("cast", parseNameCast);
		specialNameParsers.set("unsafe", parseNameUnsafe);
	}

   public function setup (s : String, module : Module, ?noCache = false, ?rules : Bool = false) { 
		this.module = module;
		lexer = Lexer.New(module.relativeFilename, s, noCache, rules);
		vars = null;
		collectSubstVars = false; // true during substitution part of refact.rule parsing
		substSt = -1;
    }
  
	/// Reads and parses the given code. The module is populated with declarations, imports, unittests and syntax errors
	public function parse(s : String, module : Module) : Void {
  	    setup(s, module);
		parse0();
	}
	
	public function parseExp(s : String, module : Module) : Flow {
	    setup(s, module, false/*noCaching*/);
		tokens = lexer.lex();
		// For safety, add some extra
		tokens.push(LEOF);
		tokens.push(LEOF);
		tokens.push(LEOF);
		
		index = 0;
		var exp = parseExpression();
		if (tokens[index] != LEOF) {
			reportError("Did not expect more: " + Lexer.token2string(tokens[index]) + " line " + lexer.getLineNumber(index), false);
		}
		return exp;
	}

    public function parseRules(rules: RulesProto, s : String, module : Module): Bool {
	    setup(s, module, true, true);
		this.rules = rules;
		tokens = lexer.lex();
		tokens.push(LEOF);
		tokens.push(LEOF);
		tokens.push(LEOF);
		index = 0;
		while (true) {
		  var pattern = parseExpression();
		  if (tokens[index] != LRulesArrow) {
			reportError("'=>' missing in rules file", false);
			return false;
		  }
		  ++ index;
		  substSt = tokenToBytes(index).start;
		  vars = new Array();
		  collectSubstVars = true;
		  var subst = parseExpression();
		  collectSubstVars = false;
		  var substEnBytes = tokenToBytes(index-1);
		  vars.sort(function(a,b){ return a.pos.st-b.pos.st;});
		  rules.flowRules.push({pattern:pattern, subst:subst, text: s.substr(substSt, substEnBytes.start+substEnBytes.bytes-substSt), vars:vars});
		  vars = null;
		  if(tokens[index] != LSemi)
			break;
		  ++ index;
		}
		if (tokens[index] != LEOF) {
			reportError("EOF expected in rules file", false);
			return false;
	    }	
		return true;
	}

	// Lex & parse a string as a type
	public function parseType2(s : String, m : Module) : FlowTypePos {
	    setup (s, m, false);
		tokens = lexer.lex();
		tokens.push(LEOF);
		index = 0;
		var t = parseType();
		return if (tokens[index] != LEOF) {
			reportError("parseType2: did not expect more", false);
			null;
		} else t;
	}
	
	public function tokenToBytes(i : Int) : { start : Int, bytes : Int } {
		return lexer.tokenToBytes(i);
	}
	
	private function parse0() : Void {
		tokens = lexer.lex();
		
		Profiler.get().profileStart("Parse");
		// For safety, add some extra
		tokens.push(LEOF);
		tokens.push(LEOF);
		tokens.push(LEOF);
		
		index = 0;
		parseProgram();
		if (tokens[index] != LEOF) {
			reportError("Did not expect more: " + Lexer.token2string(tokens[index]) + " line " + lexer.getLineNumber(index), false);
		}
		Profiler.get().profileEnd("Parse");
	}

	function blip(n : String) {
		//trace("Parse " + n + " token " + index + " " + tokens[index] + " line " + lexer.getLineNumber(index));
	}

	function reportError(n : String, recover : Bool) : Void {
		if (recover) {
			module.addError(formatErrorAndRecover(n));
		} else {
			var error = lexer.getLineNumber(index) + ": " + n;
			module.addError(error);
		}
	}
	
	function error(n : String) : Flow {
		module.addError(formatErrorAndRecover(n));
		return SyntaxError(formatErrorAndRecover(n), posCurr());
	}
	
	function formatErrorAndRecover(n : String) : String {
		var message = lexer.getLineNumber(index) + ": " + n;
		// Error-recovery: Go until next semicolon or right brace
		//blip(message);
		while (tokens[index] != LEOF && tokens[index] != LSemi && tokens[index] != LRightBrace) {
			index++;
		}
		if (tokens[index] == LRightBrace) index++;
		if (tokens[index] == LSemi) index++;
		return message;
	}
	
	private function parseProgram() : Void {
		// imports?
		var name = getName();
		if (name == "import") {
			parseImport();
			return;
		}
		if (name == "require") {
			parseDynamicImport();
			return;
		}		
		if (name == "export") {
			parseExport();
			return;
		}
		if (name == "forbid") {
			parseForbid();
			return;
		}
		
		parseToplevelDeclaration(false);
		expectSemicolon(' after toplevel declaration');
		var token = tokens[index];
		while (token != LEOF) {
			parseToplevelDeclaration(false);
			expectSemicolon(' after  toplevel declaration');
			token = tokens[index];
		}
	}

	private function parseImport() : Void {
		// import name;
		++index;
		
		var moduleName = getName();
		if (moduleName == null) {
			reportError("Expected name of module", false);
			return;
		}
		++index;
		
		// Support "import ui/buttons;" syntax
		while (tokens[index] == LDivide) {
			moduleName += "/";
			++index;
			var n = getName();
			if (n == null) {
				reportError("Expected name after / in import", true);
				return;
			}
			moduleName += n;
			++index;
		}
		
		expectSemicolon();
		
		module.importModule(moduleName);
		
		// Parse the rest
		parseProgram();
	}
	private function parseDynamicImport() : Void {
		parseImport();
	}

	function parseToplevelDeclaration(export : Bool) : Void {
		//blip("Top level Declaration");
		var st = index;
		var name = getName();
		if (name == null) {
			++index;
			reportError("Expected declaration at top-level", false);
			return;
		}
		++index;
		if (name == "unittest") {
			if (export) {
				reportError("unittests not supported in export sections", false);
			}
			parseUnittest();
			return;
		}
		if (name == "native") {
		    parseNative(export, st);
			return;
		}
		var token = tokens[index];
		if (token == LAssign) {
			// "name = exp"
			index++;

			var value = parseExpression();
			if (module.defined(name)) {
				reportError(name + " is already declared", false);
			}
			// TODO: The position for the assignment itself will not be correct here, because it uses only the position from the value
			module.define(name, value, null, posAt(st, index));
			if (export) {
				module.exportName(name);
			}
			return;
		} else if (token == LColonColonEqual) {
			parseUnionNames(name, st, export);
		} else if (token == LLessThan) {
			// typename<?> ::= Union
			// TODO: Right now, we support this syntax, but just ignore the type variables!
			// This is to let the new flow-parsed flow compiler support this syntax, and do the right thing with it
			++index;
			var args = [];
			while (tokens[index] != LGreaterThan) {
				args.push(parseType());
				if (tokens[index] != LComma && tokens[index] != LGreaterThan) {
					reportError('Expected comma or > for in type parameters to ' + name + ', not ' + Lexer.token2string(tokens[index]), true);
				}
				if (tokens[index] == LComma) {
					++index;
				}
			}
			++index;
			parseUnionNames(name, st, export);

		} else if (token == LLeftParenthesis) {
			// Function definition "name(pars) exp" top-level syntax
			var native_definition = null;
			if (module.defined(name)) {
				// Proceed if the conflicting definition is a native
				var def = module.toplevel.get(name);
				switch (def) {
				case Native(name, io, args, result, defbody, pos):
					if (defbody == null)
						native_definition = def;
				default:
				}

				if (native_definition == null) {
					reportError(name + " is already declared", false);
				}
			}
			++index;
			var args = new FlowArray<String>();
			var types = new FlowArray<FlowType>();
			var mutables : Map<Int, Bool> = null;
			while (true) {
				switch (tokens[index]) {
				case LName(n):
					if (n == "mutable") {
						switch (tokens[index+1]) {
							case LName(n2):
								if (mutables == null)
									mutables = new Map();
								mutables.set(args.length, true);
								n = n2;
								++index;
							default:
								// nothing
						}
					}
					if (n != null && FlowUtil.memberString(n, args))
						reportError("Duplicate argument name: "+n, false);
					args.push(n);
					++index;
					var type = null;
					if (tokens[index] == LColon) {
						++index;
						type = parseType();
						switch (type) {
							case TStruct(sn, sa, sm): {
								if (sn == null) {
									// See bug 20410
									reportError("Nested struct definitions not supported in definition of '" + name + "'. Do you miss '-> type' to specify a function type for the argument '" + n + "'?", false);
									return;
								}
							}
							default:
						}
					}
					types.push(type);
					if (tokens[index] != LComma && tokens[index] != LRightParenthesis) {
						reportError("Expected comma or ) in function declaration, not " + Lexer.token2string(tokens[index]), true);
					}
					if (tokens[index] == LComma) {
						++index;
					}
				case LRightParenthesis:
					++index;

					if (mutables != null && tokens[index] != LSemi) {
						reportError("Functions cannot have mutable fields.", false);
					}

					if (tokens[index] == LSemi) {
						// OK, it turns out this was a struct type declaration.
						if (native_definition != null) {
							reportError(name + " is already declared as a native", false);
						}
						// Let's assemble things together as such
						var decls = new FlowArray();
						for (i in 0...types.length) {
							//// Check that we got types for everything
							var t = types[i];
							if (t == null) {
								reportError("To declare a structure type, all arguments need a type", false);
								return;
							}
							var mut = (mutables != null && mutables.exists(i));
							decls.push({name : args[i], type : t, position: posAt(st, index), is_mutable: mut});
						}
						var type = TStruct(name, decls, false);
						// false: structs in explicit type declarations are final, but
						// this is no type declaration, it is the definition of this struct
						var td = module.userTypeDeclarations.get(name);
						if (td != null) {
							reportError('Do not redefine ' + name + ' : ' + pts(td.type) + ' to ' + pt(type), false);
						} 
						module.defineType({name: name, type: FlowUtil.quantify(type), position: posAt(st, index)});
						if (export) {
							module.exportName(name);
						}
					} else if (tokens[index] == LArrow || tokens[index] == LColon) {
						// Oh, it is a function type declaration.
						if (tokens[index] == LColon) {
							// A common error:
							reportError("Use -> rather than : for result types", false);
						}

						++index;
						var returns = parseType();
						var sanetypes = new FlowArray();
						for (t in types) {
							sanetypes.push(if (t == null) TTyvar(FlowUtil.mkTyvar(null)) else t);
						}
						var type = TFunction(sanetypes, returns);
						type = parsePolymorphicConstraints(type);

						var td = module.userTypeDeclarations.get(name);

						if (native_definition == null) {
							var sigma = FlowUtil.quantify(type);
							module.defineType({name: name, type: sigma, position: posAt(st, index)});
						}
						if (export) {
							module.exportName(name);
						}
						if (tokens[index] == LLeftBrace) {
							// Oh, we have the definition as well
							var body = parseExpression();
							var pos = posAt(st, index);
							defineFunctionBody(name, args, type, body, pos, native_definition);
							// We use a trick here with string representation of the type for comparison.
							if (td != null && pt(td.type.type) != pt(type)) {
								reportError('Do not redefine ' + name + ' : ' + pts(td.type) + ' to ' + pt(type), false);
							}
						} else {
							if (native_definition != null) {
								reportError(name + " is already declared as a native", false);
							}
							if (td != null) {
								reportError('Do not redefine ' + name + ' : ' + pts(td.type) + ' to ' + pt(type), false);
							}
						}
					} else {
						// It's a function alright
						var body = parseExpression();
						var sanetypes = new FlowArray();
						var anyTypeExplicit = false;
						for (t in types) {
							sanetypes.push(if (t == null) TTyvar(FlowUtil.mkTyvar(null)) else t);
							if (t != null) {
								anyTypeExplicit = true;
							}
						}
						var t = if (anyTypeExplicit) (TFunction(sanetypes, TTyvar(FlowUtil.mkTyvar(null)))) else null;
						var pos = posAt(st, index);

						defineFunctionBody(name, args, t, body, pos, native_definition);
						if (export) {
							module.exportName(name);
						}
					}
					return;
				default:
					reportError("Expected name or ), not " + Lexer.token2string(tokens[index]), true);
					return;
				}
			}
		} else if (token == LColon) {
			// var : type;
			// var : type = e1;
			++index;
			var type = parseType();

			// Here, we can allow the "with" syntax
			type = parsePolymorphicConstraints(type);

			// If it is a TStruct, parseType could not know what the structname is, so inject structname
			switch (type) {
				case TStruct(structname, args, max):
					for (arg in args) {
						if (arg.name == null) {
							reportError('Give names to fields in struct ' + name, false);
							return;
						}
						switch (arg.type) {
							case TStruct(sn, sa, sm): {
								if (sn == null) {
									// See bug 21201
									reportError("Nested struct definitions not supported when defining: " + name, false);
									return;
								}
							}
							default:
						}
					}
					if (structname == null) type = TStruct(name, args, max);
				default:
			}
			var sigma = FlowUtil.quantify(type);
			module.defineType({name: name, type: sigma, position: posAt(st, index)});
			if (export) {
				module.exportName(name);
			}
			if (tokens[index] == LAssign) {
				// var : type = e1;
				index++;
				var value = parseExpression();
				if (module.defined(name)) {
					reportError(name + " is already declared", false);
				}
				module.define(name, value, sigma, posAt(st, index));
				if (export) {
					module.exportName(name);
				}
			}
			return;
		} else {
			++index;
			reportError("Expected declaration at top-level", false);
			return;
		}
	}

	private function parseUnionNames(name : String, st : Int, export : Bool) : Void {
		// "typename ::= typename1, ..., typename7"
		++index;
		var token = tokens[index];
		var types = new Map();
		while (true) {
			var t = parseTypeName();
			if (t == null) {
				reportError('After "' + name + ' ::= " put one or more type names.', true);
				return;
			}
			types.set(FlowUtil.typename(t), t);

			token = tokens[index];

			if (token == LSemi) {
				if (module.userTypeDeclarations.exists(name)) {
					reportError('Do not redefine type ' + name, false);
				}
				module.defineType({name: name, type: mono(TUnion(types, types)), position: posAt(st, index)});
				// true:  structs in explicit type declarations are final, i.e., this
				// type cannot grow during unification.  This is no type assignment,
				// but a typedef, i.e., a definition of a typename.  But all type
				// assignments using this typename must be final, so it still correct
				// to make this union of structs final.
				if (export) {
					module.exportName(name);
				}
				return;
			}
			expect([LComma, LPipe]);
			token = tokens[index];
		}
	}

	private function parseUnittest() : Void {
		module.unittests.push(parseExpression());
	}
	
	private function parseExport() : Void {
		++index;
		expect([LLeftBrace]);
		
		parseToplevelDeclaration(true);
		expectSemicolon();
		var token = tokens[index];
		while (token != LRightBrace && token != LEOF) {
			parseToplevelDeclaration(true);
			expectSemicolon();
			token = tokens[index];
		}
		if (token == LRightBrace) {
			++index;
		} else {
			reportError("Missing end brace for export", false);
		}
		
		// It is ok to only export. We do not require any private declarations
		if (tokens[index] != LEOF) {
			parseProgram();
		}
	}

	private function parseForbid() : Void {
		// import name;
		++index;
		
		var moduleName = getName();
		if (moduleName == null) {
			reportError("Expected name of module", false);
			return;
		}
		++index;
		
		// Support "import ui/buttons;" syntax
		while (tokens[index] == LDivide) {
			moduleName += "/";
			++index;
			var n = getName();
			if (n == null) {
				reportError("Expected name after / in forbid", true);
				return;
			}
			moduleName += n;
			++index;
		}
		
		expectSemicolon();
		
		module.forbidModule(moduleName);
		
		// Parse the rest
		parseProgram();
	}
	
	private function parseNative(export : Bool, st : Int) : Void {
		// "native name : (type, ..., type) -> type" 
		var name = getName();
		if (module.defined(name)) {
			reportError(name + " is already declared", false);
		}
		++index;
		expect([LColon]);
		var io = parseIo();
		var type = parseType();

		// Here, we can allow the "with" syntax
		type = parsePolymorphicConstraints(type);

		expect([LAssign]);
		var nativeName = getName();
		++index;
		if (nativeName == null) {
			reportError("Expected name", true);
			return;
		}
		// We allow "name.name...name.method" syntax
		while (tokens[index] == LDot) {
			++index;
			var n = getName();
			if (n == null) {
				reportError("Expected name after .", false);
				break;
			} else {
				nativeName += "." + n;
				++index;
			}
		}

		switch (type) {
		case TFunction(args, returns):
			var sigma = FlowUtil.quantify(type);
			var pos = posAt(st, index);
			module.define(name, Native(nativeName, io, args, returns, null, pos), sigma, pos);
			if (export) {
				module.exportName(name);
			}
		default:
			reportError("native only supports function types", false);
		}
	}

	// true iff "io" token found
	function parseIo() : Bool {
		switch (tokens[index]) {
			case LName(s):
				if (s == "io") {
					++index;
					return true;
				}
			default:
		}
		return false;
	}

	function parsePolymorphicConstraints(t : FlowType) : FlowType {
		var token = tokens[index];
		if (token == LWith) {
			// OK, we have polymorphic constraints.
			// We just replace them according to the map to recover the "old" configuration
			var constraints = new Map();
			++index;
			while (true) {
				switch (tokens[index]) {
					case LQuestion(from): {
						++index;
						while (tokens[index] == LSquiggly) {
							++index;
							token = tokens[index];
							switch (token) {
								case LQuestion(to): {
									++index;
									token = tokens[index];
									// Util.println("Adding " + Std.string(from) + " ~> " + Std.string(to));
									if (from < to) {
										constraints.set(to, from);
									} else {
										constraints.set(from, to);
									}
									if (token == LComma) {
										++index;
										continue;
									} else if (token == LSquiggly) {
										from = to;
									} else {
										break;
									}
								}
								default: {
									reportError("Expected type parameter", false);
									break;
								}
							}
						}
					}
					default: break;
				}
			}
			// OK, we have to replace polymorphic types according to the map
			var rt = FlowUtil.mapType(t, function(f : FlowType) : FlowType {
				switch (f) {
					case TBoundTyvar(n): {
						while (n != null) {
							var newId = constraints.get(n);
							if (newId == null) {
								return TBoundTyvar(n);
							} else {
								n = newId;
							}
						}
						return f;
					}
					default: return f;
				}
			});
			Util.println("Mapped " + pt(t) + " to " + pt(rt));
			return rt;
		} else {
			return t;
		}
	}


	// Parse the following token(s) as a type (assuming tokens &c. are initialised
	// correctly).  Use parseType2() if that is not the case.
	function parseType(allowNamelessStructs=true) : FlowTypePos {
	    var st = index;
		var token = tokens[index];
		var name = getName();
		++index;
		if (name == null) {
			if (token == LLeftBracket) {
				// [type]
				var t = parseType();
				token = tokens[index];
				expect([LRightBracket]);
				return mkFlowTypePos(st, TArray(t));
			} else if (token == LLeftParenthesis) {
				// (type)
				// (name:type, ..., name:type)
				// (type, ..., type) -> type
				// (name:type, ..., name:type) -> type
				var args = new FlowArray<FlowTypePos>();
				var names = new FlowArray<String>();
				while (tokens[index] != LRightParenthesis) {
					var n = null;
					if (tokens[index + 1] == LColon) {
						n = getName();
						if (n == null) {
							reportError("Expected name before : in parameter list", true);
							return mkFlowTypePos (st, TVoid);
						}
						index += 2;
					}
					if (n != null && FlowUtil.memberString(n, names))
						reportError("Duplicate argument name: "+n, false);
					names.push(n);
					args.push(parseType());
					if (tokens[index] != LComma && tokens[index] != LRightParenthesis) {
						reportError("Expected comma or ), not " + Lexer.token2string(tokens[index]), true);
						return mkFlowTypePos (st, TVoid);
					}
					if (tokens[index] == LComma) {
						++index;
					}
				}
				++index;
				
				if (tokens[index] != LArrow) {
					// (int) is just int
					if (args.length == 1 && names[0] == null) {
						return args[0];
					}
					// It's a struct
					var decls = new FlowArray<MonoTypeDeclaration>();
					var pos = posAt(st, index);
					for (i in 0...args.length) {
					  decls.push({name: names[i], type: args[i], position: pos, is_mutable:false});
					}
                    // If nameless structs aren't allowed (because whatever called parseType
                    // won't patch in the name as parseToplevelDeclaration does), then raise error.
                    if(!allowNamelessStructs){
                        reportError("Detected nameless struct following use of ref. " +
                                    "Perhaps missing -> to indicate function output?", true);
                    }
					return mkFlowTypePos (st, TStruct(null, decls, false)); // parseToplevelDeclaration() will replace the null
				}
				
				expect([LArrow]);
				var result = parseType();
				return mkFlowTypePos (st, TFunction(args, result));
			} else if (token == LHat) {
				++index;
				return mkFlowTypePos (st, TReference(parseType()));
			} else if (token == LRef) {
                // Explicitly ensure nameless struct is not allowed to avoid
                // any parse errors mistaking a struct definition after ref.
				return mkFlowTypePos (st, TReference(parseType(false)));
			} else {
				switch (token) {
					case LQuestion(c):
					  return mkFlowTypePos (st, TBoundTyvar(c));
					default:
				}
			}
			reportError("Expected type", true);
			return mkFlowTypePos (st, TVoid);
		} else if (name == "bool") { return mkFlowTypePos (st, TBool);
		} else if (name == "int") { return mkFlowTypePos (st, TInt); 
		} else if (name == "double") { return mkFlowTypePos (st, TDouble); 
		} else if (name == "string") { return mkFlowTypePos (st, TString);
		} else if (name == "flow") { return mkFlowTypePos (st, TFlow);
		} else if (name == "void") { return mkFlowTypePos (st, TVoid);
		} else if (name == "native") { return mkFlowTypePos (st, TNative);
		} else {
			--index;
			return parseTypeNames();
		}
	}

	// parse a list of struct names, e.g., "Maybe<t>" or "None" or "None, Some" or "None|Some".
	function parseTypeNames() : FlowTypePos {
		var types = new Map();
		var n = 0;
		var st = index;
		while (true) {
			var t = parseTypeName();
			if (t == null) {
				return null;
			}
			types.set(FlowUtil.typename(PositionUtil.getValue(t)), PositionUtil.getValue(t));
			n++;
			var token = tokens[index];
			if (token != LPipe) {
			    return if (n == 1) t else mkFlowTypePos (st, TUnion(types, types));
			}
			expect([LPipe]);
			token = tokens[index];
		}
		return null; // never happens
	}
	
	function parseTypeName() : FlowTypePos {
	    var st = index;
		var token = tokens[index];
		var name = getName();
		++index;
		if (name == null) {
			//reportError('Expected type name, not ' + token, true);
			return null;
		} else {
			// typename<type, ..., type>
			var args = new FlowArray<FlowTypePos>();
			if (tokens[index] == LLessThan) {
				++index;
				var types = [];
				while (tokens[index] != LGreaterThan) {
					args.push(parseType());
					if (tokens[index] != LComma && tokens[index] != LGreaterThan) {
						reportError('Expected comma or > for in type parameters to ' + name + ', not ' + Lexer.token2string(tokens[index]), true);
						return mkFlowTypePos (st, TName(name, args));
					}
					if (tokens[index] == LComma) {
						++index;
					}
				}
				++index;
				//trace('I parsed type : ' + name + '<' + args.join(',') + '>');
			}
			return mkFlowTypePos (st, TName(name, args));
		}
	}
	
	private function expectSemicolon(?s : String) : Void {
		var token = tokens[index];
		if (token != LSemi && token != LEOF) {
			if (index > 0 && tokens[index - 1] == LRightBrace) {
				// Special case: If the previous symbol is }, it is ok.
				return;
			}
			if (tokens[index] == LRightBrace) {
				// Another special case: If the current symbol is }, it is also ok.
				return;
			}
			++index;
			reportError("Expected semicolon, not " + Lexer.token2string(token) + (s != null ? " (" + s + ")" : ""), true);
			return;
		}
		if (token == LEOF) {
			return;
		}
		while (token == LSemi && token != LEOF) {
			++index;
			token = tokens[index];
		}
	}
	
	private function expect(alts : Array<Token>) : Token {
		var token = tokens[index++];
		for (a in alts) {
			if (token == a) {
				return token;
			}
		}
		if (alts.length == 1) {
			reportError("Expected " + Lexer.token2string(alts[0]) + ", not " + Lexer.token2string(token), true);
		} else {
			var error = "Expected one of ";
			var sep = "";
			for (a in alts) {
				error += sep + Lexer.token2string(a);
				sep = ",";
			}
			reportError(error + ", not " + Lexer.token2string(token), true);
		}
		return token;
	}
	
	private function parseExpression() : Flow {
	    var st = index;
		var token = tokens[index++];
		if (token == LIf || token == LRequire) {
			//blip("If");
			if (tokens[index] != LLeftParenthesis) {
				return error("Expected ( after '" + Lexer.token2string(token) + "', not " + Lexer.token2string(tokens[index]));
			}
			++index;
			
			var e1 = parseExpression();
			if (tokens[index] != LRightParenthesis) {
				return error("Expected ) after '" + Lexer.token2string(token) + " (... ', not " + Lexer.token2string(tokens[index]));
			}
			++index;
			var e2 = parseExpression();
			if (tokens[index] != LElse) {
				if (token == LRequire) {
					return e2;
				} else {
					return If(e1, e2, ConstantVoid(posCurr()), posAt(st, index));
				}
			}
			++index;
			if (tokens[index] == LEOF) {
				return error("Expected expression after 'if (...) ... else', not " + Lexer.token2string(tokens[index]));
			}
			var e3 = parseExpression();
			return If(e1, e2, e3, posAt(st, index));
		} else if (token == LRef) {
			//blip("ref");
			var e = parseExpression();
			return RefTo(e, posAt(st, index));
		} else {
			--index;
			return parseAssignment();
		}
	}
	
	private function parseAssignment() : Flow {
		var ast = parsePipeForward();
		var token = tokens[index];
		var type = null;
		var st = index;
		if (token == LColon) {
			++index;
			type = parseType();
			token = tokens[index];
			if (token != LAssign) {
				reportError('After ' + pp(ast) + ' : ' + ptp(type) + ', I expected =', false);
			}
		}
		if (token == LAssign) {
			//blip("Assignment");
			var eSt = index;
			index++;
			switch (ast) {
			case VarRef(name, pos):
				var value = parseExpression();
				return Let(name, FlowUtil.quantify(type), value, null, posAt(eSt, index));
			default:
				return error("Expected variable name in assignment: " + ast);
			}
		} else if (token == LRefAssign) {
			//blip("Ref assignment");
			index++;
			var value = parseExpression();
			return SetRef(ast, value, posAt(st, index));
		} else if (token == LColonColonEqual) {
			index++;

			var struct,field;
			switch (ast) {
				case Field(e, f, fpos):
					var value = parseExpression();
					return SetMutable(e, f, value, posAt(st, index));
				default:
					return error("Expected a field expression as lvalue of ::=");
			}
		}
		return ast;
	}

	private function parsePipeForward() : Flow {
		var ast = parseOr();
		var token = tokens[index];
		var st = index;
		while (token == LPipeForward) {
			//blip("PipeForward");
			index++;
			var args = new FlowArray<Flow>();
			args.push(ast);
			ast = Call(parseOr(), args, posAt(st, index));
			token = tokens[index];
		}
		return ast;
	}

	private function parseOr() : Flow {
	    var st = index;
		var ast = parseAnd();
		var token = tokens[index];
		while (token == LOr) {
			//blip("Or");
			index++;
			var b = parseAnd();
			ast = Or(ast, b, posAt(st, index));
			token = tokens[index];
		}
		return ast;
	}
	
	private function parseAnd() : Flow {
	    var st = index;
		var ast = parseComparison();
		var token = tokens[index];
		while (token == LAnd) {
			//blip("And");
			index++;
			var b = parseComparison();
			ast = And(ast,  b, posAt(st, index));
			token = tokens[index];
		}
		return ast;
	}
	
	private function parseComparison() : Flow {
	    var st = index;
		var ast = parseRandom();
		var token = tokens[index];
		if ( token == LEqual || token == LNotEqual 
			|| token == LLessThan || token == LLessEqual 
			|| token == LGreaterThan || token == LGreaterEqual) {
			index++;
			//blip("Comparison " + token);
			if (token == LEqual) {
			  ast = Equal(ast, parseRandom(), posAt(st, index));
			} else if (token == LNotEqual) {
				ast = NotEqual(ast, parseRandom(), posAt(st, index));
			} else if (token == LLessThan) {
				ast = LessThan(ast, parseRandom(), posAt(st, index));
			} else if (token == LLessEqual) {
				ast = LessEqual(ast, parseRandom(), posAt(st, index));
			} else if (token == LGreaterThan) {
				ast = GreaterThan(ast, parseRandom(), posAt(st, index));
			} else if (token == LGreaterEqual) {
				ast = GreaterEqual(ast, parseRandom(), posAt(st, index));
			}
			token = tokens[index];
		}
		return ast;
	}

	private function parseRandom() : Flow {
		var ast = parseAdditive();
		return ast; 
		/*
		var token = tokens[index];
		if (token == LColon) {
			index++;
			ast = Random(ast, parseAdditive());
			token = tokens[index];
		}
		return ast;
		*/
	}
	
	private function parseAdditive() : Flow {
	    var st = index;
		var a = parseTerm();
		var token = tokens[index];
		while (token == LPlus || token == LMinus) {
			//blip("Additive " + token);
			index++;
			if (token == LPlus) {
			  var b = parseTerm(); 
			  a = Plus(a, b, posAt(st, index));
			} else if (token == LMinus) {
			  var b = parseTerm(); 
			  a = Minus(a, b, posAt(st, index));
			}
			token = tokens[index];
		}
		return a;
	}
	
	private function parseTerm() : Flow {
	    var st = index;
		var ast = parseFactor();
		var token = tokens[index];
		while ( token == LMultiply || token == LDivide || token == LModulo) {
			//blip("Term " + token);
			index++;
			if (token == LMultiply) {
			  ast = Multiply(ast, parseFactor(), posAt(st, index));
			} else if (token == LDivide) {
			  ast = Divide(ast, parseFactor(), posAt(st, index));
			} else {
			  ast = Modulo(ast, parseFactor(), posAt(st, index));
			}
			token = tokens[index];
		}
		return ast;
	}

	private function parseFactor() : Flow {
		var st = index;
		var token = tokens[index++];
		switch (token) {
		case LNot : 
			var ast = parseFactor();
			return Not(ast, posAt(st, index));
		case LMinus :
			var ast = parseFactor();
			return Negate(ast, posAt(st, index));
		case LBackslash:
			//blip("lambda");
			// Lambda: \ ArgNames? "->" Expression;
			var args = new FlowArray<String>();
			var argTypes = new FlowArray<FlowTypePos>();
			while (true) {
				switch (tokens[index]) {
				case LName(n):
					args.push(n);
					++index;
					var t = tokens[index];
					if (t != LComma && t != LArrow && t != LColon) {
						return error("Expected comma, ': type' or -> after \\name, not " + Lexer.token2string(tokens[index]));
					}
					if (t == LColon) {
						++index;
						argTypes.push(parseType());
						t = tokens[index];
						if (t == LComma) {
							++index;
						}
					} else {
					    argTypes.push(mkFlowTypePos(index, TTyvar(FlowUtil.mkTyvar(null))));
						if (t == LComma) {
							++index;
						}
					}
				case LArrow:
					++index;
					var body = parseExpression();
					return FlowUtil.lambda(args, TFunction(argTypes, TTyvar(FlowUtil.mkTyvar(null))), body, posAt(st, index));
				default:
					return error("Expected name or -> after \\, not " + Lexer.token2string(tokens[index]));
				}
			}
			return error("Expected name or -> after \\, not " + Lexer.token2string(tokens[index]));
		default:
			--index;
			return parseAtomWithPostfix();
		}
	}

	function parseAtomWithPostfix() : Flow {
		var e = parseAtom();
		return parsePostfix(e);
	}

	function parseArgs() : FlowArray<Flow> {
		var args = new FlowArray<Flow>();
		args.push(parseExpression());
		while (tokens[index] == LComma) {
			++index;
			if (tokens[index] == LRightParenthesis) {
				// Special case: Trailing comma is ok
				break;
			}
			args.push(parseExpression());
		}
		return args;
	}

	// if a postfix operator (i.e., e.field, e[index], e(args)) follows, add it to e; otherwise return e unchanged
	function parsePostfix(e : Flow) : Flow {
		var st = index;
		var token = tokens[index];
		if (token == LLeftParenthesis) {
			//blip("Function call");
			index++;
			if (tokens[index] == LRightParenthesis) {
				++index;
				return parsePostfix(Call(e, new FlowArray(), posAt(st, index)));
			} else {
				if (findLWithWithinParentheses()) {
					// special case with "with" struct construction
					var source = parseAtomWithPostfix();
					index++; // skipping LWith

					if (tokens[index] == LRightParenthesis) {
						return error("Expected comma-separated pairs \"field_name=value\" after \"with\"");
					} else {
						var args = parseArgs();

						if (tokens[index] == LRightParenthesis) {
							var special = [ConstantVoid(PositionUtil.dummy), source]; // ConstantVoid as the marker to detect "with" in Modules.desugarModules after parsing
							args = special.concat(args);
							++index;
							return parsePostfix(Call(e, args,  posAt(st, index)));
						} else {
							return error("Expected ), not " + Lexer.token2string(tokens[index]));
						}
					}
				} else {
					var args = parseArgs();
					if (tokens[index] == LRightParenthesis) {
						++index;
						return parsePostfix(Call(e, args, posAt(st, index)));
					} else {
						return error("Expected ), not " + Lexer.token2string(tokens[index]));
					}
				}
			}
		} else if (token == LDot) {
			index++;
			var fast = parseAtom();
			var field = "";
			switch (fast) {
				case VarRef(f, pos) : 
					return parsePostfix(Field(e, f, posAt(st, index)));
				default:
					return error("Expected field instead of " + fast);
			}
		} else if (token == LLeftBracket) {
			//blip("Array index");
			index++;
			var arrayindex = parseExpression();
			if (tokens[index] == LRightBracket) {
				++index;
				return parsePostfix(ArrayGet(e, arrayindex, posAt(st, index - 1)));
			} else {
				return error("Expected ], not " + Lexer.token2string(tokens[index]));
			}
		} else {
			return e;
		}
	}

	private function findLWithWithinParentheses() : Bool {
		var testIndex = index;
		var parenthesesToClose = 0;
		while(true) {
			switch (tokens[testIndex]) {
				case LWith : return parenthesesToClose == 0;
				case LLeftParenthesis : parenthesesToClose++;
				case LRightParenthesis : {
					if (parenthesesToClose == 0) // we reached closing parenthesis for our case
						return false;
					else
						parenthesesToClose--;
				}
				default : {}
			}
			testIndex++;
		}
	}

	private function parseAtom() : Flow {
	    var st = index;
 		var token = tokens[index++];
		switch (token) {
		case LIf: 
			// allow an expression as an atom even though there is no () around in order to allow 
			// stuff like '7 + if ...' without demanding () around the if expression
			--index;
			return parseExpression();
		case LName(s) : return parseName(s);
		case LDouble(f) : return ConstantDouble(f, posAt(st, index));
		case LInt(i) : return ConstantI32(i, posAt(st, index));
		case LString(s) : return ConstantString(s, posAt(st, index));
		case LStringInclude(path) :
			var a = ConstantString(null, posAt(st, index));
			module.includeString(path, a);
			return a;
		case LLeftParenthesis :
			var ast = parseExpression();
			token = tokens[index++];
			if (token != LRightParenthesis) {
				return error("Missing ), got " + Lexer.token2string(token));
			}
			return ast;
		case LLeftBrace :
			return parseBrace();

		case LLeftBracket :
			if (tokens[index] == LRightBracket) {
				++index;
				return ConstantArray(new FlowArray(), posAt(st, index));
			}
			var vals = new FlowArray<Flow>();
			vals.push(parseExpression());
			while (tokens[index] == LComma) {
				++index;
				// Allow trailing comma
				if (tokens[index] == LRightBracket) {
					break;
				}
				vals.push(parseExpression());
			}
			if (tokens[index] == LRightBracket) {
				++index;
				return ConstantArray(vals, posAt(st, index));
			} else {
				return error("Expected ] or comma, not " + Lexer.token2string(tokens[index]));
			}
		case LHat :
			//blip("deref");
			var e = parseAtom();
			return Deref(e, posAt(st, index));
		default:
			return error("Unexpected: " + Lexer.token2string(token));
		}
	}

	private var specialNameParsers : Map<String, Int -> Flow>;

	private function parseNameTrue(st : Int) {
		return ConstantBool(true, posAt(st, index));
	}
	private function parseNameFalse(st : Int) {
		return ConstantBool(false, posAt(st, index));
	}
	private function parseNameCast(st : Int) {
		expect([LLeftParenthesis]);
		var val = parsePipeForward();
		expect([LColon]);
		var from = parseType();
		expect([LArrow]);
		var to = parseType();
		expect([LRightParenthesis]);
		return Cast(val, from, to, posAt(st, index));
	}
	private function parseNameUnsafe(st : Int) {
		expect([LLeftParenthesis]);
		var unsafeFn = parsePipeForward();
		expect([LComma]);
		var safeFn = parsePipeForward();
		expect([LRightParenthesis]);
		return unsafeFn;
	}	

	function parseName(s : String) : Flow {
		var st = index-1;
		var p = specialNameParsers.get(s);
		if (p != null)
			return p(st);
		//blip("var");
		if (collectSubstVars && RulesProto.isVar(s)) {
		  var bytes = tokenToBytes(index-1);
		  //Assert.trace("name: " + s + " bytes: " + bytes + " substSt: " + substSt);
		  vars.push({name:s, pos:new Range(bytes.start-substSt, bytes.start+bytes.bytes-substSt)});
		}
		return VarRef(s, posAt(st, index));
	}
	
	function parseSwitch(st : Int) : Flow {
		/*
		switch (c : Range) {
		 Array(a) : ...;
		 Subrange(a) : ...;
		 default : ...;
		}
		*/
	    
		expect([LLeftParenthesis]);
		var value = parsePipeForward();
		var type = null;
		if (tokens[index] == LColon) {
			index++;
			type = parseType();
		}
		
		expect([LRightParenthesis]);
		expect([LLeftBrace]);
		var cases = new FlowArray();
		while (tokens[index] != LLeftBrace && tokens[index] != LEOF) {
			var sn = getName();
			if (sn == null) {
				break;
			}
			if (sn == "case") {
				// Common problem is handled this way
				module.addError(lexer.getLineNumber(index) + ": case keyword is not used in switch in flow");
				index++;
				sn = getName();
			}
			++index;
			if (sn == "default") {
				expect([LColon]);
				var body = parseExpression();
				expectSemicolon();
				var nextcase : SwitchCase = { structname: sn, args : new FlowArray(), used_args: null, body : body };
				cases.push(nextcase);
			} else {
				if (tokens[index] == LLeftParenthesis) {
					expect([LLeftParenthesis]);
					var args = new FlowArray();
					while (true) {
						switch (tokens[index]) {
						case LName(n):
							args.push(n);
							++index;
							if (tokens[index] == LColon) {
								// A common problem: Listing the type
								return error("Do not list the type for parameter " + n + " in the case for " + sn);
							}
							if (tokens[index] != LComma && tokens[index] != LRightParenthesis) {
								return error("Expected , or ) after structname " + sn + ", not " + Lexer.token2string(tokens[index])
											 + '. Maybe you forgot to put {} around the case.');
							}
							if (tokens[index] == LComma) {
								++index;
							}
						case LRightParenthesis:
							++index;
							expect([LColon]);
							var body = parseExpression();
							expectSemicolon();
							var nextcase : SwitchCase = { structname: sn, args : args, used_args: null, body : body };
							cases.push(nextcase);
							break;
						default:
							return error("Expected name or ) after structname " + sn + ", not " + Lexer.token2string(tokens[index])
										 + '. Maybe you forgot to put {   } around the case.');
						}
					}
				} else {
					// Common error case
					module.addError(lexer.getLineNumber(index) + ": need parenthesis after structname in case: '" + sn + "(): ...'");
					var args = new FlowArray();
					expect([LColon]);
					var body = parseExpression();
					expectSemicolon();
					var nextcase : SwitchCase = {structname: sn, args: args, used_args: null, body: body};
					cases.push(nextcase);
				}
			}
		}
		expect([LRightBrace]);
		return Switch(value, type, cases, posAt(st, index));
	}
	
	function parseBrace() : Flow{
		//blip("brace");
		if (tokens[index] == LRightBrace) {
			++index;
			return ConstantVoid(posAt(index-1, index));
		}
		var asts = [parseDeclaration()];
		while (tokens[index] != LRightBrace && tokens[index] != LEOF) {
			asts.push(parseDeclaration());
		}
		if (tokens[index] == LEOF) {
			// Bug 19932
			return error("Missing ending brace");
//			return makeSequence(asts);
		}
		index++;
		return makeSequence(asts);
	}
	
	private function parseDeclaration() : Flow {
		//blip("Declaration");
		var e = parseExpression();
		expectSemicolon();
		return e;
	}
	
	function makeSequence(asts : Array<Flow>) : Flow {
		// The empty program returns void
		if (asts.length == 0) return ConstantVoid(posCurr());
		var result = new FlowArray();
		var i = 0;
		while (i < asts.length) {
			var e = asts[i];
			switch(e) {
			case Let(n, sigma, v, scope, pos):
				// If this is undefined, we thread into the following stuff
				if (scope == null) {
					result.push(Let(n, sigma, v, makeSequence(asts.slice(i + 1)), pos));
					i = asts.length;
				} else {
					result.push(e);
				}
			default:
				result.push(e);
			}
			++i;
		}
		if (result.length == 1) {
			return result[0];
		}
		return Sequence(result, FlowUtil.getPosition(result[0]));
	}
	
	private function getName() : String {
		switch (tokens[index]) {
		case LName(s): return s;
		case LRequire: return 'require';
		default:
		}
		return null;
	}
	
    function posAt(st: Int, en: Int) : Position {
	  return { f:module.relativeFilename/*filename*//* module.fullFilename*/, l : lexer.linenumbers[st], s:st, e:en-st, type: null, type2: null };
	}
	
    function posCurr() : Position {
	  return posAt(index, index+1);
	}
#if typepos
    function mkFlowTypePos(st: Int, type: FlowType): FlowTypePos { 
	  return {val: type, pos: posAt(st, index)}; 
    }
#else
    function mkFlowTypePos(st: Int, type: FlowType): FlowTypePos { 
	  return type; 
    }
#end

	private function defineFunctionBody(name : String, args : FlowArray<String>, t : FlowType, body : Flow, pos : Position, native_definition : Flow)
	{
		var fnlambda = FlowUtil.lambda(args, t, body, pos);

		if (native_definition != null)
		{
			switch (native_definition) {
			case Native(n_name, n_io, n_args, n_result, n_defbody, n_pos):
				if (n_args.length != args.length) {
					reportError("Native "+name+" defined to have "+n_args.length+" arguments, not "+args.length, false);
				}
				// Add the lambda to the native
				module.toplevel.set(name, Native(n_name, n_io, n_args, n_result, fnlambda, n_pos));
			default:
				throw "impossible";
			}
		}
		else
		{
			module.define(name, fnlambda, mono(t), pos);
		}
	}

	// turn a type without tyvars into a type scheme trivially, i.e., make a monomorphic type
	static private function mono(t : FlowType) : TypeScheme {
		return if (t == null) null else FlowUtil.mono(t);
	}

	static private function pt(t : FlowType) : String {
		return Prettyprint.prettyprintType(t);
	}

	static private function ptp(t : FlowTypePos) : String {
		return Prettyprint.prettyprintTypePos(t);
	}

	static private function pts(t : TypeScheme) : String {
		return Prettyprint.prettyprintTypeScheme(t);
	}

	static private function pp(code : Flow) : String {
		return Prettyprint.prettyprint(code, '');
	}

	public var lexer (default,null)  : Lexer;
	private var tokens : FlowArray<Token>;
	private var index : Int;

	private var module : Module;
    private var rules : RulesProto;
    private var vars : Array<VarSubst>;
    private var collectSubstVars : Bool;
    private var substSt : Int; // beginnning of subst refact.rule part
}
