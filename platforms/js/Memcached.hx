class Memcached {

	//native connectMemcached : (host : string, port : int, callback : (native) -> void, onError : (string) -> void) -> void = Memcached.connectMemcached;
	public static function connectMemcached(host : String, port : Int, callback : Dynamic -> Void, onError : String -> Void) : Void {
		onError("Memcached not supported in this target");
	}

	//native setMemcached : (memcached : native, key : string, value : string, expiration : int, callback : () -> void, onError : (string) -> void) -> void = Memcached.setMemcached;
	public static function setMemcached(memcached : Dynamic, key : String, value : String, expiration : Int, callback : Void -> Void, onError : String -> Void) : Void {
		onError("Memcached not supported in this target");
	}

	//native getMemcached : (memcached : native, key : string, callback : (string) -> void, onError : (string) -> void) -> void = Memcached.getMemcached;
	public static function getMemcached(memcached : Dynamic, key : String, callback : String -> Void, onError : String -> Void) : Void {
		onError("Memcached not supported in this target");
	}

}
