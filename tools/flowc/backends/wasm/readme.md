Wasm backend
------------

This is an experimental backend for WASM.

The idea is to compile flow to WASM.

Requires the WebAssembly Binary Toolkit

https://github.com/WebAssembly/wabt
https://github.com/WebAssembly/wabt/releases


Test with something like:

    flowc file=tools/flowc/tests/wasm/test1.flow wasm=test1 wasmhost=test1.html dce=0

Then open test1.html in a web-browser.

Alternatively, use nodejs (make sure you have hxnodejs haxe library installed):
  
    flowc file=tools/flowc/tests/wasm/test1.flow wasm=test1 wasmhost=test1.js wasmnodejs=1 dce=0

And then run with node.js:
  
    nodejs --expose-wasm test1.js

There is an option to produce listing file - `wasmlisting=<file>` - that dumps compiler-generated 
tables in JSON format into the specified file. Helps debugging code generation.

Wasm memory size is 100 pages (each page is 64K) by default, to change that, use `wasm-memory=<size>`
(i.e. `wasm-memory=1000` provides `65 536 000` available bytes).

We might be able to run command line using something like

https://github.com/WAVM/WAVM

at some point.


TODO:
- ref counting for locals, parameters. Deref counters when locals, parameters go out of
  scope, except for the final values of all control flow constructs.

- Support int/double to string cast

- Stitch the JS-side runtime together somehow, rather than hardcode in fiWriteHostTemplateFile.
  Consider to define some kind of DSL that allows us to reference and refine the haxe runtime,
  and automatically build the bridge functions that connects the two worlds.

  Extend "decode_data(address :int, typedescriptor : int) -> Object" function in the JS world
  which reads memory and converts to JS value.
  Write "convertJSToWasm(obj : Object, typedescriptor : int) -> int" functio nin the JS world,
  which allocates memory in Wasm, and writes the value there.

- Implement polymorphism. At first, add implicit conversion to/from flow type when not already
  flow

- Improve memory allocator. Use fixed-size regions with bitmaps to mark usage

- Optimize switch to not copy the body for default case

- Escape analysis to keep things on stack

Representation of data
----------------------

This is how values are represented on the stack, and stack-like places.

void - i32, or nothing.
bool - i32, although we should only use 0 or 1
int - i32
double - f64

string - i32. Heap pointer to ref. count, 32-bit length in bytes and then 2-byte char based string itself

array - i32. Heap pointer to ref. count, then 32-bit length of items, then data in stack value format

ref - i32. Heap pointer to ref. count, then data in stack value format

native - i32. Heap pointer to ref. count, then 32-bit index in hash table on js side

struct - i32. Heap pointer to ref. count, 32-bit pointer to type descriptor, then args in stack value format

function/closure - i32. Heap pointer to struct that has data in stack-value format and function index as the last parameter.

flow - i32. Heap pointer to ref. count, then 32-bit pointer to type descriptor, then stack value format.

Tail Calls
----------

Tail calls are compiled into an extra block and loop around the function body:
```
(block $exit
	(loop $cont
		...
		param1
		set_local 0
		param2
		set_local 1
		...
		br $cont  ;; <- this is tail call - replaced with "continue" for the outer loop
		
		br $exit ;; <- this is normal function exit
	)
)
```


Data section
------------

The data section has three parts:

* strings
* type descriptors (including all structs)
* function type tables

The last entry is special however - it is not mapped into the linear memory spaces as the strings
and type descriptors do, but represents a totally separate index space accessible from
`call_indirect` instructions only.

Lambdas
-------

Lambdas are supported through lambda lifting - moving inline lambda declarations to the global level. This is done as an AST pass before WASM generation per se. 

A closure is a struct containing all free variables for a lambda plus a function pointer (index in function type table). All functions (including global, but excluding natives and functions with names starting with `wasm_`) are modified to receive an extra last parameter of type `i32` that is named `__closure__` and is a pointer to closure. 

Lambda creation statement (`FiLambda`) is replaced with closure creation statement 
(which is in turn structure constructor) which captures all free variables and a function index.

Every indirect function call (call that does not refer to the global function by name) is replaced
with the following:
1. Put function arguments to stack
2. Put function pointer (variable value) to stack - this will work as the last argument being
closure pointer
3. Put function pointer (variable value) to stack again, add 8 (offset of the first field), and
load an `i32` from this address - this will read the function index from the closure struct
4. Do a `call_indirect` 

A free-standing `FiVar` that references a global function is transformed into a closure creation
statement using a pre-defined `WasmGlobalClosureWrapper` closure type which has no free variables,
just a function index. 

Closure comparison is implemented as struct comparison - as every unique lambda has unique struct type, 2 different lambdas are always different, and closures of the same lambda are equal iff the captured variables are equal.

Nested lambdas are implemented using refs to outer closures - an extra field is added to closure 
(itself also named `closure`) that points to the containing struct, and the reference is generated as `__closure__.__closure__.variable` using arbitrary depth.

Polymorphic lambdas are support in both dimensions (by arguments and by captured variables). Both
lifted function declaration and closure (struct) can be polymorphic.

Garbage collection and Ref counting
------------------

At first, we are going for ref. counting. The implementation is as follows:
* all heap values are ref counted
* ref counts are INCREASED in the following cases:
	* when assigning a new non-auto-generated-temp local variable - for the value
	* when calling a function - for all arguments
	* when returning from a function - for the result
* ref counts are DECREASED in the following cases:
	* when local variable scope ends (include temp's!)
	* when function parameter scope ends
* all compiler-generated code and standard library functions behave according
to those items unless otherwise specified explicitly

Later we can improve our own (see for instance notes on how Go's alloc
works here https://about.sourcegraph.com/go/gophercon-2018-allocator-wrestling/),
or switch to GC.

Polymorphism
------------

- Specialize polymorphic functions by type-kind.
  The basic operations we need to support for polymorphic functions can
  maybe be limited to copying and comparisons, and struct operations. That 
  implies that we can reuse code for polymorphic functions which share the 
  same size of data as well as comparison code.

After lambda lifting, the following is performed:
1) Collect all polymorphic names in a map from name to polymorphic type. This includes
   functions, structs, natives, unions, global variables.

2) Traverse AST and build a map from name to concrete type specialization required
	fiMatchTypars does this matching, and can return a Tree<string, FiType> for each
	type parameter. This is done iteratively until nothing more is found, and at each step
	there all existing polymorphic entities are specialized to search for usages of other 
	entities in their specialized bodies.

3) Replace all polymorphic names with mangled name based on concrete type
	mangleSuffix can produce a suffix for the specialized version based on a
	concrete type

4) Instantiate polymorphic names in all specialized versions, using mangled names
	instantiateFiExpTypars can do this specialization of a polymorphic top-level
	name based on a name of the bindings


TODO: implement reflection-like stuff including toString, isSameStructType and 
friends. We do need
to record the original type description for the type, so the specialized structs
should have a new type descriptor id type, with a pointer to the original, polymorphic
struct specialization.
makeStructValue will need to calculate the specific suffix in the same way as the
compiler, and search for the proper type descriptor using the mangled name.

Representation of natives
-------------------------

Currently the following classes of natives are implemented (defined by prefix in nativeName):
- `wasm.` - translate to wasm assembly instructions
- `host.` - translate to an import declaration and an invocation of a JS function. A 
  consequence is that such natives must be provided when instantiating a Wasm module
- `host_w.` - the same as simple 'host.' but in addition will be wrapped by another JS function which will take care about data packing/unpacking
- `wasm_compiler.` - translate to compiler-computed values like heap initial offset

Global variables are immutable by default - however, to support certain compiler features, there is 
a convention that variable whose name starts with `wasm_` and ends with `_mut` is declared as mutable: `(global $wasm_variable_mut (mut i32) i32.const 0)`.

Ideas for further development below:

Wasm-bindgen has a "slab" in the JS world where objects live with
reference counting. There is both a stack version and a heap version

https://rustwasm.github.io/wasm-bindgen/design/js-objects-in-rust.html

This is useful for natives that needs to live in the JS world, but be
owned by the Wasm side.

Sending data back and forth
---------------------------

Currently wasm side exports functions that the main flow module exports, and imports functions 
that are `host.` natives as described above. 

Ideas on how to refine below: 

Wasm-bindgen has malloc in Wasm side, which Js calls to allocate memory
for strings that are then copied.

https://rustwasm.github.io/wasm-bindgen/design/exporting-rust.html

Each JS function is wrapped by another one, which does the conversion.
The same on the Rust-side - each function has a shim, which does the 
conversion.

There are some that run the Wasm in a webworker for multi-threading,
and then uses postmessage to send messages back and forth.

It seems it is possible to send binary messages this way:
https://djhworld.github.io/post/2018/09/21/i-ported-my-gameboy-color-emulator-to-webassembly/
https://github.com/djhworld/gomeboycolor-wasm/commit/4f9933fd0fab6d9f310776d89f8c296e72af1c9a

Runtime
-------

Low-level runtime requires a heap, as well as code for comparison
of values. This is found in wasm_runtime.flow with a simplistic
allocator in wasm_runtime_allocator.

Runtime uses a restricted subset of flow (basically, equivalent to C):
 - no structs, arrays, or references, only bool, int and double types
 - no polymorphism (generics)
 - no standard library functions
 - no closures, lambdas, and functions-as-values
 
Some of those constructs are allowed in some parts of the library. 
The most critical and lowest level is memory allocator, which
absolutely has to obey the restrictions above, since the language
features mentioned require a memory allocator to work.

Natives
-------

Natives are implemented in either Wasm or JS side.

To implement a native in Wasm, just add it to wasm_natives_native.flow (prefix with `wasm_`)
and define the linkage in wasm_native_linkage. For polymorphic natives, this provides a way to link
a specialized native into relevant low-level function - i.e. concat___aiaiai 
(specialized form of concat([int], [int])-> [int]) into concat_i32. 

Further ideas for runtime development are listed below.

Bytecoder has this runtime in JS that they use:
https://github.com/mirkosertic/Bytecoder/blob/77fe07cddd59f35a48ec06d9e947c8d7a18df0b4/integrationtest/src/main/webapp/indexwasm.html

This contains floor, ceil, sin, cos, round, float_rem, sqrt

And then use this at the WASM side:
	(func $float_remainder (import "math" "float_rem") (param $p1 f32) (param $p2 f32) (result f32))

Here is a naive WASM side implementation of mod:
	(func $floatMod (type $t8) (param $p0 f64) (param $p1 f64) (result f64)
	get_local $p0
	get_local $p0
	get_local $p1
	f64.div
	f64.floor
	get_local $p1
	f64.mul
	f64.sub)

It is possible to get some implementations of these things using
https://webassembly.studio/

and adding C functions like

	double __attribute__ ((noinline)) mySin(double a)
	{
	    return sin(a);
	}

and then grab the corresponding code.

Wasm-bindgen automatically binds all of JS functions in Rust space.
