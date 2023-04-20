# Apply a function which takes an index and each element of an array until it returns true
# Returns index of last element function was applied to.
proc $F_0(iteriUntil)*[T](a: openArray[T], op: proc(idx: int32, v: T): bool): int32 =
  for i in 0..a.len - 1:
    if op(int32(i), a[int32(i)]):
      return int32(i)
  return int32(a.len)
