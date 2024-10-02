# native createDirectory : (string) -> string = FlowFileSystem.createDirectory;
import os

proc $F_0(createDirectory)*(dir : RtString): RtString =
    try:
        os.createDir(rt_string_to_utf8(dir))
        return rt_empty_string()
    except OSError as e:
        return rt_utf8_to_string(e.msg)