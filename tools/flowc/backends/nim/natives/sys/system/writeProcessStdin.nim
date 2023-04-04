import osproc
import streams

# Untested
proc writeProcessStdin*(process: Native, input: string) =
  case process.ntp:
  of ntProcess:
    if (process.p != nil and process.p.running and process.p.inputStream != nil):
        process.p.inputStream.write(input)
        process.p.inputStream.flush()
  else : discard