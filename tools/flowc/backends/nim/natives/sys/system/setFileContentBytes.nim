# native setFileContentBytes : io (filename : string, content : string) -> bool  = Native.setFileContentBytes;

proc $F_0(setFileContentBytes)*(filename : string, content : string): bool =
  return setFileContentBytes(filename, content)
