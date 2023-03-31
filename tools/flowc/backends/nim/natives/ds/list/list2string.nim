proc list2string*(list: List[string]): string =
  var p = list
  var r = ""

  while true:
    if p of EmptyList[string]:
      break
    else:
      let cons = Cons[string](p)
      r = cons.head & r
      p = cons.tail
  return r