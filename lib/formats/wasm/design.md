# Design of low-level C-like language for Wasm

It should have local type inference, but only support very basic types.

Lexical scoping. No closures. No structures.

## Syntax

	// Globals
	<id> : <type> = <expr>;
	<id> : mutable <type> = <expr>;
	export <id> : <type> = <expr>;

	// Functions
	foo(arg : i32) -> i32 {
		a = 1;
		a + arg
	}

	export foo(arg : i32) -> i32 {
		arg
	}

	// Function import from host
	native println : (i32) -> void = console.log;

	// Global import
	native id : i32 = module.name;
	native id : mutable i32 = module.name;

# Expressions

a = 1; // let-binding
<scope>

a := 2; // set local or global

Normal let binding and var ref, function call, if, ifelse, break<n>

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

"null : func" for null reference to function
"null : extern" for null reference to extern
"expr is null"

"choose(cond, then, else)"

## Load/store

Load could be:
	peek<i32, <offset>, s8>(index)		// i32.load
	peek<i32, <offset>, <align>>(index)	// i32.load

Store could be:

	poke<i32, <offset>>(index, value)	// i32.store

we infer the type of value to decide exactly which type it is.

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

Table instruction

Drop: Whether or not to have implicit drop in sequence or not:
	{
		_ = <foo>;	// This is type correct and corresponds to drop
		2
	}

## Data

	data : data<i32> = 0, 1, 2, 3, 4;
	data : data<i8> = "utf8 string is very comfortable";

	meminit<data>(offset)
	drop<data>();

## Advanced concepts

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

