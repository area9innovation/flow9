#native runSystemProcess : (command : string, args : [string], currentWorkingDirectory : string, onStdOutLine : (out : string) -> void, onStdErr : (error : string) -> void, onExit : (errocode : int) -> void) -> native = Native.runSystemProcess;
import osproc
import threadpool
import streams

proc runOutputStream(process: Process, onStdOutLine: proc (output: RtString)) {.thread.} =
  let stream = process.outputStream()
  while true:
    try:
        let line = stream.readLine()
        if line.len == 0: break
        onStdOutLine(rt_utf8_to_string(line))
    except IOError:
        break

proc runErrorStream(process: Process, onStdErr: proc (error: RtString)) {.thread.} =
  let stream = process.errorStream()
  while true:
    try:
        let line = stream.readLine()
        if line.len == 0: break
        onStdErr(rt_utf8_to_string(line))
    except IOError:
        break

proc waitForProcessThread(process: Process, onExit: proc (errorCode: int32)) {.thread.} =
  let exitCode = process.waitForExit()
  onExit(int32(exitCode))

proc $F_0(runSystemProcess)*(command: RtString, args: seq[RtString], cwd: RtString,
                      onStdOutLine: proc (output: RtString), onStdErr: proc (error: RtString),
                      onExit: proc (errorCode: int32)): Native =
  try:
    let process = startProcess(rt_string_to_utf8(command), args = map(args, rt_string_to_utf8),
      workingDir = rt_string_to_utf8(cwd),
      options = {poUsePath})

    spawn runOutputStream(process, onStdOutLine)
    spawn runErrorStream(process, onStdErr)
    spawn waitForProcessThread(process, onExit)

    return Native(ntp: ntProcess, p: process)
  except OSError:
    return Native(ntp: ntProcess, p: nil)
