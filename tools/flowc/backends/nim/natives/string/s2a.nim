import unicode

proc $F_0(s2a)*(s : String): seq[int32] =
  when use16BitString:
    return map(s, proc(ch: Utf16Char): int32 = rt_utf16char_to_int(ch))
  else:  
    let runes = toRunes(s)
    result = newSeq[int32](runes.len)
    for i in 0 .. (runes.len - 1):
      result[i] = int32(runes[i])