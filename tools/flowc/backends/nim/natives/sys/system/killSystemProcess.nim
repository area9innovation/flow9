import osproc

# Untested
proc killSystemProcess*(process: Process) =
  process.terminate()
