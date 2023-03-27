# native readDirectory : (string) -> [string] = FlowFileSystem.readDirectory;
import os
import sequtils

proc readDirectory*(path :string): seq[string] =
    var newPath = normalizedPath(path & "/*")
    toSeq(walkDirs(newPath))