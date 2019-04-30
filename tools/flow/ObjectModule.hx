import Flow;

import Date;
import Prettyprint;
import haxe.Serializer;
import haxe.Unserializer;
import ByteMemory;
import CodeWriter;
import BytecodeWriter;
import OrderedHash;
import ObjectInfo;
import FlowArray;
typedef TablesBounds = {decls : Range, types : Range};

class ObjectModule extends Module
{
	public var bounds: TablesBounds;
	public var info: ObjectInfo;
	public var globalsRefs: Array<Int>;
	public var bytes : BytesOutput;

	public function new(filename : String, objectPath : String) {
		super(filename, objectPath);
		this.bounds = {decls: new Range (-1,-1), types: new Range (-1,-1)};
		this.info  = null;
		this.globalsRefs = new Array();
		this.bytes       = null;
	}

	override public function coerce() : ObjectModule {	return this; }

	override public function compileRange(names : Names, p: Program, run: Void -> BytesOutput) {
		//Assert.trace(">>>>> compile module: " + name);
		if (precompiled) {
			bytes = new BytesOutput(info.debugInfo);
			for(d in info.order) {
				var n = names.toplevelAndOuter.length;
				names.toplevelAndOuter.set(d.name, TopLevel(n));
			}
			scanBytecode(names, bytes, info.bytecode);
		} else {
			bytes = super.compileRange(names, p, run);
			for (di in bounds.decls) {
				var d = p.declsOrder [di];
				switch (names.toplevelAndOuter.get(d)) {
					case TopLevel(n): {
						var t = p.typeEnvironment.lookup(d);
						if (t == null)
							Assert.check(false, "no type for: " + t);
						info.order.push({name:d, hidden: isHidden(d), no: n, type: t});
					}
					default: Assert.fail("No toplevel");
				}
			}
		}
		return bytes;
	}

	override public function postprocessBytecodeAndWrite(modules : Modules, names : Names, bytes : haxe.io.Bytes) {
		if (!precompiled) {
 			setupImports(modules);
 			setupIncluded();
			info.setBytecode(bytes);
			info.debugInfo = this.bytes.getDebugInfo();
			collectRefs(info, names);
			if (this != modules.topmodule)
			  writeToFile(info);
		}
	}

	private function setupImports(modules: Modules) {
	  //Util.println("setupImports: " + relativeFilename + " #imports=" + imports.length);
		var imports = new Array();
		for (iname in this.imports) {
			var i = modules.modules.get(iname).coerce();
			if (i == null)
				Assert.check(false, "i != null");
			if (i.info.bytecode == null)
				Assert.check(false, "i.info.bytecode != null: " + i.relativeFilename);
			imports.push({name: i.name, filename: i.filename, fullFilename: i.fullFilename,
				  objectPath: i.objectPath, objectHash:Md5.encode(i.info.bytecode.toString())});
		}
		info.imports = imports;
	}
	
	private function setupIncluded() {
		var included = new Array();
		for (incl in includedStrings) {
			included.push({name: incl.path, hash: Md5.encode(incl.content)});
		}
		info.includedStrings = included;
	}
	
	private function scanBytecode(names : Names, output : BytesOutput, b : haxe.io.Bytes) {
	        var bytes  = new BytesInput(b, 0, b.length);
		var memory = new ByteMemory(bytes.size);
		var code   = new CodeMemory(bytes, memory, 0);
		for (pc in info.structDefs) {
			code.setPosition(pc);
			Assert.check(Bytecode.CStructDef == code.readByte());
			code.skipInt(); // id
			var name  = code.readString(code.readInt31());
			var nargs = code.readInt31();
			var newId = names.structs.length;
			names.structs.set(name, NameResolution.Struct(newId, name, nargs));
			memory.setI32(pc+1, (newId));
			//Assert.trace("update struct def " + name + " to #" + newId + " at " + pc);
		}
		for (r in info.structRefs) {
		    var n = names.structs.get(r.name);
			Assert.check(n != null, "Module " + name + "  r.name=" + r.name + "  n=null");
			switch (n) {
			case Struct(id, name, args):
				//Assert.trace("update struct ref " + name + " to #" + id + " at " + r.pc);
				memory.setI32(r.pc, (id));
			default:
				throw "Not a struct";
			}
			
		}
		for (r in info.globalRefs) {
			var outer = names.toplevelAndOuter.get(r.name);
			Assert.check(outer != null, "outer != null"); 
			switch (outer) {
				case TopLevel(id): {
					//Assert.trace("update global ref " + name + " to #" + id + " at " + r.pc);
					memory.setI32(r.pc, (id));
				}
				default: Assert.fail("no Toplevel for name " + name);
			}
		}
		#if neko
		output.writeRawBytes(memory.memory, 0, memory.size);
		#else
		for (i in 0 ... memory.size)
			output.writeByte(memory.getByte(i));
		#end
	}


	private function collectRefs(info : ObjectInfo, names : Names) {
		var b = info.bytecode;
		var bytes  = new BytesInput(b, 0, b.length);
		var memory = new ByteMemory(bytes.size);
		var code   = new CodeMemory(bytes, memory, 0);
		var readString = function() { return code.readString(code.readInt31()); }
		var startPc = code.getPosition();
		while (!code.eof ()) {
			var pc = code.getPosition();
			var op = code.readByte();
			var structRef = function(pos: Int) {
				var id = I2i.toInt(memory.getI32(pos));
				var name = names.structs.keyi(id);
 				info.structRefs.push({pc : pos, name : name});
				//Assert.trace("struct ref " + name + " #" + id + " at " + pos);
 			}
			var collectSwitch = function()  {
				var n = code.readInt31();
				for (i in 0...n)
					structRef(pc+1+8+i*8);
			}
			switch (op) {
				case Bytecode.CStructDef: {
					info.structDefs.push(pc);
					var id = code.readInt31();
					var structname = readString();
					//Assert.trace("struct def " + structname + " #" + id + " at " + pc);
				}
				case Bytecode.CStruct: structRef(pc+1);
				case Bytecode.CSwitch: collectSwitch();
				case Bytecode.CSimpleSwitch: collectSwitch();
				case Bytecode.CGetGlobal: {
					var id = code.readInt31();
					var name = names.toplevelAndOuter.keyi(id);
					Assert.check(name != null, "name != null");
					info.globalRefs.push({pc:pc+1, name:name});
					//Assert.trace("global ref " + name + " #" + id + " at " + pc);
				}
				default: {}
			}
			code.setPosition(pc);
			BytecodeUtil.skipCommand(code);
		}
	}

	override public function populateInterpreter(interpreter : FlowInterpreter) : Void {
		if (precompiled) {
		  //Assert.trace("------------- Populate: " + name + "-----------------------");
			bounds.decls.st = interpreter.order.length;
			bounds.types.st = interpreter.userTypeDeclarations.length;
			for (t in info.expTypes) {
				//Assert.trace("#######> " + t);
				populateInterpreterFromType(interpreter, t);
			}
			for(d in info.order) {
				//Assert.trace("@#######> " + d.name + " hidden: " + d.hidden);
				interpreter.order.push(d.name);
				if (! userTypeDeclarations.exists(d.name)) {
					interpreter.typeEnvironment.define(d.name, d.type);
				}
				if(d.hidden) {
					interpreter.hide(d.name, name);
				}
			}
			bounds.types.en = interpreter.userTypeDeclarations.length;
			bounds.decls.en = interpreter.order.length;
		} else {
			bounds.decls.st = interpreter.order.length;
			bounds.types.st = interpreter.userTypeDeclarations.length;
			super.populateInterpreter(interpreter);
			bounds.types.en = interpreter.userTypeDeclarations.length;
			bounds.decls.en = interpreter.order.length;
			populateInfoFromInterpreter(interpreter);
		}
	}

	private function populateInfoFromInterpreter(i: FlowInterpreter) {
		var hash = getSourceHash();
		info = new ObjectInfo(name, filename, hash);
		info.expTypes = i.userTypeDeclarations.slice(bounds.types).vals;

		if (exports != null)
			for (name in exports.keys()) {
				info.exports.push(name);
			}
	}

	//------------------ reading/writing ------------
	private function writeToFile(i: ObjectInfo)	{
		//Assert.trace("WRITE: " + getObjectFileName() + " filename=" + filename + " full=" + fullFilename);
		#if sys
		var writer = Util.openFile(getObjectFileName());
		info.serialize(this, writer);
		writer.close();
		#elseif flash
		var output = new haxe.io.BytesOutput();
		info.serialize(this, output);
		var so = flash.net.SharedObject.getLocal("Flow-Object/" + getObjectFileName());
		Reflect.setField(so.data, "info", output.getBytes().getData());
		so.flush();
		#else
		Assert.fail("Not implemented");
		#end
	}

	//----------------------------------

	
	// utility functions:
	static private function info2String(i: ObjectInfo) {
		var buf = new StringBuf();
		buf.add("Module " + i.moduleName + " (file: " + i.filename + ")\n");
		buf.add("  Imports: ");
		var sep = "";
		for (imp in i.imports) {
		   buf.add(sep);
		   buf.add(imp);
		   sep = ", ";
		}
		buf.add("\n");

		buf.add("  Export: types: \n");
		for (exp in i.expTypes)
			//buf.add("    " + exp.name + ": " + exp.value.type + "\n");
			buf.add("    " + exp.name + ": " + Prettyprint.prettyprintTypeScheme(exp.type) + "\n");
		
		buf.add("  Export: values: \n");
		for (exp in i.exports)
			buf.add("    " + exp);
		
		return buf.toString();
	}

	static private function toString<T>(i: T) {
		var buf = new StringBuf();
		buf.add(i);
		return buf.toString();
	}


}
