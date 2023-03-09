import unicode

func fromCharCode*(code: int32): string =
  return unicode.toUTF8(cast[Rune](code))