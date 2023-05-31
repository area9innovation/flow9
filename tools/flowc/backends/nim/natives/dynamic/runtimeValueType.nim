proc $F_0(runtimeValueType)(v: Flow): String =
  case v.tp:
  of rtVoid:   return rt_utf8_to_string("void")
  of rtBool:   return rt_utf8_to_string("bool")
  of rtInt:    return rt_utf8_to_string("int")
  of rtDouble: return rt_utf8_to_string("double")
  of rtString: return rt_utf8_to_string("string")
  of rtNative: return rt_utf8_to_string("native")
  of rtRef:    return rt_utf8_to_string("ref")
  of rtArray:  return rt_utf8_to_string("array")
  of rtFunc:   return rt_utf8_to_string("function")
  of rtStruct: return rt_struct_id_to_name(v.str_id)