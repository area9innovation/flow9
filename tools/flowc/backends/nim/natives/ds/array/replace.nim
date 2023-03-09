# Replace a given element in an array with a new value. Makes a copy
#native replace : ([?], int32, ?) -> [?] = Native.replace;
proc replace*[T](s: seq[T], i: int32, v: T): seq[T] =
  #if i < 0 or s == nil:
  if i < 0 or len(s) == 0:
    return @[]
  else:
    var s1 = s & @[] # Copy of s
    if cast[int32](len(s1)) > i:
      s1[i] = v
    else:
      add(s1, v) # Append item to the end of array, increasing length
    return s1