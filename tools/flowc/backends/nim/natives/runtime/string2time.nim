import times

# format : "2012-10-01 18:05:40"
proc $F_0(string2time)*(time : string): float =
  let dt = parse(time, "yyyy-MM-dd HH:mm:ss")
  return toUnixFloat(toTime(dt)) * 1000.0