import HaxeRuntime;
import Native;
import js.html.ArrayBuffer;
import js.html.Uint8Array;
import js.html.DataView;

// A value still being read around the current one: what it is, how many elements it takes, those read so far
private typedef BinaryFrame = { kind : Int, count : Int, elements : Array<Dynamic>, name : String };

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

	private static inline var arrayFrame = 0;
	private static inline var structFrame = 1;
	private static inline var refFrame = 2;

	// A result index below zero marks damaged input: the whole value becomes the default
	private static inline var damagedBinaryIndex = -1;

	private inline function damaged() : Dynamic {
		return [ DefValue, damagedBinaryIndex ];
	}

	private inline function isDamaged(r : Dynamic) : Bool {
		return r[1] < 0;
	}

	private function getFooterOffset() : Dynamic {
		if (length < 2) {
			return [ 0, 2 ];
		}
		var footerOffset = getWord(0) | (getWord(1) << 16);
		if (footerOffset != 1) {
			return [ footerOffset, 2 ];
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

	// Bounded reads: each checks that its words lie before endIndex and yields the value and the index after it
	private function readWord(index : Int) : Dynamic {
		if (index >= endIndex) return damaged();
		return [ getWord(index), index + 1 ];
	}

	private function readInt(index : Int) : Dynamic {
		if (endIndex - index < 2) return damaged();
		return [ getInt(index), index + 2 ];
	}

	private function readDouble(index : Int) : Dynamic {
		if (endIndex - index < 4) return damaged();
		return [ getDouble(index), index + 4 ];
	}

	// A run of l characters; a negative length is damaged too
	private function readChars(index : Int, l : Int) : Dynamic {
		if (l < 0 || l > endIndex - index) return damaged();
		return [ substr(index, l), index + l ];
	}

	// An int at index: a small word, or a tagged 32-bit int in one of its two forms
	private function readIntValue(index : Int) : Dynamic {
		var tag = readWord(index);
		if (isDamaged(tag)) return tag;
		var word : Int = tag[0];
		if (word < 0xFFF3) return tag;
		if (word == 0xFFF5) return readInt(tag[1]);
		if (word != 0xFFF3) return damaged();
		// Two ints, value & 0xF0F0F0F0 and value & 0x0F0F0F0F, so that no word is a UTF-16 surrogate
		var high = readInt(tag[1]);
		if (isDamaged(high)) return high;
		var low = readInt(high[1]);
		if (isDamaged(low)) return low;
		return [ high[0] | low[0], low[1] ];
	}

	// A string at index: its length in a word or an int after the tag, then its characters
	private function readStringValue(index : Int) : Dynamic {
		var tag = readWord(index);
		if (isDamaged(tag)) return tag;
		var l = tag[0] == 0xFFFA ? readWord(tag[1]) : tag[0] == 0xFFFB ? readInt(tag[1]) : damaged();
		if (isDamaged(l)) return l;
		return readChars(l[1], l[0]);
	}

	// An array head at index: its element count, which fits the words that remain, and where its elements start
	private function readCount(index : Int) : Dynamic {
		var tag = readWord(index);
		if (isDamaged(tag)) return tag;
		var count = tag[0] == 0xFFF7 ? [ 0, tag[1] ] : tag[0] == 0xFFF8 ? readWord(tag[1]) : tag[0] == 0xFFF9 ? readInt(tag[1]) : damaged();
		// Each element takes at least one word
		if (isDamaged(count) || count[0] < 0 || count[0] > endIndex - count[1]) return damaged();
		return count;
	}

	// A value with no elements of its own, read with its tag at index
	private function readLeaf(index : Int) : Dynamic {
		var word = getWord(index);
		var ni = index + 1;
		if (word == 0xFFF3 || word == 0xFFF5) return readIntValue(index);
		if (word == 0xFFFA || word == 0xFFFB) return readStringValue(index);
		if (word == 0xFFFC) return readDouble(ni);
		if (word == 0xFFFD) return [ false, ni ];
		if (word == 0xFFFE) return [ true, ni ];
		return [ null, ni ]; // 0xFFFF is void
	}

	// The footer is [[arity, name], ...]: an array of entries, each an array of exactly an int and a string
	private function readStructDefs(index : Int) : Array<Dynamic> {
		var count = readCount(index);
		if (isDamaged(count)) return null;
		var entries : Int = count[0];
		var defs = [];
		var i : Int = count[1];
		for (n in 0...entries) {
			var size = readCount(i);
			if (isDamaged(size) || size[0] != 2) return null;
			var arity = readIntValue(size[1]);
			if (isDamaged(arity) || arity[0] < 0) return null;
			var name = readStringValue(arity[1]);
			if (isDamaged(name)) return null;
			defs.push([ arity[0], name[0] ]);
			i = name[1];
		}
		return defs;
	}

	private function makeStruct(name : String, args : Array<Dynamic>) : Dynamic {
		var fixup = getFixup(name);
		return fixup == null ? Native.makeStructValue(name, args, FlowIllegalStruct) : fixup(args);
	}

	// Reads the value at index; frames hold the values still open around the current one, the innermost last
	private function doBinary(index : Int) : Dynamic {
		var frames : Array<BinaryFrame> = [];
		var i = index;
		while (true) {
			if (i >= endIndex) return damaged();
			var word = getWord(i);
			var value : Dynamic = null;
			if (word < 0xFFF3) {
				// Small ints are the most common value
				value = word;
				i++;
			} else if (word == 0xFFF4) {
				var structIndex = readWord(i + 1);
				if (isDamaged(structIndex) || structIndex[0] >= StructDefs.length) return damaged();
				var def : Array<Dynamic> = StructDefs[structIndex[0]];
				var arity : Int = def[0];
				i = structIndex[1];
				// Each field takes at least one word
				if (arity > endIndex - i) return damaged();
				if (arity > 0) {
					frames.push({ kind: structFrame, count: arity, elements: [], name: def[1] });
					continue;
				}
				value = makeStruct(def[1], []);
			} else if (word == 0xFFF6) {
				frames.push({ kind: refFrame, count: 1, elements: null, name: null });
				i++;
				continue;
			} else if (word == 0xFFF7 || word == 0xFFF8 || word == 0xFFF9) {
				var count = readCount(i);
				if (isDamaged(count)) return damaged();
				i = count[1];
				if (count[0] > 0) {
					frames.push({ kind: arrayFrame, count: count[0], elements: [], name: null });
					continue;
				}
				value = [];
			} else {
				var leaf = readLeaf(i);
				if (isDamaged(leaf)) return damaged();
				value = leaf[0];
				i = leaf[1];
			}
			// The value is complete: it closes every frame it fills
			while (true) {
				if (frames.length == 0) return [ value, i ];
				var frame = frames[frames.length - 1];
				if (frame.kind == refFrame) {
					frames.pop();
					value = HaxeRuntime.ref__(value);
				} else {
					frame.elements.push(value);
					if (frame.elements.length < frame.count) break;
					frames.pop();
					value = frame.kind == arrayFrame ? frame.elements : makeStruct(frame.name, frame.elements);
				}
			}
		}
	}

	private var DefValue : Dynamic;
	private var Fixups : Dynamic;
	private var endIndex : Int;
	public function deserialise(defvalue : Dynamic, fixups : Dynamic) : Dynamic {
		if (FlowIllegalStruct == null) FlowIllegalStruct = Native.makeStructValue("IllegalStruct", [], null);

		DefValue = defvalue;
		Fixups = fixups;
		// Another call may bring other fixups and another footer
		StructDefs = [];
		StructFixupCache = new Map();

		var footer = getFooterOffset();
		var footerOffset : Int = footer[0];
		var bodyStart : Int = footer[1];
		// The footer lies after the header words and holds at least one word
		if (!(bodyStart < footerOffset && footerOffset < length)) return damagedInput();

		endIndex = length;
		var defs = readStructDefs(footerOffset);
		if (defs == null) return damagedInput();
		StructDefs = defs;

		endIndex = footerOffset;
		var r = doBinary(bodyStart);
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
