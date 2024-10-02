proc $F_0(s2a)*(s : RtString): seq[int32] =
  let utf16_s = when use16BitString: s else: rt_utf8_to_utf16(s)
  return map(utf16_s, proc(ch: Utf16Char): int32 = rt_utf16char_to_int(ch))