# native readDirectory : (string) -> [string] = FlowFileSystem.readDirectory;
import os

proc readDirectory*(path :string): seq[string] =
  let newPath = normalizedPath(path)
  if (newPath == ""):
    return @[]
  else:
    for kind, path in walkDir(newPath, true):
      case kind:
        of pcFile: result.add(path)
        of pcDir: result.add(path)
        of pcLinkToFile: discard
        of pcLinkToDir: discard