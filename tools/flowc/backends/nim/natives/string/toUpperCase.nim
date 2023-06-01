proc $F_0(toUpperCase)*(s: RtString): RtString =
  return rt_utf8_to_string(unicode.toUpper(rt_string_to_utf8(s)))
#[
  const ascii_a = 97i32
  const ascii_z = 122i32
  when use16BitString:
    var is_uppercase = true
    for ch in s:
      let code = rt_utf16char_to_int(ch)
      if ascii_a <= code and code <= ascii_z:
        is_uppercase = false
        break
    if is_uppercase: return s
    else:
      result = newSeqOfCap[Utf16Char](s.len)
      for ch in s:
        let code = rt_utf16char_to_int(ch)
        if ascii_a <= code and code <= ascii_z:
          # shift a register of a char
          result.add(Utf16Char(code - 32i32))
        else:
          result.add(ch)
  else:
    return unicode.toUpper(s)
]#
