proc $F_0(toString2)*(x: Flow): string =
  if x.tp == rtString:
    return x.string_v
  else:
    return rt_to_string(x)