import tables

#native makeNativeHashMap : (hash :(?) -> int, cap : int, load : double, __ : [Pair<?, ??>]) -> native = NativeHashMap.init;

proc $F_0(makeNativeHashMap)*[K, V](hash: proc(k: K): int32, cap: int32, load: float, p: seq[$F_1(Pair)[K, V]]): Native =
  return Native(ntp: ntOther, native_v: NimTable[K, V](table: newTable[K, V](cap)))
