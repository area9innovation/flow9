import os
import strutils

proc $F_0(getUrlParameterNative)*(name: string): string =
  # params from main() ?
  when declared(commandLineParams):
    let prefix = name & "="
    for arg in commandLineParams():
      if arg.startsWith(prefix):
        return arg[prefix.len .. ^1]
  else:
    result = ""