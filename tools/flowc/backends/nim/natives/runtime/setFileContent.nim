proc $F_0(setFileContent)*(path : RtString, content : RtString): bool =
  try:
    writeFile(rt_string_to_utf8(path), rt_string_to_utf8(content))
    return true    
  except IOError:
    return false
  
