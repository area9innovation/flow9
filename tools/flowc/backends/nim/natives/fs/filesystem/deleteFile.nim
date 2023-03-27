# native deleteFile : (string) -> string = FlowFileSystem.deleteFile;
import os

proc deleteFile*(dir : string): string =
    try:
        os.removeFile(dir)
        return ""
    except OSError as e:
        return e.msg