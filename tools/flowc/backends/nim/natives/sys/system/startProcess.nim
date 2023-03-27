import osproc
import streams
import threadpool


proc startProcessAction( cmd: string, cmdArgs: seq[string], currentWorkingDirectory: string, stdin: string, onExit: proc(v1 : int32, v2 : string, v3 : string): void) : void =
    try:
        var p = startProcess(command = cmd, workingDir = currentWorkingDirectory, args = cmdArgs, options = {})
        let errorcode = p.waitForExit()
        defer: 
            let stderr = p.errorStream().readAll()
            let stdout = p.outputStream().readAll()
            close(p)
            onExit(int32(errorcode), stdout, stderr)
    except OSError:
        onExit(-1i32, "", getCurrentExceptionMsg())

proc startProcess*( cmd: string, cmdArgs: seq[string], currentWorkingDirectory: string, stdin: string, onExit: proc(v1 : int32, v2 : string, v3 : string): void) : void =
    spawn startProcessAction(cmd, cmdArgs, currentWorkingDirectory, stdin, onExit)