import math
from std/times import epochTime

proc timestamp*(): float =
  return float(round(epochTime() * 1000.0))