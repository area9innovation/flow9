import os
when defined(posix):
  import posix
  import posix_utils
else:
  import std/tempfiles
  import winlean

proc $F_0(copyFile)*(src, dst: RtString): bool =
  try:
    let source = rt_string_to_utf8(src)
    let target = rt_string_to_utf8(dst)
    if not os.fileExists(source) or target.len == 0: return false
    when defined(posix):
      var st: Stat
      let existing = posix.stat(target.cstring, st) == 0
      if existing and not S_ISREG(st.st_mode): return false
      if not existing and errno != ENOENT: return false
    else:
      if os.dirExists(target): return false
      let existing = os.fileExists(target)
    if existing and os.sameFile(source, target): return false

    let parent = if target.parentDir.len == 0: "." else: target.parentDir
    when defined(posix):
      let stage = posix_utils.mkdtemp(parent / ".flowcopy")
    else:
      let stage = createTempDir(".flowcopy", "", parent)
    let tmp = stage / "data"
    defer: os.removeDir(stage)

    let input = open(source, fmRead)
    defer: close(input)
    var output = open(tmp, fmWrite)
    defer:
      if output != nil: close(output)
    # Nim's flushFile and close discard stdio errors. Observe both before rename.
    proc flushStream(f: File): cint {.importc: "fflush", header: "<stdio.h>".}
    proc closeStream(f: File): cint {.importc: "fclose", header: "<stdio.h>".}
    var buf: array[16384, byte]
    while true:
      let n = input.readBuffer(addr buf[0], buf.len)
      if n == 0: break
      if output.writeBuffer(addr buf[0], n) != n: return false
    if flushStream(output) != 0: return false
    let closeResult = closeStream(output)
    output = nil
    if closeResult != 0: return false

    when defined(windows):
      return moveFileExW(newWideCString(tmp), newWideCString(target), MOVEFILE_REPLACE_EXISTING) != 0
    else:
      if existing and posix.chmod(tmp.cstring, st.st_mode and Mode(0o777)) != 0: return false
      proc renameFile(src, dst: cstring): cint {.importc: "rename", header: "<stdio.h>".}
      return renameFile(tmp.cstring, target.cstring) == 0
  except IOError, OSError:
    return false
