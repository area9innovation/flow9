#  native strRangeIndexOf : (string, string, int, int) -> int = Native.strRangeIndexOf;

from strutils import find

func $F_0(strRangeIndexOf)*(str : string, substr : string, start : int32, last : int32) : int32 =
    cast[int32](find(str, substr, start, last - 1))
