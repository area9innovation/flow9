proc setMutableField(s: Flow, field: string, val: Flow): void =
  rt_set_flow_field(s, field, val)
