proc runtimeValueType(v: Flow): string =
  case v.tp:
  of rtVoid:   return "void"
  of rtBool:   return "bool"
  of rtInt:    return "int"
  of rtDouble: return "double"
  of rtString: return "string"
  of rtNative: return "native"
  of rtRef:    return "ref"
  of rtArray:  return "array"
  of rtFunc:   return "function"
  of rtStruct: return v.str_name