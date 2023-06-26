import tables

# native funcNativeHashMap : (m : native, __ : [Pair<?, ??>]) -> (?) -> int = NativeHashMap.hash;

proc $F_0(funcNativeHashMap)*[K, V](m: Native, P: seq[$F_1(Pair)[K, V]]): proc(k: K): int32 =
  return proc(k: K): int32 = int32(hash(k))
