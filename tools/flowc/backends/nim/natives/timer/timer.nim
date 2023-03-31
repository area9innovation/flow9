# timer : io (int, () -> void) -> void = Native.timer;

import os
import threadpool

proc timerBody(delay : int32, fn : proc (): void) : void =
  sleep(int(delay))
  fn()

proc timer*(delay : int32, fn : proc (): void) : void =
  spawn timerBody(delay, fn)