proc list2array*[T](list: List[T]): seq[T] =
  var p = list
  var r = newSeq[T]()

  while true:
    if p of EmptyList[T]:
      break
    else:
      let cons = Cons[T](p)
      r = @[cons.head] & r
      p = cons.tail
  return r