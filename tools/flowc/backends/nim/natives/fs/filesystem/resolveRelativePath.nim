# native resolveRelativePath : (string) -> string = FlowFileSystem.resolveRelativePath;
import os
import strutils

proc $F_0(resolveRelativePath)*(path : String) : String = 
  rt_utf8_to_string(replace(os.absolutePath(rt_string_to_utf8(path)), "\\", "/"))