proc $F_0(isSameStructType)*[T1, T2](a: T1, b: T2): bool =
  when (T1 is Struct or T1 is Flow) and (T2 is Struct or T2 is Flow):
    return a.str_id == b.str_id
  else:
    return false
