# native resolveRelativePath : (string) -> string = FlowFileSystem.resolveRelativePath;
import os
import strutils

proc resolveRelativePath*(path : string) : string = 
  replace(os.absolutePath(path), "\\", "/")