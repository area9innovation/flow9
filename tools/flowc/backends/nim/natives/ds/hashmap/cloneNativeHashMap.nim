import tables

# native cloneNativeHashMap : (m : native, __ : [Pair<?, ??>]) -> native = NativeHashMap.clone;

proc $F_0(cloneNativeHashMap)*[K, V](m: Native, p: seq[$F_1(Pair)[K, V]]): Native =
  let tab = cast[NimTable[K, V]](m.native_v).table
  let ret = newTable(tab.len)
  for k, v in pairs(tab): ret[k] = v
  return ret