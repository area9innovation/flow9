import tables

# native containsNativeHashMap : (m : native, key : ?, __ : [Pair<?, ??>]) -> bool = NativeHashMap.contains;

proc $F_0(containsNativeHashMap)*[K, V](m: Native, k: K, p: seq[$F_1(Pair)[K, V]]): bool =
  return cast[NimTable[K, V]](m.native_v).table.hasKey(k)
