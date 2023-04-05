proc $F_0(println2)*[T](x : T): void =
  when T is Flow: echo(if x.tp == rtString: x.string_v else: rt_to_string(x))
  elif T is string: echo(x)
  else: echo(rt_to_string(x))