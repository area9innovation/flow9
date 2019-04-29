import Flow;
import haxe.io.Input;
import haxe.io.Output;
import FlowArray;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

typedef Import = {name: String, filename: String, fullFilename: String, objectPath: String, objectHash: String};
typedef Include = {name: String, hash: String};
typedef Decl = {name: String, hidden: Bool, no:Int, type : TypeScheme };

typedef InfoWriter = {out: Output, types: TypeTable, strings : Map<String, Int>, noStrings : Int};
typedef InfoReader = {inp: Input, types: Array<FlowType>, strings : Map<Int, String>, noStrings : Int};
typedef NameRef = {pc: Int, name: String};

typedef TypeDef = {t: FlowType, i: Int};
class TypeTable {
	private static var HASH_SIZE = Type.getEnumConstructs(FlowType).length;
	var types : Array<Array<TypeDef>>;
	var index : Int;
	public function new() {
		types = new Array();
		for (i in 0 ... HASH_SIZE) {
			types.push(new Array());
		}
		index = 0;
	}
	public function put(t: FlowType) {
		types [hash(t)].push({i:index,t:t});
		Assert.check(get(t) == index);
		++ index;
	}
	public function get(t: FlowType): Int {
		var ts = types [hash(t)];
		for (tp in ts)
			if (t == tp.t) {
				return tp.i;
			}
		return -1;
	}
	private static function hash(t: FlowType) {
		return Type.enumIndex(t);
	}
}

class ObjectInfo {
	private static var cnt = 0;
	public static var MAGIC = 0x10402030;
	public static var VERSION = 76;

    private static var infoCache = new Map();

	public var moduleName : String;
	public var   filename : String;
	public var sourceHash : String;
	public var   imports  : Array<Import>;
	public var   exports  : Array<String>;
    public var includedStrings : Array<Include>;
	public var   expTypes : Array<TypeDeclaration>;
	public var   order    : Array<Decl>;
    public var bytecode (default, null) : haxe.io.Bytes;
	public var bytecodeHash : String;
	public var structDefs : Array<Int>;
	public var structRefs : Array<NameRef>;
	public var globalRefs : Array<NameRef>;
	public var debugInfo  : DebugInfo;

    public function setBytecode(b: haxe.io.Bytes) {
	  this.bytecode = b;
	  this.bytecodeHash = if (b == null) "" else Md5.encode(b.toString());
	  return b;
    }
	
	public function new(moduleName: String, filename: String, hash : String) {
		this.moduleName = moduleName;
		this.filename   =   filename;
		this.sourceHash =  hash;
		this.imports = new Array();
		this.exports = new Array();
		this.order   = new Array();
		this.structDefs = new Array();
		this.structRefs = new Array();
		this.globalRefs = new Array();
		this.bytecode = null;
		this.bytecodeHash = "";
		this.debugInfo = null;
	}

    public function dump(): String {
	   var s = 
		 "ModuleName: " + moduleName + "\n" +
		 "  FileName: " +   filename + "\n" +
		 "SourceHash: " + sourceHash + "\n";
	   s += "\n";
	   for (i in imports) {
		 s += 
		   "  Imported " + i.name + /*" fileName: " + i.filename + " fullFilename " + i.fullFilename +
									  " objectPath: " + i.objectPath +*/ " objectHash: " + i.objectHash + "\n";
	   }
	   s += "\nExported:\n";
	   for (e in exports) {
		 s += "    " + e + "\n";
	   }
	   s += "\nIncluded Strings: \n";
	   for (is in includedStrings) {
		 s += "  " + is.name + "  Map: " + is.hash + "\n";
	   }
	   s += "\nExported types:\n";
	   for (td in expTypes) {
		 s += "  " + td.name + " = " + Prettyprint.prettyprintTypeScheme(td.type) + "\n";
	   }
	   s += "\nOrder decls:\n";
	   for (d in order) {
		 s += "  " + d.name + " #" + d.no + " hidded: " + d.hidden + "\n";
	   }

	   s += "\nName defs:\n";
	   for (n in structDefs) {
		 s += n;
	   }
	   s += "\nName refs:\n";
	   for (n in structRefs) {
		 s += "  " + n.name + " at " + n.pc + "\n";
	   }
	   s += "\nName refs:\n";
	   for (n in globalRefs) {
		 s += "  " + n.name + " at " + n.pc + "\n";
	   }
	   s += "\nBytecode length: " + bytecode.length + "  hash: " + bytecodeHash + "\n";
	   return s;
	}

	//typedef Import = {name: String, filename: String, fullFilename: String, objectPath: String, time: Date};
	//typedef Decl = {name: String, hidden: Bool, no:Int};
    public function serialize(module: Module, out: Output) {
		Profiler.get().profileStart("Serializing");
		var writer = {out: out, types: new TypeTable(), strings : new Map(), noStrings: 0 };
 		writer.out.writeInt32(MAGIC);
		writer.out.writeInt32(VERSION);
		writeString(writer, moduleName);
		writeString(writer, filename);
		writeString(writer, sourceHash);
		Assert.check(imports != null, "imports != null");

		writeArray (writer, function(writer: InfoWriter, i: Import) {
			writeString(writer, i.name);
			writeString(writer, i.filename);
			writeString(writer, i.fullFilename);
			writeString(writer, i.objectPath);
			writeString(writer, i.objectHash);
		}, imports);
		writeArray(writer, writeString, exports);
		writeArray (writer, function(writer: InfoWriter, i: Include) {
			writeString(writer, i.name);
			writeString(writer, i.hash);
		}, includedStrings);
		writeArray(writer, writeTypeDecl, expTypes);
		writeOrder(writer);
		writeArray(writer, writeUInt, structDefs);
		writeArray(writer, writeNameRef, structRefs);
		writeArray(writer, writeNameRef, globalRefs);
		writeBytes(writer, bytecode);
		writeString(writer, bytecodeHash);
		debugInfo.write(writer);
		Profiler.get().profileEnd("Serializing");
		infoCache.set(module.relativeFilename, this);
	}
#if sys
   public static function getUnserializedInfo(module: Module, noHashCheck : Bool = false) {
	  var fname = module.getObjectFileName();
	  var info = infoCache.get(module.relativeFilename);
	  if (info == null && FileSystem.exists(fname)) {
		Profiler.get().profileStart("Reading incremental object files");
	  	var fileContents = File.getBytes(fname);
		info = ObjectInfo.unserialize(module, new haxe.io.BytesInput(fileContents), noHashCheck);
		Profiler.get().profileStart("Reading incremental object files");
		infoCache.set(module.relativeFilename, info);
	  }
	  return info;
    }
#end
    public static function unserialize(module: Module, inp: Input, noHashCheck : Bool = false) : ObjectInfo {
		//Assert.trace("loaded from store: " + module.name + " endian=" + inp.bigEndian);
		cnt = 0;
		var magic = inp.readInt32();
 		if (magic != MAGIC) {
			//Assert.trace(module.name + ": invalid MAGIC");
			return null;
		}
		
		var version = inp.readInt32();
 		if (version != VERSION)	{
			//Assert.trace(module.name + ": invalid version: " + version);
			return null;
		}

		Profiler.get().profileStart("Deserializing");
		var reader = {inp:inp, types:new Array(), strings : new Map(), noStrings : 0 };
		var moduleName = readString(reader);
		var filename   = readString(reader);
		var oldHash = readString(reader);
		if (!noHashCheck) {
		  var newHash = module.getSourceHash();
		  if (oldHash != newHash) {
			Assert.trace(module.name + ": file hashes mismatch: " + oldHash + " /= " + newHash);
			return null;
		  }
		}
		var i = new ObjectInfo(moduleName, filename, oldHash);
		i.imports  = readArray(reader, function(reader: InfoReader) {
			var name         = readString(reader);
			var filename     = readString(reader);
			var fullFilename = readString(reader);
			var objectPath   = readString(reader);
			var objectHash   = readString(reader);
			return {name:name, filename:filename, fullFilename:fullFilename, objectPath:objectPath, objectHash:objectHash};
		});
		i.exports  = readArray(reader, readString);
		i.includedStrings = readArray(reader, function(reader: InfoReader) {
			var name = readString(reader);
			var hash = readString(reader);
			return {name:name, hash:hash};
		});
		i.expTypes = readArray(reader, readTypeDecl);
		i.readOrder(reader);

		i.structDefs = readArray(reader, readUInt);
		i.structRefs = readArray(reader, readNameRef);
		i.globalRefs = readArray(reader, readNameRef);

		i.bytecode     = readBytes(reader);
		i.bytecodeHash = readString(reader);
		i.debugInfo = DebugInfo.read(reader);
		Profiler.get().profileEnd("Deserializing");
		return i;
	}

	private static function writeBytes(writer: InfoWriter, b: haxe.io.Bytes) {
		writeUInt(writer, b.length);
		writer.out.write(b);
	}
	
	private static function readBytes(reader: InfoReader): haxe.io.Bytes {
		var len = readUInt(reader);
		return reader.inp.read(len);
	}
	
	private static function writeNameRef(writer: InfoWriter, ref: NameRef) {
		writeUInt(writer, ref.pc);
		writeString(writer, ref.name);
	}
	
	private static function readNameRef(reader: InfoReader): NameRef {
		var pc = readUInt(reader);
		return {pc:pc, name:readString(reader)};
	}
	
	private static function writeTypeDecl(writer: InfoWriter, td: TypeDeclaration) {
		writeString(writer, td.name);
		writeTypeScheme(writer, td.type);
		writePos(writer, td.position);
	}
	
	private static inline function readTypeDecl(reader: InfoReader) {
		var name = readString(reader);
		var type = readTypeScheme(reader);
		var position = readPos(reader);
		return {name:name, type:type, position:position};
	}

	public static inline function readString(reader: InfoReader) {
		var len = readSInt(reader);
		if (len < 0) {
			return reader.strings.get(len);
		} else {
			var s = reader.inp.readString(len);
			reader.noStrings = reader.noStrings - 1;
			reader.strings.set(reader.noStrings, s);
			return s;
		}
	}

	public static inline function writeString(writer: InfoWriter, string: String) {
		var l = writer.strings.get(string);
		if (l == null) {
			writeSInt(writer, string.length);
			writer.out.writeString(string);
			writer.noStrings = writer.noStrings - 1;
			writer.strings.set(string, writer.noStrings);
		} else {
			writeSInt(writer, l);
		}
	}

	public static inline function  readBool(reader:  InfoReader) { return reader.inp.readInt8() != 0; }
	public static inline function writeBool(writer: InfoWriter, b: Bool) {
		writer.out.writeInt8(if (b) 1 else 0);
	}

	public static function writeUInt(writer: InfoWriter, v: Int) {
		if (v < 0)
			Assert.check(false, "writeUInt: v<0: " + v);
		if (v < 192) 
			writer.out.writeByte(v);
		else {
			writer.out.writeByte((v & 0x3F) + 192);
			v >>>= 6;
			while (v >= 0x80) {
				writer.out.writeByte(v & 0x7F);
				v >>>= 7;
			}
			writer.out.writeByte(v | 0x80);
		}
	}
	public static function readUInt(reader: InfoReader) {
		var b = reader.inp.readByte();
		if (b < 192) {
			return b;
		} else {
			var v = b - 192;
			var shift = 6;
			do {
				b = reader.inp.readByte();
				v |= ((b & 0x7F) << shift);
				shift += 7;
			} while((b & 0x80) == 0);
			return v;
		}
	}

	public static function  readSInt(reader:  InfoReader) {
		var i = readUInt(reader);
		if ((i & 1) == 0)
			return i >> 1;
		else
			return -(i >> 1);
	}
	public static function writeSInt(writer: InfoWriter, v: Int) {
		//Assert.check(v <=  0x20000000, "v=" + v);
		//Assert.check(v  > -0x20000000, "v=" + v);
		if (v >= 0)
			writeUInt(writer, v << 1);
		else
			writeUInt(writer, ((-v) << 1) | 1);
	}

	public static function  readPos(reader:  InfoReader): Position {
		var f = readString(reader);
		var l : Null<Int> = readUInt  (reader);
		var s = readSInt  (reader);
		var e = readSInt  (reader);
		var t = readType  (reader);
		var t2 = readType  (reader);
		return {f:f, l:l, s:s, e:e, type:t, type2:t2};
	}
	public static function writePos(writer: InfoWriter, pos: Position, ?types : Bool = true) {
		writeString(writer, pos.f);
		writeUInt  (writer, pos.l);
		writeSInt  (writer, pos.s);
		writeSInt  (writer, pos.e);
		if (types) {
			writeType  (writer, pos.type);
			writeType  (writer, pos.type2);
		} else {
			writeType  (writer, null);
			writeType  (writer, null);
		}
	}

	public static function readArray<T>(reader: InfoReader, readT: InfoReader -> T): Array<T> {
		var len = readUInt(reader);
		var res = new Array();
		for (i in 0 ... len)
			res.push(readT(reader));
		return res;
	}
	public static function writeArray<T>(writer: InfoWriter, tWrite: InfoWriter -> T -> Void, v: Array<T>) {
		writeUInt(writer, v.length);
		for (f in v) {
			tWrite(writer, f);
		}
	}

	private function writeOrder(writer: InfoWriter) {
		writeUInt(writer, order.length);
		for (d in order) {
			writeString(writer, d.name   );
			writeBool  (writer, d.hidden );
			writeUInt  (writer, d.no     );
			writeTypeScheme(writer, d.type);		}
	}

	private function readOrder(reader: InfoReader) {
		var len = readUInt(reader);
		for (i in 0 ... len) {
			var name    = readString(reader);
			var hidden  = readBool  (reader);
			var no      = readUInt  (reader);
			var type = readTypeScheme(reader);
			order.push({name:name, hidden:hidden, no:no, type:type});
		}
	}
	
	public static function writeType(writer: InfoWriter, t: FlowType) {
		if (t == null) {
			writeSInt(writer,-1);
			return;
		}

		var ti = writer.types.get(t);
		if (ti != -1) {
				writeSInt(writer,ti);
				return;
		}
		writeSInt(writer,-2);
		switch (t) {
			case TVoid  : writer.out.writeByte(TypeTag.TVoid  );
			case TBool  : writer.out.writeByte(TypeTag.TBool  );
			case TInt   : writer.out.writeByte(TypeTag.TInt   );
			case TDouble: writer.out.writeByte(TypeTag.TDouble);
			case TString: writer.out.writeByte(TypeTag.TString);
			case TFlow  : writer.out.writeByte(TypeTag.TFlow  );
			case TNative: writer.out.writeByte(TypeTag.TNative);
				
			case TReference(t): writer.out.writeByte(TypeTag.TReference); writeType(writer,t);
			case TPointer  (t): writer.out.writeByte(TypeTag.TPointer  ); writeType(writer,t);
			case TArray    (t): writer.out.writeByte(TypeTag.TArray    ); writeType(writer,t);
			case TTyvar    (r): writer.out.writeByte(TypeTag.TTyvar    ); writeType(writer,r.type);
			case TFunction(args, returns):
				writer.out.writeByte(TypeTag.TFunction);
 				writeArray(writer, writeType, FlowArrayUtil.toArray(args));
				writeType(writer,returns);
				
			case TStruct(structname, args, max):
				writer.out.writeByte(TypeTag.TStruct);
				writeString(writer, structname);
				writeArray(writer, function(writer: InfoWriter, m: MonoTypeDeclaration) {
					writeString(writer, m.name);
					writeType(writer, m.type);
					writePos(writer, m.position);
					writeBool(writer, m.is_mutable);
				}, FlowArrayUtil.toArray(args));
				writeBool(writer, max);

			case TUnion(min, max):
				//Assert.check(min == max, "min == max");
				writer.out.writeByte(TypeTag.TUnion);
				var write = function (h: Map<String,FlowType>) {
					if (h == null) {
						writeBool(writer, false);
						return;
					}
					writeBool(writer, true);
					for (id in h.keys()) {
						writeBool(writer, true);
						writeString(writer, id);
						writeType(writer, h.get(id));
					}
					writeBool(writer, false);
				};
				write(min);
				// this is no opt - physical equality of min & max is essential and should be preserved
				if (min != max) { 
					writeBool(writer, false);
					write(max);
				} else {
					writeBool(writer, true);
				}
					
			case TBoundTyvar(id): writer.out.writeByte(TypeTag.TBoundTyvar); writeUInt(writer,id);
			case TName(name, args):
				writer.out.writeByte(TypeTag.TName);
				writeString(writer, name);
				writeArray(writer, writeType, FlowArrayUtil.toArray(args));
		}
		writer.types.put(t);
	}
	
	public static function readType(reader: InfoReader): FlowType {
		var kind = readSInt(reader);
		if (kind == -1) {
			return null;
		} else if (kind >= 0) {
			//Assert.check(reader.types.length - kind > 0, "" + kind + " < " + reader.types.length);
			return reader.types[kind];
		} else {
			Assert.check(kind == -2, "kind == -2 at offset ");
		}
		var tag = reader.inp.readByte();
		var t =	switch (tag) {
			case TypeTag.TVoid  : TVoid;
			case TypeTag.TBool  : TBool;
			case TypeTag.TInt   : TInt ;  
			case TypeTag.TDouble: TDouble;
			case TypeTag.TString: TString;
			case TypeTag.TFlow  : TFlow;
			case TypeTag.TNative: TNative;
		
			case TypeTag.TReference: TReference(readType(reader));
			case TypeTag.TPointer  : TPointer  (readType(reader));
			case TypeTag.TArray    : TArray    (readType(reader));
			case TypeTag.TTyvar    : TTyvar(FlowUtil.mkTyvar(readType(reader)));
			case TypeTag.TFunction : { 
				var args = FlowArrayUtil.fromArray(readArray(reader, readType));
				TFunction(args, readType(reader));
			}
			
			case TypeTag.TStruct: {
				var name = readString(reader);
				var args = FlowArrayUtil.fromArray(readArray(reader, function(reader: InfoReader) {
					var name = readString(reader);
					var type = readType(reader);
					var pos  = readPos(reader);
					var mut = readBool(reader);
					return {name:name, type:type, position:pos, is_mutable:mut};
				}));
				TStruct(name, args, readBool(reader));
			}
			
			case TypeTag.TUnion: {
				var read = function() {
					if (!readBool(reader)) {
						return null;
					}
					var b = new Map();
					while (readBool(reader)) {
						var id = readString(reader);
						b.set(id, readType(reader));
					};
					return b;
				};
				var min = read();
				var max = if (readBool(reader))	min else read();
				TUnion(min,max);
			}
			
			case TypeTag.TBoundTyvar: TBoundTyvar(readUInt(reader));
			case TypeTag.TName: {
				var name = readString(reader);
				TName(name, FlowArrayUtil.fromArray(readArray(reader, readType)));
			}

			default: Assert.fail("Invalid tag=" + tag); null;
		};
		reader.types.push(t);
		Assert.check(t != null);
		return t;
	}
	
	public static function writeTypeScheme(writer: InfoWriter, t: TypeScheme) {
		writeUInt(writer, t.tyvars.length);
		for (f in t.tyvars) {
			writeUInt(writer, f);
		}
		writeType(writer, t.type);
	}
	
	public static function readTypeScheme(reader: InfoReader): TypeScheme {
		var tyvars = FlowArrayUtil.fromArray(readArray(reader, readUInt));
		return {tyvars:tyvars, type:readType(reader)};
	}
}

class TypeTag {
	public static inline var TVoid       = 1;
	public static inline var TBool       = 2;
	public static inline var TInt        = 3;
	public static inline var TDouble     = 4;
	public static inline var TString     = 5;
	public static inline var TReference  = 6;
	public static inline var TPointer    = 7;
	public static inline var TArray      = 8;
	public static inline var TFunction   = 9;
	public static inline var TStruct     = 10;
	public static inline var TUnion      = 11;
	public static inline var TTyvar      = 12;
	public static inline var TBoundTyvar = 13;
	public static inline var TFlow       = 14;
	public static inline var TNative     = 15;
	public static inline var TName       = 16;
}
