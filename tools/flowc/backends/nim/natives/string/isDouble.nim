# native isDouble : (s : string) -> bool = Native.isDouble;
from strutils import parseFloat
import math

func $F_0(isDouble)*(s : String) : bool =
  try:
    let res = classify(rt_string_to_utf8(s).parseFloat())
    return res != fcNaN and res != fcInf and res != fcNegInf
  except ValueError :
    return false