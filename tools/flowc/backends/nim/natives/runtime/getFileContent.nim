proc $F_0(getFileContent)*(path : String): String =
  try:  
    rt_utf8_to_string(readFile(rt_string_to_utf8(path)))
  except IOError:
    return rt_empty_string()