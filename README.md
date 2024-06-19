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

Hello world
-----------

    import runtime;

    main() {
    	println("Hello world");
    }

Meet flow
---------

- flow is a simple, functional language in the ML family
- C-family syntax
- Strongly typed, polymorphism, subtypes
- Designed to look like other languages and be easy to learn
- Minimalistic to reduce complexity and ease porting to new platforms
- Same code compiles and runs on HTML5, iOS, Android, Windows, macOS, Linux
- Production quality. Software used by millions of users
- Pixel precision—high-design, responsive UI on all platforms with identical code
- Complete standard library written in flow itself, with natives for each backend
- Extensive UI toolkit based on Google Material Design guidelines
- UI toolkit based on Functional Reactive Programming

Installation
------------

The easiest way to get started is to use VS Code with Dev Containers. See: [VS Code dev containers](doc/devcontainer.md). It can also be installed via the following steps: 

1. Make sure you have [Git LFS](https://git-lfs.github.com) installed.

2.  Check out this repository with something like

	git clone https://github.com/area9innovation/flow9

3. Add `flow9\bin` to your path.

4. Install Python 3, and make sure it is in your path.

5. Install OpenJDK 11 or newer. It must be the 64 bit version. For example: https://jdk.java.net/java-se-ri/14

6. Cd into the flow9 directory and compile and run the first program:

    c:/flow9> flowcpp demos/demos.flow

If this does not work, make sure you have [Git LFS](https://git-lfs.github.com) installed. 
You have to reclone the flow9 repository after installing Git LFS, or use `git lfs pull`.

See `demos/demos.flow` to read the code for this example.

Documentation
-------------

See [doc/readme.markdown](doc/readme.markdown) for further documentation about the language 
and platform, including more details on how to get started.

See [flow9 Wiki](https://github.com/area9innovation/flow9/wiki) for documentation on the [Material library](https://github.com/area9innovation/flow9/wiki/Material)
and main UI building blocks.

Community
---------

There is a YouTube channel here:

https://www.youtube.com/channel/UC9lxa2X3hMFQKaKnn-sq2Pg

Here is a Discord server for discussions about flow:

https://discord.gg/9gGJu6KU

Tooling
-------

- `flowc` is the current compiler, written in flow itself. See [tools/flowc](tools/flowc). Can work as a compile server.
- `flow` is the original compiler, written in haxe. See [tools/flow](tools/flow)
- Single-step debugger using gdb protocol (see [platforms/qt](platforms/qt))
- Profiler for time, instructions, memory, garbage collection
- JIT (just-in-time) compiler for x64, interpreter for ARM and others
- Compiles to C++ and Java for performance-critical code, typically server side
- IDE/Code editor support for [VSCode](https://github.com/area9innovation/flow9/tree/master/resources/vscode/flow), [Sublime Text](https://github.com/area9innovation/flow9/tree/master/resources/sublimetext), [Kate](https://github.com/area9innovation/flow9/tree/master/resources/kate) & [others](https://github.com/area9innovation/flow9/tree/master/resources)
- Mature PEG parser generator. See [doc/lingo.markdown](doc/lingo.markdown)

Folders
-------

- bin - binaries for the compiler and related tools
- debug - code for the debugger and profiler
- demos - a demo program showing how the UI library can be used
- doc - documentation of the language and libraries
- lib - the flow standard library
- platforms - the flow runtime platforms source code
- resources - integrations with VS code (recommended), Sublimetext and more
- sandbox - contains hello world
- tools - the compiler and processor for rendering fonts
- www - required files to be exposed by the web-server for running flow programs online
- www_source - the source files of some of the files in the www folder

License
-------

The flow compiler is licensed under GNU General Public License version 2 or any later version.
The flow standard library is released under the MIT license.
For the license of other components, see LICENSE.txt.

Name
----

`flow` was started in 2010. This predates the 'flow' typechecker from Facebook. Thus, we elect 
to keep the name, since it came first, is a full platform and the risk of confusion seems small. 
However, should the need arise, then `flow9` can also be used to refer to this language.

History
-------

- August 2010: The very first program ran on Flash & HTML5
- November 2013: First app approved in iOS store
- April 2014: First app approved in Android PlayStore
- November 2015: Flash was retired, completely migrated to HTML5
- January 2016: Material guidelines implemented
- November 2016: JIT for x64 was added
- May 2018: Self-hosted compiler written in flow itself
- April 2019: Initial open source release
