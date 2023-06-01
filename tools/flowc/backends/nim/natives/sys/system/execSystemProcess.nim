
# execSystemProcess : io (command : string, args : [string], currentWorkingDirectory : string, onStdOutLine : (out : string) -> void, onStdErr : (error : string) -> void) -> int = Native.execSystemProcess;

proc $F_0(execSystemProcess)(command: RtString, args: seq[RtString], cwd: RtString, onStdOutLine: proc(o: RtString): void, onStdErr: proc(error: RtString): void): int32 =
  echo "execSystemProcess is not implemented yet"
  return 1i32