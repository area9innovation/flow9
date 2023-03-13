proc makeStructValue*(name : string, args : seq[Flow], default_value : Flow): Flow =
  let struct_id = rt_struct_name_to_id(name)
  if struct_id == -1: return default_value
  else:
    let type_args = @[struct_id] & map(args, proc(arg: Flow): int32 = rt_flow_type_id(arg))
    let al_type = (ctStruct, type_args, name)
    var type_id = rt_find_type_id(al_type)
    if (type_id == -1):
      rt_register_type(al_type)
      type_id = rt_find_type_id(al_type)
    return Flow(tp: rtStruct, str_id: type_id, str_name: name, str_args: args)
