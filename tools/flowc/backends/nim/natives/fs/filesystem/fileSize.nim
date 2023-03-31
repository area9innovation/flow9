# native fileSize : (string) -> double = FlowFileSystem.fileSize;
import os

proc $F_0(fileSize)*(path : string): float =
    try:
        result = toBiggestFloat(os.getFileSize(path))
    except OSError:
        result = 0.0