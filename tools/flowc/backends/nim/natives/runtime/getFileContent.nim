proc getFileContent*(path : string): string =
  try:  
    readFile(path)
  except IOError:
    return ""