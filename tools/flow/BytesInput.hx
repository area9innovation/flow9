class BytesInput extends haxe.io.BytesInput {
	public function new( b : haxe.io.Bytes, ?pos : Int, ?len : Int ) {
		super(b, pos, len);
		size = len;
	}
	public inline function getPosition() : Int {
		#if flash9
		return untyped b.position;
		#else
		return untyped pos;
		#end
	}
	public inline function setPosition(position : Int) : Void {
		#if flash9
		untyped b.position = position;
		#else
		var d = pos - position;
		untyped pos = position;
		untyped len += d;
		#end
	}
	public inline function eof() : Bool {
		return getPosition() >= size;
	}
	public var size : Int;
}
