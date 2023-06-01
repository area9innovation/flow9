proc $F_0(strIndexOf)*(s: RtString, sub: RtString): int32 =
  when use16BitString:
    if sub.len == 0: return 0
    elif s.len == 0: return -1
    else:
      var i = 0i32
      var j = 0i32
      while i + j < s.len:
        if s[i + j] == sub[j]:
          if j + 1 == sub.len: return i else: inc j
        else:
          j = 0
          i = i + j + 1
      return -1i32
  else:
    return int32(strutils.find(s, sub, 0))