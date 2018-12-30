This is a DSL for testing the unification of the FTypes used in the type checker.

These rules are so subtle that it is very hard to review them through
test cases written in flow. For this reason, this DSL has been defined
to allow systematic and comprehensive testing of the reducction rules
of the FType unifications.

Hopefully, this makes it possible to isolate problematic cases from the
bigger flow test cases, and isolate them to specific unifications, and
in this way, make it easier to get a monotoneous improvement of the
correctness of the unification.

This DSL will probably be extended to also cover the finalization
phase, so we can also get regression testing of that.

This work goes in concert with the ~100 test cases currently used by
the flowc compiler.
