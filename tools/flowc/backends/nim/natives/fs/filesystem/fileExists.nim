import os

proc $F_0(fileExists)*(f: RtString): bool = 
  return fileExists(rt_string_to_utf8(f))