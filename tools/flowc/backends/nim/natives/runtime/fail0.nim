proc $F_0(fail0)*[T](error : String): T =
  rt_runtime_error("Runtime failure: " & rt_string_to_utf8(error))
  quit(0)