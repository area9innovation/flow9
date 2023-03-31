proc getDataTagForValue(v: Flow): int32 =
  case v.tp:
  of rtVoid:   return 0
  of rtBool:   return 1
  of rtInt:    return 2
  of rtDouble: return 3
  of rtString: return 4
  of rtRef:    return 31
  of rtArray:  return 5
  of rtStruct: return 6
  of rtFunc:   return 34
  of rtNative: return 32