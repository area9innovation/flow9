# timer : io (int, () -> void) -> void = Native.timer;

import asyncdispatch

proc timerFuture(delay : int32, fn : proc (): void {.gcsafe.}) {.async.} =
  var systemTimer = sleepAsync(int(delay))
  addCallback(systemTimer, fn)
  try:
    await systemTimer
  except CatchableError:
    discard # ignore error

proc timer*(delay : int32, fn : proc (): void {.gcsafe.}) : void =
  asyncCheck timerFuture(delay, fn)