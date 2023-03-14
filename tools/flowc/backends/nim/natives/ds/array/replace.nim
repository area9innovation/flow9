# Replace a given element in an array with a new value. Makes a copy
#native replace : ([?], int32, ?) -> [?] = Native.replace;
proc replace*[T](s: openArray[T], i: int32, v: T): seq[T] =
  if i < 0 or s.len == 0:
    return @[]
  else:
    var s1 = @s # Copy of s
    if cast[int32](s1.len) > i:
      s1[i] = v
    else:
      add(s1, v) # Append item to the end of array, increasing length
    return s1