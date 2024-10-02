# native md5 : (s : string) -> string = Native.md5;

import md5

proc $F_0(md5)*(s : RtString): RtString =
  return rt_utf8_to_string(getMD5(rt_string_to_utf8(s)))