import unicode

proc $F_0(s2a)*(s : string): seq[int32] =
  let runes = toRunes(s)
  result = newSeq[int32](runes.len)
  for i in 0 .. (runes.len - 1):
    result[i] = int32(runes[i])