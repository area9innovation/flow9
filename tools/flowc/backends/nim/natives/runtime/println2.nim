proc $F_0(println2)*[T](x : T): void =
  let s: string = when x is Flow:
    if x.tp == rtString: x.string_v else: rt_to_string(x)
  else: rt_to_string(x)
  echo s