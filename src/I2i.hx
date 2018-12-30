class I2i {
	static public inline function toInt(i : Int) {
		return i;
	}

	static public function intFromFloat(d : Float) : Int {
		return Std.int(d);
	}
	
	static public function floatFromInt(f : Int) : Float {
		return 0.0 + f;
	}

	static public inline function compare(i1 : Int, i2 : Int) : Int {
		if (i1 < i2) return -1
		else if (i1 == i2) return 0
		else return 1;
	}

	public static function ucompare( a : Int, b : Int ) : Int {
		if ( a < 0 )
			return b < 0 ? compare(~b,~a) : 1;
		return b < 0 ? -1 : compare(a, b);
	}

}
