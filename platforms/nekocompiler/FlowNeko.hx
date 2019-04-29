import Flow;
import Native;
import Bytecode;
import BytecodeWriter;
import Database;
import Extractor;
import HtmlSupport;
import SwfWriter;
import Refactor;
import Position;
import JsWriter;

import sys.io.File;
import sys.io.Process;
import sys.FileSystem;
import Sys;
import haxe.Http;
import haxe.io.Path;

typedef DFontConfig = {name : String, url : String, embed: Bool, path: String, baseurl: String};

class FlowNeko extends Options {
	static public function main() {
		Assert.memStat("start");
		Options.init();

#if neko
		if (neko.Web.isModNeko) {
			var m = new FlowCgi();
			// use cacheModule in production - but not on development machines
			if (Sys.systemName() != "Windows") {
				neko.Web.cacheModule(m.handleCgiRequest);
			}
			m.handleCgiRequest();
		} else {
			var m = new FlowNeko(Sys.args());
			Errors.closeErrorLog();

			Sys.exit(if (m.runResult) 0 else 1);
		}
#elseif sys
		var m = new FlowNeko(Sys.args());
		Sys.exit(if (m.runResult) 0 else 1);
#end
	}

	public function new(theargs : Array<String>) {
		var args = theargs.filter(function(a) { return a != ""; });
		super(args);
		var ind = parseOptions(args, 0);
		runResult = false;

		includes.unshift(root == '.' ? "lib" : Util.makePath(root, "lib"));

		Errors.dontlog = dontlog;
		if (findDefinition == null && exportType == null)
			Options.printCmdLine();
#if sys
		if (dumpBytes != null) {
			var module = new ObjectModule(dumpBytes, dumpBytes);
			try {
				if (FileSystem.exists(dumpBytes)) {
					var fileContents = File.read(dumpBytes, true).readAll();
					var info = ObjectInfo.unserialize(module, new haxe.io.BytesInput(fileContents), true);
					Util.println(info.dump());
				}
			} catch (s : Dynamic) {
				Options.DEBUG = true; 
				Assert.printExnStack("readFromFile: Exception" + s);
				Util.println(prefix + "Error: " + s);
			}
			return;
		}
#end

		// Optimization: If there are no .flow files changed, we do not need to recompile this guy
		if (batchCompilation || swfBatchCompilation || jsOverlayCompilation) {
			var allRunResultOK = true;
			while (ind != args.length) {
				if (ind + 2 > args.length) {
					Util.println(prefix + "Error: odd parameters number for the batch compilation");
					return;
				}
				var dst = args[ind++];
				if (swfBatchCompilation)
					swf = dst;
				else if (jsOverlayCompilation)
					js_target = dst;
				else
					bytecode = dst;
				file    = args[ind++];
				runResult = false;
				doCompileProgram();
				if (!runResult) {
					if (!noStop)
						return;
					allRunResultOK = false;
				}
			}
			runResult = allRunResultOK;
			if (runResult)
				linkJs();
		} else {
			if (file == null && refactor == null) {
				Util.println("No file given!");
				return;
			}

			doCompileProgram();
		}
	}

	private function doCompileProgram() {
		modules =
			if (incremental && (bytecode != null || dontlink))
				new ObjectModules(includes, objectPath, rebuild);
			else
				new Modules(includes, objectPath, allNodeTypes);
		
		if (refactor != null) {
			Refactor.doRefactorings (this);
			return;
		}

		modules.topmodule = null;
		if (!StringTools.endsWith(file, ".flow")) {
			file += ".flow";
		}

		// Make the path relative to ../flowapps
		file = StringTools.replace(file, "\\", "/");
		if (StringTools.startsWith(file, "./")) file = file.substr(2);
		var relative = file.indexOf("flowapps/");
		if (relative != -1) {
			file = file.substr(relative + "flowapps/".length);
		}

		if (syntaxCheck) {
			var module = modules.newModule(file);
			var contents = FilesCache.content(file);
			module.fullFilename = FileSystem.fullPath(file);

			module.relativeFilename = file;
			module.parse(contents);
			return;
		}

		Profiler.get().profileStart("Rest");
		// Read and parse the module
		Assert.memStat("parseFileAndImports began");
		var needWriteDeps = false;
		runResult = modules.parseFileAndImports(file, run, function (topmodule: Module) { 
				if (dependenciesNotChanged(topmodule)) {
					// Util.println(prefix + "- Skipped " + topmodule.relativeFilename);
					return true;
				}
				needWriteDeps = true;
				if (findDefinition == null && exportType == null)
					Util.println(prefix + "Compiling " + topmodule.relativeFilename + " ...");
				return false;
			});

		if (runResult && Options.DEPS && needWriteDeps) {
			var depsBuf = new StringBuf();
			Assert.check(modules.topmodule != null, "modules.topmodule != null");
			modules.topmodule.writeDependencies(modules, depsBuf);
			Util.writeFile(modules.topmodule.getObjectFileName(".deps"), depsBuf.toString());
		}
		Profiler.get().profileEnd("Rest");
		if (timePhases) {
			Profiler.get().dump("Time");
		}
	}

	private function dependenciesNotChanged(topmodule : Module) : Bool {
		if (Options.DEPS && dontrun) {
			var h = topmodule.readDependencies();
			if (h == null) {
				// Util.println(prefix + "  - Could not find dependencies file, so compiling " + topmodule.name + "...");
			} else {
				for (fname in h.keys()) {
					var fhash = h.get(fname);
					//Util.println(prefix + "  - File " + fname + " md5 hashes: " + fhash + " ?= " + modules.filesCache.hash(fname));
					if (FilesCache.hash(fname) != fhash) {
						Util.println(prefix + "  - File " + fname + " md5 hashes mismatch. Compile " + topmodule.relativeFilename);
						return false;
					}
				}

				if (verbose)
					Util.println(prefix + " - No required files are changed. Skipping compilation of " + topmodule.name + ".flow");
				return true;
			}
		}
		return false;
	}

	// return execution result: false if there were errors
	function run(module : Module) : Bool {
		if (useStats) {
			dumpUseStats();
			return true;
		}

		Assert.memStat("Run");

		if (lastGoodTime != null) {
			// Chek the filestamps of the files, and see if any are newer that the given time
			// lastGoodTime in format: 
			//   01234567890123
			//   yyyyMMddHHmmss. 
			// We want it in 
			//   YYYY-MM-DD hh:mm:ss 
			// format.
			var l = lastGoodTime;
			var formattedtime = l.substr(0, 4) + "-" + l.substr(4, 2) + "-" + l.substr(6, 2) + " " 
				+ l.substr(8, 2) + ":" + l.substr(10, 2) + ":" + l.substr(12, 2);
			var lastGood = Date.fromString(formattedtime).getTime();
			var changed = false;
			var latest = 0.0;
			for (m in modules.modules) {
				var stats = FileSystem.stat(m.fullFilename);
				var changeTime = stats.ctime.getTime();
				latest = Math.max(changeTime, latest);
				if (changeTime > lastGood) {
					changed = true;
				}
			}
			if (!changed) {
				if (verbose)
					Util.println("No required files have changed since " + formattedtime + ". Last change was " + Date.fromTime(latest).toString() + ". Skipping compilation of " + module.name);
				return true;
			} else {
				Util.println("Some required files have changed since " + formattedtime + ". Compiling " + module.name + "...");
			}
		}
				
		if (unittest) {
			//trace('runUnittests() ' + file);
			if (modules.runUnittests(debug)) {
				return false;
			}
		}

		if (module == null) {
			Util.println("Unknown module");
			return false;
		}
		
		modules.checkImports(module);

		if (duplication) {
			Errors.get().doTrace = false; // type errors etc. not interesting when finding cutnpaste code
			var interpreter = modules.linkAst(module);
			var duplication = new FindDuplication(interpreter, exactOnly);
			return true;
		}
		
		if (findDefinition != null) {
			Errors.get().doTrace = false; // type errors etc. not interesting when searching for a definition.
			if (Options.EDITOR == Options.EditorType.Emacs) {
				// parse line:col format
				var sep = findDefinition.indexOf(":");
				if(sep == -1) {
					Util.println("(message \"find-def: invalid token position: \'" + findDefinition + "\'\")");
					return true;
				}
				var line = Std.parseInt(findDefinition.substr(0, sep));
				if(line == null || line == 0) {
					Util.println("(message \"find-def: invalid token position: \'" + findDefinition + "\'\")");
					return true;
				}
				var col = Std.parseInt(findDefinition.substr(sep+1));
				if(col == null || col == 0) {
					Util.println("(message \"find-def: invalid token position: \'" + findDefinition + "\'\")");
					return true;
				}

				//convert to char position:
				var currLine = 0;
				var currCol  = 0;
				var tokPos   = 0;
				while (tokPos < module.content.length) {
					if (currLine == line && currCol == col)
						break;
					if (module.content.charAt(tokPos) == "\n") {
						++ currLine;
						currCol = 0;
					} else {
						++ currCol;
					}
					++ tokPos;
				}
				//Util.println("(message \"TOKPOS: \'" + tokPos + " " + line + " " + col + " " + findDefinition + "\'\")");
				//return true;

				var tok = module.tokenAtPos(tokPos);
				if (tok == -1) {
					Util.println("(message \"find-def: no token at position: \'" + findDefinition + "\'\")");
					return true;
				}
				switch(module.tokenAtIndex(tok)) {
				case Lexer.Token.LName(s): findDefinition = s;
				default: {
					Util.println("(message \"find-def: token at position: \'" + findDefinition + "\' isn't an identifier\")");
					return true;
				}
				}
				//Util.println("EMACS find-def: " + findDefinition);
			}
			var interpreter = modules.linkAst(module);
			var present = function(pos : Position, s) {
				var m = modules.getModuleByFilename(pos.f);
				var p = modules.positionToFileAndBytes(pos);
				if (Options.EDITOR == Options.EditorType.Emacs) {
					var st = p.start;
					if (m != null)
						while (st > 0 && m.content.charAt(st-1) != "\n")
							-- st;
					Util.println("(a9flow-goto-file-line \"" + FileSystem.fullPath(pos.f) + "\" " + pos.l + " " + (p.start - st) + ")");
				} else {
					//Util.println("s=" + pos.s + " e=" + pos.e);
					Util.println(pos.f + ":" + pos.l + " (" + p.file + ":" + pos.l + "@" + p.start + "-" + (p.start + p.bytes) + ") = " + s);
				}
			};
						
			var site = interpreter.topdecs.get(findDefinition);
			if (site != null) {
				var pos = FlowUtil.getPosition(site);
				present(pos, findDefinition + " = " + Prettyprint.prettyprint(site));
				return true;
			} else {
				// Maybe it is a type?
				var t = interpreter.userTypeDeclarations.get(findDefinition);
				if (t != null) {
					var pos = t.position;
					present(pos, Prettyprint.prettyprintTypeScheme(t.type, interpreter.typeEnvironment.normalise));
					return true;
				} else {
					if (Options.EDITOR == Options.EditorType.Emacs) {
						Util.println("(message \"find-def: " + findDefinition + " not found\")");
					} else {
						Util.println("Error: " + findDefinition + " not found");
					}
					return false;
				}
			}
		}
		
		Assert.memStat("Run-2");
		if (callgraph != null) {
			Errors.get().doTrace = false; // type errors etc. not interesting when searching for a definition.
			var interpreter = modules.linkAst(module);
			var cg = new CallGraph();
			cg.make(interpreter, callgraph);
			return true;
		}

		if (exportType != null) {
			var interpreter = modules.linkTypecheck(module, debug);
			ExportType.exportType(exportType, interpreter.typeEnvironment);
			return true;
		}
		
		// Demand there is a main() unless we are unittesting or extracting vo
		var mainCode = module.toplevel.get("main");
		var doCompile = bytecode != null || cpp != null || java != null || csharp != null || haxe_target != null || js_target != null || swf != null || syntaxCheck || dontlink || extractTexts || xliff || dumpIds != null || dumpCallgraph != null;
		if (mainCode == null) {
			if (unittest) {
				// Not a problem
				return Errors.getCount() == 0;
			}
			if (!dontrun) {
				Util.println('I could not find main() {...}. Either specify --dontrun or give me a main() function.');
				return false;
			} else if (doCompile) {
				Util.println("WARNING: Program does not have 'main()' function, its resulting bytecode will not run.");
			}
		}

		var result = null;
		Assert.memStat("Run-3");
		var interpreter = modules.linkTypecheck(module, debug);
		Assert.memStat("Run-4");

		if (interpreter != null) {
			if (doCompile) {
				var program : Program = {userTypeDeclarations: interpreter.userTypeDeclarations,
											 typeEnvironment: interpreter.typeEnvironment,
											 modules: modules, 
											 declsOrder: interpreter.order,
											 topdecs: interpreter.topdecs};
				if (optimise) {
					Optimiser.optimise(program, noDelet, inlineLimit, function(p) {
							//Errors.print('AFTER OPTIMISATION');
							//traceprogram(program);
							if (shareStrings) {
								ShareStrings.shareStrings(p);
							}
							bytecodeRun(p);
						});
					return true;
				} else {
					Assert.memStat("Run-4");
					bytecodeRun(program);
				}
			} else {
				if (mainCode == null) {
					if (! dontrun) trace('Either specify --dontrun or give a main() function.'); 
				} else {
					var code = Call(mainCode, [], null);
					//trace('typecheck(main()) ' + file);
					var t = interpreter.typecheck(code);
					if (t != null && ! dontrun) {
						//trace('evalTopdecs() ' + file);
						interpreter.evalTopdecs();
						//trace('eval(main()) ' + file);
						result = interpreter.eval(code);
					}
				}
			}
			if (dumpIds != null) {
				doDumpIds(interpreter);
			}
			if (dumpCallgraph != null) {
				Errors.get().doTrace = false; // type errors etc. not interesting when searching for a definition.
				var cg = new CallGraph();
				cg.makeForDark(interpreter, modules, dumpCallgraph);
				return true;
			}
		}
				
		if (exportResult != null) {
			Util.writeFile(exportResult, Prettyprint.prettyprint(result, ''));
		}

		return xliff || (result != null || dontrun) && Errors.getCount() == 0;
	}

	function bytecodeRun(p : Program) : Void {
		if (instrument != null) {
			Instrument.instrument(p, instrument);
		}

		if (deadcodeelim) {
			p = new DeadCodeElimination(p).program;
		}
	
		if (inlineLimit > 0) {
			Profiler.get().profileStart("Inlining");
			Inlining.inlineCalls(p, inlineLimit, verbose);
			Profiler.get().profileEnd("Inlining");
		}
		// we do it here to use dead code elimination
		if (extractTexts || xliff) {
			Errors.get().doTrace = false;
			var interpreter = modules.linkAst(modules.getModule(file));
			interpreter.evalTopdecs();
			interpreter.order = p.declsOrder;
			var extractor = new Extractor(modules, interpreter, voices);
			extractor.xliff = xliff;
			extractor.xliffpath = xliffpath;
			extractor.extractRawFormat = extractRawFormat;
			var lastSlash = file.lastIndexOf("/");
			if (lastSlash > 0)
				Extractor.soundPath = file.substr(0, lastSlash);
			else
				Extractor.soundPath = "";

			extractor.extract();
			if (vozip != '' && !xliff) {
				extractor.insertvo(vozip);
			}
			return;
		}

		if (haxe_target != null) {
			compileThroughHaxe(p);
			return;
		}
		if (js_target != null) {
			compileToJs(p);
			return;
		}
		if (cpp != null) {
			compileToCpp(p);
			return;
		}
		if (java != null) {
			compileToJava(p);
			return;
		}
		if (csharp != null) {
			compileToCSharp(p);
			return;
		}
		if (swf != null) {
			// Try turning on simple optimizations per default!
			compileToSwf(p, true);
			return;
		}
		var debugInfo = new DebugInfo();
		var encoder = new BytecodeWriter(extStructDefs);
				
		var names = new Names();
		var bytes;
		Assert.memStat("bytecodeRun-1");
		try {
			Profiler.get().profileStart("Compile");
			bytes = encoder.compile(p, debugInfo, names);
			Assert.memStat("bytecodeRun-2");
			Profiler.get().profileEnd("Compile");
			if (bytecode != null) {
				var bytecodefile = File.write(bytecode, true);
				bytecodefile.writeBytes(bytes, 0, bytes.length);
				bytecodefile.close();

				if (uploadBytecode) {
					uploadBytecodeFile(bytecode, bytes.length);
				}
			}
		} catch (e : Dynamic) {
			Util.println("Could not produce bytecode: " + e);
     		Util.println(Assert.callStackToString(haxe.CallStack.exceptionStack()));
			return;
		}

		if (debugInfoFile != null) {
			try {
				debugInfo.DumpToFile(debugInfoFile);
			} catch (e : Dynamic) {
				Util.println("Could not output debug info to file: " + e);
				Util.println(Assert.callStackToString(haxe.CallStack.exceptionStack()));
			}            
		}

		if (disassembly) {
			// Disassemble the file
			var file1 = File.read(bytecode, true);
			var bytes1 = file1.readAll();
			file1.close();
			var bytesInput1 = new BytesInput(bytes1, 0, bytes1.length);
			var disassembler = new BytecodeDisassembler(bytesInput1, debugInfo);
			disassembler.disassemble(names, normalizeAsm);
		}
										
		if (!dontrun) {
			Profiler.get().profileStart("Run");
			// Immediately read and run it
			var file = File.read(bytecode, true);
			var bytes = file.readAll();
			file.close();
												
			var bytesInput = new BytesInput(bytes, 0, bytes.length);
			var runner = new BytecodeRunner();
			try {
				runner.init(bytesInput, debugInfo);
				runner.run();
				if (runcount) Util.println("" + runner.runcount);
				// runner.dumpstack();
				Profiler.get().profileEnd("Run");
			} catch (e : Dynamic) {
				Util.println("Could not run bytecode: " + e);
				runner.printCallstack();
				Util.println(Assert.callStackToString(haxe.CallStack.exceptionStack()));
			}
		}
	}

	private static inline var UPLOAD_SCRIPT_URL = "https://localhost/flow/php/uploadbytecode.php";
	//private static inline var UPLOAD_SCRIPT_URL = "localhost:8000/php/uploadbytecode.php";
	#if neko
	private static var make_md5 = neko.Lib.load("std","make_md5", 1);
	#end

	function uploadBytecodeFile(path : String, length : Int) {
		try {
			Util.println("Uploading uploads/" + bytecode + "...");
			var content = File.getBytes(bytecode);
			#if neko
			var hash : String = haxe.io.Bytes.ofData(make_md5(content.getData())).toHex();
			// Neko VM does not support SSL. Wget does not support multipart form data.
			// So using curl here.
			Util.println("> curl " + UPLOAD_SCRIPT_URL + " -k -Fhash=" + hash + " -Fbytecode=@" + bytecode);
			Sys.command("curl", [UPLOAD_SCRIPT_URL, "-k", "-Fhash=" + hash, "-Fbytecode=@" + bytecode]);
			#else
			Util.println("Upload not supported on this platform");
			#end
		} catch (e : Dynamic) {
			Util.println("Could not upload bytecode file: " + e);
			Util.println(Assert.callStackToString(haxe.CallStack.exceptionStack()));
		}
	}
		
	function compileThroughHaxe(p : Program) {
		if (FileSystem.exists("FlowProgram.hx")) {
			throw "FlowProgram.hx already exists. Aborting.";
		}
		var output = File.write("FlowProgram.hx", false);
		var hw = new HaxeWriter(p, output, StringTools.endsWith(haxe_target, ".js"));
		output.close();

		Profiler.get().profileStart("Compile haXe");
				
		var args = ["-main", "FlowProgram"];
		if (root != '.') {
			args.push('-cp');
			args.push(root+'/platforms/nekocompiler');
			args.push('-cp');
			args.push(root+'/platforms/common/haxe');
		}
		if (StringTools.endsWith(haxe_target, ".n")) {
			args.push("-neko");
			args.push(haxe_target);
		} else if (StringTools.endsWith(haxe_target, ".js")) {
			args.push("-js");
			args.push(haxe_target);
		} else {
			args.push("-swf9");
			args.push(haxe_target);
			args.push("-swf-version");
			args.push("11");
			args.push("-swf-header");
			args.push("1024:600:30:FFFFFF");
			args.push("-swf-lib");
			args.push(resourceFile);
			if (debug > 0) {
				args.push("-debug");
			}
		}
				
		args.push("FlowProgram.hx");
		Sys.command("haxe", args);
				
		Profiler.get().profileEnd("Compile haXe");
		deleteTempFile("FlowProgram.hx");
		return;
	}

	var js_group : JsOverlayGroup;

	function compileToJs(p : Program) {
		if (FileSystem.exists(js_target)) {
			try {
				FileSystem.deleteFile(js_target);
			} catch (e : Dynamic) {
				Errors.report("Internal error: failed to delete " + js_target);
			}
		}

		if (js_group == null) {
			js_group = new JsOverlayGroup(debug > 0, js_target, jsReportSizes);
			js_group.compileMain(p);

			if (!jsOverlayCompilation)
				linkJs();
		} else {
			js_group.compileOverlay(p, js_target);
		}
	}

	function linkJs() {
		if (js_group == null)
			return;

		var tmpfiles = [];
		var baseName = Path.withoutExtension(js_target);

		var args = [];
		if (root != '.') {
			args.push('-cp');
			args.push(root+'/platforms/nekocompiler');
			args.push('-cp');
			args.push(root+'/platforms/common/haxe');
		}
		if (debug > 0) {
			args.push("-debug");
		}

		var fontconfig : {styles : Dynamic, webfontconfig : Dynamic, dfonts : Array<DFontConfig>};
		try {
			fontconfig = haxe.Json.parse(getFileContent(fontconfigFile));
		} catch (e : Dynamic) {
			Errors.report("Error parsing font config file: " + e);
			throw e;
		}
		if (fontconfig != null) {

			// Save the webfont config to be loaded at runtime
			if (fontconfig.webfontconfig != null) {
				var tmpWebFontConfigFile = baseName + "_webfont_config_tmp.json";
				File.saveContent(tmpWebFontConfigFile, haxe.Json.stringify(fontconfig.webfontconfig));
				tmpfiles.push(tmpWebFontConfigFile);

				args.push("-resource");
				args.push(tmpWebFontConfigFile + "@webfontconfig");
			}

			// Save the flow font to css styles conversions
			if (fontconfig.styles != null) {

				// Create the same styles hash, but converting all the flow font names to lowercase
				var oldStyles = fontconfig.styles;
				var newStyles = {};
				for (fontname in Reflect.fields(oldStyles))
					Reflect.setField(newStyles, fontname.toLowerCase(), Reflect.field(oldStyles, fontname));

				var tmpFontStylesFile = baseName + "_fontstyles_tmp.json";
				File.saveContent(tmpFontStylesFile, haxe.Json.stringify(newStyles));
				tmpfiles.push(tmpFontStylesFile);

				args.push("-resource");
				args.push(tmpFontStylesFile + "@fontstyles");
			}

			// Save the the dfonts field with the font names and URLs to be loaded at runtime
			if (fontconfig.dfonts != null) {
				var tmpDFontsFile = baseName + "_dfonts_tmp.json";
				File.saveContent(tmpDFontsFile, haxe.Json.stringify(fontconfig.dfonts));
				args.push("-resource");
				args.push(tmpDFontsFile + "@dfonts");
				tmpfiles.push(tmpDFontsFile);
			} else {
				Errors.report("Warning: Empty dfonts field in font config file");
			}

		} else {
			Errors.report("Warning: Missing font configuration file");
		}

		js_group.link(args);
		js_group = null;

		for (tmpfile in tmpfiles) {
			try {
				FileSystem.deleteFile(tmpfile);
			} catch (e : Dynamic) {
				Errors.report("Failed to delete temporary file: " + tmpfile);
			}
		}
	}

	#if sys
	private function embedDFont(dfont : DFontConfig, args : Array<String>, tmpfiles : Array<String>) : Void {
		var content : String;
		var source : String;
		if (dfont.path != null) {
			try {
				content = getFileContent(dfont.path);
				source = dfont.path;
			} catch (e : Dynamic) {
				Errors.report("Error parsing dfont file: " + e);
				throw e;
			}
		} else {
			content = downloadFile(dfont.url);
			source = dfont.url;
			if (content == null) {
				Errors.print("Warning: Error downloading dfont file from " + dfont.url);
				return;
			}
		}

		if (content == null)
			return;

		var indexjson : Dynamic;
		try {
			indexjson = haxe.Json.parse(content);
		} catch (e : Dynamic) {
			Errors.report('Warning: Error parsing JSON font file: $source. Embedding skipped.');
			return;
		}

		if (dfont.baseurl != null)
			indexjson.basepath = dfont.baseurl;
		else
			indexjson.basepath = dfont.url.substr(0, dfont.url.lastIndexOf("/")) + "/";

		indexjson.crossOrigin = false;

		var tmpfile = dfont.name + "_index.json";
		File.saveContent(tmpfile, haxe.Json.stringify(indexjson));
		tmpfiles.push(tmpfile);

		args.push("-resource");
		args.push(tmpfile + "@" + dfont.name);
	}
	#end

	#if sys
	private function getFileContent(path : String) : String {
		path = getFileContentWithInclude(path);
		if (!sys.FileSystem.exists(path)) {
			if (haxe.io.Path.isAbsolute(path)) {
				throw 'File not found: $path';
			} else {
				// Try to look for the file relative to the flow root dir
				path = haxe.io.Path.join([root, path]);
				if (!sys.FileSystem.exists(path))
					throw 'File not found: $path';
			}
		}
		return sys.io.File.getContent(path);
	}

	private function getFileContentWithInclude(filename : String) : String {
		if (FileSystem.exists(filename)) {
			return FileSystem.fullPath(filename);
		} else {
			for (i in includes) {
			    var f = Util.makePath(i, filename);
				if (FileSystem.exists(f)) {
					return FileSystem.fullPath(f);
				}
			}
			// Check the flow file root
			var f = Util.makePath(root, filename);
			if (FileSystem.exists(f)) {
				return FileSystem.fullPath(f);
			}			
			Errors.report("Could not find " + filename + ". Use -I <path>");
			return filename;
		}
	}
	#end

	function makeEmptyDir(name : String) {
		if (FileSystem.exists(name)) {
			if (!FileSystem.isDirectory(name)) {
				Errors.report("Internal error: "+name+' already exists and is not a directory');
			}
			for (f in FileSystem.readDirectory(name)) {
				try {
					FileSystem.deleteFile(name + "/" + f);
				} catch(x : Dynamic) {
					Errors.report("Internal error: could not delete "+name+'/'+f);
				}
			}
		} else {
			try {
				FileSystem.createDirectory(name);
			} catch (e : Dynamic) {
				Errors.report("Internal error: could not create directory " + name);
			}
		}
	}

	#if sys
	// Returns the content of the file as a string
	function downloadFile(url : String) : String {
		var output : String = new sys.io.Process("curl", [url]).stdout.readAll().toString();
		return output;
	}
	#end

	function compileToCpp(p : Program) {
		makeEmptyDir(cpp);

		var hw = new CppWriter(includes, p, debug > 0, 'native_program', cpp, extStructDefs);

		return;
	}

	function compileToJava(p : Program) {
		makeEmptyDir(java);

		var hw = new JavaWriter(p, debug > 0, 'javagen', java, extStructDefs);

		return;
	}

	function compileToCSharp(p : Program) {
		makeEmptyDir(csharp);

		var hw = new CSharpWriter(p, debug > 0, 'flowgen', csharp, extStructDefs);

		return;
	}

	function compileToSwf(p : Program, optSimple : Bool) {
		var debugInfo = new DebugInfo(null);
		var encoder = new SwfWriter(debug, optSimple);
		var names = new SwfNames();
		var bytes;
		try {
			Profiler.get().profileStart("Compile SWF");
			bytes = encoder.compile(p, debugInfo, names);
			Profiler.get().profileEnd("Compile SWF");

			var swfnodir = haxe.io.Path.withoutDirectory(swf);

			var swffileName = swfnodir + "-" + StringTools.lpad(Std.string(Std.random(65535)), "0", 4) + ".swf";
			var swffile = File.write(swffileName, true);
			swffile.writeBytes(bytes, 0, bytes.length);
			swffile.close();

			var baseName = swfnodir.substr(0, swfnodir.length - 4);
			baseName = (baseName.charAt(0).toUpperCase()) + baseName.substr(1);

			var imports = encoder.getImports();
			var mainfileName = baseName+"SwfRunner.hx";
			var importfile = File.write(mainfileName, false);
			importfile.writeString(imports);
			importfile.writeString("import SwfRunner;");
			importfile.close();

			Profiler.get().profileStart("Link SWF");

			var fontNames = StringTools.replace(resourceFile, ".swf", ".fontnames");
			if (!sys.FileSystem.exists(fontNames)) {
				fontNames = root + "/" + fontNames;
			}

			// Next, link with the runtime
			var args = [mainfileName, "-main", "SwfRunner", "-swf", swf, "-swf-version", "11", "-swf-lib", swffileName,
			          "-swf-lib", resourceFile, 
			          "-resource",  fontNames + "@fontnames",
			          "-swf-header", "1024:600:30:FFFFFF", "-D", "jsruntime",
			          '-cp', root+'/platforms/nekocompiler', '-cp', root, '-cp', '.'
			          ];
			if (debug > 0) {
				args.push("-debug");
				args.push("-D");
				args.push("advanced-telemetry");
			}
			Assert.trace("Linking " + swffileName + ": " + args);
			if (verbose) {
				Util.println('haxe ' + args.join(' '));
			}
			Sys.command("haxe", args);
			Assert.trace("<<<< Ended");
			Profiler.get().profileEnd("Link SWF");
			deleteTempFile(swffileName);
			deleteTempFile(mainfileName);
		} catch (e : Dynamic) {
			Util.println("Could not produce SWF file: " + e);
			Util.println(Assert.callStackToString(haxe.CallStack.exceptionStack()));
			throw e;
		}
	}

	function deleteTempFile(name : String) {
		if (debug == 0) {
			try {
				FileSystem.deleteFile(name);
			} catch (e : Dynamic) {
				Errors.report("Internal error: failed to delete " + name);
			}
		}
	}

	function doDumpIds(p : FlowInterpreter) {
		#if sys
						
		var def = function(findDefinition : String, declPos) : String {
			var site = p.topdecs.get(findDefinition);
			var pos = 
			if (site != null) {
				FlowUtil.getPosition(site).l;
			} else {
				// Maybe it is a type?
				var t = p.userTypeDeclarations.get(findDefinition);
				if (t != null) {
					// will be equal to decl pos
					t.position.l;
				} else -1;
			};

			return if (pos < 0 || pos == declPos) "" else "," + pos;
		};

		var ppNative = function(name : String, n : Flow) : String {
			var ret = "";
			switch (n) {
				case Native(nname, io, args, result, defbody, pos):
					ret = name + ' : (';
					var sep = '';
					for (a in args) {
						// in the case of only one argument, we need brackets around that argument in case it is a function
					    ret += sep + Prettyprint.prettyprintType(PositionUtil.getValue(a));
						sep = ', ';
					}
					// no brackets around the return type: ok to prettyprint a->(b->c) as a->b->c.
					ret += ') -> ' + Prettyprint.prettyprintType(PositionUtil.getValue(result)) + " = " + nname;
				default:
			}

			return ret;
		};

		var nat = function(name : String, m : Module, n) : String {
			var ret = n.position.l + def(n.name, n.position.l) + ":function " + Prettyprint.ppTD(n) + ";\n";
			var site = m.toplevel.get(name);
			if (site != null) {
				switch (site) {
					case Native(nname, io, args, result, defbody, pos):
						ret = n.position.l + ":native " + ppNative(name, site) + ";\n";
					default:
				}
			}

			return ret;
		};







		var file = File.write(dumpIds, true);

		for (f in modules.modules.keys()) {
			var module = modules.getModule(f);
			var moduleName = module.name;
			file.writeString("file " + moduleName + '\n');

			if (module.imports != null) {
				for (n in module.imports) {
					file.writeString("import " + n + "\n");
				}
			}

			var checkExp = function(k) {
				return true;
//				return module.exports.exists(k) && module.exports[k];
			};

			if(module.userTypeDeclarations != null) {
				var unionsStr = "";
				var structsStr = "";
				var nativesStr = "";
				var functionsStr = "";

				for (n in module.userTypeDeclarations.iterator()) {
					if (checkExp(n.name)) {
						switch (n.type.type) {
							case TStruct(sn, args, max): {
								structsStr += n.position.l + ":struct " + Prettyprint.ppTD(n) + ";\n";
							};
							case TUnion(min, max): {
								unionsStr += n.position.l + ":union " + Prettyprint.ppTD(n) + ";\n";
							};
							case TNative: {
								nativesStr += n.position.l + ":native " + n.name + ";\n";
							};
							case TFunction(args, returns): {
								functionsStr += nat(n.name, module, n);
							};
							default: {};
						};
					}
				}

				file.writeString(structsStr);
				file.writeString(unionsStr);
				file.writeString(nativesStr);
				file.writeString(functionsStr);
			}
		}

		file.close();
		#end
	}

	function dumpUseStats() {
		var moduleList = [];
		for (f in modules.modules.keys()) {
			var module = modules.getModule(f);
			moduleList.push(module);
		}
		var stats = new UseStats(moduleList, redundantImports, redundantFunctions, dumpSymbols, dumpDot);
		if (dumpDot) {
			Sys.command("dot", [ "-Tsvg", "imports.dot", "-o", "imports.svg" ]);
		}
	}

	function findFlowFiles(path : String, files : Array<String>) : Void {
		var filesAndDirs = FileSystem.readDirectory(path);
		for (f in filesAndDirs) {
			try {
				var file = path + "/" + f;
				if (StringTools.startsWith(f, ".")) {
					// Ignore these
				} else if (FileSystem.isDirectory(file)) {
					findFlowFiles(file, files);
				} else {
					if (StringTools.endsWith(f, ".flow")) {
						files.push(file);
					}
				}
			} catch (e : Dynamic) {
			}
		}
	}

	function doExportType(type : String, env : TypeEnvironment) : Void {
		ExportType.exportType(type, env);
	}
		
	static private function traceprogram(p : Program) : Void {
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);
			Errors.print(d + "  ====  " + Prettyprint.prettyprint(e));
		}
	}

	var runResult : Bool;

	// changed files list:
	var changesHash : Map<String,Bool>;

}
