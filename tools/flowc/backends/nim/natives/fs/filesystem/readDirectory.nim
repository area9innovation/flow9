# native readDirectory : (string) -> [string] = FlowFileSystem.readDirectory;
import os

proc $F_0(readDirectory)*(path: String): seq[String] =
  let path_utf8 = rt_string_to_utf8(path)
  let newPath = normalizedPath(path_utf8)
  if (newPath == ""):
    return @[]
  else:
    for kind, path in walkDir(newPath, true):
      case kind:
        of pcFile: result.add(rt_utf8_to_string(path))
        of pcDir: result.add(rt_utf8_to_string(path))
        of pcLinkToFile: discard
        of pcLinkToDir: discard