import sequtils

# CAUTION!!!
# NAMES and order of argments (s1 and s2) MATTER - used in compiler to fix errors caused by concat with empty array

proc concat*[T](s1, s2: openArray[T]): seq[T] {.inline.} =
  sequtils.concat(@s1, @s2)