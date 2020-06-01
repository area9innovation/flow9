package com.area9innovation.flow;

import java.util.*;
import java.nio.charset.Charset;

@SuppressWarnings("unchecked")
public class Database extends NativeHost {
	// native connectDb : (host : string, port : int, socket : string, user : string, password : string, database : string) -> native = Database.connectDb;
	public Object connectDb(String host, int port, String socket, String user, String password, String database) {
		return null;
	}

	public String connectExceptionDb(Object database) {
		return "Database not supported in this target";
	}

	// native closeDb : (database : native) -> void = Database.closeDb;
	public Object closeDb(Object database) {
	}

	// native escapeDb : (database : native, s : string) -> string = Database.escapeDb;
	public String escapeDb(Object database, String s) {
		return s;
	}

	// native requestDb : (database : native, query : string) -> native = Database.requestDb;
	public Object requestDb(Object database, String s) {
		return null;
	}

	// native requestExceptionDb : (database : native) -> string = Database.requestExceptionDb;
	public String requestExceptionDb(Object database) {
		return "Database requests not supported in this target";
	}

	// native lastInsertIdDb : (database : native) -> int = Database.lastInsertIdDb;
	public Integer lastInsertIdDb(Object database) {
		return -1;
	}

	// native requestDbMulti : io (database : native, queries : [string]) -> [[[DbField]]] = Database.requestDbMulti;
	public Object[][][] requestDbMulti(Object database, Object[] queries) {
		return new Object[0][0][0];
	}

	// native startTransactionDb : (database : native) -> void = Database.startTransactionDb;
	public Object startTransactionDb(Object database) {
	}

	// native commitDb : (database : native) -> void = Database.commitDb;
	public Object commitDb(Object database) {
	}

	// native rollbackDb : (database : native) -> void = Database.rollbackDb;
	public Object rollbackDb(Object database) {
	}

	// native resultLengthDb : (result : native) -> int = Database.resultLengthDb;
	public Integer resultLengthDb(Object result) {
		return 0;
	}

	// native getIntResultDb : (result : native, n : int) -> int = Database.getIntResultDb;
	public Integer getIntResultDb(Object result, Integer n) {
		return 0;
	}

	// native getFloatResultDb : (result : native, n : int) -> double = Database.getFloatResultDb;
	public Double getFloatResultDb(Object result, Integer n) {
		return 0.0;
	}

	// native getResultDb : (result : native, n : int) -> string = Database.getResultDb;
	public String getResultDb(Object result, Integer n)  {
		return "";
	}

	// native hasNextResultDb : (result : native) -> bool = Database.hasNextResultDb;
	public boolean hasNextResultDb(Object result)  {
		return false;
	}

	// native nextResultDb : (result : native) -> [DbField] = Database.nextResultDb;
	public Object[] nextResultDb(Object result) {
		return new Object[0];
	}
}