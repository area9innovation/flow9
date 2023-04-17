import unicode

func $F_0(getCharCodeAt)*(s: string, i: int32): int32 =
  if i >= 0 and i < cast[int32](len(s)):
    return cast[int32](unicode.runeAt(s, i))
  else:
    return -1