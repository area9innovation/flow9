# Apply a function to each element of an array
proc iter*[T](a: seq[T], op: proc (v: T): void): void =
  for x in a:
    op(x)
  return