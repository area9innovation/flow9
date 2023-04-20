# Apply a function which takes an index and each element of an array to give a new array
proc $F_0(mapi)*[T, S](s: openArray[T], op: proc (i: int32, v: T): S): seq[S] =
  var rv: seq[S] = newSeq[S](s.len)
  var i : int32 = 0
  while i < s.len:
    rv[i] = op(i, s[i])
    inc i
  return rv