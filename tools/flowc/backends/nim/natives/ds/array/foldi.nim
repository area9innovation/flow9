# Apply a collecting function which takes an index, initial value and each element
proc $F_0(foldi)*[T, S](xs: openArray[T], init: S, fn: proc(idx: int32, acc: S, v: T): S): S =
  var ini = init
  for i in 0..xs.len - 1:
    ini = fn(int32(i), ini, xs[i])
  return ini