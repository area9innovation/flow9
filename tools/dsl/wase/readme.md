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
		b = 2.0; // This is implicitly auto, and thus inferred
		a
	}

The type inference is based on Hindley-Milner style unification, so it should be robust.

TODO:
- Variable shadowing should give an error

- Get this to type:
  - a = if (b) return else 2;

- Check that the return value of a return matches the function return value

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
	export "_start" start() -> () {
		...
	}

	main() -> () {
		// This is the initial function automatically called otherwise
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

- Add syntax for raw bytes, or change ints to be bytes?

- Add support for naming the data index for memory.init and data.drop

- Capture the address of data segments?

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

	// Arithmetic, all signed.
	1 + 2 / 3 * 4 % 5

	// Unsigned divisions and remainder. TODO: Reconsider this syntax and use functions instead
	1 /u 2 %u 3

	// Bitwise operations
	1 & 3 | 5 ^ 7

	// Comparisons are signed. Use instructions for unsigned comparisons
	1 < 5 | 5 >= 2 & a = 2.0

	// Tuples, aka multi-values
	[1, 2.0, 45]

## Control flow

	// Function call
	foo(1, 2) 

	if (a) b else c;
	if (a) b;

	// Sequence
	{
		a();	// An implicit drop is added here
		b();	// An implicit drop is added here
		[1, 2];  // Two implicit drops are added here
		c
	}

	// Return from the function.
	foo() -> i32 {
		if (early) {
			return 1;	 // Has to match function return type
		}
		code;
	}
	bar() -> () {
		if (early) {
			// Matches no result from function return type
			return;
		}
		code
	}

	block {
		code;
		// This breaks to the end of the block
		if (earlyStop) break;
		code;
	}

	loop {
		code;
		// This breaks to the top of the loop
		if (continue) break;
		code;
	}

	block {
		loop {
			code;
			// This breaks to the top of the loop
			if (continue) break;
			code;
			// This breaks out of the loop to endcode
			if (earlyStop) break 1;
			code;
		}
	};
	endcode;

TODO:
- More natural switch syntax?
	switch (index) {
		0: {}
		1: {}
		2: {}
		default: whatever;
	}

- More natural call-indirect syntax
	calls : table< (i32) -> i32 > = [fn1, fn2, fn3];
	call_indirect<calls>(index)(args)

	fnidx<calls, fn1>  = how to get a function pointer

## Low level instructions

The low-level instructions in Wase have the form

	id<pars>(args)

where pars are parameters for the operation decided at compile time,
while args are arguments to the instruction put on the stack.

TODO:
- Add more instructions from table below

- Have some "hole" that is not an instruction so

	[1, ? + 2];

  will work to expose pure stack discipline.
  In a [1,2,3] context, we could have pure stack.
 
## Load/store

Loads from memory are written like this:

	load<>(index);

The width of the load is inferred from the use of the value.

	// This is i32 load, since a is i32
	a : i23 = load<>(0);

	// This is f32 load, since f is f32
	f : f32 = load<>(32):

TODO: Support offset and alignment:

	load<offset>(index)
	load<offset, align>(index)

Stores are written like this:

	store<>(index, value);

The width of the store is inferred from the type of the value.

	// This is f64.store, because 2.0 is f64
	store<>(32, 2.0);

TODO: Support offset and alignment:
	store<offset>(index, value)
	store<offset, alignment>(index, value)

Loads and stores also exist in versions that work with smaller bit-widths:

	// Loads a byte from the given memory address, sign extending it into a i32 or i64
	signedByteValue : i32 = load8_s<>(0);
	signedByteValue64 : i64 = load8_s<>(0);

	// Loads an unsigned byte from the given memory address into a i32 or i64
	byteValue : i32 = load8_u<>(0);
	byteValue64 : i64 = load8_u<>(0);

	sword : i32 = load16_s<>(0);
	sword64 : i64 = load16_s<>(0);
	uword : i32 = load16_u<>(0);
	uword64 : i64 = load16_u<>(0);

	sint32 : i64 = load32_s<>(0);
	uint32 : i64 = load32_u<>(0);

	// Stores the byte "32" at address 0
	store8<>(0, 32)

	// The same, except it comes from an i64
	int64 : i64 = big;
	store8<>(0, big); // Only picks the lower 8 bits of "big"

	// Stores the lower 16 bits of the value at the given address
	store16<>(address, value);

	// Stores the lower 32 bits of the value at the given address
	store32<>(address, value);

# Comparison of Wasm and Wase

49/87 implemented.

## Control instructions

9/10 implemented.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
| `block` | `block { exp }`| X | Type is inferred
| `loop` | `loop { exp }` | X | Type is inferred
| `if` | `if (cond) exp` | X | Type is inferred
| `ifelse` | `if (cond) exp else exp` | X  | Type is inferred
| `unreachable` | `unreachable<>()` | X
| `nop` | `nop<>()` | X
| `br` | `break` or `break int` | X |  Default break is 0
| `br_if` | `break_if<int>(cond)` or `break_if<>(cond)` | X | Default break is 0
| `return` | `return` or `return exp` | X
| `call` | `fn(args)` | X
| `call_indirect` | `call_indirect<table>(args)` | -

## Reference Instructions

2/3 implemented.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
| `ref.null` | `ref.null<func>()` or `ref_null<extern>()` | X
| `ref.is_null` | `exp is null` | X
| `ref.func` | `ref.func<id>` | -

##  Parametric Instructions

2/2 implemented.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
| `drop` | `drop<>` or implicit in sequence `{1;2}` | X
| `select` | `select<>(cond, then, else)` | X | This is an eager `if`, where both `then` and `else` are always evaluated, but only one chosen based on the condition. This is branch-less so can be more efficient than normal `if`. (Automatically chooses the ref instruction version based on the type.)

## Variable Instructions

4/5 implemented.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
| `local.get` | `id` | X
| `local.set` | `id := exp` | X
| `local.tee` | `local.tee<id>()` | -
| `global.get` | `id` | X
| `global.set` | `id := exp` | X

## Table Instructions

0/7 implemented.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
| `table.get` | `table.get<id>(index)` | - | Retrieves a value from a table slot. The id is omittable and default to 0
| `table.set` | `table.set<id>(index, value)` | - | Sets a value in a table slot. id is default 0.
| `table.size` | `table.size<id>()` | - | Returns the size of a table. id is default 0.
| `table.grow` | `table.grow<id>(init, size)` | - | Changes the size of a table, initializing with the `init` value in empty slots. id is default 0.
| `table.copy` | `table.copy<id1, id2>(elems : i32, source : i32, dest : i32)` | - | Copies `elems` slots from one area of a table `id1` to another table `id2` 
| `table.init` | `table.init<tableid, elemid>(i32, i32, i32)` | - | Initializes a table with elements?
| `elem.drop` | `elem.drop<id>()` | - | Discards the memory in an element segment.

## Memory Instructions

4/8 implemented.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
| `*.load` | `load<>(address)` | X | The type is inferred from the use. TODO: Support offset and alignment
| `*.load(8,16,32)_(s,u)` | `load(8,16,32)_(s,u)<>(address)` | X | Load the lower N bits from a memory address. _s implies sign-extension. The type is inferred from the use
| `*.store` | `store<>(address, value)` | X | The width is inferred from the value.  TODO: Support offset and alignment
| `*.store(8,16,32)` | `store(8,16,32)<>(address, value)` | X | Store the lower N bits of a value. The width is inferred from the value
| `memory.size` | `memory.size<>()` | - | Returns the unsigned size of memory in terms of pages (64k)
| `memory.grow` | `memory.grow<>(size)` | - | Increases the memory by `size` pages. Returns the previous size of memory, or -1 if memory can not increase
| `memory.copy` | `memory.copy<>(bytes, source, dest)` | - | Copy `bytes` bytes from source to destination
| `memory.fill` | `memory.fill<>(bytes, bytevalue, dest)` | - | Fills `bytes` bytes with the given bytevalue at `dest`
| `memory.init` | `memory.init<id>()` | -
| `data.drop` | `data.drop<id>()` | -

## Numeric Instructions

28/52 implemented.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
| `i32.const` | `1` | X
| `i64.const` | `2l` | - | Syntax not decided
| `f32.const` | `1.2f` | - | Syntax not decided
| `f64.const` | `3.1` | X
| `*.clz` | `clz<>(exp)` | X | Returns the number of leading zeros. The width is inferred
| `*.ctz` | `ctz<>(exp)` | X | Returns the number of trailing zeros. The width is inferred
| `*.popcnt` | `popcnt<>(exp)` | X | Returns the number of 1-bits. The width is inferred
| `*.add` | `<exp> + <exp>` | X | The width is inferred
| `*.sub` | `<exp> - <exp>` | X | The width is inferred
| `*.mul` | `<exp> * <exp>` | X | The width is inferred
| `*.div_s` | `<exp> / <exp>` | X | Signed division. Rounds towards zero. The width is inferred
| `*.div_u` | `<exp> /u <exp>` | X | Unsigned division. The width is inferred
| `*.div` | `<exp> / <exp>` | X | Signed division. The width is inferred
| `*.rem_s` | `<exp> % <exp>` | X | Signed remainder. The width is inferred
| `*.rem_u` | `<exp> %u <exp>` | X | Unsigned remainder. The width is inferred
| `*.and` | `<exp> & <exp>` | X | Bitwise and. The width is inferred
| `*.or` | `<exp> \| <exp>` | X | Bitwise or. The width is inferred
| `*.xor` | `<exp> ^ <exp>` | X | Bitwise xord. The width is inferred
| `*.shl` | `shl<>(val, bits)` | X | Shift left, i.e. multiplication of power of two. The width is inferred
| `*.shr_s` | `shr_s<>(val, bits)` | X | Signed right shift. Division by power of two, rounding down. The width is inferred
| `*.shr_u` | `shr_u<>(val, bits)` | X | Unsigned right shift. Division by power of two. The width is inferred
| `*.rotl` | `rotl<>(val, bits)` | X | Rotate left. Bits "loop" around. The width is inferred
| `*.rotr` | `rotr<>(val, bits)` | X | Rotate right. Bits "loop" around. The width is inferred
| `*.abs` | `abs<>(val)` | - | Absolute value of floats. The width is inferred
| `*.neg` | -2.0 | X | Negate floating point value. The width is inferred
| `*.ceil` | `ceil<>(val)` | - | The width is inferred
| `*.floor` | `floor<>(val)` | - | The width is inferred
| `*.trunc` | `trunc<>(val)` | - | The width is inferred
| `*.nearest` | `nearest<>(val)` | - | The width is inferred
| `*.sqrt` | `sqrt<>(val)` | - | The width is inferred
| `*.min` | `min<>(val, val)` | - | The width is inferred
| `*.max` | `max<>(val, val)` | - | The width is inferred
| `*.copysign` | `copysign<>(val, val)` | - | The width is inferred
| `*.eqz` | `eqz<>(val)` | - | The width is inferred
| `*.eq` | `val == val` | X | The width is inferred
| `*.ne` | `val != val` | X | The width is inferred
| `*.lt_s` | `val < val` | X | The width is inferred
| `*.lt_u` | `lt_u<>(val, val)` | - | The width is inferred
| `*.gt_s` | `val > val` | X | The width is inferred
| `*.gt_u` | `gt_u<>(val, val)` | - | The width is inferred
| `*.le_s` | `val <= val` | X | The width is inferred
| `*.le_u` | `le_u<>(val, val)` | - | The width is inferred
| `*.ge_s` | `val >= val` | X | The width is inferred
| `*.ge_u` | `ge_u<>(val, val)` | - | The width is inferred
| `i32.wrap_i64` | `wrap_i64<>(val)` | - | Maybe we can infer all types?
| `*.trunc*` | `trunc*<>(val)` | - | Maybe we can infer all types?
| `*.trunc_sat*` | `trunc_sat*<>(val)` | - | Maybe we can infer all types?
| `*.extend*` | `extend*<>(val)` | - | Maybe we can infer all types?
| `*.convert*` | `convert*<>(val)` | - | Maybe we can infer all types?
| `*.demote*` | `demote*<>(val)` | - | Maybe we can infer all types?
| `*.promote*` | `promote*<>(val)` | - | Maybe we can infer all types?
| `*.reinterpret*` | `reinterpret*<>(val)` | - | Maybe we can infer all types?

## **Vector Instructions**

None of these are implemented yet.

| Wasm | Wase | Implemented | Comments |
|-|-|-|-|
