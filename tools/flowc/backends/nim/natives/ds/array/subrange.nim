# Get a subrange of an array from index
# if index < 0 or length < 1 it returns an empty array
proc subrange*[T](s: openArray[T], index: int32, length : int32): seq[T] {.inline.} =
  if (index < 0) or (length < 1) or s.len <= index:
    return @[]
  else:
    s[index .. index + length - 1]