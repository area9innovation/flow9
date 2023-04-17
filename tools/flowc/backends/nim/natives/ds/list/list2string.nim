proc $F_0(list2string)*(list: List[string]): string =
  var p = list
  var r = ""

  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[Cons[string]](p)
      r = cons.head & r
      p = cons.tail
  return r