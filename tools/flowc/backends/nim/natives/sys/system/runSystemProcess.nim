#native runSystemProcess : (command : string, args : [string], currentWorkingDirectory : string, onStdOutLine : (out : string) -> void, onStdErr : (error : string) -> void, onExit : (errocode : int) -> void) -> native = Native.runSystemProcess;
import osproc
import threadpool
import streams

proc runOutputStream(process: Process, onStdOutLine: proc (output: string)) {.thread.} =
  let stream = process.outputStream()
  while true:
    try:
        let line = stream.readLine()
        if line.len == 0: break
        onStdOutLine(line)
    except IOError:
        break

proc runErrorStream(process: Process, onStdErr: proc (error: string)) {.thread.} =
  let stream = process.errorStream()
  while true:
    try:
        let line = stream.readLine()
        if line.len == 0: break
        onStdErr(line)
    except IOError:
        break

proc waitForProcessThread(process: Process, onExit: proc (errorCode: int32)) {.thread.} =
  let exitCode = process.waitForExit()
  onExit(int32(exitCode))

proc runSystemProcess*(command: string, args: seq[string], currentWorkingDirectory: string,
                      onStdOutLine: proc (output: string), onStdErr: proc (error: string),
                      onExit: proc (errorCode: int32)): Native =
  try:
    let process = startProcess(command, args = args,
      workingDir = currentWorkingDirectory,
      options = {})

    spawn runOutputStream(process, onStdOutLine)
    spawn runErrorStream(process, onStdErr)
    spawn waitForProcessThread(process, onExit)

    return Native(what : "Process", ntp: ntProcess, p : process)
  except OSError:
    return nil
