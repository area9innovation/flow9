# Wase - a friendly, low-level language for Wasm

This is a language, which maps one-to-one with WebAssembly, and compiles directly
to Wasm bytecode. As such, it can be seen as an alternative to the WAT text format,
but it is easier to use because of these things:

- It uses more conventional syntax rather than S-expr
- It has type inference
- It handles all the index business for you

The language is lexically scoped, but does not have closures, and no real data structures, nor memory management. It provides direct access to the memory through
load/stores, just like Wasm.

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
checking is complete. The syntax for functions is like this:

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

The type inference is Hindley-Milner unification, so it should be robust.

## Top-level Syntax

At the top-level, we have syntax for the different kinds of sections in
Wasm. This includes globals, functions, imports, tables and data.

The order of top-level declarations is important. The names of globals,
functions and such only take effect from the point they are defined.

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

	pi : f64 = 3.14159265359;
	counter : mutable i32 = 0;
	// Exports this global to the host with the name "secret"
	export secret : i32 = 0xdeadbeaf;
	// Exports this mutable global with the name "changes"
	export changes : mutable f32 = 6.1341;
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

If the program contains a function called `main`, it is marked as the
function that starts the program.

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
  arbitrary order, and also try to support mutual recursion between functions

## Memory

You have to explicitly define how much memory is available for the runtime.
To reserve memory, use syntax like this:

	export? memory <min> <max>?;

Examples:

	// Reserves one page of 64k
	memory 1;

	// Reserves 64k at first, but maximum 1mb
	memory 1 4;

	// Reserves 128k and exports this memory under the name "memory" to the host
	export memory 2;

	// Reserves and exports memory under the name "mymem"
	export "mymem" memory 1 4;

TODO: Implement importing memory:

	// Memory import
	import memory min max = module.name;

## Data

You can place constant data in the output file using syntax like this:

	// Strings are placed as UTF8 but with the length first
	data "utf8 string is very comfortable";

	// We can have a sequence of data. The ints are encoded as LEB-128
	data 1, 2, 3, "text", 3.0;

	// Moving the data into offset 32 of the memory
	data "Hello, world!" offset 32;

The result is that this data is copied into memory on startup.

TODO:
- Add syntax for passive data, which is not automatically copied into memory
  until memory.init is called.

- Add syntax for raw bytes?

- Capture the address of data segments?

- Support opcodes:

	meminit<data>(offset)

	// This will drop the data given segment
	drop<data>();

## Tables

TODO: Define syntax for this

	// Tables
	import id : table(min, max?)<reftype> from module.name;

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

	// Unsigned divisions and remainder. TODO: Reconsider this syntax and use functions instead
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

	// Tuples, aka multi-values
	[1, 2.0, 45]

TODO: Get more stuff to work:
- Add syntax for u64 and f32 constants
- Get hex constants to work
- Add unsigned comparisons for i32, i64
- Add instructions for shifts, clz, ctz, popcnt
- Get this to type:
  - a = if (b) return else 2;

- Add more instructions:
	break <int>

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

	// null reference to function
	null_func

	// null reference to extern
	null_extern

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
	load(index, value);
	load<<offset>, s8>(index, value)		// i32.load
	load<<offset>, <align>>(index, value)	// i32.load

Store could be:

	store<<offset>>(index, value)	// i32.store

We could probably infer the type of value to decide exactly which type it is?

