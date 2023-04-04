proc $F_0(isSameStructType)*[T1, T2](a: T1, b: T2): bool =
  when (a of Struct) and (b of Struct):
    return a.str_id == b.str_id
  else:
    return false
