#  native getFileContentBinary : io (filename : string) -> string = Native.getFileContentBinary;

proc getFileContentBinary(filename: string): string =
  var f: File
  if open(f, filename, fmRead):
    try:
      result = readAll(f)
    except OverflowDefect, IOError, CatchableError:
      result = ""
      # reraise the unknown exception:
    #   raise
    finally:
      close(f)