proc isSameStructType*[T1, T2](a: T1, b: T2): bool =
  when (a is Struct) and (b is Struct):
    return a.id == b.id
  else:
    return false
