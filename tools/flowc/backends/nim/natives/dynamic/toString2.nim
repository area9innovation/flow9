proc $F_0(toString2)*(x: Flow): String =
  if x.tp == rtString:
    return rt_utf8_to_string("\"") & rt_escape(x.string_v) & rt_utf8_to_string("\"")
  else:
    return rt_to_string(x)