proc $F_0(list2array)*[T](list: List[T]): seq[T] =
  var p = list
  var r = newSeq[T]()

  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[Cons[T]](p)
      r = @[cons.head] & r
      p = cons.tail
  return r