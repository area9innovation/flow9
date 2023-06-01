import unicode

func $F_0(getCharAt)*(s: RtString, i: int32): RtString =
  when use16BitString:
    if i >= 0 and i < rt_string_len(s):
      return @[s[i]]
    else:
      return rt_empty_string()
  else:
    if i >= 0 and i < int32(runeLen(s)):
      return unicode.toUTF8(unicode.runeAtPos(s, i))
    else:
      return rt_empty_string()
