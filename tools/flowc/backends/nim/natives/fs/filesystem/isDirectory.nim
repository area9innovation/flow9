# native isDirectory : (string) -> bool = FlowFileSystem.isDirectory;

import os

proc $F_0(isDirectory)*(path : string): bool =
  dirExists(path)