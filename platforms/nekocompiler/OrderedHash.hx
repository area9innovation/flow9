class Order<T> {
	public var keys: Array<String>;
	public var vals: Array<T>;
	public function new(keys: Array<String>, vals: Array<T>) {
		this.keys = keys;
		this.vals = vals;
	}
	public function range() { return new Range(0, keys.length); }
}

class OrderedHash <T>{
	public static var NONE = -1;
	private var hash : Map<String,Int>;
	public var length (get, null) : Int;
	var order: Order<T>;

	public function new() {
		hash = new Map();
		order = new Order (new Array(), new Array());
	}

	public function set(key: String, val: T){
		hash.set(key,length);
		order.keys.push(key);
		order.vals.push(val);
	}

	public function remove(key: String){
		hash.remove(key);
		order.keys.push(key);
		order.vals.push(null);
	}

	public function get(key:String):T {
		var index = this.index(key);
		return if (index == NONE) null else order.vals[index];
	}
	public function index(key:String):Int {
		var index = hash.get(key);
		return if (index == null) NONE else index;
	}
	public function geti(i:Int):T { return order.vals[i]; }
	public function keyi(i:Int):String { return order.keys[i]; }
	public function exists(key: String):Bool { return hash.exists(key); }
	public function slice(rng: Range): Order<T> {
		return new Order(order.keys.slice(rng.st, rng.en), order.vals.slice(rng.st, rng.en));
	}
	public function iterator() {
		var it = hash.iterator();
		return {hasNext : it.hasNext, next : function() { return geti(it.next()); }};
	}
	private function get_length() { Assert.check(order.keys.length == order.vals.length); return order.keys.length; }
	public function keys() { return order.keys; }
	public function vals() { return order.vals; }
	public function range() { return order.range(); }
	public function empty() { return length == 0; }
}