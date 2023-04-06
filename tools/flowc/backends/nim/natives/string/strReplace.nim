# native strReplace : (string, string, string) -> string = Native.strReplace;
import strutils
func $F_0(strReplace)*(s, s1, s2 : string) : string =
  replace(s, s1, s2)