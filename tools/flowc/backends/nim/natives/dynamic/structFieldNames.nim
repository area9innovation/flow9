proc $F_0(structFieldNames)*(name: String): seq[String] =
  return rt_struct_name_to_fields(name)