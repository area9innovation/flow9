#if jsruntime
#error "Attempt to link Flow compiler code into runtime"
#end

typedef Patch = {pc:Int, value:Int};
typedef Patches = Array<Patch>;

class BytesOutput {
	public static var counter = 0;
	public function new(debug) {
		buf = new haxe.io.BytesOutput();
		length = 0;
		patches = new Patches();
		debugInfo = debug;
		#if js
		parser = new js.BinaryParser(false, true);
		#end
	}
	public function writeInt31(i : Int) {
		buf.writeInt32(i);
		length += 4;
	}
	public function writeInt31_8(i : Int, name : String) {
		if (i < 0 || i >= 256)
			throw ("More than 256 " + name);
		writeInt31(i);
	}
	public function writeInt31_16(i : Int, name : String) {
		if (i < 0 || i >= 65536)
			throw ("More than 64K " + name);
		writeInt31(i);
	}
	public function writeInt32(i : Int) {
		buf.writeInt32(i);
		length += 4;
	}
	public inline function writeString(s : String) {
		var b = haxe.io.Bytes.ofString(s);
		writeRawBytes(b, 0, b.length);
	}
	public function writeDouble(d : Float) {
		#if js
		var data = parser.fromDouble(d);
		for (byte in 0...data.length) {
			writeByte(data.charCodeAt(byte));
		}
		#else
		buf.writeDouble(d);
		#end
		length += 8;
	}
	
	public function writeByte( c : Int ) {
		buf.writeByte(c);
		length += 1;
	}
	
	public function writeRawBytes(b : haxe.io.Bytes, st : Int, len : Int) {
		buf.writeBytes(b, st, len);
		length += len;
	}
	
	public function writeBytes(b : haxe.io.Bytes, debug : DebugInfo) {
		var pc = getPc();
		debugInfo.append(pc, debug);
		writeRawBytes(b, 0, b.length);
	}

	private static var utf8d : Array<Int> = [
	  // The first part of the table maps bytes to character classes that
	  // to reduce the size of the transition table and create bitmasks.
	   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
	   7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7].concat(
	   [8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
	  10,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3, 11,6,6,6,5,8,8,8,8,8,8,8,8,8,8,8,

	  // The second part is a transition table that maps a combination
	  // of a state of the automaton and a character class to a state.
	   0,12,24,36,60,96,84,12,12,12,48,72, 12,12,12,12,12,12,12,12,12,12,12,12,
	  12, 0,12,12,12,12,12, 0,12, 0,12,12, 12,24,12,12,12,12,12,24,12,24,12,12,
	  12,12,12,12,12,12,12,24,12,12,12,12, 12,24,12,12,12,12,12,12,12,24,12,12,
	  12,12,12,12,12,12,12,36,12,36,12,12, 12,36,12,12,12,12,12,36,12,36,12,12,
	  12,36,12,12,12,12,12,12,12,12,12,12] );
	  
	private static inline var UTF8_ACCEPT = 0;
	private static inline var UTF8_REJECT = 12;

	private function utf16BytesfromString(str : String) : haxe.io.Bytes {
		#if (flash || js)
		var utf16 = haxe.io.Bytes.alloc(2 * str.length);
		var j = 0;
		for (i in 0...str.length) {
			var c = str.charCodeAt(i);
			utf16.set(j++, c & 0xff);
			utf16.set(j++, c >> 8);
		}
		return utf16;
		#else

		var utf8_bytes = haxe.io.Bytes.ofString(str);
		
		#if sys
		var size = haxe.Utf8.length(str);
		#else
		var size = str.length;
		#end

		var utf16_bytes = haxe.io.Bytes.alloc(size * 2);
		var codepoint = 0;
		var state = UTF8_ACCEPT, prev = UTF8_ACCEPT;
		var utf16_pos = 0;
		var utf8_length = utf8_bytes.length;

		var i = 0;
		while (i < utf8_length) {
			var byte = utf8_bytes.get(i);
			var type = utf8d[byte];

			codepoint = (state != UTF8_ACCEPT) ? (byte & 0x3f) | (codepoint << 6) :
						(0xff >> type) & (byte);

			state = utf8d[256 + state + type];
			
			if (state == UTF8_ACCEPT) {
				if (codepoint > 0xffff) {
					utf16_bytes.set(utf16_pos++, 0xFD);
					utf16_bytes.set(utf16_pos++, 0xFF);
				} else {
					utf16_bytes.set(utf16_pos++, codepoint & 0x00FF);
					utf16_bytes.set(utf16_pos++, (codepoint & 0xFF00) >> 8);
				}
			} else if (state == UTF8_REJECT) {
				utf16_bytes.set(utf16_pos++, 0xFD);
				utf16_bytes.set(utf16_pos++, 0xFF);
				if (prev != UTF8_ACCEPT) --i;
				state = UTF8_ACCEPT;
			}
			
			prev = state;
			++i;
		}
		
		return utf16_bytes;
		#end
	}

	public function writeWideString(s : String) {
		var utf16_bytes = utf16BytesfromString(s);
		buf.writeByte(utf16_bytes.length >> 1);
		buf.writeBytes(utf16_bytes, 0, utf16_bytes.length);
		length += 1 + utf16_bytes.length;
	}

	public function writeWideStringRaw(s : String) : Int {
		var utf16_bytes = utf16BytesfromString(s);
		buf.writeBytes(utf16_bytes, 0, utf16_bytes.length);
		length += utf16_bytes.length;
		return utf16_bytes.length >> 1;
	}

	public function writeBytesVector(outputs : Array<BytesOutput>) {
		for (o in outputs) {
			writeBytes(o.extractBytes(), o.getDebugInfo());
		}
	}
	
	public function addDebug(p : Position) {
		debugInfo.add(getPc(), p);
	}
	
	public function getPc() : Int {
		return length;

		// The old code is extremely slow on neko,
		// which is where it matters most:
		/*
		#if flash
		var p = untyped buf.b.length;
		#elseif neko
		var str = untyped StringBuf.__to_string(untyped buf.b.b);
		var p = untyped __dollar__ssize(str);
		#elseif js
		var p = untyped buf.b.b;
		#elseif cpp
		var p = untyped buf.b.length;
		#end
		return p;*/
	}

	// After this has been called, the buffer is no good.
	public function extractBytes() : haxe.io.Bytes {
		var b = buf.getBytes();
		buf = null;
		for (p in patches) {
			var bw = new BytesOutput(new DebugInfo());
			bw.writeInt31(p.value);
			b.blit(p.pc, bw.extractBytes(), 0, 4);
		}
		patches = null;
		return b;
	}
	
	public function getDebugInfo() : DebugInfo {
		return debugInfo;
	}

	public function patchInt31(pc : Int, value : Int) {
		patches.push({pc:pc, value:value});
	}

    public function prepare(size: Int) {
      #if !flash // workaround: flash target return prepared size as actual
	  buf.prepare(size);
	  #end
    }
	
	private var buf : haxe.io.BytesOutput;
	private var length : Int;
	var debugInfo : DebugInfo;
	#if js
	var parser: js.BinaryParser;
	#end
	var patches : Patches;
}
