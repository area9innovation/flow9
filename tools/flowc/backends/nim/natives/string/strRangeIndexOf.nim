#  native strRangeIndexOf : (string, string, int, int) -> int = Native.strRangeIndexOf;

from strutils import find

func $F_0(strRangeIndexOf)*(s : RtString, sub : RtString, start : int32, aend0 : int32) : int32 =
  when use16BitString:
    let aend = min(aend0, s.len)
    if start >= aend or start >= s.len or s.len < sub.len: return -1
    elif sub.len == 0: return start
    else:
      var i = int32(start)
      var j = 0i32
      while i + j < s.len and i < aend:
        if s[i + j] == sub[j]:
          if j + 1 == sub.len: return i else: inc j
        else:
          j = 0
          i = i + j + 1
      return -1i32
  else:
    let aend = min(aend0, s.len)
    if start >= aend or start >= s.len or s.len < sub.len: return -1
    elif sub.len == 0: return start
    else: return int32(find(s, sub, start, aend - 1))
