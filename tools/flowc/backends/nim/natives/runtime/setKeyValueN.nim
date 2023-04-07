# native setKeyValueN : io (key : string, value : string) -> bool = Native.setKeyValue;

proc setKeyValueN*(key : string, value : string): bool =
  echo "setKeyValueN is not supported."
  false