import os

proc $F_0(getApplicationPath)*(): RtString =
  rt_utf8_to_string(getAppFilename())
