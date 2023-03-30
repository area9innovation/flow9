import os
import strutils

proc getUrlParameterNative*(name: string): string =
  # params from main() ?
  when declared(commandLineParams):
    let prefix = name & "="
    for arg in commandLineParams():
      if arg.startsWith(prefix):
        return arg[prefix.len .. ^1]
  else:
    result = ""