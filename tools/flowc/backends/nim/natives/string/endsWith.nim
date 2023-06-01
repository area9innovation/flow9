func $F_0(endsWith)*(s: RtString, e: RtString): bool =
  when use16BitString:
    if e.len == 0: return true
    elif s.len == 0: return false
    else:
      let shift = s.len - e.len
      if shift < 0: return false
      for i in 0 ..< e.len:
        if e[i] != s[i + shift]: return false
      return true
  else:
    return endsWith(s, e)