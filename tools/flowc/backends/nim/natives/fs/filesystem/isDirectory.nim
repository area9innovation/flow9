# native isDirectory : (string) -> bool = FlowFileSystem.isDirectory;

import os

proc $F_0(isDirectory)*(path : String): bool =
  dirExists(rt_string_to_utf8(path))