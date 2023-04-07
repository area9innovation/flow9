proc $F_0(fail0)*[T](error : string): T =
  echo "Runtime failure: " & error
  quit(0)