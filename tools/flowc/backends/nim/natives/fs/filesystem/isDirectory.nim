# native isDirectory : (string) -> bool = FlowFileSystem.isDirectory;

import os

proc isDirectory*(path : string): bool =
  dirExists(path)