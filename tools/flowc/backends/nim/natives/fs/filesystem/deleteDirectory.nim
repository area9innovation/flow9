#  native deleteDirectory : (string) -> string = FlowFileSystem.deleteDirectory;
import os

proc $F_0(deleteDirectory)*(dir : RtString): RtString =
    try:
        os.removeDir(rt_string_to_utf8(dir), true)
        return rt_empty_string()
    except OSError as e:
        return rt_utf8_to_string(e.msg)