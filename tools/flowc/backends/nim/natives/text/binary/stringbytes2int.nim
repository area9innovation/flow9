# native stringbytes2int : (str : string) -> int = Native.stringbytes2int;
# Read 4 bytes of the string in UTF-16 and converts to an int

proc $F_0(stringbytes2int)(s: RtString): int32 =
    let l = len(s)
    if (l == 2):
        #[ var bb = newSeq[byte](2 * 2)
        for i in 0..l-1:
            let v = uint32(unicode.runeAt(s, i))
            bb[2*i] = (byte) (v and 0xff)
            bb[2*i + 1] = (byte) (v shr 8)
        result = int32(
                (cast[uint32](bb[0]) shl 0) or
                (cast[uint32](bb[1]) shl 8) or
                (cast[uint32](bb[2]) shl 16) or
                (cast[uint32](bb[3]) shl 24)
        ) ]#
        let bits0 = int32(when use16BitString: s[0] else: unicode.runeAt(s, 0))
        let bits1 = int32(when use16BitString: s[1] else: unicode.runeAt(s, 1))
        result = int32((bits0 and 0xff) or (bits1 shl 16))
    else:
        result = -1i32 # error