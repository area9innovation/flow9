import osproc, threadpool, streams

# Untested
proc processOutput(process: Process, onStdOutLine: proc (output: string)) {.thread.} =
  let stream = process.outputStream()
  while true:
    let line = stream.readLine()
    if line.len == 0:
      break
    onStdOutLine(line)

proc processError(process: Process, onStdErr: proc (error: string)) {.thread.} =
  let stream = process.errorStream()
  while true:
    let line = stream.readLine()
    if line.len == 0:
      break
    onStdErr(line)

proc waitForExitWithCallback(process: Process, onExit: proc (errorCode: int)) {.thread.} =
  let exitCode = process.waitForExit()
  onExit(exitCode)

proc runSystemProcess*(command: string, args: seq[string], currentWorkingDirectory: string,
                      onStdOutLine: proc (output: string), onStdErr: proc (error: string),
                      onExit: proc (errorCode: int)): Process =
  let process = startProcess(command, args = args,
    workingDir = currentWorkingDirectory,
    options = {})

  spawn processOutput(process, onStdOutLine)
  spawn processError(process, onStdErr)

  # Set up exit callback
  spawn waitForExitWithCallback(process, onExit)

  return process
