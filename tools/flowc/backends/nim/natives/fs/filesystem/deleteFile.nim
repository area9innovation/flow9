# native deleteFile : (string) -> string = FlowFileSystem.deleteFile;
import os

proc $F_0(deleteFile)*(dir : String): String =
  let dir_utf8 = rt_string_to_utf8(dir)
  if (fileExists(dir_utf8)):
    try:
      os.removeFile(dir_utf8)
      return rt_empty_string()
    except OSError as e:
      return rt_utf8_to_string(e.msg)
  else:
    return rt_utf8_to_string("The system cannot find the path specified.")