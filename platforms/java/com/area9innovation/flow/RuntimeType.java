package com.area9innovation.flow;

import java.util.Hashtable;

public enum RuntimeType {
	VOID, BOOL, INT, DOUBLE, STRING, REF, STRUCT, ARRAY, UNKNOWN;

	private static Hashtable<Class, RuntimeType> type_map = new Hashtable<Class, RuntimeType>();

	static {
		type_map.put(Boolean.class, BOOL);
		type_map.put(Integer.class, INT);
		type_map.put(Double.class, DOUBLE);
		type_map.put(String.class, STRING);
		type_map.put(Object[].class, ARRAY);
		type_map.put(Reference.class, REF);
	}

	public static RuntimeType classify(Object v) {
		if (v == null)
			return VOID;

		if (v instanceof Struct)
			return STRUCT;

		RuntimeType rt = type_map.get(v.getClass());

		return (rt == null) ? UNKNOWN : rt;
	}
}
