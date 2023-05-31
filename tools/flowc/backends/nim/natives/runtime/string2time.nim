import times

# format : "2012-10-01 18:05:40"
proc $F_0(string2time)*(time : String): float =
  let dt = parse(time, rt_string_to_utf8("yyyy-MM-dd HH:mm:ss"))
  return toUnixFloat(toTime(dt)) * 1000.0