import tables

#native setNativeHashMap : (m : native, key : ?, value : ??) -> void = NativeHashMap.set;

proc $F_0(setNativeHashMap)*[K, V](m: Native, k: K, v: V): void =
  cast[NimTable[K, V]](m.native_v).table[k] = v
