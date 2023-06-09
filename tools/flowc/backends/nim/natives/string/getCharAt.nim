import unicode

func $F_0(getCharAt)*(s: RtString, i: int32): RtString =
  if i >= 0 and i < rt_string_len(s):
    return when use16BitString: @[s[i]] else: $s[i]
  else:
    return rt_empty_string()
