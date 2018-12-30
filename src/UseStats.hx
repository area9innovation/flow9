#if sys
import sys.io.File;
#end

class UseStats {
	public function new(ms : FlowArray<Module>, reportUnusedImports : Bool, reportUnusedFunctions : Bool, dumpSymbols : Bool, dot : Bool) {
		Profiler.get().profileStart("Use stats");
		var cg = new CallGraph();
		// What module does a name come from?
		name2module = new Map();

		// Names used, but not exported
		var hiddenNames = new Map();

		// From name to how many times it is used
		var useCounts : Map<String,Int> = new Map();

		// From module to what names it uses
		var module2uses : Map<String,FlowArray<String>> = new Map();

		// From module name to module structure
		modules = new Map();
		
		for (module in ms) {
			var moduleName = module.name;
			modules.set(moduleName, module);
			if (module.exports != null) {
				for (n in module.exports.keys()) {
					name2module.set(n, moduleName);
				}
			}
			for (n in module.toplevel.keys()) {
				if (!module.exports.exists(n)) {
					hiddenNames.set(n, moduleName);
				}
			}
			
			var uses = cg.collectUses(module);

			for (u in uses) {
				var c = useCounts.get(u);
				if (c == null) {
					c = 0;
				}
				c++;
				useCounts.set(u, c);
			}
			module2uses.set(moduleName, uniqueArray(uses));
		}

		// What modules does this module ultimately need?
		var module2moduleUse : Map<String,Map<String,Bool>> = new Map();
		var module2import : Map<String,Map<String,Bool>> = new Map();
		for (module in ms) {
			var moduleName = module.name;
			var uses = module2uses.get(moduleName);
			var moduleUses = new Map();
			for (use in uses) {
				var mod = name2module.get(use);
				if (mod != null) {
					moduleUses.set(mod, true);
				} 
			}
			module2moduleUse.set(moduleName, moduleUses);

			var imports = new Map();
			for (m in module.imports) {
				imports.set(m, true);
			}
			module2import.set(moduleName, imports);
		}
	
		// Find implicit and superfluous imports, and dead code
		for (module in ms) {
			var moduleName = module.name;
			var uses = module2uses.get(moduleName);
			var messages = [];
			var error = function(text, ?warning = true) {
			  messages.push({text:text, warning:warning});
			}

			var modulesUsed = new Map();
			for (n in uses) {
				var fromModule = name2module.get(n);
				if (fromModule != null) {
					modulesUsed.set(fromModule, true);
				} else {
					var hidden = hiddenNames.get(n);
					if (hidden != null && hidden != moduleName) {
						error("  export " + n + " in " + hidden);
					}
				}
			}
			
			// Find superflous imports
			if (reportUnusedImports) {
				for (m in module.imports) {
					if (!modulesUsed.get(m)) {
						var neededModules = module2moduleUse.get(moduleName);
						var importedModule = modules.get(m);
						var directImports = module2import.get(moduleName);
						var needs = [];
						for (m1 in importedModule.imports) {
							if (neededModules.get(m1) && !directImports.get(m1)) {
								needs.push(m1);
							}
						}

						if (needs.length == 0) {
							error("  -import " + m + ";");
						} else {
							error("  -import " + m + ";");
							for (n in needs) {
								var covered = false;
								for (s in needs) {
									if (s != n && transitiveImport(modules.get(s), n)) {
										covered = true;
									}
								}
								if (!covered) {
									error("  +import " + n + ";");
								}
							}
						}
					}
					
					if (false) {
						if (importRedundant(module, m)) {
							error("  redundant \"import " + m + ";\"");
						}
					}
				}
			}
			
			// Find implicit imports not covered transitively
			var importNeeds = [];
			for (m in modulesUsed.keys()) {
				var found = false;
				for (m2 in module.imports) {
					if (m == m2) { found = true; break; }
				}
				if (!found && m != moduleName) {
					if (!transitiveImport(module, m)) {
						importNeeds.push(m);
					}
				}
			}
			
			// OK, then we should filter these imports, because some of them are handled by others
			var coveredByOthers = new Map();
			for (m1 in importNeeds) {
				var module = modules.get(m1);
				for (m2 in importNeeds) {
					if (m1 == m2) continue;
					if (transitiveImport(module, m2)) {
						coveredByOthers.set(m2, m1);	
					}
				}
			}
			
			var realImportNeeds = [];
			for (m in importNeeds) {
				if (!coveredByOthers.exists(m)) {
					realImportNeeds.push(m);
				}
			}
			
			for (m in realImportNeeds) {
				// Check if it would result in a cycle, in which case the situation is more complex
				var message;
				var target = modules.get(m);
				if (transitiveImport(target, module.name)) {
					message = "  implicit cyclic dependency with " + m + " (which includes " + module.name + ")\n"
							  + "     because " + module.name + " needs access to the following from " + m + ":";
				} else {
					message = "  add missing \"import " + m + ";\" to get access to";
				}
				var need = new Map();
				for (n in uses) {
					var fromModule = name2module.get(n);
					if (fromModule == m) {
						need.set(n, true);
					}
				}

				var needs = [];
				for (n in need.keys()) {
					needs.push(n);
				}
				
				error(message + " " + needs.join(", "), false);
			}
			
			// Find unused, exported functions
			if (reportUnusedFunctions && module.exports != null) {
				for (n in module.exports.keys()) {
					var count = useCounts.get(n);
					if (count == null || count == 0) {
						error("  never used: " + n);
					}
				}
			}

			// Print all our messages
			if (messages.length != 0) {
				Errors.warning(moduleName + ".flow:");
				for (m in messages) {
				         (if (m.warning) Errors.warning else Errors.report) (m.text);
				}
			}
		}
		

		if (dumpSymbols) {
			doDumpSymbols(ms, module2uses);
		}

		#if sys
			if (dot) {
				var file = File.write("imports.dot", true);
				file.writeString(imports(ms));
				file.close();
			}
		#end
		Profiler.get().profileEnd("Use stats");
	}
	
	// Does this module import the given name?
	function transitiveImport(module : Module, name : String) {
		visited = new Map();
		return doTransitiveImport(module, name);
	}
	
	function doTransitiveImport(module : Module, name : String) {
		if (module == null || visited.get(module.name)) {
			return false;
		}
		visited.set(module.name, true);
		for (i in module.imports) {
			if (i == name) { return true; }
			var im = modules.get(i);
			if (doTransitiveImport(im, name)) {
				return true;
			}
		}
		return false;
	}

	public function checkForbids(module : Module) {
		visited = new Map();
		var forbids = new Array<String>();
		forbids = forbids.concat(module.forbids);
		return doCheckForbids(module, forbids);
	}

	function doCheckForbids(module : Module, forbids : Array<String>) {
		if (module == null || visited.get(module.name)) {
			return false;
		}
		visited.set(module.name, true);
		for (i in module.imports) {
			for (forbid in forbids) {
				if (i == forbid || StringTools.startsWith(i, forbid + "/")) {
					Errors.report(module.relativeFilename + ":1: forbidden to import " + i);
					return true;
				}
			}
			var im = modules.get(i);
			var forbids2 = forbids.concat(im.forbids);
			if (doCheckForbids(im, forbids2)) {
				Errors.report(im.relativeFilename + ":1: From here");
				return true;
			}
		}
		return false;
	}

	function importRedundant(module : Module, name : String) {
		visited = new Map();
		for (i in module.imports) {
			var im = modules.get(i);
			if (transitiveImport(im, name)) {
				return true;
			}
		}
		return false;
	}
	
	var visited : Map<String,Bool>;
	var modules : Map<String,Module>;
	
	// dot -Tsvg imports.dot >imports.svg
	function imports(m : Array<Module>) : String {
		var dot = 'digraph "Imports" {\n';
		
		dot += 'node [shape=box, margin="0.3, 0.1"]\n';

		for (module in m) {
			var fromNode = module.name;
			for (i in module.imports) {
				if (!importRedundant(module, i)) {
					dot += '"' + fromNode + '" -> "' + i + '";\n';
				}
			}
		}

		dot += "}\n";
		return dot;
	}
	
	var name2module : Map<String,String>;

	function objectModulesOrder () : Array <ObjectModule> { return null; }

	function uniqueArray(a : FlowArray<String>) : FlowArray<String> {
		var u = new Map();
		for (s in a) {
			u.set(s, 0);
		}
		var r = new FlowArray();
		for (s in u.keys()) {
			r.push(s);
		}
		return r;
	}


	function doDumpSymbols(ms : FlowArray<Module>, module2uses : Map<String,FlowArray<String>>) {
		#if sys
		var file = File.write("symbols.txt", true);

		for (module in ms) {
			var moduleName = module.name;
			file.writeString(moduleName + '\n');
			if (module.exports != null) {
				var sep = "exports: ";
				for (n in module.exports.keys()) {
					file.writeString(sep + n);
					sep =",";
				}
			}
			file.writeString('\n');

			var uses = module2uses.get(moduleName);
			var sep = "uses: ";
			for (u in uses) {
				var m = name2module.get(u);
				if (m != null && m != moduleName) {
					file.writeString(sep + u);
					sep = ",";
				}
			}
			file.writeString('\n');
		}

		file.close();
		#end

	}
}
