import Flow;
import Position;
import FlowArray;

#if jsruntime
#error "Attempt to link Flow compiler code into JS runtime"
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

enum ParseCont {
	ChainParse(cb : Void -> ParseCont);
	EndParse(rv : Bool);
}

/// The main engine for parsing, linking and running modules
class Modules {
	public function new(incl : Array<String>, ?objectPath : String, ?allTypes : Bool = false) {
		includes = incl;

		#if (flash || js)
		files = new Files();
		#end
	
		modules = new Map();
		topmodule = null;
		this.objectPath = objectPath;
		this.allNodeTypes = allTypes;
	}

	public static function execChain(cb : Void -> ParseCont) : Bool {
		while (true) {
			switch (cb()) {
			case ChainParse(cb2): cb = cb2;
			case EndParse(rv): return rv;
			}
		}
		return false;
	}

	// Use loadModule instead of parseFileAndImports if you want to force a reload of all
	// files.  Shape uses this, because after editing we want to reload.
	public function loadModule(module : String, getResult : FlowInterpreter -> Bool) : Bool {
		#if (flash || js)
		files.clearCache();
		Util .clearCache();
		#end
		topmodule = null;
		modules = new Map();
		return parseFileAndImports(module, linkModule.bind(getResult));
	}

	// Make an interpreter with the declarations in module & all modules it imports
	function linkModule(cb: FlowInterpreter -> Bool, module : Module) : Bool {
		var interpreter = new FlowInterpreter(allNodeTypes);
		try {
			link(interpreter, module);
			interpreter.typecheckTopdecs(0);
			interpreter.evalTopdecs();
		} catch (e : String) {
			println("Error: " + e);
			interpreter.printCallstack();
		}
		if (Errors.getCount() > 0) {
			return false;
		}
		return cb(interpreter);
	}

	// Read and parse a file, and any imports it might have, applying the function to each
	// of them, presumably to link them
	// !!!! with --incremental never returns: run result function & exit
	public function parseFileAndImports(filename : String, result : Module -> Bool, ?checkTopmoduleDeps : Module -> Bool) : Bool {
	    var cont = function () {
		    Assert.check(topmodule != null, "topmodule != null");
			Assert.trace("ALL OK: module " + topmodule.name + " finishing... #imports=" + topmodule.imports.length);
			var errors = Errors.getCount();
			Assert.trace("Parsing: #errors=" + errors);
			if (errors != 0)
			  return EndParse(false);

			// This call to result happens only once: when we are done reading all files
			Assert.trace("Parsing all OK: check & update");
			desugarModules();
			return EndParse(result(topmodule) && (errors == 0));
		};
		return execChain(parseFileAndImportsInner.bind(filename, cont, checkTopmoduleDeps));
	}

	function desugarModules() : Void {
		for (module in modules) {
			desugarModule(module);
		}
	}

	function desugarModule(module : Module) : Void {
		for (key in module.toplevel.keys()) {
			module.toplevel.set(key, desugarDeclaration(module.toplevel.get(key)));
		}
	}

	function desugarDeclaration(decl : Flow) : Flow {
		return FlowUtil.mapFlow(decl, function(f) {
			return switch (f) {
				case Call(clos, arguments, pos) : {
					var makeCall = function(newArguments) {
						return Call(clos, newArguments, pos);
					}

					var al = arguments.length;
					if (al > 0) {
						switch (arguments[0]) {
							// special "with" case
							// Normally arguments should not contain this
							case ConstantVoid(p) : {
								// Since this is just syntactic sugar, we simply do array with same lenght,
								// as the real args for the struct and fill it either with passed values
								// or field refs to the source struct
								var sourceRef = arguments[1];
								var typeName = switch (clos) {
									case VarRef(name, p) : name;
									default : "";
								}
								var structDef = null;

								for(module in modules) {
									structDef = module.userTypeDeclarations.get(typeName);
									if (structDef != null) break;
								}

								if (structDef == null || !FlowUtil.isStructType(structDef.type.type)) {
									makeCall([SyntaxError(typeName + " type definition wasn't found", pos)]);
								} else {
									switch (structDef.type.type) {
										case TStruct(structname, args, max) : {
											var makeNewArgs = function(src) {
												var newArgs = new FlowArray<Flow>();
												var newFields = new Map<String, Flow>();
												var structFieldNames = args.map(function(arg) { return arg.name; }); // Used in checking for incorrect names
												var error : Null<Flow> = null;
												for (i in 2...al) {
													switch (arguments[i]) {
														case Let(name, sigma, value, scope, p) : {
															if (structFieldNames.indexOf(name) == -1) { // Wrong field name was passed
																error = SyntaxError("No field named \"" + name + "\" in " + structname, p);
																break;
															} else if (newFields.exists(name)) {
																error = SyntaxError("Duplicate field \"" + name + "\" in " + structname, p);
																break;
															} else
																newFields.set(name, value);
														}
														default : {};
													}
												}
												if (error != null) {
													for (i in 0...args.length) {
														newArgs.push(error);
													}
												} else {
													for (i in 0...args.length) {
														var value = newFields.get(args[i].name);
														var valueToPush = if (value == null) Field(src, args[i].name, PositionUtil.copy(pos)) else value;
														newArgs.push(valueToPush);
													}
												}
												
												return newArgs;
											}
											
											var sourceName = "source_" + typeName;
											switch (sourceRef) {
												case VarRef(name, pos) : makeCall(makeNewArgs(sourceRef));
												default : Sequence(
													FlowArrayUtil.one(Let(
														sourceName,
														structDef.type,
														sourceRef,
														Sequence(FlowArrayUtil.one(makeCall(makeNewArgs(VarRef(sourceName, PositionUtil.copy(pos))))), PositionUtil.copy(pos)),
														PositionUtil.copy(pos)
													)),
													PositionUtil.copy(pos)
												);
											}
										}
										default : {
											Util.println("Something wrong in \"with\" construction: " + Std.string(structDef));
											makeCall([]);
										}
									}
								}
								
							}
							default : makeCall(arguments);
						}
					} else
						makeCall(arguments);
				}
				default : f;
			}
		});
	}
	
    public function getFullFileName(filename : String) : String {
		#if sys
			if (FileSystem.exists(filename)) {
				return FileSystem.fullPath(filename);
			} else {
				for (i in includes) {
				    var f = Util.makePath(i, filename);
					if (FileSystem.exists(f)) {
						return FileSystem.fullPath(f);
					}
				}
				Errors.report("Could not find " + filename + ". Use -I <path>");
				return filename;
			}
		#elseif (flash || js)
			// TODO : fix for flash / js if required
			return filename;
		#else
			return filename;
		#end
	}
	
	private function parseFileAndImportsInner(filename : String, cont : Void -> ParseCont, checkTopmoduleDeps : Module -> Bool) : ParseCont {
		Assert.trace("parseFileAndImportsInner: " + filename);
		var module = newModule(filename);
		if (topmodule == null) {
			topmodule = module;
		}

		#if sys
			if (FileSystem.exists(filename)) {
				var contents = FilesCache.content(filename);
				module.fullFilename = FileSystem.fullPath(filename);
				module.relativeFilename = filename;
				return ChainParse(parse.bind(module, contents, cont, checkTopmoduleDeps));
			} else {
				for (i in includes) {
					var f = Util.makePath(i, filename);
					if (FileSystem.exists(f)) {
						var contents = FilesCache.content(f);
						module.fullFilename = FileSystem.fullPath(f);
						module.relativeFilename = f;
						return ChainParse(parse.bind(module, contents, cont, checkTopmoduleDeps));
					}
				}
				Errors.report("Could not find " + filename + ". Use -I <path>");
				modules.set(module.name, module); // for UseStats
				return EndParse(false);
			}
		#elseif (flash || js)
			var contents = haxe.Resource.getString(filename);
			if (contents == null) {
				// We try to download it
				var files = [];
				var res = true;
				// OK, we have to search for it
				files.push(filename);
				for (i in includes) {
				  files.push(Util.makePath(i, filename));
				}
				module.fullFilename = module.name;
				if (this.files.download(filename, files, function(fn,s) {
					// This is wrong: The file downloader should tell us which path is the real one
					module.relativeFilename = fn;
					res = execChain(parse.bind(module, s, cont, null));
				})) { };
				return EndParse(res);
			}
			return ChainParse(parse.bind(module, contents, cont, null));
		#else
			return EndParse(false);
		#end
	}

	public function parse(module : Module, contents : String, cont : Void -> ParseCont, checkTopmoduleDeps : Module -> Bool) : ParseCont {
	  	Assert.trace("--> simple parse module " + module.name );
		module.setContent(contents);
		if (checkTopmoduleDeps != null && module == topmodule) {
		  if (checkTopmoduleDeps(topmodule)) {
			return EndParse(true);
		  }
		}
		try {
			module.parse(contents);
		} catch (e : Dynamic) {
			Errors.report("Error while parsing '" + module.filename + "': " + e);
		}
	
		if (module.name.indexOf("/") != -1) {
			var nopath = module.name.substr(module.name.lastIndexOf("/") + 1);
			if (modules.exists(nopath)) {
				Errors.report("Import conflict: " + nopath + " should be imported with the full path: " + module.name);
				return EndParse(false);
			}
		}
		
		modules.set(module.name, module);
		readIncludedStrings(module);

		return ChainParse(parseFinished.bind(module, cont));
	}

	function processNestedImports(owner : Module, ind : Int, cont : Void -> ParseCont) {
	  //Assert.trace("1: Module " + owner.name + "  imported#" + ind + " #imps=" + owner.imports.length);
	  if (owner.imports.length == ind)
		  return ChainParse(cont);
	  return processNestedImportsCont(owner, ind, processNestedImports.bind(owner, ind+1, cont)); 
	}

	function processNestedImportsCont(owner : Module, ind : Int, cont : Void -> ParseCont) {
		//Util.println("2: Module " + owner.name + "  imported#" + ind + " #imps=" + owner.imports.length);
			var importName = owner.imports[ind];
			var imported = modules.get(importName);
			//Util.println("importName=" + importName + "  imported=" + (imported != null));
			if (imported == null) {
				return ChainParse(parseFileAndImportsInner.bind(findModuleFile(importName), cont, null));
			} else {
				//Util.println("   DONE PARSING: " + imported.doneParsing + " of " + owner.relativeFilename);
				if (! imported.doneParsing) {
					// Cyclic imports cause spurious undefined names when a name in an
					// incompletely loaded module is referenced from another module.  It
					// would be nicer to allow cyclic imports, but that requires some
					// fiddling.
					Errors.report("Break cycle in imports between " + importName + " & " + owner.name);
				}
			}
			return ChainParse(cont);
	}

	function parseFinished(module : Module, cont : Void -> ParseCont) : ParseCont {
	    return processNestedImports(module, 0, function() { module.doneParsing = true; return ChainParse(cont); } );
	}

	// Read all "#include f" strings into includedStrings
	function readIncludedStrings(module : Module) : Void {
		for (incl in module.includedStrings) {
			var file = StringTools.trim(incl.path);
			if (incl.path != incl.path.toLowerCase()) {
				Errors.report(Prettyprint.position(FlowUtil.getPosition(incl.stringConstantPointer)) + ': ' + 'File path for string: "#include ' + incl.path + ' should be lowercase');
			}
			if (! readFile(file, function (content : String) {
				// patch up the placeholder string constant with what was in the file included
				// sadly, this will not work:
				//incl.stringConstantPointer.value = content;
				incl.content = content;
			})) {
				var found = false;
				for (i in includes) {
				    var f = Util.makePath(i, file);
					if (readFile(f, function (content : String) { incl.content = content; })) {
						found = true;
						break;
					}
				}
				if (!found) {
					Errors.report(Prettyprint.position(FlowUtil.getPosition(incl.stringConstantPointer)) + ': ' + 'Could not read file for string: "#include ' + file + '".  Give the path relative to flow/.');
					incl.content = "<error: #include file '" + incl.path + "' not found>"; 
				}
			}
		}
	}

	// Apply the acceptor function to the content of file
	function readFile(file : String, acceptor : String -> Void) : Bool {
		var contOpt = FilesCache.contentOpt(file);
		if (contOpt != null) {
			acceptor(contOpt);
			return true;
		}
		#if sys
			if (FileSystem.exists(file)) {
				acceptor(FilesCache.content(file));
				return true;
			} else {
				return false;
			}
		#elseif (flash || js)
			var files = [];
			if (file.indexOf("/") != -1) {
				files.push(file);
			} else {		
				for (i in includes) {
				  files.push(Util.makePath(i, file));
				}
			}
			this.files.forceDownload(file, files, function (name, content) {
				acceptor(FilesCache.setContent(file, content));
			});
			return true;
		#else
			Errors.report('Modules.readFile not implemented for this backend');
			return false;
		#end
	}

	// The top-level module which is loaded
	public var topmodule : Module;
	
	// Run all collected unit tests
	public function runUnittests(debug : Int) : Bool {
		var unitFailed = false;
		for (module in modules) {
			for (c in module.unittests) {
				var interpreter = linkTypecheck(module, debug);
				if (interpreter != null) {
					interpreter.evalTopdecs();
					if (interpreter.typeRun(c) == null || Errors.getCount() != 0) {
						unitFailed = true;
					}
				} else {
					unitFailed = true;
				}
			}
		}
		return unitFailed;
	}
	
	/**
	 * Link and evaluate the given code (from the given module). 
	 * If debug is set, we print a trace of evaluation.
	 * If error is true, we stop before evaluating if there are parsing errors.
	 */
	public function linkTypecheck(module : Module, debug : Int) : FlowInterpreter {
		return linkTypecheckCont(module, debug, function(interp) { return interp; }, defaultBind);
	}

	public static function defaultBind<T>(cont : Void -> T, ?msg : String = null) : T {
		Assert.trace("... >>= ..." + (if (msg == null) "" else (": " + msg)));
		return cont();
	}

	public static function flashBind<T>(cont : Void -> T, ?msg : String = null) : T {
	#if flash
		haxe.Timer.delay(function () { defaultBind(cont, msg); }, 1);
		return null;
	#else
		return defaultBind(cont, msg);
	#end
	}
	
	public function linkTypecheckCont<T>(
		module : Module, debug : Int,
		cont : FlowInterpreter -> T,
		bind : (Void -> T) -> String -> T 
	) : T  {
			//Errors.resetCount();
		Profiler.get().profileStart("Typecheck");
		var interpreter = new FlowInterpreter(allNodeTypes);
		FlowInterpreter.debug = debug;
		if (debug > 1) {
			println('Linking file ' + module.filename);
		}
		var retFn = function() { return cont (if (Errors.getCount() == 0) interpreter else null); };
		try {
			return bind (function() {
				link(interpreter, module);
				Assert.trace("Type checking...");
				return bind(function () {
					return interpreter.typecheckTopdecs(debug, retFn, bind);
				}, "typecheck");
			}, "link");
		} catch (e : String) {
			Options.DEBUG = true; Assert.printExnStack();
			println("Link & typecheck error: " + e);
			interpreter.printCallstack();
		}
		Profiler.get().profileEnd("Typecheck");
		/*
		// This code is to check that prettyprinting a type & then parsing it gives the
		// same type again, i.e., that prettyprinting a type can be used as a way to
		// serialise it.  Too slow to run in 15s in flash, so will only work in neko.
		println('diffcheck {');
		var fakemodule = new Module("foo");
		var parser = new Parser();
		var pt = function (t : FlowType) {return Prettyprint.prettyprintType(t, null, false, false);}
		for (u in interpreter.userTypeDeclarations.keys()) {
			var td = interpreter.userTypeDeclarations.get(u);
			var s = pt(td.type.type);
			var ty  = parser.parseType2(s, fakemodule);
			var s2 = pt(ty);
			if (s != s2) {
				println('diff: ' + s + '\t != ' + s2);
			}
			//println('        ' + u + ' :\t' + s + '\tparsed: ' + pt(ty));
		}
		println('}');
		*/
		return bind(retFn, "failRet");
	}
	
	public function linkAst(module : Module) : FlowInterpreter {
		var interpreter = new FlowInterpreter(allNodeTypes);
		link(interpreter, module);
		return interpreter;
	}
	
	public function positionToFileAndBytes(position : Position) : { file : String, start : Int, bytes : Int } {
		var module = getModuleByFilename(position.f);
		if (module != null) {
			var p = module.positionToBytes(position);
			return {
				file: module.fullFilename,
				start: p.start,
				bytes: p.bytes
			};
		} else {
			return {
				file: position.f,
				start: -1,
				bytes: 0
			};
		}
	}
	
	public function positionToString(position : Position) : String {
		var f = positionToFileAndBytes(position);
		return f.file + ":" + position.l + "@" + f.start + "-" + (f.start + f.bytes);
	}
	
	public function originalCode(flow : Flow) : String {
		var pos = FlowUtil.getPosition(flow);
		var module = getModule(pos.f);
		if (module == null) {
			return Prettyprint.prettyprint(flow, '');
		}
		return '';
	}
	
	// add the declarations of module (and all modules it imports) to the interpreter
	function link(interpreter : FlowInterpreter, module : Module) : Void {
		var imported = new Map<String,Bool>();
		doLink(interpreter, module, imported);
	}

	// loop through imported modules & add their declarations to the interpreter
	function doLink(interpreter : FlowInterpreter, module : Module, alreadyImported : Map<String,Bool>) {
		if (alreadyImported.exists(module.name)) {
			return;
		}
		alreadyImported.set(module.name, true);
		for (importName in module.imports) {
			var imported = modules.get(importName);
			if (imported == null) {
				throw "Could not find " + importName;
			}
			doLink(interpreter, imported, alreadyImported);
		}

		module.populateInterpreter(interpreter);
	}
	
	public function checkImports(main : Module) {
		var moduleList = new FlowArray();
		for (f in modules.keys()) {
			var module = getModule(f);
			moduleList.push(module);
		}
		var useStats = new UseStats(moduleList, false, false, false, false);

		if (useStats.checkForbids(main)) {
			
		}
	}
	
	/// Given the name of a module, try to find the filename for it
	function findModuleFile(moduleName : String) : String {
		return moduleName + ".flow";
	}

	
	static public function println(s : String) : Void {
		Errors.report(s);
	}

	static private function pt(t : FlowType) : String {
		return Prettyprint.prettyprintType(t);
	}

	static private function pp(code : Flow) : String {
		return Prettyprint.prettyprint(code, '');
	}

	public function getModuleByFilename(name : String) : Module {
	  for (m in modules) {
		if (m.relativeFilename == name)
		  return m;
	  }
	  return null;
	}

	public function getModule(name : String) : Module {
		return modules.get(Module.getModuleName(name));
	}

	public function newModule(name : String) : Module { // overrided in IncrementalModules
		return new Module(name, objectPath);
	}

	public function objectModulesOrder() : Array <ObjectModule> { return null; }
	public function postProcessWholeBytecode(b : haxe.io.Bytes) { }
	public function isIncremental(): Bool { return false; }
		public function coerce(): ObjectModules { Assert.fail("Modules.coerce() called"); return null; }

	// Include paths
	var includes : Array<String>;
	public var modules : Map<String,Module>;
	public var objectPath : String;

	var allNodeTypes : Bool;

	#if (flash || js)
	// Loader and cache of .flow source files
	public var files : Files; // required in object module for .bytecode loading
	#end
}
