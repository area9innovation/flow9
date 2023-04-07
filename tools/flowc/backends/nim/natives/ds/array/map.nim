import sequtils

proc $F_0(map)*[T, S](s: openArray[T], op: proc (x: T): S): seq[S] {.inline.} =
  sequtils.map(s, op)