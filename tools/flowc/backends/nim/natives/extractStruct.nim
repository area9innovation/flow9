# extractStruct : (a : [?], e : ??) -> ?? = Native.extractStruct;

func extractStruct*[T, V](arr : openArray[T], elem : V): V =
  return elem