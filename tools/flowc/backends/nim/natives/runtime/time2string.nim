# time is given in milliseconds since epoch 1970 in UTC
proc $F_0(time2string)*(time : float): RtString =
  let dt = local(fromUnixFloat(time / 1000.0))
  return rt_utf8_to_string(dt.format("yyyy-MM-dd HH:mm:ss"))