# native strReplace : (string, string, string) -> string = Native.strReplace;
import strutils
func $F_0(strReplace)*(s, s1, s2 : String) : String =
  when use16BitString:
    if s.len == 0 or s1.len == 0: return s
    else:
      var s1_met = 0
      var i = 0i32
      var j = 0i32
      while i + j < s.len:
        if s[i + j] == s1[j]:
          if j + 1 == s1.len:
            inc s1_met
            j = 0; i = i + j + 1
          else:
            inc j
        else:
          j = 0; i = i + j + 1
      if s1_met == 0:
        return s
      else:
        var ret = newSeqOfCap[Utf16Char](s.len + s1_met * (s2.len - s1.len))
        var i = 0i32
        while i < s.len:
          var j = 0i32
          while i + j < s.len and j < s1.len and s[i + j] == s1[j]: inc j
          if j == s1.len:
            ret.add(s2)
            i = i + j
          else:
            ret.add(s[i])
            inc i
        return ret
  else:
    return replace(s, s1, s2)