proc $F_0(extractStructArguments)*(v : Flow): seq[Flow] =
  return if v.tp == rtStruct: v.str_args else: @[]

