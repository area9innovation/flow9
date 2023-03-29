import os

proc getAllUrlParametersArray*(): seq[seq[string]] =
  var params = filter(commandLineParams(), proc(param: string): bool = param.len > 0)
  return map(params, proc(param: string): seq[string] =
    let p = split(param, "=")
    if p.len == 1:
      return @[param, ""]
    else:
      return @[p[0], p[1]]
  )