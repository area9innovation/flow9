# native bitShl : (a : int, n : int) -> int = Native.bitShl
proc bitShl*(a : int32, n : int32): int32 =
    a shl n