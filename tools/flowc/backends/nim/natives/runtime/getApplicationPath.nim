import os

proc $F_0(getApplicationPath)*(): String =
  rt_utf8_to_string(getAppFilename())
