#native sin : (double) -> double = Native.sin; - is already defined
from math import sin

func $F_0(sin)*(x: float): float =
  return sin(x)