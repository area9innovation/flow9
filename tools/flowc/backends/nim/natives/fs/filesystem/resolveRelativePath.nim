# native resolveRelativePath : (string) -> string = FlowFileSystem.resolveRelativePath;
import os
proc resolveRelativePath*(path : string) : string = 
  os.absolutePath(path)