Introduction
------------

This is yet another compiler for flow, written in flow.

Goals:
- Very fast compilation time
- Clean and conventional code
- Strongly typed implementation

Use
---

Install OpenJDK 14 or later in a 64-bit version and python 3.
Python 3 is necessary to run the flowc1 launching script. Then use

	flowc1

to see usage information, and use

	flowc1 sandbox/fun.flow

to parse and typecheck a file. By default, compilation is incremental and parallel.

When working on the compiler itself, you can also invoke flowc using

	flowc sandbox/fun.flow

but this is typically much slower.

flowcpp will automatically use flowc1 when invoked with a .flow file:

	flowcpp sandbox/fun.flow

On *nix based OS, you can use flow as a scripting language. To do it, place a link to the bin/flows script into /usr/bin. Then it is sufficient to provide a shebang-header to the file like

  #!/usr/bin/flows

and make it executable to run the file (it must contain main function).

Differences to haxe compiler
----------------------------

flowc requries structs to be applied. The haxe compiler accepts code like

  a = Empty;

but flowc does not. You have to write

  a = Empty();

There is a script, which can help fix these problems. To use this, first compile your program and pipe the output to a file called `out.flow`:

	flowc1 foo/bar.flow >out.flow

Then run

	fixstructs

and this program will use the error messages from the `out.flow` file
to automatically apply structs. Compile again, and repeat until there are
no more unapplied struct errors.

flowc is stricter about types, especially when it comes to polymorphism.
In particular, there is a notion of implicit polymorphism, which can be
surprising.

  Maybe<?> ::= None, Some<?>;
    None();
    Some(value : ?);

Since `Maybe<?>` is polymorphic, flowc implicitly promotes `None` to also be
polymorphic. There are good theoretical reasons for this, and in most code,
it is not a problem. It does mean, however, that you can not "reuse" `None`
in another union, which differs in the number of polymorphic arguments:

   Foo ::= None, Bar;
       Bar();

This is not allowed.

Phases and representations
--------------------------

1. Parsing is done using a compiled Lingo grammar, which produces an
   untyped SyntaxTree AST. See tools/flowc/flow.lingo, and the
   compiled results flow_parser.flow and flow_ast.flow.

2. Desugar to Flow c. Each file becomes a FcModule. This is a strongly-
   typed AST, only meant to be used in memory. This is done in desugar.flow.

3. Type check, producing a strongly typed FiModule. The type checker works in 
   three phases:

   a. Annotate types on all AST nodes, using tyvars when the type is
      unknown. Extract constraints between these types that have to be
      respected. See typechecker.flow and type_expect.flow. These types 
      and constraints are expressed between FcTypes, which is a direct 
      AST of the type syntax of flow.

   b. These expectations are converted into FType representation.
      This is the background type system used by the compiler. This
      representation has additional constructs, such as unnamed unions,
      row-types, as well as bounds on subtypes. See ftype.flow.
      From these, the constraints are recursively checked, and information
      is propagated into sub-parts of the types. See ftype_solve.flow.

   c. Once all constraints for a top-level function or global variable has
      been propagated, the finalization phase is done. In this phase,
      we try to convert the ftypes closer to the fctypes. As part of this,
      new constraints can be uncovered, and we will iterate b) and c)
      until we reach a fixpoint, or a cap on the number of iterations.

   d. At this point, the FTypes are as precise as we can make them,
      and they are finally converted back to FcTypes as the final types.

   e. The top-level function types are recorded in a global FcTypeEnv
      environment. The local types are recorded in the AST itself.

   f. At the end, we convert the FcExp and FcType to the corresponding
      FiExp and FiType, which are suitable for incremental serialization.

   g. We can run type verification on the FiModule representation. This is
      done when dependent code is changed, and we have to check that the
    module is still correct.

4. Code generation. Bytecode, JS, Java, others are in progress.

You can inspect the process of type checking in detail, including the 
resolution of types and constraints using "verbose=2":

   flowc file=maybe.flow verbose=2 >out.flow

You can inspect graphs of the iterations using

   mkdot.bat

if you have Graphviz installed.


Notes about incremental compilation
------------------------------------

"incremental compilation" is compiling where we reuse previously parsed, 
desugared and typechecked modules. In "incremental mode", when a module is 
finished typechecking, we save a ".module" file in the "objc" folder with 
the resulting AST, including the types, i.e. a serialized FiModule.
So this ".module" file is an incremental module.

Compiling proceeds with these phases interleaved. For a given module, we 
parse it, when all dependent modules have been parsed as well, we desugar 
it, and when all dependent modules have been typecheked, we typecheck it.

If an incremental module (.module file) is out of date, since the source 
.flow has a different timestamp, OR because a dependent module is changed, 
then we have to re-parse-desugar and typecheck it. So there are two SEPARATE 
cases that cause an incremental module to become obsolete.

So basically, flowc is making this dance of moving the modules thorugh the 
pipeline of parsing, desugaring and typechecking, and reusing incremental 
modules as best it can. Of course, things become more complicated in the 
parallel case, where we try to parse, desugar (and ultimately typecheck) 
things in parallel to the extend possible. It helps to have a mental model 
of the dependency graph between modules. 

Ultimately, we are doing a topological traversal of the import graph, 
starting with the leaves, which are files like maybe.flow, which does not have 
any imports, and then tracking what dependent files can be processed next. The 
final file will ALWAYS be the input file, and it will always be processed alone.

Testing
-------

	flowc unittests=1 outfolder=1 >out.flow

runs a bunch of unit tests (in tools/flowc/tests/) and saves the output for 
direct comparison against a bunch of baselines.

	flowc unittests=tools/flowcompiler/unittests >out.flow

runs a varied set of tests that exercise relatively big parts of the compiler.

	flowc unittests=tools/flowc/tests/errors >out.flow
	flowc unittests=lib/lingo/flow/test >out.flow

runs another bunch of tests, which tests a bunch of errors that the
compiler should report.

There is also the normal flow unit tests:

	flowc file=flowunit/flowunit_flash.flow bytecode=flowunit debug=1 >out.flow
	flowcpp flowunit.bytecode flowunit.debug

which currently fails due to some math rounding problems.

WebAssembly
-----------

We have a beta backend for this. See `tools/flowc/backends/wasm/readme.md`. Unfortunately,
all speed tests show that JS is faster, even for integer-only code. WebAssembly has to be
considered a young technology. Maybe it will be faster in the future.

Java backend
------------

Flow program may be translated to java with setting the `java` option to an output directory like:

	flowc java=src program.flow

The default package for the programs, translated to java is `com.area9innovation.flow`. If you want to used
another package name, you can provide it with `java-package` option:

	flowc java=src java-package=aaa.bbb.ccc program.flow

In case you want to build a jar archive, you can use jar=1 or jar=name.jar option to build a jar target.
In case jar=1 the name of a program will be used as a name of the jar file. Example:

	flowc jar=1 program.flow

JavaScript backend
------------------

Most of natives for the JavaScript are generated from haxe sources. External (non haxe) natives may be added
by following options:

	flowc js-extern-lib=<file> js-extern-natives=<name_1>,<name_2>,...,<name_k> ...

The first inlines a whole file into the generated JS code. This file should contain an object, say 'native_host',
containing member functions 'f_1', 'f_2', ... ,'f_k' - the natives, listed in the second option. The names 
in the second option must be in the form: 'name_1' = 'native_host.f_1', ... , 'name_k' = 'native_host.f_k'.


### Library usage.
If you want to make a library instead of runnable program, you can specify the interface functions of a
library with `java-library` option (the second variant will build library.jar from library.flow):

	flowc java=src java-library=fun1,fun2,fun3  library.flow
	flowc jar=1 java-library=fun1,fun2,fun3  library.flow
	flowc jar=aname-lib.jar java-library=fun1,fun2,fun3  library.flow

Here fun1,fun2,fun3 are functions, which are used in a library interface. 
The library contains a class with the same name as a compiled flow flie, which contains: 
- `public static void init(String[] args)` - the function to initialize the runtime. `args` are the command line
arguments, passed to the library. Must be called before usage.
- public static methods fun1, fun2, fun3, etc. , listed in the `java-library` option.

So, to use a library function `fun2` you should import the Main class and appropriate data type classes from the 
translated package (by default it is `com.area9innovation.flow`).

### Conversion of data types from flow typesystem to java:
- primitive types stay the almost, same (`int` to `int`, `void` to `void` and so on).
- `flow` type converts to `Object`.
- array types are converted to java arrays.
- structs: the naming convention converts a struct `Data : (a : T1, b : int)` (flow) into 
`public class Struct_Data` (java) with public fields `Object f_a;` and `int f_b;`.
- functions: the type of a function `(A1, A2, A3) -> RT` translates to the 
interface java type `Func3<RT,A1,A2,A3>` with the single method `RT invoke(A1 a1, A2 a2, A3 a3)`.
- polymorphic types are converted to `Object`.

All classes of library may be explored in the jar file for more .

### Example of building and using java library from flow source.
Flow library source code `libtest.flow`:
```
import string;
import math/math;

InputData(a : [string], b : string);
OutputData(a : [int], b : int);

transf(d : InputData) -> OutputData {
	OutputData(map(d.a, s2i), s2i(d.b));
}
```
The library is created by calling:

	flowc1 jar=1 java-library=transf libtest.flow

The java program `libtest.java`, which uses flow library:
```
import com.area9innovation.flow.Struct_InputData;
import com.area9innovation.flow.Struct_OutputData;
import com.area9innovation.flow.Main;

public class libtest {
	static public void main(String[] args) {
		Main.init(args);
		String[] as = { "1", "2", "3" };
		Struct_InputData input = new Struct_InputData(as, "5");
		Struct_OutputData out = Main.transf(input);
		for (Object s : out.f_a) {
			System.out.println((Integer)s);
		}
		System.out.println(out.f_b);
	}
};
```

Compiling the program: 

	javac -cp .:libtest.jar libtest.java

Running the resulting class:

	java -cp .:libtest.jar libtest

Testing C++ backend
-------------------

We have some tests for C++ backend located in tools\flowc\tests\cpp. Use run_test.bat <testId> to produce
corresponding .cpp-file in "out/" folder. Please note that currently you need to have override_println=1 in your
flow.config in order the tests to be compiled correctly (done for tools\flowc\tests\cpp\flow.config)

To build a test manually with g++ from command line please use following arguments:

	g++ -std=c++1z -I<path to flow> -I<path to flow>/platforms/common/cpp/core/ -o <executable name> -O3 -fno-exceptions <path to test*.cpp> -lstdc++fs

Add "-D NDEBUG" to command line to remove asserts when measuring performance.

Currently we support MSVC 2017 and g++ 7.2. Other compilers might be added later.

Parse error reporting
---------------------
Flowc is PEG-based parser. Error reporting in PEG explained in document

  http://www.inf.puc-rio.br/~roberto/docs/sblp2013-1.pdf

At the moment error reporting is implemented as of paragraph 2 of mentioned article.

PEG parsing uses a lot of backtracking and 'failure' is a normal state of
this process. This is similar to hand-written recursive descent parser.
The real failure of parsing is the fact that not all input is consumed
at the end of parsing. To report decent errors we use a 'farthest failure position'
heuristic. Current parsing point position is tracked and all backtrack
expected symbols are collected for the current position. If the parser moves
forward (increases the current position), the error position moves forward too
and backtrack expected symbols reset and collected again for new position.

That is what `ExpectError()` struct intended for.
`expected : [string]` is a list of symbols, expected at `pos : int` of input
`met : string` prepared for holding currently found symbol/string
(not yet implemented)

`updateExpectError()` function called each time 'expected' error leads to
backtracking and updates farthest failure position and messages.

Further development is to change `ExpectError()` to eliminate its recreation
and implementing `cut points` from mentioned article.

Using UTF-8 in the Windows cmd console
--------------------------------------

Run this command:

  chcp 65001

and be sure to use Lucida Console as the default font in the console. This is
helpful when looking at the output from the typechecker, which has a habit of
using greek letters for type variables and groups.

Theoritical background for the type checker
-------------------------------------------

At first, we try to implement the algorithm from this thesis and paper:

https://www.cl.cam.ac.uk/~sd601/thesis.pdf
http://www.cl.cam.ac.uk/~sd601/papers/mlsub-preprint.pdf

There is an introduction video here
https://www.youtube.com/watch?v=E3PIKlsXOQo

However, flow has a number of features, which are different from the language treated
in this. In particular, flow has a kind of dependent types in switch-cases, where
we automatically downcast according to the switch. Also, we do not directly have
row-types, but rather tagged unions. These differences are enough to make it very
hard to apply the same algorithm. Trust us, we have tried.

There is also other algorithms out there, such as this one

https://hal.inria.fr/hal-01413043/document

However, this kind of algorithm only does type checking, not inference. This means
that they can just verify that a program is well-typed, but not figure out what
the exact type of each part of the program is.

We want to infer the type of all parts of the program, so we have to use other techniques.
The basic technique is similar to the one used in the haXe compiler. We keep bounds on
tyvars used in the constraints. These bounds are iteratively refined as information
about the types is propagated according to data flow of the program.

There is a new type checker called "gtype", which uses another method, with less heuristics. It is almost ready for production. Try by using the "gtype=1" parameter:

	flowc1 demos/demos.flow gtype=1 incremental=0 server=0

Todos
-----

- Fix error reporting when unknown names are found to do a levenshtein search to find the closest
  ids that might match

Typechecker improvement desires
-------------------------------

Improvement points:
- Error reporting. Track what tyvars have problems, and only report the first error.
  Error recovery: If a tyvar fails, keep track of that, and do not report consequent errors from this.
  Better error messages.
  Have an error reporting DSL.
- When there is a conflict, and one of the types is explicitly written by the programmer,
  then be sure to say expected X, got Y, rather than X and Y are in conflict.

Correctness:
- Handle both type inference and type verification with the same code
- More precise import handling of names
  - More explicitly track names and scopes?
- Separate checking of annotated types from type inference? Maybe this is part of type verification?
- Improve subtyping
  - Reconsider the field type Fi constructs. Research required
- Systematic test for all FiType vs. FiType cases
- Fix all known errors
- Reconsider polar types? switch type specialization, arrays, refs, struct/.field is different

Simplification:
- Explicit tracking of flow, by conversion in the AST instead?
- Work on Fi rather than Fc?
- Associate a tyvar with every AST node instead of a type?

Performance:
- Handle smarter constraint solving, maybe with prioritized heuristic, and avoid iteration
- Reconsider overall flow: Maybe interleave parsing, desugaring+typechecking more?
- Parallel type checking in the same file?
- Consider postponing call/struct construct disambiguation until typechecking


<h3 id=require>Restricted scope and dynamic linking</h3>

This feature is only available in an obsolete compiler called `flowcompiler`. 

We would like to add this to the flowc compiler as well, but it is not done.

It allows more fine-grained control of the scope of imported code through a new `require` 
construct. This construct also allows dynamic linking of code in JS 
backend. That allows required modules to only load when needed instead of 
at startup. To declare the intent of restricting the scope (dynamically 
linking) a module, use the `require` directive:

    require path/to/required/module;

The `require` directive is similar to `import` in that exported symbols from 
`path/to/required/module` are made available in the current module, however in 
the scope `require` and `unsafe` constructs only.

Before actually using functions and variables from a dynamically linked 
module, the linking module must ensure that the linked module has actually 
been loaded. Use the `require` expression to ensure the availability of the 
linked module:

    require path/to/required/module;

    myFun(x : int) {
        result = require(path/to/required/module) {
            functionInRequiredModule(2 * x)
        }
        println(result);
    }

The type system will enforce that symbols from dynamically linked modules are 
only used within `require` expressions.

The `require` expression will block if it needs to load the module. Subsequent
`require` expressions, however, will not if the module is still available. If
the linked module is available, the expression `require(module) expression`
will be equivalent to `expression`. (Notice that blocking is not a busy-loop,
but an asynchronous callback invoked once the module has been loaded.)

A non-blocking alternative expression to `require` is `unsafe`. An `unsafe` 
will return a dynamically linked symbol if the module is available. Otherwise
it will return an alternative. E.g.:

    myFun(x : int) {
        fallback : (int)->int = \x->0;
        result = unsafe(functionInRequiredModule, fallback)(2 * x);
        println(result);
    }

In this case, `functionInRequiredModule` will be called with the argument 
`2 * x` if the module is available. If not, `fallback` is invoked with the 
same argument.

Note that the syntax of `unsafe` is more restrictive that `require`. The first
argument to `unsafe` must be a symbol, not a general expression. Furthermore,
the type of the unsafe symbol and the fallback function must be the same.

Types in dynamically linked modules are always available:

    require module;

    MyStruct(value : ImportedType);
    MyUnion ::= MyStruct, ImportedStruct;

    main() {
        u : MyUnion = ImportedStruct(117);
        switch (u) {
            MyStruct(value): println(value);
            ImportedStruct(x): println(x);
        }
    }

I.e. constructing and using values of dynamically imported types is legal 
outside `require` expressions as well as defining new types based on imported 
types.

Functions using dynamically imported symbols do not need `require` expressions 
if it can be determined that they in turn are always evaluated within 
appropriate `require` expressions. For example `main` must wrap all directly 
or indirectly dynamically imported symbols in `require`s. Furthermore, top 
level variables and exported symbols must wrap imports. E.g.:

    require importedModule;

    export {
        // Illegal: Can't export as f must be invoked in a require expression.
        f : (int)->int;

        // Ok: g calls f in a require expression.
        g : (int)->int;
    }

    f(x) funFromImportedModule(x + 1);

    g(x) require(module) f(x);

    // Illegal: Top level variables must wrap f in require.
    foo : int;
    foo = f(x);

    // Illegal: main must wrap f in a require.
    main() {
        println(f(7));
    }

This is useful in modules with a large number of small utility functions.

Exported symbols in modules statically imported (directly or indirectly) from
dynamically imported modules are dynamically available. E.g. given:

    foo --import--> bar
    bar --import--> baz
    mainModule --require-->foo

Then symbols from modules `foo`, `bar`, and `baz` all need to be wrapped in 
`require` or `unsafe` in `mainModule`. E.g. in `mainModule`:

    require foo;

    main() {
        r1 = require(foo) funInFoo(funInBar(7));
        r2 = require(foo) funInBaz(r1);
    }

Symbols from dynamically linked modules from dynamically linked modules need 
to their own `require`. E.g. for:

    foo --require--> bar
    mainModule --require--> foo

then two `require` expressions are needed:

    require foo;

    main() {
        r1 = require(foo) require (bar) funInFoo(funInBar(7));
    }

If a module is both linked using `import` and `require`, it will become 
available statically, i.e. symbols  need not occur in `require` or `unsafe` 
expressions. E.g. the following is legal:

    import module;
    require module;

    main() {
        println(funInModule(7));
    }

This is especially relevant for indirectly linked modules. e.g. given the 
following imports:

    module1 --import-> maybe
    module2 --import-> maybe
    mainModule --import--> module1
    mainModule --require--> module2

Then symbols in `module1` and `maybe` are statically available while symbols 
from `module2` are dynamically available.

Use the compiler option `showimportdependencies=1` to get an overview over 
which modules are available where and whether they are statically or 
dynamically linked. For the above imports, the output would be:

    maybe: 
    module1: maybe
    module2: maybe
    mainModule: module1, module2(dynamic), maybe

The scope of the `require` expression does not determine the lifetime of the 
imported module as closures invoking the imported module may escape the scope:

    foo : (int)->(int)->int;
    foo(x) require(module) \y->imported(x, y);

    bar() {
        foo(1)(2);
    }

The syntax suggests that `module` can be unloaded after `foo` returns. However
it is the invocation in `bar` that actually calls into `module` via the lambda
returned inn foo.

## Wasm

There is initial support for Wasm, through the nim backend:

Steps:
0) Follow installation steps on https://github.com/treeform/nim_emscripten_tutorial
1) flowc demos/euler/euler8.flow nim=euler8.nim
2) copy euler8.nim to nim_emscripten_tutorial\ and "cd" there

3) Save this to euler8.nims in that folder:

	if defined(emscripten):
	# This path will only run if -d:emscripten is passed to nim.

	--nimcache:tmp # Store intermediate files close by in the ./tmp dir.

	--os:linux # Emscripten pretends to be linux.
	--cpu:wasm32 # Emscripten is 32bits.
	--cc:clang # Emscripten is very close to clang, so we ill replace it.
	when defined(windows):
		--clang.exe:emcc.bat  # Replace C
		--clang.linkerexe:emcc.bat # Replace C linker
		--clang.cpp.exe:emcc.bat # Replace C++
		--clang.cpp.linkerexe:emcc.bat # Replace C++ linker.
	else:
		--clang.exe:emcc  # Replace C
		--clang.linkerexe:emcc # Replace C linker
		--clang.cpp.exe:emcc # Replace C++
		--clang.cpp.linkerexe:emcc # Replace C++ linker.
	--listCmd # List what commands we are running so that we can debug them.

	--gc:arc # GC:arc is friendlier with crazy platforms.
	--exceptions:goto # Goto exceptions are friendlier with crazy platforms.
	--define:noSignalHandler # Emscripten doesn't support signal handlers.
	--overflowChecks:off # Flow semantics are different

	# Pass this to Emscripten linker to generate html file scaffold for us.
	switch("passL", "-o euler8.html --shell-file shell_minimal.html")

3) nim c -d:emscripten -d:wasm -d:release -o:euler8.html euler8.nim
4) nimhttpd -p:8000
5) Open http://localhost:8000/euler8.html in browser

and in the console, it prints the result.

### Installing nim

We recommend you use choosenim:
https://github.com/dom96/choosenim#choosenim

### Adding new natives to nim

Compile a program

	flowc tools/gringo/gringo.flow nim=gringo.nim

and you get a list of natives missing:

	Error: native getFileContent(path : string) -> string = Native.getFileContent is not implemented in nim backend
	Error: native printCallstack() -> void = Native.printCallstack is not implemented in nim backend
	Error: native setFileContent(path : string, content : string) -> bool = Native.setFileContent is not implemented in nim backend
	Error: native fileExists(string) -> bool = FlowFileSystem.fileExists is not implemented in nim backend

Add an implementation to the directory `tools/flowc/backends/nim/natives`. There's a filesystem analogical to the one in the
flow9/lib like:
nim/
	natives/
	├── ds/
	│   ├── array/
	│	│   ├── length.nim
	│	│   ├── concat.nim
	│	│   ├── ....
	│	│   └── subrange.nim
	│   ├── list/
	│	│   ├── list2array.nim
	│	│   ├── list2string.nim
	│	│   └── ...
	│   └── ....
	├── runtime/
	│   ├── bitAnd.nim
	|	├── bitAnd.nim
	│   └── ...
	└── sys/
		├── target/
		│   ├── getTargetName.nim
		│   ├── ....
		│   └── ...
		└── ...

Each file represents a single native function. The path to the file may no accurately correspond to the corresponding path
in the library, but its name must exactly coincide with the name of the native, because natives are indexed by their files names.

Then compile again, compile the resulting nim, and check that it works.

	nim c gringo.nim
	gringo.exe

