# Wase - a friendly, low-level language for Wasm

This is a language, which maps one-to-one with WebAssembly, and compiles directly
to Wasm bytecode. As such, it can be seen as an alternative to the WAT text format,
but it is easier to use because of these things:

- It uses more conventional syntax rather than Lisp
- It has type inference
- It handles all the index business for you

The language is lexically scoped, but does not have closures, and no real data structures.
It provides direct access to the memory through load/stores, just like Wasm.

The language is designed to expose the full low-level flexibility of Wasm directly.

# Status

Only the most basic programs work and can compile directly from text to WASM binaries.
A lot of instructions are not implemented yet. For each instruction, we need to define
three different things:

- Syntax. Done in grammar.flow.
- Typing. Done in type.flow
- Compilation. Done in compile.flow

# Type system

It supports the types of Wasm:

	i32, i64, f32, f64, v128, func, extern

At compile time, however, the compiler uses the real types for functions to ensure type
checking is robust. The syntax for functions is like this:

	// A function that takes an i32 and a f64, and returns a i32
	foo(i32, f64) -> i32 { ... }
	
	// Does not take any arguments, does not return anything
	foo() -> () { ... }

	// Multi-values is supported with this syntax: This function returns both an i32 and a i64
	foo(i32) -> (i32, i64) { ... }

As a special type, there is also "auto", where the type will be inferred by
the compiler: 

	// The return type of this function is inferred to be "i32"
	bar() -> auto {
		1;
	}

This also works for locals:

	bar() -> auto {
		a : auto = 1;
		a
	}

The type inference is Hindley-Milner, so it should be robust.

## Top-level Syntax

At the top-level, we have syntax for the different kinds of sections in
Wasm. This includes globals, functions, imports, tables and data.

The order of top-level declarations is important. The names of globals,
functions and such only take effect from the point they are defined.

TODO:
- What about mutual recursion?

## Global syntax

The grammar for globals is like this:

	// Constant global
	<id> : <type> = <expr>;

	// Mutable global
	<id> : mutable <type> = <expr>;

	// Exported global
	export <id> : <type> = <expr>;

	// Exported mutable global
	export <id> : mutable <type> = <expr>;

Some examples:

	pi : f64 = 3.14159;
	counter : mutable i32 = 0;
	export secret : i32 = 0xdeadbeaf;
	export changes : mutable f32 = 3.1341;
	// Exports this global to the host with the name "external"
	export "external" internal : i32 = 1;

TODO:
- Extend the type checker to check mutability of globals

## Function syntax

	// Functions
	foo(arg : i32) -> i32 {
		a : i32 = 1;
		a + arg
	}

	// This function is exported to the host using the name "foo"
	export foo(arg : i32) -> i32 {
		arg
	}

	// Exports this function using the "_start" name to the host, in compliance with Wasi
	export "_start" main() -> () {
		...
	}

## Imports of globals and functions

Use this syntax to import a function from the host:

	// Function import from host
	import println : (i32) -> void = console.log;

Notice imports have to be the first thing in the program.

The same works for globals:

	// Global import
	import id : i32 = module.name;
	import id : mutable i32 = module.name;

TODO:
- Do a two-phase declaration processing, so we can have imports in 
  arbitrary order, and also try to support mutual recursion

## Tables

TODO: Define syntax for this

## Data

TODO: Implement this

	data : data<i32> = 0, 1, 2, 3, 4;
	data : data<i8> = "utf8 string is very comfortable";

	meminit<data>(offset)
	drop<data>();

# Expressions

The body of globals and functions are expressions. There are no
statements, but only expressions. The syntax is pretty standard:

	// Let-binding have scope
	a : i32 = 1;
	<scope> // "a" is defined in this scope

	a := 2; // set local or global

	if (a) b else c;
	if (a) b;

	// Function call
	foo(1, 2) 

	// Arithmetic
	1 + 2 / 3 * 4 % 5

	// Unsigned divisions and remainder:
	1 /u 2 %u 3

	// Bitwise operations
	1 & 3 | 5 % 7

	// Sequence
	{
		a();	// An implicit drop is added here
		b();	// An implicit drop is added here
		c
	}

	// Return from the function.
	foo() {
		return value;
	}
	bar() {
		return;
	}


TODO: Get more stuff to work:
- Add unsigned comparisons for i32, i64
- Add instructions for shifts, clz, ctz, popcnt
- Get this to type:
  - a = if (b) return else 2;

	break <int>
	return
	return <exp>

	block {
		code;
		break;
		code;
	}

	loop {
		code;
		if (sadf) break
		code
	}

	// null reference to functino
	null : func
	// null reference to extern
	null : extern

	// Checking for nll
	expr is null

	// Syntax for select:
	select(cond, then, else)

	localtee "a + tee<a>"?

break-if
	ifbreak(cond, n)

break-table
	breaktable<[3,2,1], 23>(index)

	switch (index) {
		0: {}
		1: {}
		2: {}
		default: whatever;
	}

call-indirect
	calls : table< (i32) -> i32 > = [fn1, fn2, fn3];
	call_indirect<calls>(index)(args)

	fnidx<calls, fn1>	= how to get a function pointer

## Load/store

TODO: Implement this.

Load could be:
	load<i32, <offset>, s8>(index)		// i32.load
	load<i32, <offset>, <align>>(index)	// i32.load

Store could be:

	store<i32, <offset>>(index, value)	// i32.store

We could probably infer the type of value to decide exactly which type it is?

## Declaring memory

To reserve memory, use:

	// Reserves one page of 64k
	memory 1;

	// Reserves and exports memory under the name "memory"
	export memory 1;

	// Reserves and exports memory under the name "mymem"
	export "mymem" memory 1;

## Advanced concepts

TODO: Implement this.

	// Memory import
	import memory(min, max?) from module.name;

	// Memory and exporting memory
	reserve_memory(min, max?);
	reserve_memory(min, max?) export as <id>;

	// Tables
	import id : table(min, max?)<reftype> from module.name;

# Future

Figure out how to define more advanced values:
- array
- tuples
- either
- maybe
