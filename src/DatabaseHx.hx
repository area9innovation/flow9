class DatabaseHx {
	// native connectDb : (host : string, port : int, socket : string, user : string, password : string, database : string) -> native = Database.connectDb;
	public static function connectDb(host : String, port : Int, socket : String, user : String, password : String, database : String) : Dynamic {
		return null;
	}

	public static function connectExceptionDb(database : Dynamic) : String {
		return "Database not supported in this target";
	}

	// native closeDb : (database : native) -> void = Database.closeDb;
	public static function closeDb(database : Dynamic) : Void {
	}

	// native escapeDb : (database : native, s : string) -> string = Database.escapeDb;
	public static function escapeDb(database : Dynamic, s : String) : String {
		return s;
	}

	// native requestDb : (database : native, query : string) -> native = Database.requestDb;
	public static function requestDb(database : Dynamic, s : String) : Dynamic {
		return null;
	}

	// native requestExceptionDb : (database : native, result : native) -> string = Database.requestExceptionDb;
	public static function requestExceptionDb(database : Dynamic, result : Dynamic) : String {
		return "Database requests not supported in this target";
	}

	// native lastInsertIdDb : (database : native) -> int = Database.lastInsertIdDb;
	public static function lastInsertIdDb(database : Dynamic) : Int {
		return -1;
	}

	// native startTransactionDb : (database : native) -> void = Database.startTransactionDb;
	public static function startTransactionDb(database : Dynamic) : Void {
	}

	// native commitDb : (database : native) -> void = Database.commitDb;
	public static function commitDb(database : Dynamic) : Void {
	}

	// native rollbackDb : (database : native) -> void = Database.rollbackDb;
	public static function rollbackDb(database : Dynamic) : Void {
	}

	// native resultLengthDb : (result : native) -> int = Database.resultLengthDb;
	public static function resultLengthDb(result : Dynamic) : Int {
		return 0;
	}

	// native getIntResultDb : (result : native, n : int) -> int = Database.getIntResultDb;
	public static function getIntResultDb(result : Dynamic, n : Int) : Int {
		return 0;
	}
	
	// native getFloatResultDb : (result : native, n : int) -> double = Database.getFloatResultDb;
	public static function getFloatResultDb(result : Dynamic, n : Int) : Float {
		return 0.0;
	}

	// native getResultDb : (result : native, n : int) -> string = Database.getResultDb;
	public static function getResultDb(result : Dynamic, n : Int) : String  {
		return "";
	}

	// native hasNextResultDb : (result : native) -> bool = Database.hasNextResultDb;
	public static function hasNextResultDb(result : Dynamic) : Bool  {
		return false;
	}

	// native nextResultDb : (result : native) -> [DbField] = Database.nextResultDb;
	public static function nextResultDb(result : Dynamic) : Array<Dynamic> {
		return [];
	}
}
