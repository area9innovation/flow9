proc $F_0(string2utf8)*(s : String): seq[int32] =
  when use16BitString:
    return map(toSeq(rt_string_to_utf8(s).cstring), proc(x: char): int32 = int32(x))
  else:
    return map(toSeq(s.cstring), proc(x: char): int32 = int32(x))
