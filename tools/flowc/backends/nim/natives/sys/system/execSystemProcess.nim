
# execSystemProcess : io (command : string, args : [string], currentWorkingDirectory : string, onStdOutLine : (out : string) -> void, onStdErr : (error : string) -> void) -> int = Native.execSystemProcess;

proc $F_0(execSystemProcess)(command: String, args: seq[String], cwd: String, onStdOutLine: proc(o: String): void, onStdErr: proc(error: String): void): int32 =
  echo "execSystemProcess is not implemented yet"
  return 1i32