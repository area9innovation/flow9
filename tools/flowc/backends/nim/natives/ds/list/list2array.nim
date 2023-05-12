proc $F_0(list2array)*[T](list: $F_1(List)[T]): seq[T] =
  # find out the number of elements in list
  var p = list
  var count = 0
  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[$F_1(Cons)[T]](p)
      count += 1
      p = cons.tail

  # arrange elements in a backwards ordered array
  p = list
  var arr = newSeq[T](count)
  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[$F_1(Cons)[T]](p)
      count -= 1
      arr[count] = cons.head
      p = cons.tail
  return arr