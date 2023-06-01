proc $F_0(makeStructValue)*(name : RtString, args : seq[Flow], default_value : Flow): Flow =
  let struct_id = rt_struct_name_to_id(name)
  if struct_id == -1: return default_value
  else: return Flow(tp: rtStruct, str_id: struct_id, str_args: args)
