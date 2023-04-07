proc $F_0(strIndexOf)*(s: string, sub: string): int32 =
  return cast[int32](strutils.find(s, sub, 0))