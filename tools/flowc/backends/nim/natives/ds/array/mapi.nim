# Apply a function which takes an index and each element of an array to give a new array
proc mapi*[T, S](s: seq[T], op: proc (i: int32, v: T): S): seq[S] =
  var rv: seq[S] = newSeq[S](s.len)
  var i : int32 = 0
  while i < s.len:
    rv[i] = op(i, s[i])
    inc i
  #for i in 0 .. s.len-1:
  #  rv[i] = op(i, s[i])
  return rv