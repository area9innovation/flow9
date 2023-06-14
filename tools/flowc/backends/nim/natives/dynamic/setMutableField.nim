proc $F_0(setMutableField)*(s: Flow, field: RtString, val: Flow): void =
  rt_set_flow_field(s, field, val)
