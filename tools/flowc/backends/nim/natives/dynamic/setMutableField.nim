proc $F_0(setMutableField)(s: Flow, field: string, val: Flow): void =
  rt_set_flow_field(s, field, val)
