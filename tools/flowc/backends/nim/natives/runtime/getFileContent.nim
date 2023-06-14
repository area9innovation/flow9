proc $F_0(getFileContent)*(path : RtString): RtString =
  try:
    let utf8_path = rt_string_to_utf8(path)
    var file: File
    if not file.open(utf8_path): return rt_empty_string()
    else:
      let size = file.getFileSize()
      var have_read = 0
      var bytes = newSeq[byte](size)
      while have_read < size:
        have_read += file.readBytes(bytes, have_read, size - have_read)
      var utf8_contents = newString(bytes.len)
      copyMem(utf8_contents[0].addr, bytes[0].unsafeAddr, bytes.len)
      return rt_utf8_to_string(utf8_contents)
  except IOError:
    return rt_empty_string()