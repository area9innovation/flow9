# native createDirectory : (string) -> string = FlowFileSystem.createDirectory;
import os

proc $F_0(createDirectory)*(dir : string): string =
    try:
        os.createDir(dir)
        return ""
    except OSError as e:
        return e.msg