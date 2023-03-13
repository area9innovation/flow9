proc isStructName(name: string): bool =
  return rt_struct_name_to_id(name) != -1