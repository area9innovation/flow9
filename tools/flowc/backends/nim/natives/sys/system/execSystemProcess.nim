
# execSystemProcess : io (command : string, args : [string], currentWorkingDirectory : string, onStdOutLine : (out : string) -> void, onStdErr : (error : string) -> void) -> int = Native.execSystemProcess;

proc $F_0(execSystemProcess)(command: string, args: seq[string], cwd: string, onStdOutLine: proc(o: string): void, onStdErr: proc(error: string): void): int32 =
  echo "execSystemProcess is not implemented yet"
  return 1i32