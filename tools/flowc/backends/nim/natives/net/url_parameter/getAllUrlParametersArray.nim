import os

proc $F_0(getAllUrlParametersArray)*(): seq[seq[RtString]] =
  let params = filter(commandLineParams(), proc(p: string): bool = p.len > 0)
  return map(params, proc(p: string): seq[RtString] =
    let eq_ind = find(p, "=")
    if eq_ind == -1:
      return @[rt_utf8_to_string(p), rt_empty_string()]
    else:
      return @[rt_utf8_to_string(p[0 .. (eq_ind - 1)]), rt_utf8_to_string(p[(eq_ind + 1) .. (p.len - 1)])]
  )