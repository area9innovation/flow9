# native urlDecode2 : (s : string) -> string = Native.urlDecode;
import uri

proc urlDecode2(s : string): string =
  decodeUrl(s)