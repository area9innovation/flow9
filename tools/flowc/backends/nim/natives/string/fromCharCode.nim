import unicode

func $F_0(fromCharCode)*(code: int32): string =
  return unicode.toUTF8(cast[Rune](code))