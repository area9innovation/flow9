import osproc

# Untested
proc writeProcessStdin*(process: Process, input: string) =
  process.inputStream.write(input)
  process.inputStream.flush()
