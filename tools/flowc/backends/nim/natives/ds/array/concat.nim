import sequtils

proc concat*[T](s1, s2: openArray[T]): seq[T] {.inline.} =
  sequtils.concat(@s1, @s2)