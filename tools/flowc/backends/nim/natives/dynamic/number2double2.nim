# native number2double2 : io (value : flow) -> double = Native.number2double;

proc $F_0(number2double2)(value : Flow): float =
  if (value.tp == rtDouble): value.double_v
  elif (value.tp == rtInt): value.int_v.float
  else: 0.0