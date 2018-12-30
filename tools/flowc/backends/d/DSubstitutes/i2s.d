FlowString i2s(FlowInteger i) {
  import std.conv;
  return new FlowString(to!string(i));
}

