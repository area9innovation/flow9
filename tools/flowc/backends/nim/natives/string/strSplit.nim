# native strSplit : (string, string) -> [string] = Native.strSplit;
import strutils

func $F_0(strSplit)*(s : String, sep : String) : seq[String] =
  when use16BitString:
    if (sep.len == 0): return @[s]
    else:
      var line = rt_empty_string()
      result = @[]
      var i = 0i32
      while i < s.len:
        var j = 0i32
        while i + j < s.len and j < sep.len and s[i + j] == sep[j]: inc j
        if j == sep.len:
          result.add(line)
          line = rt_empty_string()
          i = i + j
        else:
          line.add(s[i])
          inc i
      result.add(line)
  else:
    if (sep == ""): return @[s]
    else: return split(s, sep)