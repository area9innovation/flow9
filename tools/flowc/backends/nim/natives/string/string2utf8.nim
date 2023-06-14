proc $F_0(string2utf8)*(s : RtString): seq[int32] =
  when use16BitString:
    # Guess length
    var ret = newSeqOfCap[char](s.len * 3)
    rt_convert_string_to_utf8(s, ret)
    return map(ret, proc(x: char): int32 = int32(x))
  else:
    return map(toSeq(s.cstring), proc(x: char): int32 = int32(x))
