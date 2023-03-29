# native fileModified : (string) -> double = FlowFileSystem.fileModified;
import os
import times

proc fileModified*(path : string) : float = 
    try:
        getLastModificationTime(path).toUnix().float * 1000.0
    except OSError:
        0.0
    