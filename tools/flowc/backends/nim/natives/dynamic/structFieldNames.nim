proc $F_0(structFieldNames)*(name: string): seq[string] =
  return rt_struct_name_to_fields(name)