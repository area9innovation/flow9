# native strSplit : (string, string) -> [string] = Native.strSplit;
import strutils
func strSplit*(s : string, sep : string) : seq[string] =
  split(s, sep)