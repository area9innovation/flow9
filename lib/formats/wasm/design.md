# Design of low-level C-like language for Wasm

It should have local type inference, but only support very basic types.

Lexical scoping. No closures. No structures.

Figure out how to define more advanced values:
- array
- tuples
- either
- maybe

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
	native id : (i32) -> i32 = module.name;

	// Global import
	native id : i32 = module.name;
	native id : mutable i32 = module.name;

# Expressions

a = 1; // let-binding
a := 2; // set local or global

Normal let binding and var ref, function call, block, loop, if, ifelse, 
break <n>, return.

"null : func" for null reference to function
"null : extern" for null reference to extern
"expr is null"

"id ? then : else" for select, with eager eval of then and else.


## Load/store

Load could be:
	mem_i32[<offset>]					// i32.load
	// TODO: Should the alginment be specified in bytes?
	mem_i32[<offset> align <2>] : i8s	// i32.load8_s	

Store could be:
	mem_i32[<offset>] := <exp>;			// i32.store
	mem_i32[<offset>] := <exp> : i8;	// I32.store8 unless type inference defines exp to be i8



break-if
break-table
call-indirect
localtee? a + tee?

Table instruction

## Advanced concepts

	// Memory import
	import memory(min, max?) from module.name;

	// Memory and exporting memory
	reserve_memory(min, max?);
	reserve_memory(min, max?) export as <id>;

	// Tables
	import id : table(min, max?)<reftype> from module.name;
