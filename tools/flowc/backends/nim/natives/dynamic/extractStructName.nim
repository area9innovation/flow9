proc $F_0(extractStructName)(v: Flow): string =
  if v.tp == rtStruct: v.str_name else: ""