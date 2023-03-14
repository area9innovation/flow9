# extractStruct : (a : [?], e : ??) -> ?? = Native.extractStruct;

proc extractStruct*[T, V](arr : openArray[T], elem : V): V =
  for i in countdown(arr.len - 1, 0):
    if arr[i].id == elem.id:
      return cast[V](arr[i])
  return elem
