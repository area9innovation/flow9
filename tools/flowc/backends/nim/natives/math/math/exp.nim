#native exp : (double) -> double = Native.exp; - is already defined
from math import exp

func $F_0(exp)*(x: float): float =
  return exp(x)
