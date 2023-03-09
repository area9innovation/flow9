proc fail*(error : string): void =
  echo "Runtime failure: " & error
  quit(0)