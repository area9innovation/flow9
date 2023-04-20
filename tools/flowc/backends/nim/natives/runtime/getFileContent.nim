proc $F_0(getFileContent)*(path : string): string =
  try:  
    readFile(path)
  except IOError:
    return ""