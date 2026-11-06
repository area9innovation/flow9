# Binary deserialization nesting

The binary readers return values whose nesting is bounded, so that decoded
values stay within what recursive functions such as `toString`, `toBinary` and
`==` handle on default stack sizes. By default, `deserializeBinary` and
`deserializeBinary2` accept at most **2048 nested containers** in the encoded
value.

- Every array, struct, and ref adds one level. Empty arrays and zero-field
  structs count too.
- A scalar root has depth zero; a container root has depth one. A scalar inside
  2048 containers is accepted, but another container at that point is not.
- Mixed container kinds share the same budget. Siblings do not accumulate depth.
- Each link of a `List` is a `Cons` struct, and its end is an `EmptyList`, so a
  `List` of 2047 elements is as deep as the default allows. An array of any
  length adds one level.
- The struct-definition footer is separate from the value's depth.
- The limit is on the encoded structure before constructor fixups. User-supplied
  fixups remain responsible for the values they return.

Input beyond the limit follows the existing damaged-input path and returns the
caller's default value.

## Which reader applies it

`deserializeBinary3` passes the limit to the `fromBinaryWithDepth` native. The
C++ bytecode runner and the JavaScript `JSBinflowBuffer` reader implement it.
Every other runtime (Java, cpp2, cpp3, C#, nim and any later one) decodes with
the Flow reader in `lib/text/binary.flow`, which applies the same limit, even
where the runtime has a faster native `fromBinary` of its own: that native does
not know the limit, so using it would let deeper input through. Giving one of
those runtimes a `fromBinaryWithDepth` native is the way to make it fast again.

The raw `Native.fromBinary` of the C++ bytecode runner and of JavaScript also
default to 2048, for callers that use it directly.

## Why 2048

2048 stays well below the depth at which those recursive functions fail on the
Java and JavaScript default stacks, leaving room for the caller's own frames. It
also covers nearly everything those runtimes can write, since `toBinary`
recurses too.

## Another limit

`deserializeBinary3(value, fixups, default_, maxDepth)` takes the limit as an
argument. A reader with a larger stack, or one that walks the value without
recursion, can pass more. The incremental caches of flowc and flow9 are read
with a limit of 1000000: the compiler built and walked those trees before it
wrote them, and flowc runs with a 32 MB stack.

## Compatibility

The wire format and `toBinary` are unchanged. Writers do not impose this reader
limit, so successfully writing a deeper value does not imply that it can be
read back with the default. Existing encoded values within the limit keep their
behavior.

This is deliberate. A stored value deeper than 2048, such as a `List` of more
than 2047 elements, now reads back as the default through `deserializeBinary`
and `deserializeBinary2`; its reader must switch to `deserializeBinary3` with a
limit its stack can handle. Raising the default instead would bring back values
that the same program cannot print or compare.

## Decisions and scope

- One limit for every runtime: runtimes without a depth-limited native fall back
  to the Flow reader rather than an unlimited native decoder, trading decode
  speed there for the same contract everywhere.
- Deeper values are rejected rather than repaired: the change bounds what the
  readers return. Making `toString`, `toBinary` and `==` non-recursive would
  remove the need for a limit but is a separate change; values built in memory
  or read with a higher `deserializeBinary3` limit are not covered by this one.
- The default is defined in Flow (`binaryMaxNestingDepth`) and repeated in the
  C++ and JavaScript readers only for their raw `fromBinary`; the three must be
  changed together.

## Tests

`tests/binary_deserialize_test.flow` covers the common contract on every target,
including the Flow reader, and `deserializeBinary3` with a lower and a higher
limit. `tests/binary_native_test.flow` covers the C++ reader.
`tests/js/binflow_buffer` exercises the JavaScript buffer reader directly with
Haxe and Node.js (`npm test`). Boundary tests cover 2047, 2048, and 2049 levels,
all container kinds, empty containers, mixed nesting, sibling resets, a `List`
of 2047, and printing and writing accepted decoded values.
