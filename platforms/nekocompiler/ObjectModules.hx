import Flow;
#if sys
import sys.io.File;
import sys.FileSystem;
#end
import Modules;

/// The main engine for parsing, linking and running modules
@:final class ObjectModules extends Modules {
	public function new(incl : Array<String>, ?objectPath : String, ?rebuild: Bool = false) {
		super(incl, objectPath, false);
		this.rebuild  = rebuild;
	}

	override public function parse(module_: Module, contents : String, cont : Void -> ParseCont, checkTopmoduleDeps : Module -> Bool) : ParseCont {
	  	Assert.trace(">> Complex parse: " + module_.name);
		var module = module_.coerce();
		module.setContent(contents);
		var noPrecompiled = function () : ParseCont {
		  return ChainParse(simpleParse.bind(module, contents, cont, checkTopmoduleDeps));
		}
		if (!rebuild && topmodule != null && module != topmodule) {
			var postprocess = function(info : ObjectInfo) {
				Assert.check(!module.doneParsing, "!module.doneParsing");
				if (info == null) {
					// Assert.trace("Module " + module.name + " unserialize failed: [" + contents + "]");
					return noPrecompiled();
				}
				var mods = new Array();
				var imports = new Array();
				//Assert.trace(module.name + ": #IMPORTS=" + info.imports.length);
				for (imp in info.imports) {
					imports.push(imp.name);
				}
				module.info = info;
				module.imports = imports;
				module.exports = new Map();
				if (module.exports != null) {
					for (e in info.exports)
						module.exports.set(e,true);
				}

				module.userTypeDeclarations = new Map();
				for (e in info.expTypes)
					module.userTypeDeclarations.set(e.name, e);

				module.precompiled = true;
				modules.set(module.name, module);
				return processNestedImports(module, 0, function() { 
					module.doneParsing = true;
					for (i in module.info.imports) {
					  var m = modules.get(i.name).coerce();
					  if (!m.precompiled) {
						module.precompiled = false;
						break;
					  }
					  
					  if (i.objectHash != m.info.bytecodeHash) {
						Assert.trace("Module " + i.name + " hash mismatch");
						module.precompiled = false;
						break;
						
					  }
		  			} 
					if (!module.precompiled)
					  return noPrecompiled();
					else
					  return ChainParse(cont);
				  });
			}

			var cont : ObjectInfo -> Int -> ParseCont = null;
			cont = function (info: ObjectInfo, i): ParseCont {
			  var res = EndParse(false);
			  if (info == null) {
				  return noPrecompiled();
			  }
			  Assert.check(info.includedStrings != null, "info.includedStrings != null");
			  if (i == info.includedStrings.length) {
			    return postprocess(info);
			  }
			  if (!readFile(info.includedStrings[i].name, function(content) {
				if (info.includedStrings[i].hash != FilesCache.hash(info.includedStrings[i].name)) {
				  //Assert.trace("#include '" + info.includedStrings[i].name + "' failed");
				  res = noPrecompiled();
				} else {
				  //Assert.trace("#include '" + info.includedStrings[i].name + "' checked");
				  res = ChainParse(cont.bind(info, i+1));
				}
				#if (flash || js)
				res = EndParse(Modules.execChain(function() { return res; }));
				#end
			      })) {
				  return noPrecompiled();
			  }
			  return res;
			};

			#if sys
			try {
			  return ChainParse(cont.bind(ObjectInfo.getUnserializedInfo(module), 0));
			} catch (s : Dynamic) {
				Assert.printExnStack("readFromFile: Exception" + s);
			}
			#elseif flash
			var objName = module.getObjectFileName();
			var so = flash.net.SharedObject.getLocal("Flow-Object/" + objName);
			if (so != null) {
				var data : haxe.io.BytesData = Reflect.field(so.data, "info");
				if (data != null) {
					Assert.trace("Loaded bytecode '" + objName + "' from local storage");
					var info = ObjectInfo.unserialize(module, new haxe.io.BytesInput(haxe.io.Bytes.ofData(data)));
					if (info != null) {
						return ChainParse(cont.bind(info, 0));
					}
				}
				Assert.trace("trying to load bytecode '" + objName + "' from server");
				files.forceDownloadAny(flash.net.URLLoaderDataFormat.BINARY, module.filename, [objName], function(name, data) {
					Assert.trace("bytecode '" + name + "' loaded, objName=" + objName);
					Reflect.setField(so.data, "info", data);
					so.flush();
					Modules.execChain(cont.bind(ObjectInfo.unserialize(module, new haxe.io.BytesInput(haxe.io.Bytes.ofData(data))), 0));
				},
				function(error : String) {
					//Assert.trace("bytecode '" + objName + "' NOT loaded");
					Modules.execChain(noPrecompiled);
				});
				return EndParse(false);
			}
			#end
		}
		return noPrecompiled();
	}
	
	public function simpleParse(module : Module, contents : String, cont : Void -> ParseCont, checkTopmoduleDeps : Module -> Bool) : ParseCont {
	    module.reset();
		return super.parse(module, contents, cont, checkTopmoduleDeps);
	}

 	override public function getModule(name : String) : Module {
		return modules.get(Module.getModuleName(name));
	}

	override public function newModule(name : String) : Module {
		return new ObjectModule(name, objectPath);
	}

	override public function objectModulesOrder() : Array <ObjectModule> {
		//Assert.trace("TOPMODULE: " + topmodule.name);
		var order = new OrderedHash();
		sortModulesByImports(topmodule.coerce(), order);
		return order.vals();
	}

    private function sortModulesByImports(root : ObjectModule, order : OrderedHash<ObjectModule>, ?ready = null) {
	  if (ready == null) {
		ready = new Map();
	  }	    
	  if (ready.exists(root.name))
		return;
	  ready.set(root.name,true);
	  if (!order.exists(root.name)) {
		for (i in root.imports) {
		  var m = modules.get(i);
		  sortModulesByImports(m.coerce(), order, ready);
		}
		order.set(root.name, root);
	  }
	}
	
	override public function postProcessWholeBytecode(b : haxe.io.Bytes) {
		#if sys
		//var model = new ModelBytecode();
		//var code = ModelBytecode.decode(b);
		//Sys.println(ModelBytecode.codeToString(code));
		//var prg = ModelBytecode.parse(code);
		//Sys.println(ModelBytecode.prgToString(prg));
		#end
	}
	override public function isIncremental(): Bool { return true; }
	override public function coerce(): ObjectModules { return this; }

	public var rebuild  : Bool;
}
