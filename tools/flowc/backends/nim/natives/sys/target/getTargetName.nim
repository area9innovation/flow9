proc $F_0(getTargetName)*(): RtString =
  return rt_utf8_to_string("nim," & hostOS & "," & hostCPU)