# native startProcess  io (command  string, args  [string], currentWorkingDirectory  string, stdin  string, onExit  (errorcode  int, stdout  string, stderr  string) - void) - void = Native.startProcess;

import osproc, asyncdispatch, streams

proc startProcessFlow*( cmd: string, cmdArgs: seq[string], currentWorkingDirectory: string, stdin: string, onExit: proc(v1 : int, v2 : string, v3 : string): void) : void =
    proc waitFuture() {.async.} =
        var systemTimer = sleepAsync(100)
        try:
            await systemTimer
        except CatchableError:
            discard # ignore errorv
    var p = startProcess(command = cmd, workingDir = currentWorkingDirectory, args = cmdArgs)
    echo("Started")
    # stdin # var readStream = inputStream(p)
    # var es = peekableErrorStream(p)
    # var os = peekableOutputStream(p)
    # var l =""
    # doAssert peekLine(os, l)
    # doAssert peekLine(os, l)
    var errorcode = -1
    var stdout = ""
    var stderr = ""
    while errorcode < 0:
        errorcode = peekExitCode(p)
        waitFor(waitFuture())
    defer: 
        echo("Ended")
        close(p)
        onExit(errorcode, stdout, stderr)