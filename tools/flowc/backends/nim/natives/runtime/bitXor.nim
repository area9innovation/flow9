# native bitXor : (int, int) -> int = Native.bitXor;
from bitops import bitxor 
proc bitXor*(a: int32, b : int32): int32 =
    bitxor(a, b)