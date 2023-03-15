# native stringbytes2int : (str : string) -> int = Native.stringbytes2int;
# Read 4 bytes of the string in UTF-16 and converts to an int

proc stringbytes2int(str : string) : int =
    0