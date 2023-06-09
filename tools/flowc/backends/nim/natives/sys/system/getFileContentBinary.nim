#  native getFileContentBinary : io (filename : string) -> string = Native.getFileContentBinary;

proc $F_0(getFileContentBinary)(filename: RtString): RtString =
  var f: File
  if open(f, rt_string_to_utf8(filename), fmRead):
    try:
      result = rt_utf8_to_string(readAll(f))
    except OverflowDefect, IOError, CatchableError:
      result = rt_empty_string()
      # reraise the unknown exception:
    #   raise
    finally:
      close(f)