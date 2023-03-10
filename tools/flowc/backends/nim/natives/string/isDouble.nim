# native isDouble : (s : string) -> bool = Native.isDouble;
from strutils import parseFloat
import math

func isDouble*(s : string) : bool =
  try:
    let res = classify(s.parseFloat())
    result = res != fcNaN and res != fcInf and res != fcNegInf
  except ValueError :
    discard