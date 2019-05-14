// editor type: affects stacktrace printin & others
enum EditorType { Other; Emacs; }

// Global compiler options
class Options
{
  public static var DEBUG  = false;
  public static var EDITOR = Other;
#if sys
  public static var DEPS   =  true; 
#else
  public static var DEPS   =  false; 
#end
  private static var DEPS_specified = false;

  public function new (args : Array<String>) {
	if (args.length == 0) { 
	  printHelp();
	  return;
	}
  }

  public static function init() {
  	DEBUG  = false;
  	EDITOR = Other;
	#if sys
	var debug = Sys.getEnv("FLOW_DEBUG");
	if (debug != null && debug != "")
	  DEBUG = true;
	var editor = Sys.getEnv("FLOW_EDITOR");
	if (editor == "emacs")
	  EDITOR = Emacs;
	#end
  }

  public static function parse(args : Array<String>, index: Int) : Int {	
	var arg = args[index];
	if (arg == "--trace") {
	  DEBUG = true;
	  ++ index;
	} else if (arg == "--emacs") {
	  EDITOR = Emacs;
	  ++ index;
	} else if (arg == "--deps") {
	  DEPS = true;
	  DEPS_specified = true;
	  ++ index;
	} else if (arg == "--no-deps") {
	  DEPS = false;
	  DEPS_specified = true;
	  ++ index;
	} 
	return index;
  }

  private function parseOptions(args : Array<String>, i : Int) : Int {
	debug = 0;
	dumpBytes = null;
	timePhases = false;
	exportResult = null;
	unittest = false;
	file = null;
	includes = [];
	root = '.';
#if neko
	// Take the root path from the module: neko foo/bar/flow.n -> 'foo/bar'
	var mname = neko.vm.Module.local().name;
	mname = StringTools.replace(mname, '\\', '/');
	if (mname.lastIndexOf('/') > 0) {
		root = mname.substr(0, mname.lastIndexOf('/'));
		while (StringTools.endsWith(root, '/'))
			root = root.substr(0, root.length-1);
		if (StringTools.endsWith(root, '/bin'))
			root = root.substr(0, root.length-4);
	}
#end
	batchCompilation = false;
	swfBatchCompilation = false;
	jsOverlayCompilation = false;
	jsReportSizes = false;
	noStop = false;
	cpp = null;
	java = null;
	csharp = null;
	voices = new Map();
	vozip = '';
	duplication = false;
	exactOnly = false;
	exportType = null;
	findDefinition = null;
	findDeclaration = null;
	flowPreview = null;
	dontrun = false;
	dontlog = false;
	dontlink= false;
	optimise = false;
	deadcodeelim = true;
	noDelet = false;
	inlineLimit = 0;
	callgraph = null;
	useStats = false;
	profileInfo = null;
	shareStrings = false;
	redundantImports = false;
	redundantFunctions = false;
	dumpSymbols = false;
	dumpDot = false;
	dumpIds = null;
	dumpCallgraph = null;
	incremental = true;
	rebuild     = false;
	objectPath = null;
	disassembly = false;
	normalizeAsm = false;
	instrument = null;
	runcount = false;
	refactor = null;
	rules = null;
	recursive = false;
	allFiles = false;
	indirect = false;
	verbose = false;
	syntaxCheck = false;
	extStructDefs = false;
	prefix = "";
	resourceFile = "resources/resource9.swf";
	fontconfigFile = "resources/fontconfig.json";
	var overrideFontconfig = true;
	extractTexts = false;
	xliff = false;
	extractRawFormat = false;
		
	while (i < args.length) {
	  var i2 = Options.parse(args, i);
	  if (i != i2) {
		i = i2;
	  } else {
		var arg = args[i++];
		if (arg == "--debug") {
		  debug = 1;
		} else if (arg == "--verbose-debug") {
		  debug = 2;
		} else if (arg == "--time-phases") {
		  timePhases = true;
		} else if (arg == "--export-result") {
		  exportResult = args[i];
		  ++i;
		} else if (arg == "--verbose") {
		  verbose = true;
		} else if (arg == "--syntax-check") {
		  syntaxCheck = true;
		} else if (arg == "--prefix") {
		  prefix = args[i];
		  ++i;
		} else if (arg == "--dump-object") {
		  dumpBytes = args[i];
		  ++i;
		} else if (arg == "--unittest") {
		  unittest = true;
		} else if (arg == "--help") {
		  printCmdLine();
		  printHelp();
		  return i;
		} else if (arg == "--root") {
		  root = args[i++];
		} else if (arg == "-I") {
		  var rpath = args[i++];
		  rpath = StringTools.replace(rpath, '\\', '/');
		  includes.push(rpath);
		} else if (arg == "--bytecode") {
		  bytecode = args[i++];
		} else if (arg == "--compile" || arg == "-c") {
		  bytecode = args[i++];
		  dontrun = true;
		} else if (arg == "--upload") {
			uploadBytecode = true;
		} else if (arg == "--batch-compile") {
		  batchCompilation = true;
		  dontrun = true;
		  break;
		} else if (arg == "--batch-compile-swf") {
		  swfBatchCompilation = true;
		  dontrun = true;
		  break;
		} else if (arg == "--js-overlay") {
		  jsOverlayCompilation = true;
		  dontrun = true;
		  break;
		} else if (arg == "--js-report-sizes") {
		  jsReportSizes = true;
		} else if (arg == "--stop") {
		  noStop = true;
		} else if (arg == "--no-stop") {
		  noStop = false;
		} else if (arg == "--changed-files") {
		  ++i;
		} else if (arg == "--last-good-time") {
		  lastGoodTime = args[i];
		  ++i;
		} else if (arg == "--haxe") {
		  haxe_target = args[i];
		  dontrun = true;
		  ++i;
		} else if (arg == "--js") {
		  js_target = args[i];
		  dontrun = true;
		  ++i;
		} else if (arg == "--swf") {
		  swf = args[i];
		  dontrun = true;
		  ++i;
		} else if (arg == "--cpp") {
		  cpp = args[i];
		  ++i;
		  dontrun = true;
		} else if (arg == "--java") {
		  java = args[i];
		  ++i;
		  allNodeTypes = true;
		  dontrun = true;
		} else if (arg == "--csharp") {
		  csharp = args[i];
		  ++i;
		  allNodeTypes = true;
		  dontrun = true;
		} else if (arg == "--extract") {
		  extractTexts = true;	
		  voices.set(args[i++], true);
		} else if (arg == "--extract-raw-format") {
		  extractRawFormat = true;
		} else if (arg == "--xliff") {
		   xliff = true;
		} else if (arg == "--xliffpath") {
		   xliffpath = args[i++];
		} else if (arg == "--insertvo") {
		  vozip = args[i++];
		} else if (arg == "--duplication") {
		  duplication = true;
		} else if (arg == "--exact-only") {
		  exactOnly = true;
		} else if (arg == "--export-type") {
		  exportType = args[i++];
		} else if (arg == "--find-definition") {
		  findDefinition = args[i++];
		} else if (arg == "--find-declaration") {
		  findDeclaration = args[i++];
		} else if (arg == "--flow-preview") {
		  flowPreview = args[i++];
		} else if (arg == "--dontrun") {
		  dontrun = true;
		} else if (arg == "--dontlog") {
		  dontlog = true;
		} else if (arg == "--dontlink") {
		  dontlink = true;
		  dontrun  = true;
		} else if (arg == "--optimise") {
		  optimise = true;
		} else if (arg == "--dce") {
		  deadcodeelim = true;
		} else if (arg == "--no-dce") {
		  deadcodeelim = false;
		} else if (arg == "--no-delet") {
		  noDelet = true;
		} else if (arg == "--inline-limit") {
		  inlineLimit = Std.parseInt(args[i]);
		  // Incremental is not compatible with inlining!
		  incremental = false;
		  ++i;
		} else if (arg == "--debuginfo") {
		  debugInfoFile = args[i];
		  ++i;
		} else if (arg == "--callgraph") {
		  callgraph = args[i];
		  ++i;
		} else if (arg == "--share-strings") {
		  shareStrings = true;
		} else if (arg == "--instrument") {
		  instrument = args[i];
		  ++i;
		} else if (arg == "--use-stats") {
		  useStats = true;
		} else if (arg == "--redundant-imports") { 
		  useStats = true;
		  redundantImports = true;
		} else if (arg == "--redundant-functions") { 
		  useStats = true;
		  redundantFunctions = true;
		} else if (arg == "--dump-symbols") { 
		  dumpSymbols = true;
		} else if (arg == "--dump-dot") { 
		  dumpDot = true;
		} else if (arg == "--dump-ids") { 
		  dumpIds = args[i++];
		} else if (arg == "--dump-callgraph") { 
		  dumpCallgraph = args[i++];
		} else if (arg == "--incremental"  || arg == "-i") { 
		  incremental = true;
		} else if (arg == "--no-incremental") { 
		  incremental = false;
		} else if (arg == "--disassembly") { 
		  disassembly = true;
		} else if (arg == "--normalize-asm") { 
		  normalizeAsm = true;
		} else if (arg == "--rebuild") { 
		  rebuild = true;
		} else if (arg == "--object-path") {
		  objectPath = args[i];
		  ++i;
		} else if (arg == "--profile-info") {
		  profileInfo = args[i];
		  ++i;
		} else if (arg == "--runcount") {
		  runcount = true;
		} else if (arg == "--refactor-rules") {
		  rules = args[i];
		  ++i;
		} else if (arg == "--refactor") {
		  refactor = args[i];
		  recursive = false;
		  allFiles  = false;
		  indirect  = false;
		  ++i;
		} else if (arg == "--refactor-rec") {
		  refactor = args[i];
		  recursive = true;
		  allFiles  = false;
		  indirect  = false;
		  ++i;
		} else if (arg == "--refactor-all") {
		  refactor = args[i];
		  recursive = false;
		  allFiles  = true;
		  indirect  = false;
		  ++i;
		} else if (arg == "--refactor-files") {
		  refactor = args[i];
		  recursive = false;
		  allFiles  = false;
		  indirect  = true;
		  ++i;
		} else if (arg == "--refactor-sfx") {
		  refactorSfx = args[i];
		  ++ i;
		} else if (arg == "--ext-structdefs") {
			extStructDefs = true;
		} else if (arg == "--resource-file" || arg == "--resource") {
		  resourceFile = args[i++];
		  if (!StringTools.endsWith(resourceFile, ".swf")) {
		  	resourceFile += ".swf";
		  }
		  if (resourceFile.indexOf("/") == -1 && resourceFile.indexOf("\\") == -1) {
		  	resourceFile = "resources/" + resourceFile;
		  }
		} else if (arg == "--fontconfig-file") {
			fontconfigFile = args[i++];
			overrideFontconfig = false;
		} else if (arg == "--") {
		  break;
		} else {
		  if (arg.charAt(0) == "-") {
			Util.println("Unknown option:" + arg);
		  }
		  if (file != null) {
			Util.println("Warning: Ignoring previous file " + file);
		  }
		  file = arg;
		}
	  }
	}


	#if sys
	if (sys.FileSystem.exists("flow.config")) {
		// Read flow.config and set parameters accordingly
		var config = sys.io.File.getContent("flow.config");
		config = StringTools.replace(config, "\r", "");
		var options = config.split("\n");
		for (o in options) {
			if (!StringTools.startsWith(StringTools.ltrim(o), "#")) {
				var opts = [for (s in o.split("=")) StringTools.trim(s)];
				if (opts.length == 2) {
					var opt = opts[0];
					var optval = opts[1];
					if (verbose) {
						Util.println("Using '" + o + "' from flow.config");
					}
					if (opt == "include") {
						var rpath = StringTools.replace(optval, '\\', '/');
						var incls = rpath.split(',');
						includes = includes.concat(incls);
					} else if (opt == "resource-file") {
						resourceFile = optval;
						if (!StringTools.endsWith(resourceFile, ".swf")) {
							resourceFile += ".swf";
						}
						if (resourceFile.indexOf("/") == -1 && resourceFile.indexOf("\\") == -1) {
							resourceFile = "resources/" + resourceFile;
						}
					} else if (opt == "file" && file == "") {
						file = StringTools.replace(optval, '\\', '/');
					} else if (opt == "fontconfig-file") {
						// do not override command line option if present
						if (overrideFontconfig)
							fontconfigFile = optval;
					} else if (opt == "media-path") {
						//ignore
					} else if (opt == "flowcompiler") {
						//ignore
					} else if (opt == "server") {
						//ignore
					} else if (StringTools.startsWith(opt, "objsync")) {
						//ignore, implemented in new compiler
					} else {
						Util.println("Unknown option in flow.config: '" + o + "'");
					}
				}
			}
		}
	}
	#end

	if (incremental && deadcodeelim && (bytecode != null || dontlink || batchCompilation)) {
		// Util.println("Dead code is not compatible with incremental bytecode. Disabling! " + bytecode);
		deadcodeelim = false;
	}

	if (objectPath == null) {
		objectPath = if (swfBatchCompilation || swf != null) "object-swf" else "object";
	}

	// use deps as default only in the batch mode:
	//Util.println("DPS_cpes=" + DEPS_specified + " swfBatchCompilation=" + swfBatchCompilation + " batchCompilation=" + batchCompilation);
	if (!DEPS_specified)
	  if (!swfBatchCompilation && !batchCompilation)
		DEPS = false;

	return i;
  }

  static function printHelp() {
		Util.println(
			"Usage: flow.n [options] files

Options:
--help           Print this help
--trace          Trace the compilation process
--verbose        Print more detailed trace of batch operations
--verbose-debug  Print a very verbose trace of the execution
--time-phases    Print info about how how the different phases of the compiler takes
--dontlog        Do not log error messages to .compile-errors
-I DIR           Include a directory for finding files
--debug          Print a trace of the execution when interpreting, including callstack of errors

Compilation:
--compile FILE            Compile to bytecode without running it
-c FILE                   (same)
--swf FILE                Compile to .SWF
  --resource-file FILE    What resource file to link to with fonts in the SWF target. Default is \"resources/resource9.swf\".
--js FILE                 Compile to JavaScript
  --js-report-sizes       Outputs a dump of how big the resulting output from each .flow input file is in the output
  --fontconfig-file FILE  Load font configuration file
--cpp DIR                 Compile to C++ (*.h and *.cpp files in target dir)
--java DIR                Compile to Java (*.java files in target dir) (experimental)
--csharp DIR              Compile to C# (*.cs files in target dir) (experimental)
--haxe FILE               Compile through haXe code. FILE can end with .swf, .js or .n (experimental)
--bytecode FILE           Compile to bytecode & run it (unless --dontrun)
--upload                  Upload bytecode file to the server
--unittest                Run all unit tests embedded in the code
--dontrun                 Do not run the program (=main())
                          --dontrun --unittest --bytecode foo will generate code & run the unittests
--debuginfo FILE          Dump debug info to file
--dce                     Dead code elimination: Only keep top-level ids referenced transitively by main
--optimise                Aggressively optimise the code to bloat
  --inline-limit N        When is a function too big to inline? Default is 42
  --no-delet              Debugging: do not run the last de-let phase
--share-strings           Identical strings are replaced by a global variable to reduce the bytecode file size
--changed-files FILE      Reads the given file for a list of files, one per line, that have changed. Aborts compilation
                          if the current compile target does not use those files to save time. (Supports output from
                          'svn update')


--last-good-time yyyyMMddHHmmss  Checks whether any of the required files have changed since the given time. Skips
                                 stops compilation if not.

--incremental        Turn on separate compilation mechanism. For bytecode compilation only. (Default is on)
-i                   (same)
--batch-compile      [options] <dst> <src> ...
--batch-compile-swf  [options] <dst> <src> ...
  --object-path      Path for storing bytecode chunks
  --force-rebuild    Force rebuilding all .byte files
--js-overlay         [options] <dst> <src> ...
--no-stop            Keep batch compilation running after error
--dontlink           Do not produce any output file. Useful for type checking
--ext-structdefs     Write additional information for fields types in StructDefs

Instrumentation:
--instrument name,name,name  Instruments all calls to the given names to print debugging info and result value

Extraction and processing of speak:
--extract NAME          Extracts all strings occurring in calls to the NAME function
  --extract-raw-format  Save all collected strings into special format to be processed by votranslate tool later (see extractvo.bat)
--xliff                 Extracts all ui texts (coach and tagged by _ function) and saves it in xliff format
  --xliffpath FILE      output xliff file path. By default xliff file is written in current dir.
--insertvo ZIP          Extracts all recorded sounds in the given archive and process them for use

Finding duplicate code:
--duplication       Looks for source code which is almost identical across different sites
  --exact-only      Additional flag to request exact duplication only

Analyzing code:
--syntax-check FILE      Quick syntax-only check
--find-definition NAME   Looks up the given name and provides the location and definition
--callgraph FILE         Exports a call graph of the code
--use-stats              Produce statistics on imports and usage
  --redundant-imports    Report unneeded import statements. Enables --use-stats.
  --redundant-functions  Report unneeded functions. Enables --use-stats.
  --dump-symbols         Save a dump of all symbols. Requires --use-stats.
  --dump-dot             Save .dot and .svg graph of imports. Requires --use-stats.

--disassembly    Disassembly bytecode
--normalize-asm  'Normalize' disassembled bytecode (remove absolute addrs & replace struct id's byenames)

--export-type TYPE            Parse the code, and print out the type of a given struct or union
--flow-preview FILE:LINE:COL  Extract the expression at this point to a separate program to allow previewing its value

--runcount  Count number of instructions executed in neko (only implemented
            in BytecodeRunner.hx, not, e.g., BytecodeRunnerO.hx)

Exporting of files: (FILE can be \"stdout\")
--export-result FILE  Export the final value to a file

--      This marks the end of options to this compiler. Parameters of the form \"key=value\" will
        make getUrlParameter(\"key\") return \"value\" in the flow code

Refactorings:
--refactor-sfx SUFFIX    Add suffix to source file name. Strongly recommended for experimentation (optional)
--refactor-rules FILE    Rules file name

   the one of the next switches specifies source files set for refactoring:
--refactor FILE          Single file
--refactor-files FILE    File that contains list of names of files to refactor
--refactor-all ROOT-DIR  Refactor all .flow files in specified dir and subdirs
--refactor-rec FILE      Refactor file and all imported files (not implemented correctly yet)

");
	}

  public var debug : Int;
  public var dumpBytes : String;
  public var exportResult : String;
  public var timePhases : Bool;
  public var unittest : Bool;
  public var file : String;
  public var root : String;
  public var includes : Array<String>;
  public var modules : Modules;
  public var bytecode : String;
  public var batchCompilation : Bool;
  public var swfBatchCompilation : Bool;
  public var jsOverlayCompilation : Bool;
  public var jsReportSizes : Bool;
  public var noStop : Bool; // keep batch compilation running after error
  public var cpp : String;
  public var java : String;
  public var csharp : String;
  public var extractTexts : Bool;
  public var xliff : Bool;
  public var xliffpath : String;
  public var extractRawFormat : Bool;
  public var haxe_target : String;
  public var js_target : String;
  public var swf : String;
  public var duplication : Bool;
  public var exactOnly : Bool;
  public var exportType : String;
  public var findDefinition : String;
  public var findDeclaration : String;
  public var flowPreview : String;
  public var dontrun : Bool;
  public var dontlog : Bool;
  public var dontlink : Bool;
  public var optimise : Bool;
  public var deadcodeelim : Bool;
  public var noDelet : Bool;
  public var inlineLimit : Int;
  public var debugInfoFile : String;
  public var callgraph : String;
  public var useStats : Bool;
  public var profileInfo : String;
  public var shareStrings : Bool;
  public var instrument : String;
  public var redundantImports : Bool;
  public var redundantFunctions : Bool;
  public var dumpSymbols : Bool;
  public var dumpDot : Bool;
  public var dumpIds : String;
  public var dumpCallgraph : String;
  public var lastGoodTime : String;
  public var incremental : Bool;
  public var refactor : String;
  public var refactorSfx : String; // suffix for refactored files
  public var rules : String;
  public var recursive : Bool;
  public var allFiles : Bool;
  public var indirect : Bool;
  public var prefix : String; // prefix for batch compilation diagnosics
  public var disassembly : Bool;
  public var normalizeAsm : Bool;
  public var rebuild: Bool;
  public var objectPath : String;
  public var runcount : Bool;
  public var verbose : Bool;
  public var syntaxCheck : Bool;
  public var extStructDefs : Bool;
  public var allNodeTypes : Bool;
  public var resourceFile : String;
  public var fontconfigFile : String;
  public var uploadBytecode : Bool;

  // For extracting strings from the code, e.g., for voice over.  List of functions
  // (e.g., "voices") whose string arguments should be extracted & saved in a csv (e.g.,
  // for sending to a vo artist to record samples).
  public var voices : Map<String,Bool>;

  // Zip file containing voice over mp3s to insert
  public var vozip : String;
  
  static public function printCmdLine() {
	if (Options.EDITOR != EditorType.Emacs) {
#if neko
	  if (!neko.Web.isModNeko) {
		Util.println('neko flow.n  ' + Sys.args().join(' '));
	  }
#elseif cpp
	  Util.println('flowneko  ' + Sys.args().join(' '));
#end
	}
  }   
  
}
