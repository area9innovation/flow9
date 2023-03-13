# timer : io (int, () -> void) -> void = Native.timer;

proc timer*(delay : int32, fn : proc (): void): void =
#   