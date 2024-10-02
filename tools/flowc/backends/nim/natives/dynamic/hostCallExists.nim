import tables

proc $F_0(hostCallExists)*(name: RtString): bool =
  return name2func.hasKey(name)