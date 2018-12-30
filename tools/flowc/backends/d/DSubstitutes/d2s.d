FlowString d2s(FlowDouble d) {
  import std.conv;
  return new FlowString(to!string(d.value));
}
