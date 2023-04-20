proc $F_0(length)*[T](s: openArray[T]): int32 {.inline.} =
  cast[int32](s.len)