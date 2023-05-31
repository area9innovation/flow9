# native isDouble : (s : string) -> bool = Native.isDouble;
from strutils import parseFloat
import math

func $F_0(isDouble)*(s : String) : bool =
  when use16BitString:
	rt_runtime_error("'isDouble' is not implemented as native yet")
  else:
    try:
      let res = classify(s.parseFloat())
      result = res != fcNaN and res != fcInf and res != fcNegInf
    except ValueError :
      discard