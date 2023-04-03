# native killSystemProcess : io (process : native) -> void = Native.killProcess;
import osproc

proc $F_0(killSystemProcess)*(process: Native) =
  case process.ntp:
  of ntProcess:
    if (process.p != nil and process.p.running):
      process.p.terminate()
      process.p.close()
  else : discard
