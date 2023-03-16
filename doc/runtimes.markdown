*flow* compilers and runtimes
=============================

There are different ways of compiling and executing *flow* code. This document attempts to document them all.

Compilers
---------

There are two different compilers for flow.

- `flow` is the original compiler, written in haxe. Invoke `flow` for usage info
- `flowc` is the current compiler, written in flow. Invoke `flowc1` for usage info

The languages supported by these compilers is almost identical. The biggest difference
is that `flowc` requires semi-colons at the end of types in export sections, and that
the type checker is more strict in `flowc` especially around polymorphism. The code in 
the standard library is intended to be compatible with both compilers for some time.

`flowc` is the recommended compiler for daily use, since it is incremental also in
typechecking. Also, `flowc` supports a compile server, which is automatically used
when developing using Visual Code, providing a nice speed up in compile times.

For more information about `flowc`, see `tools/flowc/readme.md`.

`flow.config`
-------------

Both compilers support setting up a compile/build configuration using a `flow.config` file 
in the current working directory when invoking the compiler. This is a .ini-syntax file, where
can provide options to the compilers, compatible with the arguments as given to `flowc`.

Include

	flowcompiler=flowc

or

	flowcompiler=flow

to select what compiler `flowcpp` should use when invoked like

	flowcpp material/tests/material_test.flow

*flow* runtimes
===============

Targets identified as "production" are, of course, the most critical.

haXe based runtimes
-------------------

<table>
	<tr>
		<th>Target platform</th>
		<th>Rendering target</th>
		<th>Main implementation file</th>
		<th>How to run</th>
		<th>Program representation</th>
		<th>Runtime value representation</th>
		<th>Notes</th>
	</tr>
	<tr>
		<td>JavaScript</td>
		<td>HTML5 via RenderSupportJsPixiHx.hx</td>
		<td>(JsWriter.hx)</td>
		<td>program.js, made using `flowc1 js=program.js program.flow` or `flow --js program.js program.flow` </td>
		<td>Compiles to Javascript.</td>
		<td>Native JavaScript values.</td>
		<td>Our production target for HTML5. Consider to optimise further using Google closure compiler:<br/>
`java -jar compiler.jar --compilation_level ADVANCED_OPTIMIZATIONS --js test.js --js_output_file testopt.js`
		</td>
	</tr>
	<tr>
		<td>HTML</td>
		<td>HTML5 via RenderSupportJsPixiHx.hx</td>
		<td>(fi2html.flow)</td>
		<td>program.html, made using `flowc1 html=program.js program.flow` </td>
		<td>Compiles to bundled HTML file with JavaScript included.</td>
		<td>Native JavaScript values.</td>
		<td>May include additional JavaScript libraries if necessary.</td>
	</tr>
</table>

C++ based runtimes
------------------

<table>
	<tr>
		<th>Target platform</th>
		<th>Rendering target</th>
		<th>Main implementation file</th>
		<th>Program representation</th>
		<th>Runtime value representation</th>
		<th>Notes</th>
	</tr>
	<tr>
		<td>Windows, Mac OS X, Linux</td>
		<td>Qt with OpenGL</td>
		<td>QtByterunner/core/ByteCodeRunner.cpp</td>
		<td>flow bytecode. See `src/Bytecode.hx`</td>
		<td>Bytememory, 8 bytes per value</td>
		<td>Useful for development, not for end users</td>
	</tr>
	<tr>
		<td>Android</td>
		<td>Android native API with OpenGL ES</td>
		<td>QtByterunner/core/ByteCodeRunner.cpp</td>
		<td>flow bytecode. See `src/Bytecode.hx`</td>
		<td>Bytememory, 8 bytes per value</td>
		<td>Production use</td>
	</tr>
	<tr>
		<td>iOS</td>
		<td>iOS native API with OpenGL ES</td>
		<td>QtByterunner/core/ByteCodeRunner.cpp</td>
		<td>flow bytecode. See `src/Bytecode.hx`</td>
		<td>Bytememory, 8 bytes per value</td>
		<td>Production use</td>
	</tr>
	<tr>
		<td>Windows, Mac, Linux, Android, iOS</td>
		<td></td>
		<td>(Bytecode2cpp.hx)</td>
		<td>C++, made using `flow --cpp outputdir program.flow`</td>
		<td>Bytememory, 8 bytes per value</td>
		<td>Generates big C++ files that take long time to compile, but the fastest target. In production server-side</td>
	</tr>
</table>


Java based runtime
------------------

This is a relatively fast target. For computational stuff, it can be 14 times faster than the C++ bytecode target.

<table>
	<tr>
		<th>Target platform</th>
		<th>Rendering target</th>
		<th>Main implementation file</th>
		<th>Program representation</th>
		<th>Runtime value representation</th>
		<th>Notes</th>
	</tr>
	<tr>
		<td>Windows, Mac OS X, Linux</td>
		<td>JavaFX</td>
		<td>src/java/*</td>
		<td>Java</td>
		<td>Java</td>
		<td>Production for command line</td>
	</tr>
</table>

Get the Java SDK. Be sure to have version 8 or later in 64-bit version:

	http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html

Test with something like

	flowc1 sandbox/fun.flow jar=fun.jar

which generates a .jar file, which can be run with

	java -jar fun.jar

C# based runtime
----------------

Notice this target is not being maintained since Windows Phone is a dying platform,
so there can be bitrot.

<table>
	<tr>
		<th>Target platform</th>
		<th>Rendering target</th>
		<th>Main implementation file</th>
		<th>Program representation</th>
		<th>Runtime value representation</th>
		<th>Notes</th>
	</tr>
	<tr>
		<td>Windows 10/8.1/8.0</td>
		<td>XAML</td>
		<td>src/csharp/?</td>
		<td>C#</td>
		<td>C#</td>
		<td>Experimental</td>
	</tr>
</table>

Get Visual Studio Express with C#, and download the Windows SDK for Windows 8.1.

Compile using

	flow --csharp src/csharp/flowgen sandbox/helloworld.flow

and then open the src\csharp\WindowsApp\WindowsApp.sln solution file in Visual Studio and
compile and run. In the solution there are separate projects for Universal Windows (Windows 10) 
and Windows 8.1.

Compiling to C++
----------------

`flow --cpp` compiles the bytecode to inlined C++ for additional performance benefits.

The problem with this work is that the gcc compiler has a hard time compiling the resulting C++ files.
As a result, compile times are very long.
To reduce this problem, you can try to do a profile-guided compilation instead. To do this, first collect a
representative timing profile using the instructions above - typically, the --profile-bytecode option
works best.

Next, construct a static profile of the top-100 functions in your program using the flowprof-selfrating
script:

	flowprof-selfrating flowprof.ins foo.debug >top.txt

Next, recompile your program like this:

	flow --cpp foo --profile top.txt foo.flow

Here, `foo` is the name of a directory where the generated `.cpp` and `.h` files
will be stored.

As the third step, then add a

	DEFINES += COMPILED

configuration item in the QtByteRunner.pro file. Also, be sure to add the files in the `foo` directory
under `SOURCES`.

Currently, the profile information is happily ignored when generating the C++, so you might want to add

	QMAKE_CXXFLAGS_RELEASE += -O1 -g
	QMAKE_LFLAGS_RELEASE += -g

to avoid using -O2 when compiling the resulting program, which most likely would blow up for any interesting
program.

Finally, rebuild all of the QtBytecodeRunner, and launch it with the bytecode as the argument
(since the program uses a mix of the bytecode and the compiled code).

Rendering
---------

Rendering is triggered by a range of natives, most of them declared in `rendersupport.flow`.
These natives have been carefully designed to allow a relatively straight-forward implementation
in all our targets.

An especially important native is `RealHTML`, which handles embedded HTML. RealHTML is 
implemented by communicating with the hosting HTML page, which will construct an iframe.

Rendering in JS is done using PixiJs in a `<canvas>` .

Rendering in Android and iOS targets is done from C++ using OpenGL ES. RealHTML is done
with an embedded web browser.

Rendering in Windows, Linux, Mac targets is done from C++ using Qt OpenGL. RealHTML is done
with an embedded Qt WebKit browser.

Running with NWJS.io
--------------------

You can compile flow code to Javascript and run it with NWJS.io

1) Download NWJS:

Get the SDK version of NWJS from

http://nwjs.io/downloads 

and extract it somewhere.

2) Install bindings to nodej for haxe

	haxelib install hxnodejs

3) Compile your program:

	flowc1 sandbox/fun.flow es6=fun.js nwjs=1

4) Create file `package.json` in flow repo with content:

{
  "name": "nw",
  "main": "www/flownw.html?name=fun"
}

5) At flow folder run:

(Windows)
c:\path\to\nw . fun

(MacOS X)
nwjs/nwjs.app/Contents/MacOS/nw . fun

You can call developer console of NWJS for debugging purpose, press F12 on Windows and 
Cmd+Alt+I on MacOS X.

# Using flow code in Typescript

To use flow code in Typescript, compile the flow code to a js-library,
define the name of the object to keep the exported names, and produce a
`.d.ts` file. This is done with a command line like this:

	flowc test/test.flow js=www/test.js jslibrary=foo jslibraryobject=test tsd=1

We compile a file `test/test.flow`, save the resulting library in the `www/test.js`
file, export the name `foo` in an object called `test`, and produce a `@types/test.d.ts` file,
which defines the type of the `foo` function for use in Typescript.

Then do this in your TS file that should use the code:

	/// <reference types="../@types/test" />

	// And now we can call:
    test.foo();

To link the flow code in JS, add something like this in the HTML:

	<html>
		<head>
			<script src="test.js"></script>
			...
		</head>
		<body >
		...
		</body>
	</html>

To use external natives from third-party packages you need to supply the flow.config file with section:

	js-dependencies += yarn[@braintree/sanitize-url;NativeHost],yarn[@vendor/other-lib;OtherNativeHost]
	js-dependencies += npm[@another-src/another-lib;NativeHostA]
	js-dependencies += file[platforms/js/lib/SomeNativeHost.ts;NativeHostB]

So, a single dependency is formed out of three parts (caps-locked parts are placeholders for corresponding string):

	SOURCE_PROVIDER[PACKAGE;NATIVE_HOST_NAME]

Following source providers are available: npm, yarn and file. The latter just adds a file from a local filesystem.