flow
----

flow is a platform for safe, easy and productive programming of complex, multi-platform apps with a modern user interface.

The flow platform includes
- The flow programming language, a safe, functional strongly-typed programming language
- The flowc compiler, an incremental compiler for multiple targets
- The flow runtime & standard library, which provides a complete cross-platform library including mature UI components

flow has production quality targets for:

- HTML through JS
- iOS
- Android
- Windows, Mac, Linux

License
-------

The flow compiler is licensed under GNU General Public License version 2 or any later version.
The flow standard library is released under the MIT license.
For the license of other components, see LICENSE.txt.

Name
----

flow was started in 2010. This predates the 'flow' typechecker from Facebook. Thus, we elect 
to keep the name, since it came first, is a full platform and the risk of confusion seems small. 
However, should the need arise, then flow9 can also be used to refer to this language.

History
-------

- August 2010: The very first program ran on Flash & HTML5
- November 2013: First app approved in iOS store
- April 2014: First app approved in Android PlayStore
- November 2015: Flash was retired, completely migrated to HTML5
- January 2016: Material guidelines implemented
- November 2016: JIT for x64 was added
- May 2018: Self-hosted compiler written in flow itself
- 2019: Initial open source release

Meet flow
---------

- flow is a simple, functional language in the ML family.
- C-family syntax
- Strongly typed, polymorphism, subtypes
- Designed to look like other languages and be easy to learn
- Minimalistic to reduce complexity and ease porting to new platforms
- Same code compiles and runs on HTML5, iOS, Android, Windows, macOS, Linux.
- Production quality. Software used by millions of users
- Pixel precision—high-design, responsive UI on all platforms with identical code
- Complete standard library written in flow itself, with natives for each backend
- Extensive UI toolkit based on Google Material Design guidelines
- UI toolkit based on Functional Reactive Programming

Hello world
-----------

    import runtime;

    main() {
    	println("Hello world");
    }

Installation
------------

Add `flow9\bin` to your path. Requires 64-bit Java Runtime.

Compile and run the first program:

    flowcpp demos/demos.flow

See `lib/demos/demos.flow` to read the code for this example.

See `doc/index.html` for further documentation about the language.

Tooling
-------

- `flow` is the original compiler, written in haxe. See src/
- `flowc` is the current compiler, written in flow itself. See tools/flowc. Can work as a compile server.
- Single-step debugger
- Profiler for time, instructions, memory, garbage collection
- JIT (just-in-time) compiler for x64, interpreter for ARM and others
- Compiles to C++ and Java for performance-critical code, typically server side
- Visual Code, Sublimte Text, Kate & Emacs integrations with syntax coloring, find def. etc
- Mature PEG parser generator. See doc/lingo.html

Folders
-------

- bin - binaries for the compiler and related tools
- debug - code for the debugger and profiler
- doc - documentation of the language and libraries
- lib - the flow standard library
- QtByteRunner - the bytecode runner used on Windows, Mac, Linux
- resources - integrations with VS code (recommended), Sublimetext and more
- sandbox - contains hello world
- src - the source code for the original haxe-based compiler, as well as the runtime
- tools - the compiler and processor for rendering fonts
- www - required files to be exposed by the web-server for running flow programs online
- www_source - the source files of some of the files in the www folder

Community
---------

To be decided.
