package com.area9innovation.flow;

import java.util.HashMap;

public class NativeHashMap extends NativeHost {

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

	public static final <K, V> HashMap<K, V> init(Func1<Integer, K> hash, int cap, double load, Object dummy[]) {
		return new HashMap<K, V>(cap, (float)load);
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> Object set(Object map, K key, V val) {
		((HashMap<K, V>) map).put(key, val);
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> Struct get(Object map, K key, Object dummy[]) {
		V val = ((HashMap<K, V>) map).get(key);
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
	public static final <K, V> Boolean contains(Object map, K key, Object dummy[]) {
		return ((HashMap<K, V>) map).containsKey(key);
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> Object remove(Object map, Object key, Object dummy[]) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		hashMap.remove(key);
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> int size(Object map, Object dummy[]) {
		return ((HashMap<K, V>) map).size();
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> Object clear(Object map, Object dummy[]) {
		((HashMap<K, V>) map).clear();
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> Object clone(Object map, Object dummy[]) {
		return ((HashMap<K, V>) map).clone();
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> Object iter(Object map, Func2<Object, K, V> fn, Object dummy[]) {
		((HashMap<K, V>) map).forEach(new java.util.function.BiConsumer<K, V>() {
			public void accept(K k, V v) {
				fn.invoke(k, v);
			}
		});
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final <K, V> Func1<Integer, K> hash(Object map, Object dummy[]) {
		return new Func1<Integer, K>() {
			public Integer invoke(K k) {
				return k.hashCode();
			}
		};
	}
}
