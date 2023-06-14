# native fileModified : (string) -> double = FlowFileSystem.fileModified;
import os
import times

proc $F_0(fileModified)*(path : RtString) : float = 
    try:
        getLastModificationTime(rt_string_to_utf8(path)).toUnix().float * 1000.0
    except OSError:
        0.0
    