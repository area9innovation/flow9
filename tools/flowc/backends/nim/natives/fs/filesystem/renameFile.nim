# native renameFile : (old : string, new : string) -> string = FlowFileSystem.renameFile;
import os

proc $F_0(renameFile)*(oldName : string, newName : string): string =
    try:
        os.moveFile(oldName, newName)
        return ""
    except OSError as e:
        return e.msg