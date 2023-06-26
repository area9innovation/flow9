import tables

#native getNativeHashMap : (m : native, key : ?, __ : [Pair<?, ??>]) -> Maybe<??> = NativeHashMap.get;

proc $F_0(getNativeHashMap)*[K, V](m: Native, k: K, p: seq[$F_1(Pair)[K, V]]): $F_1(Maybe)[V] =
  let tab = cast[NimTable[K, V]](m.native_v).table
  if tab.hasKey(k):
    return cast[$F_1(Maybe)[V]]($F_1(Some)[V](str_id: st_Some, value: tab[k]))
  else:
    return cast[$F_1(Maybe)[V]]($F_1(None)(str_id: st_None))
