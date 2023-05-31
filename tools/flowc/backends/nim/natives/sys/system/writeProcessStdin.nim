import osproc
import streams

# Untested
proc $F_0(writeProcessStdin)*(process: Native, input: String) =
  case process.ntp:
  of ntProcess:
    if (process.p != nil and process.p.running and process.p.inputStream != nil):
        process.p.inputStream.write(rt_string_to_utf8(input))
        process.p.inputStream.flush()
  else : discard
