package js;

class BinaryBuffer {
	private var bigEndian: Bool;
	private var buffer: Array<Int>;

	public function new(bigEndian, buffer: Array<Int>) {
		this.bigEndian = bigEndian;
		this.buffer = [];
		this.setBuffer(buffer);
	}

	public function readBits(start, length) {
		untyped __js__("//shl fix: Henri Torgemane ~1996 (compressed by Jonas Raoni)
			    function shl(a, b){
				for(++b; --b; a = ((a %= 0x7fffffff + 1) & 0x40000000) == 0x40000000 ? a * 2 : (a - 0x40000000) * 2 + 0x7fffffff + 1);
				return a;
			    }
			    if(start < 0 || length <= 0)
				return 0;
			    this.checkBuffer(start + length);
			    for(var offsetLeft, offsetRight = start % 8, curByte = this.buffer.length - (start >> 3) - 1,
				lastByte = this.buffer.length + (-(start + length) >> 3), diff = curByte - lastByte,
				sum = ((this.buffer[ curByte ] >> offsetRight) & ((1 << (diff ? 8 - offsetRight : length)) - 1))
				+ (diff && (offsetLeft = (start + length) % 8) ? (this.buffer[ lastByte++ ] & ((1 << offsetLeft) - 1))
				<< (diff-- << 3) - offsetRight : 0); diff; sum += shl(this.buffer[ lastByte++ ], (diff-- << 3) - offsetRight)
			    );
			    return sum;
		");
	}

	public function setBuffer(data: Array<Int>) {
		untyped __js__("if(data){
			for(var l, i = l = data.length, b = this.buffer = new Array(l); i; b[l - i] = data.charCodeAt(--i));
			this.bigEndian && b.reverse();
		    }");
	}

	public function hasNeededBits(neededBits: Int): Bool {
            return this.buffer.length >= -(-neededBits >> 3);
        }

        public function checkBuffer(neededBits: Int){
            if(!this.hasNeededBits(neededBits))
                untyped __js__("throw new Error(\"checkBuffer::missing bytes\");");
        }

}