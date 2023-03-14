# Get a subrange of an array from index
# if index < 0 or length < 1 it returns an empty array
proc subrange*[T](s: openArray[T], index: int32, length : int32): seq[T] {.inline.} =
  s[index, index + len]