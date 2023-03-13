# Apply a function to each element of an array
proc iteri*[T](a: seq[T], op: proc (idx : int32, v: T): void): void =
  for i in 0..a.len - 1:
    op(i, a[int32(i)])
  return