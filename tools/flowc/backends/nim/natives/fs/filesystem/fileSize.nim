# native fileSize : (string) -> double = FlowFileSystem.fileSize;
import os

proc $F_0(fileSize)*(path : RtString): float =
    try:
        result = toBiggestFloat(os.getFileSize(rt_string_to_utf8(path)))
    except OSError:
        result = 0.0