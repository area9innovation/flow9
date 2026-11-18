import os

proc $F_0(copyFile)*(src, dst: RtString): bool =
  try:
    let source = rt_string_to_utf8(src)
    let target = rt_string_to_utf8(dst)
    if not os.fileExists(source) or (os.fileExists(target) and os.sameFile(source, target)):
      return false
    when defined(windows):
      if os.symlinkExists(source): return false # os.copyFile skips these
    os.copyFile(source, target)
    return true
  except IOError, OSError:
    return false
