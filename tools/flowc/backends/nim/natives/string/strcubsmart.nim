proc $F_0(strsubsmart)*(s: string, start: int32, fl0wlen: int32): string =
    if start >= 0 and fl0wlen > 0:
      substring(s, start, fl0wlen)
    else:
      var slen: int32 =
        strlen(s)
      var trueStart: int32 = (
        if start >= 0: (
          start
        ) else: (
          var ss: int32 =
            slen+start;
          if ss >= 0: (
            ss
          ) else:
            0
          )
        )
      var trueLength: int32 =
        if fl0wlen > 0:
          fl0wlen
        else:
          slen + fl0wlen - trueStart
      substring(s, trueStart, trueLength)