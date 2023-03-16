TABLE OF CONTENTS:
=================

* [Editor integration](#ides)
* [Developing](#dev)
* [How to refactor code](#refactor)
* [My program crashes!](#crash)
* [My GUI is slow!](#slow)
* [Memory leaks](#leaks)
* [Profiling with flowcpp](#profiling)
* [Profiling the JS target](#profjs)
* [Profiling the Java target](#profjava)
* [Code coverage](#coverage)
* [Analyzing code](#analyzing)

<h2 id=ides>Editor integration</h2>

You can configure your editor to make it better to work with Flow
code. At minimum, you'll want syntax highlighting.  Also, the compiler
supports looking up the definition sites of flow functions, which is very
handy.

<h3>VS Code</h3>

See [resources/vscode/flow/README.md](../resources/vscode/flow/README.md) for instructions on how to install all the
*flow* support we have. This is the best editor at this point.

<h3>Sublime Text 3</h3>

Another good editor for *flow* programming is Sublime Text 3.

See [resources/sublimetext/readme.md](../resources/sublimetext/readme.md) for instructions on how to install all the *flow*
support we have. This includes syntax highlighting, live syntax checking, look-up definition,
single-step debugging, profiling and more.

We recommend you learn to use 'ctrl+shift+f' for full-text search, as well as 'ctrl+p'
for quick navigation of files.

<h3>Emacs</h3>

See [resources/emacs/readme.txt](../resources/emacs/readme.txt) for instructions on how to edit Flow code in Emacs.

<h2 id=dev>Developing</h2>

When you are developing *flow* programs, here are a few tips to make it easier:

- Use `println()` for debugging output. For the JavaScript target, the output appears
  in the JavaScript console of your browser. This is typically found in some Tools/Developer
  menu of the browser.

- Use `printCallstack()` to learn where code is called from. Requires that you compile
  with debug. For flowcpp, also use the "--no-jit" command line argument

- Install and configure VS Code or Sublimetext, and learn to use the single-step debugger

- Use the JS debugger in your browser, and be sure to compile with debug info

- To run flow programs on the command-line without a window, use something like:

  `flowcpp --batch tests/helloworld.flow`

  To run in CGI mode and add parameters that can be retrieved with `getUrlParameter`, use:

  `flowcpp --cgi tests/helloworld.flow -- "a=This is a value"`

  Note that running in CGI mode will cause HTTP headers to be printed.

<h3>Single step debugging on the command line</h3>

You can use the debugger from the command prompt using a command like
`flowcpp --batch --debug flow9/sandbox/helloworld.flow`. Inside the debugger you can use
the `help` command to see a list of available commands, most of which behave exactly as
the analogous commands in `gdb`. For example, if you are in a directory such that `flow9`
is a subdirectory, and you invoke the debugger with
`flowcpp --batch --debug flow9/sandbox/helloworld.flow`, then at the `fdb` prompt you could
set a breakpoint at the call to `println` (line 4) of `helloworld.flow` by typing:
`break flow9/sandbox/helloworld.flow:4`.
Note how the path is relative to the working directory from which you invoke the debugger.

When debugging with `flowcpp`, you may see some strange looking stack trace entries of the
form `~foo at foo.flow:123 VIA bar at bar.flow:456`. These were implemented as a way of
making behaviour debugging easier, and means that function `bar` is actually being executed,
but *on behalf* of function `foo`. This way, for instance, when the `select` behaviour
transform is being updated, you will not just see `select$1 at transforms.flow:145` in
the stacktrace, but also know which closure was used to compute the value in that select.
This information is actually provided to the debugger by flow code via certain natives.

It is also possible to browse the visible object tree via a special dialog window when debugging,
if you call `flowcpp` with the `--clip-tree` argument. Selected clips are highlighted in the main
window, and some of them have associated stack traces.

<h2 id=crash>My program crashes!</h2>

The most crashes occur because you are indexing out of array bounds. Another category of errors is to
access unknown fields of dynamically type structs. In these cases, you should get a usable stack trace
in the console, but sometimes it is too deep to be readable or something like that.

Another cause of crashes is out-of-stack problems. This typically happens without any indication in
Chrome on Macs, which seem to have the smallest call stacks of all targets. If you suspect this is the
case, then you can simulate a small call stack using the c++ debugger. Set a break point at the start of
main, and start the program. Then type `set call-stack-limit 2048` in the GDB window. If your program
uses a deeper stack than this, you will get a "Call stack depth trap in function ..." error. The way to
avoid deep stacks is to use tail calls. See more information about it [here](./faq.markdown#why-we-must-use-tail-recursions)

If you experience any crash problems due to resource exhaustion, see below to learn how to profile your program.
You can also try to run the program in the C++ target or JavaScript target.

The most common changes to avoid these problems involves using other data structures - in particular to
avoid producing garbage intermediate values. If you are building a long array or string of something
piece by piece, try to use a `List`, or a `Tree` instead in the construction phase.


<h2 id=leaks>Memory leaks</h2>

#### Leaks. Overview

Flow is a programming language with automatic memory management. The developer
does not have to free used memory by hand (in most cases).  The `garbage
collector` (`GC`) is a copying, compacting `GC` that rewrites all pointers on
all collections in C++. In JS, we use the javascript GC. The `GC` gets rid
of objects it can prove are unreachable from as so called `roots`. Let's
consider one class of the `roots` that generated a lot of memory leaks.

#### Leaks. Global behaviours

A behaviour is technically a mutable value and a list of subscribers -
functions to be called when it gets new value. All the behaviours in the
global scope are in the set of `roots` for GC. So, it is very easy to produce
immortal object that is not used anymore but still consumes space as some
behavior transforms are leaky (see `flow9/lib/transforms.flow`). In the example
below `makeForm` produces a leaky `Form` as `select` adds a subscriber to the
`globalAdditionalOffsetB` behaviour each time it is executed and following
links chain is created ` globalAdditionalOffsetB` -> `offsetX` -> `Translate`
-> `form`.

	makeForm(localOffset) {
		offsetX = select(globalAdditionalOffsetB, \val  -> val + localOffset)
		form = <...>
		Translate(offsetX, zero, form)
	}

There is no `unsubscriber` returned by `select` (unlike `selectu`) and, thus,
it is not possible to break the links chain to allow `GC` make its work.
Library functions and Forms that accepts behaviours are (or at least should
be) leaks free. It is safe to pass global behaviours as arguments directly.
The problems arises due to transforms without unsubscribers.

Note, it's often better to use `fselect` and friends from `fusion` instead
of `select`, `selectDistinct` or even `selectu`, `selectDistinctu`. Fusions
are leak free and distinct version of behaviours.

However, you should be aware that `fselect` and friends will not run immediately,
in a contrast to `select`. So, if you just write in your code

	fselect(b, FLift(\x -> println(x)));

it will not do anything except build a tree of `FSelect`s. The `println` will
not happen even if you change b. To run fusion you need to use `fuse`.
If you use `Material` or `Tropic`, you do not have use to `fuse`, since the engine
will handle all of that for you.

You can use fusion in the `Form` world, but it will often be more of a hassle
than a benefit. In the Form world, the recommendation is to just use selectu
and friends. When you work with Tropic and Material, fusion is your friend.
Fusion provides a different trade-off than behaviour+transforms.flow:

1) It handles unsubscription, but you have to explicitly call `fuse`.

2) It tries to optimize chains of transforms to avoid too many temporaries, which can save
memory and speed up updates, but at the cost of an "interpretation" cost in
fuse.

So if you use behaviours and `selectu` and friends, that is perfectly fine.
There is no automatic help from the system to ensure you do not leak, but if
you are disciplined, that technology is perfectly fine.

#### Leaks. Typical refactorings

- Use `Select(globalB, makeForm)` instead of `Mutable(select(globalB, makeForm))`.
  `Select2` and `Select3` also exist. But sometimes `Select` can destroy performance: compare
	`Select(globalOffset, \val -> Translate(const(val + 10.0), zero, form))` and `Translate(select(globalOffset, \val -> val + 10.0), zero, form)`. The first one is rerendered each time `globalOffset` changes value.

- In such cases use `SelectGlobal(globalOffset, \val -> val + 10.0, \localB -> Translate(localB, zero, form))`. The produced Form will subscribe too `globalOffset` each time it is rendered and unsubscribe each time it is disposed.

- Use `<transform>u` and execute unsubscriber by hand in other cases. Do not forget that it might be necessary to subscribe / unsubscribe each time the Form is rendered / disposed - `Constructor` is your helper.

- NEVER USE `select` and `selectDistinct` (as well as `select2`, `select3`, etc). Instead use `fselect` and friends from fusion.flow (that are distinct already). It's especially easy when using Material library as it supports `Transform<?>` in most of the places.

For example:

	selectDistinct(selectedIndex, \i -> i != -1)

can be written as

	fselect(selectedIndex, FLift(\i -> i != -1))

or using helpers as

	fneq(selectedIndex, -1)

#### Leaks. Examples

Some leaks are caused by usage of select, selectDistinct and friends (NEVER DO THIS, use fusion from Tropic instead)
and part of them are caused by not calling corresponding unsubscriber, including tricky cases like this:

	uns = subscribe(b, \x -> ...);

	TConstruct(
		\-> uns
	], m);

This will call unsubscriber as soon as the Tropic will be destroyed. But the problem is that unsubscriber won't be called
if the Tropic is not shown. So the better way to do it is:

	TConstruct([
		\ -> subscribe(b, \x -> ...)
	], m)

There is one more kind of leak - the scoupe of closure. Suppose we create in the code some closure and pass it to some long-lived object.
Then all in the sope of closure will not be garbage collected till the end of lifetime of the long-lived object.
So if we should make such registration, make sure the scope is small and de-register the closure in the end of lifetime of the scope manually.
For example: https://git.area9lyceum.com/Lyceum/lyceum/commit/8f77ee3e90314553ba347570130fb74aadb6a86

#### Leaks. Debug

`behaviour.flow` is added with `setLeakingSubscribersHandler(minCountToReport : int, reportStep : int, handler : (int, string) -> void) -> void`.
It allows to register callback to be executed when behaviour gets minCountToReport, minCountToReport + reportStep, ... subscribers.

printCallstack in cpp target shows line with transform which has added the last subscriber, but the line might be not leaky. For example, it might contain <transform>u (and unsubscriber might be used correctly), but leak of the `same` behaviour happens in other place.

- Note: sometimes behaviour can have a lot of subscribers and that is not a leak.
- Note2: it is absolutely safe to use chain of functions from transform.flow without 'u'  if first behaviour in the chain is a local one.
- Note3: `Tropic` - our new GUI framework uses `Transform` instead of `behaviour`.  `Transform` do not have subscribers leak
issues.

Another way to check for memory leaks involving behaviours is to use `debugBehaviours` and `examineSuspects` functions
from behaviour.flow

	debugBehaviours("my code", "my run", \-> {
		foo(...)
	});

	examineSuspects("my code")

This will print list of suspects (behaviours without unsubscribers) to the console. Sometime you need to
defer `examineSuspects` call, i.e.

	timer(500, \-> {
		examineSuspects("my code")
	})

Also if you run `flowcpp` with `--debug` you can see a callstack for each of the suspect. Sometimes it's not easy to figure out as they all ends somewhere deep and it's not always the end of the callstack that is causing the problem. You can do a quick check to see if there are any selects in the callstack.

<h2 id=profiling>Profiling with flowcpp</h2>

There are various ways to profile flow code, both in terms of time and
memory. The most precise way is:

 * use the C++ bytecode runner to gather profiling data
 * use the profiling viewer to view the results

Profiling is easy if you have Sublimetext set up. If so, then press `ctrl+shift+p` and type flow. You can
select between making 3 kinds of profiles: time, instructions or memory. First, record the profiling and exit
the program when done. Then use ctrl+shift+p with "flow" again, and then view the profile. Notice that in the
view window, you can right click and choose "self rating" and other things for advanced analysis.

Note that the profile view feature requires that you have a 64-bit Java Runtime Environment installed. That's
because the viewer is a Clojure program, `flow9/debug/flowprof.clj`.

If you do not have Sublimetext, you can do the same manually:

1. Run profiling. There are four modes:

  Instruction counter profiling: records a stack trace every 2000 flow instructions executed.

		flowcpp --profile-bytecode 2000 path/foo.flow

  Use this to attribute significant extra cost to natives that manipulate GUI clips
  (useful to detect redundant clip tree rebuilds):

		flowcpp --profile-bytecode 2000 --profile-gui-cost 500 path/foo.flow

  Memory profiling: likewise, but every 2000 bytes of flow memory allocated.

		flowcpp --profile-memory 2000 path/foo.flow

  Real time profiling: likewise, but every 1000 microseconds of execution with flow code on the stack.

		flowcpp --profile-time 1000 path/foo.flow

  The data is saved into either `flowprof.ins`, `flowprof.mem`, or `flowprof.time` correspondingly.

  Notice that the `--profile-X` command line parameter has to be the first parameter!

  If your program runs for a long time, try using higher numbers to avoid memory problems.

  Live objects profiling: Finds out where memory allocations come

		flowcpp --profile-garbage 30 foo/foo.flow

  where 30 is the stack depth to record at each memory allocation. This mode will produce a range
  of `flowprof.fullgc-X` and `flowprof.fullgc-X-new` files where `X` is the gc generation. The
  `-new` files contain the new objects created since the last gc, while the other one contains the
  live objects at that point.

  Notice that the `--profile-X` command line parameter has to be the first parameter!

  It is also possible to enable and disable instruction and memory profiling when debugging,
  using the profile command of the debugger console. This allows recording data about different
  phases of operation to different files:

		(fdb) profile code 2000 flowprof.ins
		(fdb) profile mem 2000 flowprof.mem
		(fdb) profile off

2. Analyze the data:

		flowprof flowprof.ins foo.debug
		flowprof flowprof.mem foo.debug
		flowprof flowprof.time foo.debug

  The initial window shows the complete recorded call tree, with functions as nodes, and full recursion
  exposure.

  The context menu of a function node (right click!) allows viewing either all functions called from
  the selected one, or all functions that call it, with recursive calls folded into the root.

  The context menu of the <root> node can be used to request a flat cumulative rating of all functions.

In the profiling view, you can find some special nodes like <special 0> and so on:

	0 is garbage collection.
	100 is for all rendering.
	101 is for computing matrices and invalidating stuff where needed.
	102 calls clips recursively to render any sub-buffers like filter inputs.
	103 is rendering the content of filters and masks
	104 is for rendering the final frame, excluding the inputs to any filters or masks
	110 is extra cost attributed to gui natives via --profile-gui-cost

  The profiler also shows the information available in the debugger as `VIA` entries, but
  instead of `~foo VIA bar` it displays it as `bar` calling a `FOR foo` node.

 3. Line-by-line analysis

  Once you have found what functions are the bottleneck, you can inspect those in details line by line.
  To do this, use the code coverage profiling script:

     flowprof-coverage flowprof.ins foo.debug

  This will dump the files in the profile, with some basic stats for each. To drill down into a file,
  add a filename as listed in the dump:

     flowprof-coverage flowprof.ins foo.debug c:/flow9/sandbox/foo.flow >out.txt

  and look in the out.txt file for a line-by-line profile in that file.

<h2 id=profjs>Profiling the JS target</h2>

This is easy: Just compile your program in debug mode to preserve all identifiers in the
generated JS:

	flowc1 my/program.flow js=program.js debug=1

Then use your browser's profiler available through developer tools. In Chrome,
start the program in JS, then use More Tools -> Developer Tools, and then the Profiles tab.

<h2 id=profjava>Profiling the Java target</h2>

Compile your program to a Jar file like this:

	flowc1 my/program.flow jar=program.jar

Now, run your flow program with something like:

	java -jar program.jar -- <args>

to verify that it works.
Next, download VisualVM from https://visualvm.github.io/.

Start this program. Once it is ready, then run your flow program. As it runs,
it will appear in the list of running Java programs in VisualVM.
Click it, and you can start a profiling session.

If you wish to profile your program from startup, then follow the instructions from this
site:

https://visualvm.github.io/startupprofiler.html

In short, install the plugin to VisualVM, click the last icon in the toolbar.
Use the defaults, except in the "<define classes to be profiled>", put
"com.area9innovation.flow.**". Start the profiling, and then run something
like

	java -agentpath:C:/Work/visualvm_21/visualvm/lib/deployed/jdk16/windows-amd64/profilerinterface.dll=C:\Work\visualvm_21\visualvm\lib,5140 -jar program.jar -- <args>

to start your program, where "-agentpath" comes from VisualVM.

Some suggest that https://www.oracle.com/java/technologies/jdk-mission-control.html might also
be useful.

<h2 id=coverage>Code coverage profiler</h2>

The C++ runner supports collecting a code coverage profile. Run your program with the
`--profile-coverage` switch:

  flowcpp --profile-coverage sandbox/foo.flow

and a profile of what instructions in the bytecode have been executed is collected
in the `flowprof.cover` file.

This profile can be analysed with coverage script:

     flowprof-coverage flowprof.cover foo.debug

This dumps an overview with these columns:

  Total number of lines with code (code lines)
  Number of lines with code that were executed at least once
  Percentage of code lines that were executed at least once
  Filename

You can then look into a specific file by adding the filename:

  flowprof-coverage flowprof.cover foo.debug c:/flow9/sandbox/foo.flow

This dumps the source code of the file with prefixes explaining the coverage.
Here, a "-" means that there is code for this line, but it was never executed.
If there is a number, it means that this many instructions were executed at least once
in this line of code.

You will notice that all global functions will have instructions executed. This does not
mean that they were called, but is just an artifact of how the bytecode works. Each function
is registered when the program starts, and that takes 2-3 instructions. These show up here.

In contrast to the instruction and time profiling, the code coverage is exact. It counts
how many of the instructions in the bytecode have been executed at least once. This makes
the code coverage report useful to make sure all your code is exercised by unit tests,
or similar.

<h2 id=slow>My GUI is slow!</h2>

The most common cause of slowness is due to excessive repainting in your GUI. The second most cause is
overly complicated layout.

The first cause can be improved by moving dynamic parts of your UI further down to minimize the parts that
change. Use the c++ runner with the --clip-tree argument to profile and find such problems. You can also
try to add 'redraw=1' in the URL or command line (`flowcpp sandbox/fun.flow -- redraw=1`) and visually
inspect where redraws happen when, and thus get a sense of where to improve the code.

The second cause can be improved by using explicit sizes and avoid having loops in the layouts.
In particular, if you have a cyclic dependency in terms of size and available space from parent to children,
you get into these vibration problems: The layout engine will layout the children. This in turns affects some
parent grid to move things around, and also affect the layout of the children because of new available space
from the new size, and then it cycles like that back and forth until a fix-point is found or the program crashes.

You can also use the C++ or JS profiler to do a GUI related profiling.

<h2 id=analyzing>Analyzing code</h2>

The flow platform contains some utilities for analyzing code.

To find code which is almost identical across different files, the `--duplication` flag
is useful. It does a heuristic search on the Abstract Syntax Tree to identify code which is the
same, except for a single node in the tree. Use the `--exact-only` flag to restrict
to exactly identical code (except for formatting).

To find the definition of a name, use the `--find-definition` switch. There is also a faster
version of --find-definition in the flowtools tool, or you can use the server version of the
flowc compiler.

You can produce a static call graph of your code with the `--callgraph` switch. It requires
dot from graphviz to produce a nice graph. Beware that the graph is often so big as to be
hard to use.

Often, it is useful to only inspect the call graph of a single file. That can be done with the
"flowuses.bat" bat file:

    flowuses lib/translation.flow

run from `c:\flow9\` will produce a "users.svg" file with a call graph of that file. It
requires "dot" from the Graphviz package to be in your path. (This program uses a flow parser
written in *lingo*, so it does have a few small differences in the syntax allowed compared to
the compiler. You might get a syntax error. If so, rewrite the code to an equivalent notation,
for instance by splitting declaration from initialization, and it normally works.)

The `--use-stats` switch to the normal compiler parses all .flow files available, and produces
warnings about missing imports (which might not give errors because other files import the required stuff),
unnecessary imports, and exported symbols that are not used by other modules. This switch also
produces an import-graph called "imports.svg" provided you have the "dot" tool. This is useful to find
imports to get rid of when you need to reduce the size of your program.

When you are doing size optimizations, it is useful to know what files result in the most code.
To investigate this, consider to use the `--js-report-sizes` option:

    flow --js myprogram.js --js-report-sizes path/myprogram.flow >sizes.tx

which dumps the resulting size in bytes of produced JS code for each .flow file. This report
knows about dead-code-elimination, but not struct definitions.
