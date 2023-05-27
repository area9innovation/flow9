from math import round
from std/times import epochTime

proc $F_0(timestamp)*(): float =
  return float(round(epochTime() * 1000.0))