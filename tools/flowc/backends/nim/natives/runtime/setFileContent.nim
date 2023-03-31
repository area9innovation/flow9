proc setFileContent*(path : string, content : string): bool =
  try:
    writeFile(path, content)
    return true    
  except IOError:
    return false
  
