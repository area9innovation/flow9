# native bitXor : (int, int) -> int = Native.bitXor;

#  nim 1.6 is case insensitive

from bitops import bitxor 

func $F_0(bitXor)*(a: int32, b : int32): int32 =
    bitxor(a, b)
