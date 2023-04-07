#native quit : io (code : int32) -> void = Native.quit; - is already defined in nim environment

proc $F_0(quit)*(code: int32): void =
  quit(code)
