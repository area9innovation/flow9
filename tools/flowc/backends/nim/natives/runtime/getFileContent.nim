proc getFileContent*(path : string): string =
  # TODO: Handle exceptions
  return readFile(path)