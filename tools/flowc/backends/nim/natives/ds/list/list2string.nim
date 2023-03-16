proc list2string*(list: Struct): string =
  var p = list
  var r = ""

  while true:
    if cast[StructType](p.id) == st_EmptyList:
      break
    else:
      let cons = Cons[string](p)
      r.add(cons.head)
      p = cons.tail
  return r