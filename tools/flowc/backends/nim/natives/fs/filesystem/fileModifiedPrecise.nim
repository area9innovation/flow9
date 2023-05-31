import os
import times

proc $F_0(fileModifiedPrecise)*(path : String) : float = 
    try:
        getLastModificationTime(rt_string_to_utf8(path)).toUnixFloat().float * 1000.0
    except OSError:
        0.0