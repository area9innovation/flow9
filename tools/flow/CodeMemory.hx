import ByteMemory;

class CodeMemory {
	public function new(codeBytes : BytesInput, memory : ByteMemory, start : Int) {
		position = start;
		this.start = start;
		this.memory = memory;
		var b = codeBytes.readAll();
		memory.setBytes(start, b);
		size = start + b.length;
	}
	
	public inline function eof() : Bool {
		return position >= size;
	}
	public inline function getPosition() : Int {
		return position;
	}
	public inline function setPosition(p : Int) : Void {
		position = p;
	}
	public inline function readByte() : Int {
		return memory.getByte(position++);
	}
	public inline function readInt31() : Int {
		var i = memory.getI32(position);
		position += 4;
		return I2i.toInt(i);
	}
	public inline function readInt32() : I32 {
		var i = memory.getI32(position);
		position += 4;
		return i;
	}
	public inline function readDouble() : Float {
		var d = memory.getDouble(position);
		position += 8;
		return d;
	}
	public function readString(l : Int) : String {
		var s = new StringBuf();
		for (i in 0...l) {
			s.addChar(readByte());
		}
		return s.toString();
	}
	
	public function readWideString(l : Int) : String {
		var s: String = "";		
		for (i in 0...l) {
			var code = readByte() | (readByte() << 8);
			s += Util.fromCharCode(code);
		}
		return s;
	}

	public function skipInt() {
		position += 4;
	}
	public function skipDouble() {
		position += 8;
	}
	public function skipByte() {
		position += 1;
	}
	public function skipString(l : Int) {
		position += l;
	}
	var position : Int;
	var start : Int;
	public var size : Int;
	var memory : ByteMemory;
}
