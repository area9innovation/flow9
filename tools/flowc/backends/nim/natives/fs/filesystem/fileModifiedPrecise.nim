import os
import times

proc $F_0(fileModifiedPrecise)*(path : string) : float = 
    try:
        getLastModificationTime(path).toUnixFloat().float * 1000.0
    except OSError:
        0.0