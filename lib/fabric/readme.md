### Flow Fabric

Extend Material with new Fabric written in flow.
This implementation uses createElement and other direct APIs into HTML to render.
It covers the new FRP model, the main layout elements lines, cols, table, group based on HTML, so we do not do metrics.
We wrap Material inside Fabric so any component can be used there. We extend these to be able to reference the Fabric FRP environment.
We add dialog, timer, ssql, whatever we need to be able to write expression only code as part of the Fabric to avoid splitting code into UI and code that looks at behaviours at the top of a function.
We add a new way to do reflection based on existing flowschema definitions in our binary, to allow the reflection based UX patterns.

Requirements:
- A way to get a DOM element from Material to allow Fabric to work on that
- Potentially expose getBoundingClientRect to try to get available to work when embedded Material inside Fabric
- Figure out the style story
- Replace JS object syntax with new "with" syntax in flow to avoid style arrays:

Foo(a: int, b : double, c : [int]):
Foo(with b=2.0) 		== Foo(0, 2.0, [])
Foo(with b=1.0, a=1) 	== Foo(1, 1.0, [])
sdsfd = 1;
Foo(with a=sdsfd) 		== Foo(sdsfd, 0.0, [])

The idea is that most types have an implicit default value:

bool = false, int = 0, double = 0.0, string = "", array = [], struct (recursive construction of args).
union: Not possible?
Maybe: None().
ref: not possible?
functions: if return type is default constructible, then construct that type. If void, then nop.
flow, native, ?, ?? can not be default constructed.
