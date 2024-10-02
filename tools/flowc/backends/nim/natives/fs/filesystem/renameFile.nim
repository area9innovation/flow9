# native renameFile : (old : string, new : string) -> string = FlowFileSystem.renameFile;
import os

proc $F_0(renameFile)*(oldName : RtString, newName : RtString): RtString =
    try:
        os.moveFile(rt_string_to_utf8(oldName), rt_string_to_utf8(newName))
        return rt_empty_string()
    except OSError as e:
        return rt_utf8_to_string(e.msg)