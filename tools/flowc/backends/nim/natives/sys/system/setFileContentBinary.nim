# native setFileContentBinary : io (filename : string, content : string) -> bool  = Native.setFileContentBinary;

proc $F_0(setFileContentBinary)(filename: String, content : String): bool =
  var f: File
  if open(f, rt_string_to_utf8(filename), fmWrite):
    try:
      write(f, rt_string_to_utf8(content))
      result = true
    except OverflowDefect, IOError, CatchableError:
      result = false
      # reraise the unknown exception:
    #   raise
    finally:
      close(f)