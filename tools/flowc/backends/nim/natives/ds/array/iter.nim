# Apply a function to each element of an array
proc $F_0(iter)*[T](a: openArray[T], op: proc (v: T): void): void =
  for x in a:
    op(x)
  return