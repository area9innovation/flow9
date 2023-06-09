import os, strutils, streams

# Untested
proc $F_0(readUntil)*(pattern: RtString): RtString =
  var line: string
  var have_read = ""
  while true:
    line = readLine(stdin)
    if line == "" or line.contains(pattern):
      break
    have_read.add(line)
  return rt_utf8_to_string(have_read)