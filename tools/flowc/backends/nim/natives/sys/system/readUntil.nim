import os, strutils, streams

# Untested
proc $F_0(readUntil)*(pattern: string): string =
  var line: string
  result = ""
  while true:
    line = readLine(stdin)
    if line == "" or line.contains(pattern):
      break
    result.add(line)
