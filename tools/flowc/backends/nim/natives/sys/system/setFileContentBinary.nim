# native setFileContentBinary : io (filename : string, content : string) -> bool  = Native.setFileContentBinary;

proc setFileContentBinary(filename: string, content : string): bool =
  var f: File
  if open(f, filename, fmWrite):
    try:
      write(f, content)
      result = true
    except OverflowDefect, IOError, CatchableError:
      result = false
      # reraise the unknown exception:
    #   raise
    finally:
      close(f)