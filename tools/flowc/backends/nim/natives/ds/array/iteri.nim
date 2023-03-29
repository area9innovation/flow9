# Apply a function to each element of an array
proc iteri*[T](a: openArray[T], op: proc (idx : int32, v: T): void): void =
  for i in 0..a.len - 1:
    op(int32(i), a[i])
  return