#  equal to nim

func $F_0(startsWith)*(s: String, b: String): bool =
  when use16BitString:
    if b.len == 0: return true
    elif s.len < b.len: return false
    else:
      for i in 0 ..< b.len:
        if b[i] != s[i]: return false
      return true
  else:
    return startsWith(s, b)
