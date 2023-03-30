import os

proc getAllUrlParametersArray*(): seq[seq[string]] =
  let params = filter(commandLineParams(), proc(p: string): bool = p.len > 0)
  return map(params, proc(p: string): seq[string] =
    let eq_ind = find(p, "=")
    if eq_ind == -1:
      return @[p, ""]
    else:
      return @[p[0 .. (eq_ind - 1)], p[(eq_ind + 1) .. (p.len - 1)]]
  )