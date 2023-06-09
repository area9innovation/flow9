proc $F_0(structFieldNames)*(name: RtString): seq[RtString] =
  return rt_struct_name_to_fields(name)