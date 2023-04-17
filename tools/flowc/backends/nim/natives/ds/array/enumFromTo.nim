proc $F_0(enumFromTo)*(f: int32, t: int32): seq[int32] =
  let n: int32 = t - f + 1
  if (n <= 0):
    return @[]
  else:
    var rv: seq[int32] = newSeq[int32](n)
    for i in 0 .. n-1:
      rv[i] = f + i
    return rv