proc $F_0(substring)*(str: string, start: int32, leng: int32): string =
  var slen = leng
  var sstart = start
  var strlen = cast[int32](len(str))
  if slen < 0:
    if (sstart < 0) :
      slen = 0
    else:
      var smartLen1 = slen + sstart
      if smartLen1 >= 0:
        slen = 0
      else:
        var smartLen2 = smartLen1 + strlen
        if (smartLen2 <= 0):
          slen = 0
        else:
          slen = smartLen2

  if (sstart < 0):
    var smartStart = sstart + strlen
    if (smartStart > 0):
      sstart = smartStart
    else:
      sstart = 0
  else:
    if (sstart >= strlen):
      slen = 0

    if (slen < 1):
      return "";

  let send = start + slen
  slen = if send > strlen or send  < 0: strlen - start else: slen
  return substr(str, sstart, sstart + slen - 1)
