# native strSplit : (string, string) -> [string] = Native.strSplit;
import strutils

func $F_0(strSplit)*(s : string, sep : string) : seq[string] =
    if (sep == ""): @[s]
    else: split(s, sep)