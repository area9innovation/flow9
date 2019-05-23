import haxe.io.Bytes;

#if flash
import flash.utils.ByteArray;
import flash.Memory;
#end

#if js
import js.BinaryParser;
#end

typedef Byte = Int;
typedef I32 = Int;


class ByteMemory {
	public function new(size : Int) {
		this.size = size;
		#if flash
		mem = new ByteArray();
		mem.length = if (size > 0x400) size else 0x400;
		Memory.select(mem);
		#else
		memory = Bytes.alloc(size);
		#end

		#if js
		parser = new BinaryParser(false, true);
		#end

	}
	#if flash
	var mem : ByteArray;
	#end
	public function resize(newSize : Int) {
		#if flash
		mem.length = newSize;
		size = newSize;
		#end
	}
	
	public var size : Int;
	public inline function setByte(addr : Int, v : Byte) {
		#if flash
		Memory.setByte(addr, v);
		#else
		memory.set(addr, v);
		#end
	}
	public function setBytes(start : Int, b : haxe.io.Bytes) {
		#if flash
		for (i in 0...b.length) {
			Memory.setByte(start + i, b.get(i));
		}
		#else
		memory.blit(start, b, 0, b.length);
		#end
	}
	public inline function setI32(addr : Int, v : I32) {
  		#if flash
		Memory.setI32(addr, I2i.toInt(v));
		#else
		setByte(addr, (v & 0xFF) );
		setByte(addr + 1, ((v >>> 8)) & 0xFF );
		setByte(addr + 2, ((v >>> 16)) & 0xFF );
		setByte(addr + 3, ((v >>> 24)) );
		#end
	}
	public inline function setDouble(addr : Int, v : Float) {
		#if flash
		Memory.setDouble(addr, v);
		#elseif neko
		memory.blit(addr, untyped new Bytes(8,_double_bytes(v,false)), 0, 8);
		#elseif cpp
		// TODO
		#elseif js
		var data = parser.fromDouble(v);
		for (byte in 0...data.length) {
			setByte(addr + byte, data.charCodeAt(byte));
		}
		#end
	}
	public inline function getByte(addr : Int) : Byte {
		#if flash
		return Memory.getByte(addr);
		#else
		return memory.get(addr);
		#end
	}
	public inline function getI32(addr : Int) : I32 {
		#if flash
		return (Memory.getI32(addr));
		#else
		var ch1 = getByte(addr);
		var ch2 = getByte(addr + 1);
		var ch3 = getByte(addr + 2);
		var ch4 = getByte(addr + 3);
		return ((ch4 << 24) | (ch3 << 16) | (ch2 << 8) | ch1);
		#end
	}
	public inline function getDouble(addr : Int) : Float {
		#if flash
		return Memory.getDouble(addr);
		#elseif neko
		return _double_of_bytes(untyped memory.sub(addr, 8).b,false);
		#elseif js
		var data = [];
		for (i in 0...8) {
			data[data.length] = String.fromCharCode(getByte(addr + i));
		}
		return parser.toDouble(data.join(""));
		#elseif cpp
		// TODO!
		return 0.0;	
		#end
	}
	public function getString(addr : Int, len : Int) : String {
		#if flash
			mem.position = addr;
			return mem.readUTFBytes(len);
		#else
			return memory.getString(addr, len);
		#end 
		/*var r = "";
		for (i in 0...len) {
			r += String.fromCharCode( getByte(addr + i));
		}
		return r;*/
	}
	
	public function copy(from : Int, to : Int, bytes : Int) : Void {
		#if flash
		if (bytes == 12) {
			Memory.setI32(to, Memory.getI32(from));
			Memory.setI32(to + 4, Memory.getI32(from + 4));
			Memory.setI32(to + 8, Memory.getI32(from + 8));
			return;
		}
		if (from == to || bytes == 0) {
			return;
		}
		for (i in 0...bytes) {
			setByte(to + i, getByte(from + i));
		}
		#else
		memory.blit(to, memory, from, bytes);
		#end
	}

	#if !(flash)
	public var memory : haxe.io.Bytes;
	#end

	#if js
	var parser: BinaryParser;
	#end

	#if neko
	static var _double_of_bytes = neko.Lib.load("std","double_of_bytes",2);
	static var _double_bytes = neko.Lib.load("std","double_bytes",2);
	#end

}
