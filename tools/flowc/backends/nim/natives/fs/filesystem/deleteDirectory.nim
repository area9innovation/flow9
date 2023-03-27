#  native deleteDirectory : (string) -> string = FlowFileSystem.deleteDirectory;
import os

proc deleteDirectory*(dir : string): string =
    try:
        os.removeDir(dir)
        return ""
    except OSError as e:
        return e.msg