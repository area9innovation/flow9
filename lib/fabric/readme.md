# Flow Fabric

Yet another implementaion of Fabric, this time directly in flow.

## Plan

Extend Material with new Fabric written in flow.
This implementation should use createElement and other direct APIs into HTML to render containers.
It covers the new FRP model, the main layout elements lines, cols, table, group based on HTML, so we do not do metrics for these.
We wrap Material inside Fabric so any component can be used there. We extend these to be able to reference the Fabric FRP environment.
We add dialog, timer, ssql, whatever we need to be able to write expression only code as part of the Fabric to avoid splitting code into UI and code that looks at behaviours at the top of a function.
We add a new way to do reflection based on existing flowschema definitions in our binary, to allow the reflection based UX patterns.

## TODO

- 7-guis: 
   3_flight: We want reflection based editor first
   5_crud: Just write it
   6_circles: undo, clipboard, frame/svg, interactive, clickable
   7_cells: table
- list, html, intinput, checkbox, dropdown, intslider, iconbutton
- letMany, formula, composite
- svg
- Generalize container to expose more of the flex layout features, at least as far as we can implement a fallback
- Split environment into bool, int, double, string, and flow parts for increased type safety?
- Potentially add native `getBoundingClientRect` to try to get available to work when embedded Material inside Fabric
- Figure out the style story

## Proposal for new flow syntax 

Replace JS object syntax with new "with" syntax in flow to avoid style arrays:

	Foo(a: int, b : double, c : [int]);

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

An alternative is to do records, which then have an implicit conversion to structs:

	Foo({b:2.0})
	Foo({b:1.0, a:1})
	sdsfd = 1;
	Foo({a:sdsfd})

The problem with the `with` syntax is that `BLines` and such will need to include the name of a style struct.
With the records, we can do

	BLines([], {})

