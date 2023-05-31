# native fileExists : (string) -> bool = FlowFileSystem.fileExists
# the same name function

proc $F_0(fileExists)(f: String): bool = 
  return fileExists(rt_string_to_utf8(f))