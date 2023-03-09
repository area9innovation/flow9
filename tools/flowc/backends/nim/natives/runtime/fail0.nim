proc fail0*[T](error : string): T =
  echo "Runtime failure: " & error
  quit(0)