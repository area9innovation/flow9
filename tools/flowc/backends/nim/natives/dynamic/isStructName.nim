proc $F_0(isStructName)*(name: RtString): bool =
  return rt_struct_name_to_id(name) != -1