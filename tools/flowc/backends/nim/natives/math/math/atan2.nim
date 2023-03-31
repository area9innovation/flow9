# native atan2 : (double, double) -> double = Native.atan2;
from math import arctan2

func $F_0(atan2)*(x: float, y : float): float =
  return arctan2(x, y)