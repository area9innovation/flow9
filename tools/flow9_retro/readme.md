# Flowe - a flow compiler

Usage:

flow9 myfile.flow

Options:
	help=1
		Print usage info

	js=1
		Compile to JS
	
	cpp=1
		Compile to CPP

	debug=<id>,<id>
		Will trace the compilation process of the given ids.
		The ids can be types, functions, globals, or files (without .flow).

	verbose=0,1,2
		Increasing amount of tracing information

Run "flow9" for more basic options.

# Goals and motivation

The goal is to an incremental compiler, which is incremental at the id level.
The existing flowc compiler is incremental at the module level, but that means
most compiles are slower than they have to be.

# Representations

This compiler has these representations:

1. Have complete AST after parsing, using typed Gringo grammar.
      PExp = Parsed Expressions
   `parsePExp` converts a string to `PExp`.
   Status: Done. Can parse all code we have. The grammar is found in 
   `pexp/pexp.gringo`.

2. Once files and dependents are parsed, desugar the program to DExp:
   DExp = Desugared Expressions.
   `desugarPExp` converts a `PExp` to `DExp`, using a `DDesugar` environment
   for struct and union lookups.
   Status: Done.

3. Once dependencies are desugared, do type inference and convert the result to
   ``BExp`. Typing happens in `ttypeInference` and then we get a bmodule from
   `dmodule2bmodule`.
   BExp = Backend, Typed Expressions.
   Status: Done.

4. Then plug into the backends. Initial JS backend exists. js=1. We can also use
   flowc backends, such as Java.

This pipeline is exposed by 

	compileFlow(cache : FlowCache, file : string) -> BModule;

where `FlowCache` is a cache for modules.

## Type inference

The type inference uses equivalence classes for the types.
The type system is extended with just one construct:

- Overloads. This defines a set of types, where we know the
  real type is exactly one of them. As type inference proceeds,
  we will eliminate options one by one until we have a winner.

We use overload types to handle the overloading of +, - as well as
dot on structs, which can be considered as an overloaded function.

When doing type inference, the language constructs result in unification
of equivalence classes as well as subtyping relations. Subtyping relations
are resolved into unifications with overloads when possible.

If a unification or subtyping is not possible to complete, it is pushed
to a queue for later processing, when more information is expected to be
available.

TODO CGraph:
C:/flow9/tools/flowc/typechecker/typechecker.flow:1281:91: Add type annotation. Unresolved type (equivalence class e9455)

 flow9 tools/flow9/flow9.flow strict=1 incremental=0 >out.flow

 Check overload sub overload typars.

- We need a subtype with multiple types when the max is closed?

- Exhaustiveness check of switch

- Verify that we give useful errors for real errors

Need decision:
- MTree is polymorphic, but Material is not. Add better warning

# Name and type lookups

A key problem is to find names, types, sub- and supertypes from the context 
of a given module. We would like this lookup to be precise in terms of the
import graph.

This is not easy. Consider the problem of transitive supertypes:

	file1:
	U := A, B;

	Add relations: A -> U, B -> U

	file2:
	import file1
	T := U, C;

	Has: A -> U, B -> U, 
	Add relations: U -> T, C -> T, and expanding U to get A -> T, B -> T

	file3:
	import file2
	V := T, D;

	Has: A -> U, B -> U, U -> T, C -> T, A -> T, B -> T
	Add relations: T -> V, D -> V, expand T to get: U -> V, (A -> V, B -> V), C -> T

	file4:
	W := C, E;

	Add: C -> W, E -> W.

So we have a graph of types and subtypes, but there are some parts of the graph
that only become online when certain files are included.

Rejected this options for having efficient solution:

- Maintaining transivitive closure: https://pure.tue.nl/ws/files/4393029/319321.pdf

Basically, requires a N^2 binary matrix for each step. Thus, maintaining all intermediate
transitive closures requires N^3 space. We have on the order of 5000 flow files.
To keep all those would require 120gb. So we have to be smarter.
We could restrict the graph to just those files that define unions. For flowe, this is 21 
files out of 148. 15%. That still becomes 1GB for Rhapsode. So doing it precisely for all 
files is not realistic.

Instead, we maintain a global lookup. We should add a way to check what path each
global is defined in. Then we need the ability to check whether a given file is included 
in the transitive import closure of another file.

Live data structures to make this possible:
- Global graph of super/subtypes
- Import graph
- Global map from symbol to what file defines that

So to find the supertypes of a given file, we get the global list.
Then we filter that list by looking up the source file of each type, and
checking that this is in the transitive closure of the current file.

This paper provides an algorithm that allows us to check if A is in the
transitive closure of B:
https://dl.acm.org/doi/abs/10.1145/99935.99944

Try to understand that, and maybe implement it.

Plan:
- TODO: Implement the transitive closure check in a second step to filter the list of ids found.
  We should probably maintain a set of dependent ids for each global, so we can quickly check this
  also when incremental is going to be done on ids?

## Optimization of the compiler

The compiler has decent speed, but could be faster.

- Try vector in union_find_map, which might be faster at least in Java.

- Try to reduce the active set of tyvars when doing chunks. Copy from one 
  tyvar space to a new one, to reduce max set.

- Compiling runtime.flow takes 2527ms. Rough breakdown:
    800ms in parsing. The best fix there is to improve Gringo backend for common
	      constructs
   1262ms in type inference
 	 	600ms in resolveTNodes

- When finding chunks, check if the code for a referenced piece of code has any
  free ids. If not, no need to chunk it. (see unicodeToLowerTable and others
  in text/unicodecharacters.flow)

## Improvements to be done

- Imports that start with "lib/" are almost surely wrong, and do not work.

- Add a check that imports really exist, and report errors for those that do not

- Add a compile server
  - Add option to only type check given ids

# JS backend/runtime

According to this benchmark:

https://jsben.ch/wY5fo

This is the fastest way to iterate an array in JS:

	var x = 0, l = arr.length;
	while (x < l) {
		dosmth = arr[x];
		++x;
	}

# C++ backend

There is a C GC library here:

Automatic:
https://github.com/mkirchner/gc
https://github.com/orangeduck/tgc

Requires implementing "mark", but that should be simple.
https://github.com/doublec/gc

Advanced, performant, but complicated:
https://chromium.googlesource.com/chromium/src/+/master/third_party/blink/renderer/platform/heap/BlinkGCAPIReference.md

The best solution is to go for Perceus:
https://www.microsoft.com/en-us/research/uploads/prod/2020/11/perceus-tr-v1.pdf

# Extension of syntax

We support a special kind of string surrounded by << anything >>, which is hoped
to help make mixing muliple languages easier.

# Efficient functional data structures

http://trout.me.uk/lisp/vlist.pdf
