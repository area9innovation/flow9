proc $F_0(println2)*[T](x : T): void =
  when T is Flow: echo(rt_string_to_utf8(if x.tp == rtString: x.string_v else: rt_to_string(x)))
  elif T is String: echo(rt_string_to_utf8(x))
  else: echo(rt_string_to_utf8(rt_to_string(x)))