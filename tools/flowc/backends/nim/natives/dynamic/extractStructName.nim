proc $F_0(extractStructName)(v: Flow): string =
  if v.tp == rtStruct: rt_struct_id_to_name(v.str_id) else: ""