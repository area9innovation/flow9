# native fromBinary : (s : string, default_ : flow, fixups : (string)->Maybe<([flow])->flow>) -> flow = Native.fromBinary;

# stub. will be used flow implementation
proc $F_0(fromBinary)*(value : string, defValue : Flow, fixups : proc(a0: string) : Struct): Flow =
  rt_to_flow(value)
