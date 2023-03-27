# native createDirectory : (string) -> string = FlowFileSystem.createDirectory;
import os

proc createDirectory*(dir : string): string =
    try:
        os.createDir(dir)
        return ""
    except OSError as e:
        return e.msg