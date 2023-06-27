import tables

# native iterNativeHashMap : (m : native, f : (?, ??) -> void, __ : [Pair<?, ??>]) -> void = NativeHashMap.iter;

proc $F_0(iterNativeHashMap)*[K, V](m: Native, f: proc(k: K, v: V): void, p: seq[$F_1(Pair)[K, V]]): void =
  for k, v in pairs(cast[NimTable[K, V]](m.native_v).table):
    f(k, v)
