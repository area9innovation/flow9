class HashTable<T> {
	private var hsize : Int;
	var values : Array<T>;
	var hfunc : T -> Int;
	var eqfunc : T -> T -> Bool;
	var htable : Array<Array<Int> >;
	public var length (get, null): Int;
	private function get_length() { return values.length; }
	public function new(hfunc, eqfunc, ?values = null, ?hsize : Int = 4*1024) {
		this.hsize = hsize;
		this.hfunc = hfunc;
		this.eqfunc = eqfunc;
		this.values = if (values != null) values; else  new Array();
		this.htable = new Array();
		for (i in 0 ... hsize) {
			htable.push(new Array());
		}

		// load htable with preloaded values:
		if (values != null)
			for(i in 0 ... values.length) {
				hash(values [i]).push(i);
			}
	}
	private inline function hash(v : T) {
	   return htable [(hfunc(v) & 0x3FFFFFF) % hsize];
	}
	public function puti(value : T) : Int {
		var tab = hash(value);
		for (i in tab)
			if (value == values[i] || eqfunc(value, values[i]))
				return i;
		tab.push(values.length);
		values.push(value);
		return values.length - 1;
	}

	public static function hstr (a : String) {
		var h = 0;
		for (i in 0 ... a.length)
			h += a.charCodeAt(i);
		return h;
	}
	
	public static function hint    (a : Int) { return a; }
	public static function hfloat  (a : Float) : Int {
		var abs = Math.abs(a);
		if (abs != 0)
			while (abs < 1e5) {
				abs *= 10;
			}
		return Math.round(abs);
	}
 	public static function hint32  (a : Int) { return I2i.toInt(a); }
	public static function eqstr   (a : String, b : String) { return a == b; }
	public static function eqint   (a : String, b : String) { return a == b; }
	public static function eqfloat (a : Float, b : Float) { return a == b; }
 	public static function eqint32 (a : Int, b : Int) { return a == b; }

	public static function int32Hash(?values = null) { return new HashTable(hint32, eqint32, values); }
	public static function floatHash(?values = null) { return new HashTable(hfloat, eqfloat, values, 64*1024); }
}