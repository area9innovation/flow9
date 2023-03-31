proc $F_0(isSameObj)*(a: Flow, b: Flow): bool =
  if a.tp != b.tp return false
  else:
    case a.tp:
    of rtVoid: return true
    of rtBool: return a.bool_v == b.bool_v
    of rtInt:  return a.int_v == b.int_v
    of rtDouble: return a.double_v == b.double_v
    of rtString: return a.string_v == b.string_v
    else: return addr(a) == addr(b)
