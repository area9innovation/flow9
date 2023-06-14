# native fromBinary : (s : string, default_ : flow, fixups : (string)->Maybe<([flow])->flow>) -> flow = Native.fromBinary;

# stub. will be used flow implementation
proc $F_0(fromBinary)*(value : RtString, defValue : Flow, fixups : proc(a0: RtString) : $F_1(Maybe)[proc(a0: seq[Flow]): Flow]): Flow =
  rt_to_flow(value)
