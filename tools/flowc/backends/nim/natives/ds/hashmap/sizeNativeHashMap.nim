import tables

# native sizeNativeHashMap : (m : native, __ : [Pair<?, ??>]) -> int = NativeHashMap.size;

proc $F_0(sizeNativeHashMap)*[K, V](m: Native, p: seq[$F_1(Pair)[K, V]]): int32 =
  return int32(cast[NimTable[K, V]](m.native_v).table.len)
