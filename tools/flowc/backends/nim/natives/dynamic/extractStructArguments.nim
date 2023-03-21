proc extractStructArguments*(v : Flow): seq[Flow] =
  return if v.tp == rtStruct: v.str_args else: @[]

