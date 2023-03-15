# native md5 : (s : string) -> string = Native.md5;

import md5

proc md5(s : string): string =
  getMD5(s)