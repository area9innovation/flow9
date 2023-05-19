proc $F_0(string2utf8)*(s : string): seq[int32] =
  return map(toSeq(s.cstring), proc(x: char): int32 = int32(x))
