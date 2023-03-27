import os
import times

proc fileModifiedPrecise*(path : string) : float = 
    getLastModificationTime(path).toUnixFloat()