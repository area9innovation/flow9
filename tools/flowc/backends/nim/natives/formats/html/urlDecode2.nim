# native urlDecode2 : (s : string) -> string = Native.urlDecode;
import uri

proc $F_0(urlDecode2)(s : string): string =
  decodeUrl(s)