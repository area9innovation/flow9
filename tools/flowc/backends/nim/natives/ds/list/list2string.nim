proc $F_0(list2string)*(list: $F_1(List)[string]): string =
  # find out the number of elements in list and a total length of a resulting string
  var p = list
  var len = 0
  var count = 0
  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[$F_1(Cons)[string]](p)
      len += cons.head.len
      count += 1
      p = cons.tail

  # arrange elements in a backwards ordered array
  p = list
  var arr = newSeq[string](count)
  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[$F_1(Cons)[string]](p)
      count -= 1
      arr[count] = cons.head
      p = cons.tail

  # finally join elements of array into a single string
  var r = newString(len)
  r = ""
  for x in arr:
    r.add(x)
  return r