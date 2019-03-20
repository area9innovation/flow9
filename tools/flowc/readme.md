Introduction
------------

This is yet another compiler for flow, written in flow.

Goals:
- Very fast compilation time
- Clean and conventional code
- Strongly typed implementation

Use
---

Install Java Runtime 1.8 or later in a 64-bit version and python 3.
Python 3 is necessary to run the flowc1 launching script. Then use

  flowc1

to see usage information, and use

  flowc1 sandbox/fun.flow

to parse and typecheck a file. By default, compilation is incremental 
and parallel.

When working on the compiler itself, you can also invoke flowc using

  flowc sandbox/fun.flow

but this is typically much slower.

You can add a line like

  flowcompiler=flowc

to a `flow.config` file in your project root to make the flowc compiler
the default. When this is done, it means that Sublime Text, Visual Code
and flowcpp will automatically use flowc:

  flowcpp sandbox/fun.flow

On *nix based OS you can use flow as a scripting language. To do it,
place a link to the bin/flows script into /usr/bin. Then it is sufficient
to provide a shebang-header to the file like

  #!/usr/bin/flows

and make it executable to run the file (it must contain main function).

Differences to haxe compiler
----------------------------

flowc requries structs to be applied. The haxe compiler accepts code like

  a = Empty;

but flowc does not. You have to write

  a = Empty();

There is a script, which can help fix these problems. To use this, first
compile and pipe the output to a file called `out.flow`:

  flowc foo/bar.flow >out.flow

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
in another union, which differens in the number of polymorphic arguments:

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
	  current module is still correct.

4. Code generation. Bytecode works, JS works, others are in progress.

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

Testing C++ backend
-------------------

We have some tests for C++ backend located in tools\flowc\tests\cpp. Use run_test.bat <testId> to produce
corresponding .cpp-file in "out/" folder. Please note that currently you need to have override_println=1 in your
flow.config in order the tests to be compiled correctly (done for tools\flowc\tests\cpp\flow.config)

To build a test manually with g++ from command line please use following arguments:

	g++ -std=c++1z -I<path to flow> -I<path to flow>/QtByteRunner/core/ -o <executable name> -O3 -fno-exceptions <path to test*.cpp> -lstdc++fs

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


WebAssembly
-----------

We have a beta backend for this. See `tools/flowc/backends/wasm/readme.md`. Unfortunately,
all speed tests show that JS is faster, even for integer-only code. WebAssembly has to be
considered a young technology. Maybe it will be faster in the future.


<h3 id=require>Restricted scope and dynamic linking</h3>

This feature is only available in the new compiler called `flowcompiler`. It allows more 
fine-grained control of the scope of imported code through a new `require` 
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
