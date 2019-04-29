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

	// Deserialisation
	private static var FlowIllegalStruct : Dynamic = null;
	private var StructDefs : Array<Dynamic> = [];
	private var StructFixupCache : Map<String, Dynamic> = new Map();

	private function getFooterOffset() : Dynamic {
		var footer_offset = getWord(0) | (getWord(1) << 16);
		if (footer_offset != 1) {
			return [ footer_offset, 2 ];
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

	private inline function doArray(index : Int, n : Int) : Dynamic {
		var ni = index;
		var ar = [];
		for (i in 0...n) {
			var v = doBinary(ni);
			ni = v[1];
			ar.push(v[0]);
		}
		return [ar, ni];
	}

	private function doBinary(index : Int) : Dynamic {
		if (index < endIndex) {
			var word = getWord(index);
			var ni = index + 1;

			if (word == 0xFFF4) {
				// struct
				var def : Array<Dynamic> = StructDefs[getWord(ni)];
				var name : String = def[1];
				var args = doArray(ni + 1, def[0]);
				var fixup = getFixup(name);
				var val = fixup == null ? Native.makeStructValue(name, args[0], FlowIllegalStruct) : fixup(args[0]);
				return [val, args[1]];
			} else if (word == 0xFFF6) {
				// ref
				var v = doBinary(ni);
				return [ HaxeRuntime.ref__(v[0]), v[1] ];
			} else if (word == 0xFFFA) {
				// string, < 65536 length
				var l = getWord(ni);
				return [ substr(ni + 1, l), ni + 1 + l ];
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
				var result = doArray(ni + 1, l);
				return result;
			} else if (word == 0xFFF7) {
				// empty array
				return [ [], ni ];
			} else if (word == 0xFFFB) {
				// string, >= 65536 length
				var l = getInt(ni);
				return [ substr(ni + 2, l), ni + 2 + l ];
			} else if (word == 0xFFF9) {
				// array, >= 65536 length
				var l = getInt(ni);
				var result = doArray(ni + 2, l);
				return result;
			} else if (word == 0xFFFF) {
				return  [ null, ni ];
			} else {
				return [ word, ni ];
			}
		} else {
			return  [ DefValue,  index ];
		}
	}

	private var DefValue : Dynamic;
	private var Fixups : Dynamic;
	private var endIndex : Int;
	public function deserialise(defvalue : Dynamic, fixups : Dynamic) : Dynamic {
		if (FlowIllegalStruct == null) FlowIllegalStruct = Native.makeStructValue("IllegalStruct", [], null);

		var footer_offset = getFooterOffset();
		endIndex = length;
		StructDefs = ( doBinary(footer_offset[0]) )[0];

		DefValue = defvalue;
		Fixups = fixups;

		endIndex = footer_offset[0];
		var r = doBinary(footer_offset[1]);
		if (r[1] < footer_offset[0]) {
			Errors.print("Did not understand all!");
		}
		return r[0];
	}
}
