import sequtils

proc map*[T, S](s: seq[T], op: proc (x: T): S): seq[S] {.inline.} =
  sequtils.map(s, op)