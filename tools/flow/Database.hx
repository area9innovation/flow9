import Flow;
import FlowArray;
import Type;

class Database {
	public function new(interpreter : Interpreter) {
		connectException = "";
		this.interpreter = interpreter;
	}
	
	var interpreter : Interpreter;

	// native connectDb : (host : string, port : int, socket : string, user : string, password : string, database : string) -> native = Database.connectDb;
	public function connectDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				connectException = "";
				var db = sys.db.Mysql.connect({
					host: FlowUtil.getString(args[0]),
					port: FlowUtil.getInt(args[1]),
					socket: FlowUtil.getString(args[2]),
					user: FlowUtil.getString(args[3]),
					pass: FlowUtil.getString(args[4]),
					database: FlowUtil.getString(args[5]),
				});
				return ConstantNative(db, pos);
			} catch (e : Dynamic) {
				connectException = '' + e;
				return ConstantNative(null, pos);
			}
		#else
			return ConstantNative(null, pos);
		#end
	}
	static var connectException : String;

	// native connectExceptionDb : (database : native) -> string = Database.connectExceptionDb;
	public function connectExceptionDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			return ConstantString(connectException, pos);
		#else
			return ConstantString("Database not supported in this target", pos);
		#end
	}

	// native closeDb : (database : native) -> void = Database.closeDb;
	public function closeDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			var db : sys.db.Connection = FlowUtil.getNative(args[0]);
			if (db != null) {
				db.close();
			}
		#end
		return ConstantVoid(pos);
	}

	// native escapeDb : (database : native, s : string) -> string = Database.escapeDb;
	public function escapeDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			var db : sys.db.Connection = FlowUtil.getNative(args[0]);
			if (db != null) {
				return ConstantString(db.escape(FlowUtil.getString(args[1])), pos);
			}
		#end
		return args[1];
	}

	// native requestDb : (database : native, query : string) -> native = Database.requestDb;
	public function requestDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				var db : sys.db.Connection = FlowUtil.getNative(args[0]);
				if (db != null) {
					requestException = "";
					return ConstantNative(db.request(FlowUtil.getString(args[1])), pos);
				} else {
					requestException = "Invalid database";
				}
			} catch (e : Dynamic) {
				requestException = '' + e;
			}
		#end
		return ConstantNative(null, pos);
	}
	static var requestException : String;

	// native requestExceptionDb : (database : native, result : native) -> string = Database.requestExceptionDb;
	public function requestExceptionDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			return ConstantString(requestException, pos);
		#else
			return ConstantString("Database requests not supported in this target", pos);
		#end
	}

	// native lastInsertIdDb : (database : native) -> int = Database.lastInsertIdDb;
	public function lastInsertIdDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			var db : sys.db.Connection = FlowUtil.getNative(args[0]);
			if (db != null) {
				return ConstantI32((db.lastInsertId()), pos);
			}
		#end
		return ConstantI32((-1), pos);
	}

	// native startTransactionDb : (database : native) -> void = Database.startTransactionDb;
	public function startTransactionDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			var db : sys.db.Connection = FlowUtil.getNative(args[0]);
			if (db != null) {
				db.startTransaction();
			}
		#end
		return ConstantVoid(pos);
	}

	// native commitDb : (database : native) -> void = Database.commitDb;
	public function commitDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			var db : sys.db.Connection = FlowUtil.getNative(args[0]);
			if (db != null) {
				db.commit();
			}
		#end
		return ConstantVoid(pos);
	}

	// native rollbackDb : (database : native) -> void = Database.rollbackDb;
	public function rollbackDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			var db : sys.db.Connection = FlowUtil.getNative(args[0]);
			if (db != null) {
				db.rollback();
			}
		#end
		return ConstantVoid(pos);
	}

	// native resultLengthDb : (result : native) -> int = Database.resultLengthDb;
	public function resultLengthDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				var results : sys.db.ResultSet = FlowUtil.getNative(args[0]);
				return ConstantI32((results.length), pos);
			} catch (e : Dynamic) {
			}
		#end
		return ConstantI32((0), pos);
	}

	// native getIntResultDb : (result : native, n : int) -> int = Database.getIntResultDb;
	public function getIntResultDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				var results : sys.db.ResultSet = FlowUtil.getNative(args[0]);
				return ConstantI32((results.getIntResult(FlowUtil.getInt(args[1]))), pos);
			} catch (e : Dynamic) {
			}
		#end
		return ConstantI32((0), pos);
	}
	
	// native getFloatResultDb : (result : native, n : int) -> double = Database.getFloatResultDb;
	public function getFloatResultDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				var results : sys.db.ResultSet = FlowUtil.getNative(args[0]);
				return ConstantDouble(results.getFloatResult(FlowUtil.getInt(args[1])), pos);
			} catch (e : Dynamic) {
			}
		#end
		return ConstantDouble(0.0, pos);
	}

	// native getResultDb : (result : native, n : int) -> string = Database.getResultDb;
	public function getResultDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				var results : sys.db.ResultSet = FlowUtil.getNative(args[0]);
				return ConstantString(results.getResult(FlowUtil.getInt(args[1])), pos);
			} catch (e : Dynamic) {
			}
		#end
		return ConstantString("", pos);
	}

	// native hasNextResultDb : (result : native) -> bool = Database.hasNextResultDb;
	public function hasNextResultDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				var results : sys.db.ResultSet = FlowUtil.getNative(args[0]);
				return ConstantBool(results.hasNext(), pos);
			} catch (e : Dynamic) {
			}
		#end
		return ConstantBool(false, pos);
	}

	// native nextResultDb : (result : native) -> [DbField] = Database.nextResultDb;
	public function nextResultDb(args : FlowArray<Flow>, pos : Position) : Flow  {
		#if sys
			try {
				var results : sys.db.ResultSet = FlowUtil.getNative(args[0]);
				var row = results.next();
				if (row != null) {
					var array = new FlowArray();
					var nfields = results.nfields;
					var fields = results.getFieldsNames();
					for (i in 0...nfields) {
						var f = fields[i];
						var v = results.getResult(i);
						var name = ConstantString(f, pos);
						// Neko is brain dead! We can NOT get ints out as ints if they are bigger than 30 bits
						// so we treat everything as strings. Sigh.
						array.push(ConstantStruct("DbStringField", [ name, ConstantString(v, pos) ], pos));
					}
					return ConstantArray(array, pos);
				}
			} catch (e : Dynamic) {
				trace(e);
				trace(Assert.callStackToString(haxe.CallStack.exceptionStack()));
			}
		#end
		return ConstantArray(new FlowArray(), pos);
	}
}
