import unicode

func $F_0(fromCharCode)*(code: int32): RtString =
  when use16BitString:
    if (code < 0x0D800 or (0x0DFFF < code and code < 0xFFFF)):
      return @[Utf16Char(cast[int16](code))]
    else:
      # must be represented as a surrogate pair
      return rt_utf8_to_string(unicode.toUTF8(cast[Rune](code)))
  else:
    return unicode.toUTF8(cast[Rune](code))