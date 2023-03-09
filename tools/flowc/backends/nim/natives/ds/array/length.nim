proc length*[T](s: seq[T]): int32 {.inline.} =
  cast[int32](len(s))