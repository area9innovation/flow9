import tables

# native removeNativeHashMap : (m : native, key : ?, __ : [Pair<?, ??>]) -> void = NativeHashMap.remove;

proc $F_0(removeNativeHashMap)*[K, V](m: Native, k: K, p: seq[$F_1(Pair)[K, V]]): void =
  cast[NimTable[K, V]](m.native_v).table.del(k)
