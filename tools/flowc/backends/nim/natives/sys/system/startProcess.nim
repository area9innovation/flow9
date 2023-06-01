import osproc
import streams
import threadpool


proc startProcessAction(cmd: RtString, args: seq[RtString], cwd: RtString, stdin: RtString, onExit: proc(v1 : int32, v2 : RtString, v3 : RtString): void) : void =
    try:
        var p = startProcess(command = rt_string_to_utf8(cmd), workingDir = rt_string_to_utf8(cwd), args = map(args, rt_string_to_utf8), options = {})
        let errorcode = p.waitForExit()
        defer: 
            let stderr = p.errorStream().readAll()
            let stdout = p.outputStream().readAll()
            close(p)
            onExit(int32(errorcode), rt_utf8_to_string(stdout), rt_utf8_to_string(stderr))
    except OSError:
        onExit(-1i32, rt_empty_string(), rt_utf8_to_string(getCurrentExceptionMsg()))

proc $F_0(startProcess)*(cmd: RtString, args: seq[RtString], cwd: RtString, stdin: RtString, onExit: proc(v1 : int32, v2 : RtString, v3 : RtString): void) : void =
    spawn startProcessAction(cmd, args, cwd, stdin, onExit)