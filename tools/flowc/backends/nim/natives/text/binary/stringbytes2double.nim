# native stringbytes2double : (str : string) -> double = Native.stringbytes2double;
# Read 8 bytes of the string in UTF-16 and converts to a double
import endians
import unicode

proc $F_0(stringbytes2double)(s : string) : float =
    if (len(s) == 4):
        var bb : array[8, byte]
        for i in 0..3:
            let v = int32(unicode.runeAt(s, i))
            let b0 = (byte) (v and 0xff)
            let b1 = (byte) (v shr 8)
            bb[2*i] = b0
            bb[2*i + 1] = b1
        littleEndian64(addr result, addr bb)
    else:
        discard # error