package com.area9innovation.flow;

import java.util.HashMap;

public class NativeIntMap extends NativeHost {

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

	public static final <V> HashMap<Integer, V> init(int cap) {
		return new HashMap<Integer, V>(cap);
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> Object set(Object map, int key, V val) {
		((HashMap<Integer, V>) map).put(key, val);
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> Struct get(Object map, int key) {
		V val = ((HashMap<Integer, V>) map).get(key);
		if (val != null) {
			final Struct copy = some.clone();
			final Object[] fields = {val};
			copy.setFields(fields);
			return copy;
		} else {
			return none;
		}
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> Boolean contains(Object map, int key) {
		return ((HashMap<Integer, V>) map).containsKey(key);
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> Object remove(Object map, Object key) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		hashMap.remove(key);
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> int size(Object map) {
		return ((HashMap<Integer, V>) map).size();
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> Object clear(Object map) {
		((HashMap<Integer, V>) map).clear();
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> Object clone(Object map) {
		return ((HashMap<Integer, V>) map).clone();
	}

	@SuppressWarnings (value="unchecked")
	public static final <V> Object iter(Object map, Func2<Object, Integer, V> fn) {
		((HashMap<Integer, V>) map).forEach(new java.util.function.BiConsumer<Integer, V>() {
			public void accept(Integer k, V v) {
				fn.invoke(k, v);
			}
		});
		return null;
	}
}
