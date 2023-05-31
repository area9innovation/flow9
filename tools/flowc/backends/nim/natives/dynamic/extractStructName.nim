proc $F_0(extractStructName)(v: Flow): String =
  if v.tp == rtStruct: rt_struct_id_to_name(v.str_id) else: rt_empty_string()