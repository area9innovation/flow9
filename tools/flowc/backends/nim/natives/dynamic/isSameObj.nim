proc $F_0(isSameObj)*[T](a: T, b: T): bool =
  when T is Flow:
    if a.tp != b.tp: return false
    else:
      case a.tp:
      of rtVoid: return true
      of rtBool: return a.bool_v == b.bool_v
      of rtInt:  return a.int_v == b.int_v
      of rtDouble: return a.double_v == b.double_v
      of rtString: return a.string_v == b.string_v
      else: return cast[pointer](a) == cast[pointer](b)
  elif T is bool: return a == b
  elif T is int32: return a == b
  elif T is float: return a == b
  elif T is string: return a == b
  else: return cast[pointer](a) == cast[pointer](b)