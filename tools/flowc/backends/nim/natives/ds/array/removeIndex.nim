# Remove element if found. . Makes a copy
# removeIndex(a : [?], index : int) -> [?]
proc removeIndex*[T](s: openArray[T], i: int32): seq[T] =
  if i < 0 or i >= s.len:
    return @s
  else:
    var s1 = @s
    s1.delete(i)
    return s1