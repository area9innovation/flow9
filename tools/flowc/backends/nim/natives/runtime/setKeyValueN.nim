# native setKeyValueN : io (key : string, value : string) -> bool = Native.setKeyValue;

proc setKeyValueN*(key : RtString, value : RtString): bool =
  echo "setKeyValueN is not supported."
  false