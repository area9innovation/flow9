import unicode

func $F_0(fromCharCode)*(code: int32): String =
  when use16BitString:
    return @[Utf16Char(cast[int16](code))]
  else:
    return unicode.toUTF8(cast[Rune](code))