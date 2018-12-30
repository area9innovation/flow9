Proof of concept of passing data from Webassembly in the C++ runner data representation
format to JS, and back. It should show all the critical features of data exchange.

Host in your web-server.

We should not need to pass structs, since list2array etc, stuff like that will 
already be implemented in c++.
So only complex things like UI and http support would have to interface with js
and while they are more complex on the inside, they use far simpler set of 
parameter types in general.

The pre-my.js file contains the "decoding" of data from Webassembly into JS.
See main of test.cpp where we construct a number of items and send them to JS.

Also, there is a call to the function test_call in test.cpp from JS:

extern "C" {
    EMSCRIPTEN_KEEPALIVE
    int test_call(int foo, char *xxx) {
        printf("TEST: %d %s\n", foo, xxx);
        return 0;
    }
}

which is called from JS like this:

    Module.ccall("test_call", 'number', ['number', 'string'], [123, "blah"]);

which uses a built-in protocol for converting numbers and strings.

Reference
http://webassembly.org/docs/js/
https://github.com/mbasso/awesome-wasm

TODO:
- Extract the GC from the existing C++ runner, so we can do GC WASM side.
  That would bring us to a minimal runtime where we can allocate objects,
  and GC them.
  Concretely: Add GarbageCollector.cpp and ByteCodeRunner.cpp to the Makefile 
  for test.cpp, and get things to compile and run with the heap managed by 
  the GC.

  The GC is tied to the ByteCodeRunner object. Eventhough we might not want
  to use the ByteCodeRunner itself, it ties the whole thing together - flow 
  memory buffers, stacks, structure definitions, native hosts are all contained 
  in the fields of the runner object.
  To get GC to work, we would have to do a memory management without mmap. Either
  just allocate the maximum heap, or ensure that memory growth keeps pointers valid.

- Get flow code to run in WASM. These approaches come to mind:
  - Compile the entire C++ bytecode runner with GC to Webassembly, and execute
    bytecode. Unlikely to beat JS in performance, but maybe the simplest place
    to start?

  - Compile flow to WASM by converting our flow bytecode to WASM. Probably
    not that hard. This is likely to bring the best performance, since in
    principle, this is similar to have the JIT works, except it is at
    compile time. This requires that it is possible to link "handwritten"
    WASM with Emscripten WASM.

  - Compile flow to WASM that uses the C++ data representation, through C++.

- Link and hook up the C++ natives that need to run WASM side. Basically, the
  set of natives needs to be divided into those that are implemented in C++
  and those that are implemented in JS.

- Hook up the JS runtime with the JS-side natives. For data that has to live
  in the JS world, we have to tell the GC about those roots somehow, or
  transfer ownership to JS, where they can then go back somehow.

Milestones
----------

- Link with GC and get that to run.
- Link with some C++ natives, and get those to work.
- Link with JS natives, and get those to work.
- Compile flow code to WASM, link that with the runtime, and get that to work.

----

Alternative approach 1
----------------------

Another way to get webassembly is to have these things:

1) A compiler that translates our bytecode to webassembly

2) A supporting runtime written in c++ compiled to webassembly,
   which will support the above compiler. So bytecodes can call
   helper functions written in C++.

3) Our JS natives that need to be done on the JS side

4) A set of natives that need to be run on the webassembly side

5) An interface between JS and the webassembly

The most tricky part is what data representation to use at runtime.
The simplest way forward is to use the same 64-bit encoding as our 
current C++ runner does on the stack.

To avoid GC, we use reference counting.

So that means everything is 64-bits + ref. counted heap.

We use the double encoding trick, where abnormals are coerced to
represent the other kinds of values we need.

Challenge: DList where ref. counting does not work.



Alternative approach 2
----------------------

Compile to haxe, then to hashlink, and then to Webassembly.

The challenges, as I see it, are:

1) No current releases of haxe and hashlink are compatible. Seems we have to compile from master manually?

2) The haxe HL target is currently considered a "sys" target, but there would be a need a for a 
   new variant, which is much more like JS, since there is no IO

3) How to interface with the JS world in terms of passing data and pointers to 
   functions back and forth between the two worlds.

WebAssembly requires you to register what functions you export and import, and all values have to be
passed through a linear byte memory. There is "wasm-bindgen" from the Rust ecosystem, which attempts 
to build a generic solution for the last point:

https://github.com/rustwasm/wasm-bindgen

But in Haxe, there need to be exposed some hashlink GC root hooks as well, if data is constructed in 
the HL world, and only kept alive in the JS world.

So while there is certainly potential, it would require some work.

