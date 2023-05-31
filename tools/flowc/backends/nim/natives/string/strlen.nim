proc $F_0(strlen)*(s: String): int32 =
  when use16BitString:
    return int32(s.len)
  else:
    return int32(runeLen(s));