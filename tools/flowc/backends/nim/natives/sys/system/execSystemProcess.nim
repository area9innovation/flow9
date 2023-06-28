
# execSystemProcess : io (command : string, args : [string], currentWorkingDirectory : string, onStdOutLine : (out : string) -> void, onStdErr : (error : string) -> void) -> int = Native.execSystemProcess;

proc $F_0(execSystemProcess)*(cmd: RtString, args: seq[RtString], cwd: RtString, onStdOutLine: proc(o: RtString): void, onStdErr: proc(error: RtString): void): int32 =
  try:
    var p = startProcess(command = rt_string_to_utf8(cmd), workingDir = rt_string_to_utf8(cwd), args = map(args, rt_string_to_utf8), options = {poUsePath})
    let errorcode = p.waitForExit()
    let stderr = p.errorStream().readAll()
    let stdout = p.outputStream().readAll()
    close(p)
    if stderr != "": onStdErr(rt_utf8_to_string(stderr))
    if stdout != "": onStdOutLine(rt_utf8_to_string(stdout))
    return int32(errorcode)
  except OSError as ex:
    onStdErr(rt_utf8_to_string(getCurrentExceptionMsg()))
    return int32(ex.errorCode)
