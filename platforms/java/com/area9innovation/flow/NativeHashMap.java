package com.area9innovation.flow;

import java.util.HashMap;

public class NativeHashMap extends NativeHost {

	public static final Object init() {
		return new HashMap<Object, Object>();
	}

	@SuppressWarnings (value="unchecked")
	public static final Object set(Object map, Object key, Object val) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		hashMap.put(key, val);
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final Object get(Object map, Object key, Object val) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		return hashMap.getOrDefault(key, val);
	}

	@SuppressWarnings (value="unchecked")
	public static final Boolean contains(Object map, Object key) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		return hashMap.containsKey(key);
	}

	@SuppressWarnings (value="unchecked")
	public static final Object remove(Object map, Object key) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		hashMap.remove(key);
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final Object[] values(Object map) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		return hashMap.values().toArray();
	}

	@SuppressWarnings (value="unchecked")
	public static final Object[] keys(Object map) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		return hashMap.keySet().toArray();
	}

	@SuppressWarnings (value="unchecked")
	public static final int size(Object map) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		return hashMap.size();
	}

	@SuppressWarnings (value="unchecked")
	public static final Object clear(Object map) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		hashMap.clear();
		return null;
	}

	@SuppressWarnings (value="unchecked")
	public static final Object clone(Object map) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		return hashMap.clone();
	}

	@SuppressWarnings (value="unchecked")
	public static final Boolean isEmpty(Object map) {
		HashMap<Object, Object> hashMap = (HashMap<Object, Object>) map;
		return hashMap.isEmpty();
	}

	@SuppressWarnings (value="unchecked")
	public static final Boolean equals(Object map1, Object map2) {
		HashMap<Object, Object> hashMap1 = (HashMap<Object, Object>) map1;
		HashMap<Object, Object> hashMap2 = (HashMap<Object, Object>) map2;
		return hashMap1.equals(hashMap2);
	}

	@SuppressWarnings (value="unchecked")
	public static final Object merge(Object map1, Object map2) {
		HashMap<Object, Object> hashMap1 = (HashMap<Object, Object>) map1;
		HashMap<Object, Object> hashMap2 = (HashMap<Object, Object>) map2;
		hashMap1.putAll(hashMap2);
		return null;
	}
}
