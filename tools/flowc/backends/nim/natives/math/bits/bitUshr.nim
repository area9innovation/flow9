# native bitUshr : (a : int, n : int) -> int = Native.bitUshr
proc bitUshr*(a : int32, n : int32): int32 =
    a shr n