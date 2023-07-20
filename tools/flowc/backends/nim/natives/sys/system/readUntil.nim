import os, strutils, streams

# Untested
proc $F_0(readUntil)*(pattern0: RtString): RtString =
  let pattern = rt_string_to_utf8(pattern0)
  var line: string
  var have_read = ""
  var read = true
  while read:
    line = readLine(stdin)
    if line == "" or line.contains(pattern): read = false
    else: have_read.add(line)
  return rt_utf8_to_string(have_read)
