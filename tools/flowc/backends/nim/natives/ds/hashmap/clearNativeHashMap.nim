import tables

#native clearNativeHashMap : (m : native, __ : [Pair<?, ??>]) -> void = NativeHashMap.clear;

proc $F_0(clearNativeHashMap)*[K, V](var m: Native, p: seq[$F_1(Pair)[K, V]]): void =
  cast[NimTable[K, V]](m.native_v).table.clear()
