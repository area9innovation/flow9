# time is given in milliseconds since epoch 1970 in UTC
proc time2string*(time : float): string =
  let dt = local(fromUnixFloat(time / 1000.0))
  return dt.format("yyyy-MM-dd HH:mm:ss")