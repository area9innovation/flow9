# native fileExists : (string) -> bool = FlowFileSystem.fileExists
# the same name function

proc $F_0(fileExists)(f: string): bool = 
  return fileExists(f)