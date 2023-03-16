# Apply a function which takes an index and each element of an array until it returns true
# Returns index of last element function was applied to.
proc iteriUntil*[T](a: openArray[T], op: proc(idx: int32, v: T): bool): int32 =
  for i in 0..a.len - 1:
    if op(i, a[i]):
      return i
  return a.len