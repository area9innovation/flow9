import sequtils

# Creates a new array, whose elements are selected from 'a' with a condition 'test'.
proc $F_0(filter)*[T](a: openArray[T]; test: proc (v: T): bool): seq[T] =
  return sequtils.filter(a, test)