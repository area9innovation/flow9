# native fileModified : (string) -> double = FlowFileSystem.fileModified;
import os
import times

proc fileModified*(path : string) : float = 
    getLastModificationTime(path).toUnix().float