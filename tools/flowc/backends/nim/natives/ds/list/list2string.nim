proc $F_0(list2string)*(list: $F_1(List)[string]): string =
  var p = list
  var r = ""

  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[$F_1(Cons)[string]](p)
      r = cons.head & r
      p = cons.tail
  return r