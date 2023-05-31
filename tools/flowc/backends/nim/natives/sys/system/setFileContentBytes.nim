# native setFileContentBytes : io (filename : string, content : string) -> bool  = Native.setFileContentBytes;

proc $F_0(setFileContentBytes)*(filename : String, content : String): bool =
  echo "stub for setFileContentBytes: setFileContent is used"
  return $F_0(setFileContent)(filename, content)
