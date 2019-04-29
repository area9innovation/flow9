import Flow;
import BytecodeWriter;
//import MurMur;

class Module {
	static var DEPS_MAGIC = "DEP-v-03";
	public function new(filename : String, objectPath : String) {
		this.filename = filename;
		this.objectPath = objectPath;
		this.name = getModuleName(filename);
		this.precompiled = false;

		// Do a test of casing of filenames
		var testCasing = filename;
		if (testCasing.charAt(1) == ":") {
			// Windows machine. Skip the drive letter which is upper case
			testCasing = testCasing.substr(2);
		}
		testCasing = StringTools.replace(testCasing, "\\", "/");

		if (testCasing != testCasing.toLowerCase()
				// Since these filenames has leaked, we do not require the lower case for these
				&& (testCasing.indexOf("biology/enzymes") == -1
						&& testCasing.indexOf("microbiology/gram_staining") == -1)
				) {
			Errors.report("For consistency, file names should be all lower case: " + filename);
		}
		reset();
		this.doneParsing = false;
		this.content = null;
		this.hash    = null;
	}

	public function reset() {
		this.imports = [];
		this.forbids = [];
		this.includedStrings = [];
		this.exports = new Map();        // null=no export section=all variables exported
		// to demand all modules have an export declaration, change null to new Map()
		this.toplevel = new Map();
		this.unittests = [];
		this.declarations = [];
		this.userTypeDeclarations = new Map();
	}

	public function coerce () : ObjectModule { return throw "Invalid cast Module to ObjectModule"; }

	public function parse(contents : String) {
		p = new Parser();
		p.parse(contents, this);
		reportUndefined();
	}
	public var p : Parser;

	public function positionToBytes(pos : Position) : { start : Int, bytes : Int } {
		var start = p.tokenToBytes(pos.s);
		var end = start;
		if (pos.e != -1) {
			end = p.tokenToBytes(pos.s + pos.e - 1);
		}
		return {
			start : start.start,
			bytes : (end.start + end.bytes) - start.start
		};
	}

	public function tokenAtPos(pos : Int) : Int {
		return p.lexer.tokenAtPos(pos);
	}

	public function tokenAtIndex(ind : Int) : Lexer.Token {
		return p.lexer.tokenAtIndex(ind);
	}

	private function reportUndefined() {
		var h = new Map<String,Bool>();
		for (s in declarations) {
			h.set(s, false);
		}
		for (s in userTypeDeclarations.keys()) {
			if (h.get(s) == null) {
				var td = userTypeDeclarations.get(s);
				switch (td.type.type) {
					// for structs the declaration is also the definition
				case TStruct(n, args, max):
				case TUnion(min, max):
				default:
					report('You declared but did not define ' + td.name + ' : ' + pts(td.type) + '. If you did, check the spelling.',
								 ConstantVoid(td.position));
				}
			}
		}
	}

	public function parseExp(contents : String) {
		p = new Parser();
		return p.parseExp(contents, this);
	}

	// The parser puts imports here
	public function importModule(name : String) : Void {
		//Assert.trace("IMPORT ADDED to Module " + relativeFilename + ": " + name);
		imports.push(name);
	}

	// The parser puts forbids here
	public function forbidModule(name : String) : Void {
		forbids.push(name);
	}

	// The parser puts string includes here.
	public function includeString(path : String, stringConstantPointer : Flow) : Void {
		includedStrings.push({path: path, stringConstantPointer: stringConstantPointer, content: null});
	}

	// The parser puts exported names here
	public function exportName(name : String) : Void {
		if (exports == null) {
			exports = new Map();
		}
		exports.set(name, true);
	}

	public function isExported(name : String) : Bool {
		return exports.exists(name);
	}

	public function isHidden(name : String) : Bool {
		return ! isExported(name);
	}

	// Is some name defined in this module?
	public function defined(name : String) : Bool {
		return toplevel.exists(name);
	}

	// The parser puts the top-level declarations here
	public function define(name : String, code : Flow, sigma : TypeScheme, pos : Position) : Void {
		// TODO: define should not also define the type, that was a mistake.  Call
		// defineType explicitly in the cases you want to, instead of doing that by
		// passing a non-null type to define();
		declarations.push(name);
		toplevel.set(name, code);
		// enter the type only if no type was explicitly declared for this identifier
		if (sigma != null && ! userTypeDeclarations.exists(name)) {
			//trace('entering ' + name + ':' + pt(type));
			var td : TypeDeclaration = {name: name, type: sigma, position: pos};
			userTypeDeclarations.set(name, td);
		}
	}

	public function defineType(td : TypeDeclaration) : Void {
		//trace('defineType ' + td.name + ':' + pt(td.type));
		userTypeDeclarations.set(td.name, td);
	}

	public function populateInterpreterFromType(interpreter: FlowInterpreter, td1: TypeDeclaration) {
		var t = td1.name;
		var td2 = interpreter.userTypeDeclarations.get(t);
		if (td2 != null) {
			Module.reportp('Type ' + t + ' is defined twice. Here:', td1.position);
			Module.reportp('                                 & here:', td2.position);
		} else {
			interpreter.userTypeDeclarations.set(t, td1);
			//interpreter.userTypeDeclarationsOrder.push(t);
			var ty = interpreter.typeEnvironment.lookup(t);
			if (ty != null) {
				Module.reportp(t + ' collides with existing type declaration "' + Module.pts(ty) + '" from another module', td1.position);
			}
			interpreter.typeEnvironment.define(t, td1.type);
			if (isHidden(t)) {
				interpreter.hide(t, name);
			}
		}
	}
	public function populateInterpreterFromDecl(interpreter: FlowInterpreter, d: String) {
		var val = interpreter.topdecs.get(d);
		if (val != null) {
			Module.report(d + ' is defined twice: ', val);
			Module.report('     & here:', toplevel.get(d));
		} else {
			interpreter.order.push(d);
			if (!precompiled) {
				var e = toplevel.get(d);
				e = addIncludedStringsAndExpandUnion(interpreter, toplevel.get(d));
				Assert.check(e != null, "e != null");
				interpreter.topdecs.set(d, e);
			}
			if (! userTypeDeclarations.exists(d)) {
				// prepare the type environment for typechecking, i.e., assume
				// "unknown" type for all identifiers that have no type declaration
				interpreter.typeEnvironment.define(d, Module.mono(TTyvar(FlowUtil.mkTyvar(null))));
			}
			if (isHidden(d)) {
				interpreter.hide(d, name);
			}
		}
	}

	// Import all top-level declarations into the given interpreter
	public function populateInterpreter(interpreter : FlowInterpreter) : Void {
		//Assert.trace("Populate: " + relativeFilename);
		checkVisibility(interpreter);
		for (t in userTypeDeclarations.keys()) {
			populateInterpreterFromType(interpreter, userTypeDeclarations.get(t));
		}

		for (d in declarations) {
			populateInterpreterFromDecl(interpreter, d);
		}
	}

	// Check all uses of identifiers are visible at their use point, i.e., that they are
	// either defined in this module or exported from the module where they are defined.
	public function checkVisibility(interpreter : FlowInterpreter) : Void {
		var checkName = function (name : String, pos : Position) : Void {
			if (interpreter.topdecs.exists(name) || interpreter.userTypeDeclarations.exists(name)) {
				// defined already in the interpreter, i.e., defined in a different module, so
				// we must check it is also exported
				if (interpreter.isHidden(name)) {
					//Assert.printStack();
					reportp('export { ' + name + ' ... } in ' + interpreter.hiddenWhere(name) + '.flow', pos);
				}
			}
		}

		var checkType = function (t : FlowType, pos : Position) : Void {
			FlowUtil.traverseType(t, function (t) {
					switch (t) {
					case TName(n, args): checkName(n, pos);
					case TUnion(min, max):
					case TStruct(n, args, max): checkName(n, pos);
					default:
					}});
		}

		var checkExp = function (e : Flow) : Void {
			FlowUtil.traverseExp(e, function (e) {
					switch (e) {
					case ConstantStruct(p_name, values, pos): checkName(p_name, pos);
					case VarRef(p_name, pos): checkName(p_name, pos);
					case Cast(value, fromtype, totype, pos):
					checkType(fromtype, pos); checkType(totype, pos);
					case Switch(e, type, cases, pp):
					if (type != null) checkType(type, pp);
					for (c in cases) {
						checkName(c.structname, FlowUtil.getPosition(c.body));
					}
					case Native(p_name, io, args, result, defbody, pos): checkName(p_name, pos);
					default:
					}});
		}

		for (d in declarations) {
			var e = toplevel.get(d);
			checkExp(e);
		}
		for (e in unittests) {
			checkExp(e);
		}
		for (td in userTypeDeclarations) {
			checkType(td.type.type, td.position);
		}
	}

	// patch occurrences of "#include f" ConstantStrings to be the string included from
	// the file f.
	function addIncludedStringsAndExpandUnion(interpreter : FlowInterpreter, e : Flow) : Flow {
		return FlowUtil.mapFlow(e, function (e1) {
				switch (e1) {
				case ConstantString(value, pos):
					if (value == null) {
						for (incl in includedStrings) {
							if (e1 == incl.stringConstantPointer) {
								//trace('I replaced an occurrence of "#include ' + incl.path + '"');
								return ConstantString(incl.content, pos);
							}
						}
						addError('#included string in expression could not be expanded.' + e1);
					}
					return e1;
				case Switch(val, typ, cases, pos):
					var newCases = SwitchExpand.expandCases(interpreter.typeEnvironment, cases);
					return Switch(val, typ, newCases, pos);
				default:
					return e1;
				}
			});
	}

	public function writeDependencies(modules: Modules, buf: StringBuf, ?ready: Map<String,Bool> = null) {
		if (ready == null) {
			buf.add(DEPS_MAGIC);
			buf.add("\n");
			ready = new Map();
		}
		if (ready.get(name) == null) {
			var tmphash = "";
			tmphash = FilesCache.hash(relativeFilename);
			buf.add(relativeFilename); buf.add("\n"); 
			buf.add(tmphash); buf.add("\n");
			for (is in includedStrings) {
				var isfullpath = modules.getFullFileName(is.path);
				tmphash = FilesCache.hash(isfullpath);
				buf.add(isfullpath); buf.add("\n");
				buf.add(tmphash); buf.add("\n");
			}
			ready.set(name, true);
			for (imp in imports) {
				var m = modules.modules.get(imp);
				Assert.check(m != null, "m != null");
				m.writeDependencies(modules, buf, ready);
			}
		}
	}

	public function readDependencies() {
		try {
			var files = Util.readFile(getObjectFileName(".deps"));
			if (files == null) {
				return null;
			}
			//Util.println("   DEPENDS: [" + files + "]");
			var depsHash = new Map();
			files = StringTools.replace(files, "\r\n", "\n");
			files = StringTools.replace(files, "\n\r", "\n");
			var lines = files.split("\n");
			var magic = lines.shift();
			if (DEPS_MAGIC != magic) {
				Util.println("Dependencies file version changed for " + getObjectFileName(".deps") + " : '" + DEPS_MAGIC + "' != '" + magic + "'");
				return null;
			}
			var i = 0;
			while (i != lines.length) {
				var fname = lines[i++];
				if (fname == "")
					continue;
				if (i >= lines.length) {
					return null;
				}
				var fhash = lines[i++];
				// Util.println("fname=" + fname + " fhash=" + fhash);
				depsHash.set(fname, fhash);
			}
			return depsHash;
		} catch (e : Dynamic) {
			// We do not have to complain here - we will complain later
			return null;
		}
	}

	public function addError(m : String) : Void {
		Errors.report(relativeFilename + ':' + m);
	}

	static function error(error : String, code : Flow) : String {
		return Prettyprint.getLocation(code) + ": " + error;
	}

	static private function report(s : String, code : Flow) : Void {
		Errors.report(error(s, code));
	}

	static private function reportp(s : String, pos : Position) : Void {
		Errors.report(Prettyprint.position(pos) + ': ' + s);
	}

	static public function getModuleName(filename : String) : String {
		var nosuffix = filename;
		var dot = nosuffix.lastIndexOf(".");
		if (dot != -1) {
			nosuffix = nosuffix.substr(0, dot);
		}
		return nosuffix;
	}

	public function getObjectFileName(?sfx : String = ".byte") {
		Assert.check(relativeFilename != null);
		var rpath = relativeFilename + sfx;
		rpath = StringTools.replace(rpath, '\\', '/');
		rpath = StringTools.replace(rpath, "../", "__/");
		rpath = StringTools.replace(rpath, ":/", "_/");
		return objectPath + "/" + rpath;
	}

	public function getSourceHash() {
		Assert.check(content != null, "content != null");
		if (hash == null) {
			hash = Md5.encode(content);
		}
		return hash;
	}

	public function compileRange(names : Names, p: Program, run: Void -> BytesOutput) : BytesOutput {
		return run();
	}

	public function postprocessBytecodeAndWrite(modules : Modules, names : Names, bytes : haxe.io.Bytes) { }
	public function setContent(content : String) { this.content = content; hash = null; }


	// turn a type without tyvars into a type scheme trivially, i.e., make a monomorphic type
	static private function mono(t : FlowType) : TypeScheme {
		return FlowUtil.mono(t);
	}

	static private function pt(t : FlowType) : String {
		return Prettyprint.prettyprintType(t);
	}

	static private function pts(t : TypeScheme) : String {
		return Prettyprint.prettyprintTypeScheme(t);
	}

	// Name of this module. For all files except those in flow/, this includes the path with / separators
	public var name : String;
	// Filename
	public var filename : String;

	// Fully qualified filename
	public var fullFilename : String;

	// filename, relative to current directory
	public var relativeFilename : String;

	// The module that are imported
	public var imports : Array<String>;

	// Modules that are forbidden
	public var forbids : Array<String>;

	// The strings that are included from external files, i.e., strings of the form
	// "#include foo/bar" that need to be read from a file.  path is "foo/bar" &
	// stringConstantPointer is the ConstantStruct() whose .value needs to be set when we
	// read the string from the file foo/bar.  content is set when reading the included
	// path.  Ideally perhaps, each include string file should be read only once, but with
	// the current use of this feature that is goldplating.
	public var includedStrings : Array<{path: String, stringConstantPointer: Flow, content: String}>;
	// Names that are exported; null=no export section=all variables exported
	public var exports : Map<String,Bool>;
	// The top-level declarations
	public var toplevel : Map<String,Flow>;
	// The unit tests
	public var unittests : Array<Flow>;
	// Declarations in source file order
	public var declarations : Array<String>;

	// Explicit type declarations by the user, e.g., makeAspect : (string, [string]) ->
	// Aspect; & nothing if the user did not declare a type & also (for now) nothing if he
	// did not declare it toplevel, e.g., \ x : int ->, results in no entry.  This map is
	// used to populate FlowInterpreter.userTypeDeclarations.
	public var userTypeDeclarations : Map<String,TypeDeclaration>;

	// If we include a module while it is not doneParsing, we know there is a cyclic module import.
	public var doneParsing : Bool;

	// object path prefix
	public var objectPath  : String;

	// precompiled:
	public var precompiled : Bool;

	// content:
	public var content (default, null) : String;
	private var hash    : String;
}
