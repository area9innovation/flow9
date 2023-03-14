proc list2array*[T](list: Struct): seq[T] =
  var p = list
  var r = newSeq[T]()

  while true:
    if cast[StructType](rt_type_id_to_struct_id(p.id)) == st_EmptyList:
      break
    else:
      let cons = Cons[T](p)
      r = r & @[cons.head]
      p = cons.tail
  return r