proc setFileContent*(path : string, content : string): bool =
  # TODO: Handle exceptions and return false when problems
  writeFile(path, content)
  return true