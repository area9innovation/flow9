# Apply a collecting function.  This is a left fold, i.e., it folds with the start of
# the array first, i.e., fold([x1, x2, x3], x0, o) = ((x0 o x1) o x2) o x3
proc $F_0(fold)*[T, S](arr: openArray[T], init: S, op: proc(acc: S, v: T): S): S =
  var ini = init
  for x in arr:
    ini = op(ini, x)
  return ini