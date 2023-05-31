proc $F_0(list2string)*(list: $F_1(List)[String]): String =
  # find out the number of elements in list and a total length of a resulting string
  var p = list
  var len = 0
  var count = 0
  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[$F_1(Cons)[String]](p)
      len += cons.head.len
      count += 1
      p = cons.tail

  # arrange elements in a backwards ordered array
  p = list
  var arr = newSeq[String](count)
  while true:
    if p.str_id == int32(st_EmptyList):
      break
    else:
      let cons = cast[$F_1(Cons)[String]](p)
      count -= 1
      arr[count] = cons.head
      p = cons.tail

  # finally join elements of array into a single string
  var r = newSeqOfCap[Utf16Char](len)
  r = rt_empty_string()
  for x in arr:
    r.add(x)
  return r