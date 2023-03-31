# native stringbytes2int : (str : string) -> int = Native.stringbytes2int;
# Read 4 bytes of the string in UTF-16 and converts to an int

proc stringbytes2int(s : string) : int32 =
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
        result = int32((int32(unicode.runeAt(s, 0)) and 0xff) or (int32(unicode.runeAt(s, 1)) shl 16))
    else:
        result = -1i32 # error