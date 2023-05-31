# native urlDecode2 : (s : string) -> string = Native.urlDecode;
import uri

proc $F_0(urlDecode2)(s : String): String =
  rt_utf8_to_string(decodeUrl(rt_string_to_utf8(s)))