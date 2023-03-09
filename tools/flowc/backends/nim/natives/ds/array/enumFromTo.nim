proc enumFromTo*(f: int32, t: int32): seq[int32] =
  var n: int32 = t - f + 1
  var rv: seq[int32]

  if (n < 0):
    rv = @[]
    return rv

  for i in 0 .. n-1:
    rv.add(f + i)

  return rv