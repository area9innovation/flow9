FlowInteger trunc(FlowDouble d) {
  import std.math;
  import std.conv;
  return new FlowInteger(to!int(std.math.trunc(d.value)));
}
