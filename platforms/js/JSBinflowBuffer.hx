import HaxeRuntime;
import Native;
import js.html.ArrayBuffer;
import js.html.Uint8Array;
import js.html.DataView;

class JSBinflowBuffer {
	private var arrayBuffer : ArrayBuffer;
	private var dataView : DataView;
	public var length : Int;
	private var byteOffset : Int;
	private var byteLength : Int;
	private var littleEndian : Bool;
	private static var DoubleSwapBuffer : DataView = new DataView(new ArrayBuffer(8));

	public function new(buffer : ArrayBuffer, byte_offset : Int, byte_length : Int, little_endian : Bool) {
		arrayBuffer = buffer;
		byteOffset = byte_offset;
		byteLength = byte_length;
		littleEndian = little_endian;
		dataView = new DataView(buffer, byteOffset, byteLength);
		length = Std.int(byteLength / 2);
	}

	private inline function getWord(idx : Int) : Int {
		return dataView.getUint16(idx * 2, littleEndian);
	}

	private inline function getInt(idx : Int) : Int {
		return getWord(idx) | (getWord(idx + 1) << 16);
	}

	private inline function getDouble(idx : Int) : Float {
		if (littleEndian) {
			return dataView.getFloat64(idx * 2, true);
		} else {
			DoubleSwapBuffer.setUint16(0, getWord(idx), true);
			DoubleSwapBuffer.setUint16(2, getWord(idx + 1), true);
			DoubleSwapBuffer.setUint16(4, getWord(idx + 2), true);
			DoubleSwapBuffer.setUint16(6, getWord(idx + 3), true);
			return DoubleSwapBuffer.getFloat64(0, true);
		}
	}

	public inline function substr(idx : Int, l : Int) : Dynamic {
		var s = new StringBuf();
		for (i in idx...(idx + l)) s.addChar(getWord(i));
		return s.toString();
	}

	public inline function charAt(idx : Int) : Dynamic {
		var s = new StringBuf();
		for (i in idx...(idx + 1)) s.addChar(getWord(i));
		return s.toString();
	}

	// Deserialisation
	private static var FlowIllegalStruct : Dynamic = null;
	private var StructDefs : Array<Dynamic> = [];
	private var StructFixupCache : Map<String, Dynamic> = new Map();

	// Nesting deeper than this is treated as damaged input. It bounds the recursion of doBinary.
	private static inline var maxBinaryNestingDepth = 1024;

	// A result index below zero marks damaged input: the whole value becomes the default
	private static inline var damagedBinaryIndex = -1;

	private inline function damaged() : Dynamic {
		return [ DefValue, damagedBinaryIndex ];
	}

	private inline function isDamaged(r : Dynamic) : Bool {
		return r[1] < 0;
	}

	// Words that follow a tag before any character or element data
	private static function tagHeaderWords(word : Int) : Int {
		if (word == 0xFFF4 || word == 0xFFFA || word == 0xFFF8) return 1;
		if (word == 0xFFF5 || word == 0xFFFB || word == 0xFFF9) return 2;
		if (word == 0xFFFC || word == 0xFFF3) return 4;
		return 0;
	}

	private function getFooterOffset() : Dynamic {
		if (length < 2) {
			return [ 0, 2 ];
		}
		var footer_offset = getWord(0) | (getWord(1) << 16);
		if (footer_offset != 1) {
			return [ footer_offset, 2 ];
		} else if (length < 6) {
			return [ 0, 6 ];
		} else {
			return  [ getInt(2) |  getInt(4), 6 ];
		}
	}

	private inline function getFixup(name : String) : Array<Dynamic> -> Dynamic {
		var chached_fixup = StructFixupCache[name];
		if (untyped __js__ ("chached_fixup === undefined")) { // Optimisation
			var fixup = Fixups(name);
			chached_fixup = HaxeRuntime._structnames_.get(fixup._id) == "None" ? null : Reflect.field(fixup, HaxeRuntime._structargs_.get(fixup._id)[0]);
			StructFixupCache.set(name, chached_fixup);
		}

		return chached_fixup;
	}

	private function doArray(index : Int, n : Int, depth : Int) : Dynamic {
		if (n < 0) return damaged();
		var ni = index;
		var ar = [];
		for (i in 0...n) {
			var v = doBinary(ni, depth);
			if (isDamaged(v)) return v;
			ni = v[1];
			ar.push(v[0]);
		}
		return [ar, ni];
	}

	private function doBinary(index : Int, depth : Int) : Dynamic {
		if (index >= endIndex || depth > maxBinaryNestingDepth) return damaged();
		var word = getWord(index);
		if (index + 1 + tagHeaderWords(word) > endIndex) return damaged();
		var r = doBinaryValue(word, index + 1, depth);
		// A damaged element damages its value, and every value ends inside the input
		if (isDamaged(r) || r[1] > endIndex) return damaged();
		return r;
	}

	private function doBinaryValue(word : Int, ni : Int, depth : Int) : Dynamic {
		if (word == 0xFFF4) {
			// struct
			var struct_ind = getWord(ni);
			if (struct_ind >= StructDefs.length) return damaged();
			var def : Array<Dynamic> = StructDefs[struct_ind];
			var name : String = def[1];
			var args = doArray(ni + 1, def[0], depth + 1);
			if (isDamaged(args)) return args;
			var fixup = getFixup(name);
			var val = fixup == null ? Native.makeStructValue(name, args[0], FlowIllegalStruct) : fixup(args[0]);
			return [val, args[1]];
		} else if (word == 0xFFF6) {
			// ref
			var v = doBinary(ni, depth + 1);
			return [ HaxeRuntime.ref__(v[0]), v[1] ];
		} else if (word == 0xFFFA) {
			// string, < 65536 length
			return binaryString(ni + 1, getWord(ni));
		} else if (word == 0xFFFC) {
			// double
			var d = getDouble(ni);
			return [ d, ni + 4 ];
		} else if (word == 0xFFF5) {
			// int, long
			var i = getInt(ni);
			return [ i, ni + 2];
		} else if (word < 0xFFF3) { // Special case, since ints are common.
			return  [ word, ni ];
		} else if (word == 0xFFF3) {
			// special case for ints in range to avoid issues with UCS-2/UTF16 encoding in JS
			// they are stored as two long integers: value & 0xF0F0F0F0 and value & 0x0F0F0F0F
			return [ getInt(ni) | getInt(ni + 2), ni + 4 ];
		} else if (word == 0xFFFD) {
			return  [ false,  ni ];
		} else if (word == 0xFFFE) {
			return [ true, ni ];
		} else if (word == 0xFFF8) {
			// array, < 65536 length
			var l = getWord(ni);
			return doArray(ni + 1, l, depth + 1);
		} else if (word == 0xFFF7) {
			// empty array
			return [ [], ni ];
		} else if (word == 0xFFFB) {
			// string, >= 65536 length
			return binaryString(ni + 2, getInt(ni));
		} else if (word == 0xFFF9) {
			// array, >= 65536 length
			var l = getInt(ni);
			return doArray(ni + 2, l, depth + 1);
		} else if (word == 0xFFFF) {
			return  [ null, ni ];
		} else {
			return [ word, ni ];
		}
	}

	// The characters of a string must end inside the input
	private function binaryString(start : Int, l : Int) : Dynamic {
		if (l < 0 || start + l > endIndex) return damaged();
		return [ substr(start, l), start + l ];
	}

	private var DefValue : Dynamic;
	private var Fixups : Dynamic;
	private var endIndex : Int;
	public function deserialise(defvalue : Dynamic, fixups : Dynamic) : Dynamic {
		if (FlowIllegalStruct == null) FlowIllegalStruct = Native.makeStructValue("IllegalStruct", [], null);

		DefValue = defvalue;
		Fixups = fixups;

		var footer_offset = getFooterOffset();
		var footerOffset : Int = footer_offset[0];
		var bodyStart : Int = footer_offset[1];
		// The footer lies after the header words and holds at least one word
		if (!(bodyStart < footerOffset && footerOffset < length)) return damagedInput();

		endIndex = length;
		var defs = doBinary(footerOffset, 0);
		if (isDamaged(defs) || !Native.isArray(defs[0])) return damagedInput();
		StructDefs = defs[0];

		endIndex = footerOffset;
		var r = doBinary(bodyStart, 0);
		if (isDamaged(r)) return damagedInput();
		if (r[1] < footerOffset) {
			Errors.print("Did not understand all!");
		}
		return r[0];
	}

	private function damagedInput() : Dynamic {
		Errors.print("Binary file damaged!");
		return DefValue;
	}
}
