import unicode

func $F_0(getCharCodeAt)*(s: RtString, i: int32): int32 =
  if i >= 0 and i < rt_string_len(s):
    return rt_string_char_code(s, i)
  else:
    return -1