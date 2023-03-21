proc list2string*(list: Struct): string =
  var p = list
  var r = ""

  while true:
    if cast[StructType](rt_type_id_to_struct_id(p.id)) == st_EmptyList:
      break
    else:
      let cons = Cons[string](p)
      r.add(cons.head)
      p = cons.tail
  return r