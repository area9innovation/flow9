import unicode

func $F_0(getCharCodeAt)*(s: String, i: int32): int32 =
  when use16BitString:
    if i >= 0 and i < int32(s.len):
      return rt_utf16char_to_int(s[i])
    else:
      return -1
  else:
    if i >= 0 and i < int32(runeLen(s)):
      return int32(unicode.runeAtPos(s, i))
    else:
      return -1