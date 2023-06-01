# native renameFile : (old : string, new : string) -> string = FlowFileSystem.renameFile;
import os

proc $F_0(renameFile)*(oldName : RtString, newName : RtString): String =
    try:
        os.moveFile(rt_string_to_utf8(oldName), rt_string_to_utf8(newName))
        return rt_empty_string()
    except OSError as e:
        return rt_string_to_utf8(e.msg)