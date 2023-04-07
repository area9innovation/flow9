import sequtils

proc $F_0(concat)*[T](s: varargs[seq[T]]): seq[T] {.inline.} =
  sequtils.concat(s)
