# native resolveRelativePath : (string) -> string = FlowFileSystem.resolveRelativePath;
import os
import strutils

proc $F_0(resolveRelativePath)*(path : string) : string = 
  replace(os.absolutePath(path), "\\", "/")