package com.area9innovation.flow;

import java.util.ArrayList;
import java.util.Enumeration;
import java.util.concurrent.ConcurrentHashMap;

public class ConcurHashMap extends NativeHost {
	private static Struct some = null;
	private static Struct none = null;

	public void initialize() {
		Integer some_id = FlowRuntime.struct_ids.get("Some"); 
		if (some_id == null) {
			System.out.println("'Some' struct is not found");
			System.exit(-1);
		}
		some = FlowRuntime.struct_prototypes[some_id];
		Integer none_id = FlowRuntime.struct_ids.get("None"); 
		if (none_id == null) {
			System.out.println("'None' struct is not found");
			System.exit(-1);
		}
		none = FlowRuntime.struct_prototypes[none_id];
	}

	public static final Object make(Func1<Integer, Object> hash, Object[] dummy) {
		return new ConcurrentHashMap();
	}

	@SuppressWarnings("unchecked")
	public static final Object set(Object map, Object key, Object value) {
		((ConcurrentHashMap<Object, Object>) map).put(key, value);
		return null;
	}

	@SuppressWarnings("unchecked")
	public static final Struct get(Object map, Object key, Object[] dummy) {
		ConcurrentHashMap concurrentMap = (ConcurrentHashMap) map;
		Object val = concurrentMap.get(key);
		if (val != null) {
			final Struct copy = some.clone();
			final Object[] fields = {val};
			copy.setFields(fields);
			return copy;
		} else {
			return none;
		}
	}

	@SuppressWarnings("unchecked")
	public static final Boolean containsKey(Object map, Object key, Object[] dummy) {
		return ((ConcurrentHashMap) map).containsKey(key);
	}

	@SuppressWarnings("unchecked")
	public static final Object[] values(Object map, Object[] dummy) {
		return ((ConcurrentHashMap) map).values().toArray();
	}

	@SuppressWarnings("unchecked")
	public static final Object remove(Object map, Object key, Object[] dummy) {
		((ConcurrentHashMap) map).remove(key);
		return null;
	}

	@SuppressWarnings("unchecked")
	public static final Object[] keys(Object map, Object[] dummy) {
		ArrayList<Object> ret = new ArrayList<Object>();
		for (Enumeration<Object> e = ((ConcurrentHashMap) map).keys(); e.hasMoreElements();) {
			ret.add(e.nextElement());
		}
		return ret.toArray();
	}

	@SuppressWarnings("unchecked")
	public static final int size(Object map, Object[] dummy) {
		return ((ConcurrentHashMap) map).size();
	}

	@SuppressWarnings("unchecked")
	public static final Object clear(Object map, Object[] dummy) {
		((ConcurrentHashMap) map).clear();
		return null;
	}

	@SuppressWarnings("unchecked")
	public static final Object clone(Object map, Object[] dummy) {
		ConcurrentHashMap clone = new ConcurrentHashMap();
		((ConcurrentHashMap) map).forEach(new java.util.function.BiConsumer<Object, Object>() {
			public void accept(Object k, Object v) {
				clone.put(k, v);
			}
		});
		return clone;
	}
	@SuppressWarnings (value="unchecked")
	public static final Object iter(Object map, Func2<Object, Object, Object> fn, Object dummy[]) {
		((ConcurrentHashMap) map).forEach(new java.util.function.BiConsumer<Object, Object>() {
			public void accept(Object k, Object v) {
				fn.invoke(k, v);
			}
		});
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final Func1<Integer, Object> hash(Object map, Object dummy[]) {
		return new Func1<Integer, Object>() {
			public Integer invoke(Object k) {
				return k.hashCode();
			}
		};
	}
}

