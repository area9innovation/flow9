proc structFieldNames*(name: string): seq[string] =
  return rt_struct_name_to_fields(name)