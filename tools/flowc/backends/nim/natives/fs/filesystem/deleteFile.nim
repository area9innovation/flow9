# native deleteFile : (string) -> string = FlowFileSystem.deleteFile;
import os

proc deleteFile*(dir : string): string =
  if (fileExists(dir)):
    try:
      os.removeFile(dir)
      return ""
    except OSError as e:
      return e.msg
  else:
    return "The system cannot find the path specified."