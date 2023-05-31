proc $F_0(toLowerCase)*(s: String): String =
  const ascii_a_cap = 65i32
  const ascii_z_cap = 90i32
  when use16BitString:
    var is_lowercase = true
    for ch in s:
      let code = rt_utf16char_to_int(ch)
      if ascii_a_cap <= code and code <= ascii_z_cap:
        is_lowercase = false
        break
    if is_lowercase: return s
    else:
      result = newSeqOfCap[Utf16Char](s.len)
      for ch in s:
        let code = rt_utf16char_to_int(ch)
        if ascii_a_cap <= code and code <= ascii_z_cap:
          # shift a register of a char
          result.add(Utf16Char(code + 32i32))
        else:
          result.add(ch)
  else:
    return unicode.toLower(s)