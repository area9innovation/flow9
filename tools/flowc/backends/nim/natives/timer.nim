# timer : io (int, () -> void) -> void = Native.timer;

proc timerFuture(delay : int32, fn : proc (): void) {.async.} =
  var systemTimer = sleepAsync(int(delay))
  try:
    await systemTimer
    fn()
  except CatchableError:
    discard # ignore error

proc timer*(delay : int32, fn : proc (): void) : void =
  asyncCheck timerFuture(delay, fn)