import haxe.ds.HashMap;
import HaxeRuntime;

private class FlowHashKey<K> {
	public var key: K;
	public var hashCode: () -> Int; 
	public function new(key, hash) {
		this.key = key;
		var code = hash(key);
		this.hashCode = function() return code;
	}
}

private class FlowHashMap<K, T> {
	public var map: HashMap<FlowHashKey<K>, T>;
	public var hash: K -> Int;
	public function new(hash) {
		this.map = new HashMap<FlowHashKey<K>, T>();
		this.hash = hash;
	}
}

class NativeHashMap {

public static function makeNativeHashMap<K, T>(hash: K -> Int, capacity: Int, load_factor: Float): FlowHashMap<K, T> {
	return new FlowHashMap<K, T>(hash);
}

public static function setNativeHashMap<K, T>(m: FlowHashMap<K, T>, key: K, val: T): Void {
	m.map.set(new FlowHashKey(key, m.hash), val);
}

public static function getNativeHashMap<K, T>(m: FlowHashMap<K, T>, key: K): Dynamic {
	var result: Null<T> = m.map.get(new FlowHashKey(key, m.hash));
	if (result != null) {
		return HaxeRuntime.makeStructValue("Some", [result], HaxeRuntime.makeStructValue("IllegalStruct", [], null));
	} else {
		return HaxeRuntime.makeStructValue("None", [], HaxeRuntime.makeStructValue("IllegalStruct", [], null));
	}
}

public static function removeNativeHashMap<K, T>(m: FlowHashMap<K, T>, key: K): Void {
	m.map.remove(new FlowHashKey(key, m.hash));
}

public static function containsNativeHashMap<K, T>(m: FlowHashMap<K, T>, key: K): Bool {
	return m.map.exists(new FlowHashKey(key, m.hash));
}

public static function sizeNativeHashMap<K, T>(m: FlowHashMap<K, T>): Int {
	var size: Int = 0;
	for (key in m.map) size += 1;
	return size;
}

public static function clearNativeHashMap<K, T>(m: FlowHashMap<K, T>): Void {
	m.map.clear();
}

public static function cloneNativeHashMap<K, T>(m: FlowHashMap<K, T>): FlowHashMap<K, T> {
	var clone = new FlowHashMap<K, T>(m.hash);
	for (k in m.map.keys()) {
		var val: Null<T> = m.map.get(k);
		if (val != null) {
			clone.map.set(k, val);
		}
	}
	return clone;
}

public static function iterNativeHashMap<K, T>(m: FlowHashMap<K, T>, fn: K -> T -> Void): Void {
	for (k in m.map.keys()) {
		var val: Null<T> = m.map.get(k);
		if (val != null) {
			fn(k.key, val);
		}
	}
}

public static function funcNativeHashMap<K, T>(m: FlowHashMap<K, T>): K -> Int {
	return m.hash;
}

}
