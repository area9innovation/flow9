# native setKeyValueN : io (key : string, value : string) -> bool = Native.setKeyValue;

proc setKeyValueN*(key : String, value : String): bool =
  echo "setKeyValueN is not supported."
  false