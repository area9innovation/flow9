#  native deleteDirectory : (string) -> string = FlowFileSystem.deleteDirectory;
import os

proc $F_0(deleteDirectory)*(dir : string): string =
    try:
        os.removeDir(dir, true)
        return ""
    except OSError as e:
        return e.msg