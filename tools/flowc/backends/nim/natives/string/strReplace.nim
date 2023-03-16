# native strReplace : (string, string, string) -> string = Native.strReplace;
import strutils
func strReplace*(s, s1, s2 : string) : string =
  replace(s, s1, s2)