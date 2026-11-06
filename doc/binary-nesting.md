# Binary deserialization nesting

The binary readers return values whose nesting is bounded. They read without
recursion, but `toString`, `toBinary` and `==` recurse, so a value nested deeper
than the stack allows would overflow it later, wherever it is printed, written
or compared. By default, `deserializeBinary` and `deserializeBinary2` accept at
most **2048 nested containers** in the encoded value. The Flow fallback in
`lib/text/binary.flow`, the JavaScript `JSBinflowBuffer` reader and the C++
binary reader all apply it.

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

## Why 2048

These are the deepest values that `toString`, `toBinary` and `==` handled with
default stack sizes, on a stack with little else on it:

| Runtime | Value | `toString` | `toBinary` | `==` |
|---|---|---|---|---|
| Java 21 | nested arrays | ~7,000 | ~5,000 | ~5,000 |
| Java 21 | linked list | ~3,000 | ~4,000 | ~10,000 |
| JavaScript (Node.js 22) | nested arrays | 3,386 | 3,661 | 5,126 |
| JavaScript (Node.js 22) | linked list | 4,882 | 4,028 | 5,370 |

Overflow starts at about 3000 levels. 2048 leaves room for the caller's own
frames below that, and covers nearly everything a Java or JavaScript program can
write, since `toBinary` itself overflows from about 3600 levels.

## Another limit

`deserializeBinary3(value, fixups, default_, maxDepth)` takes the limit as an
argument. A reader with a larger stack, or one that walks the value without
recursion, can pass more. The incremental caches of flowc and flow9 are read
with a limit of 1000000: the compiler built and walked those trees before it
wrote them, and flowc runs with a 32 MB stack.

The limit reaches the C++ and JavaScript readers through the
`fromBinaryWithDepth` native. A runtime without it uses its `fromBinary`, with
that runtime's own limit, if any.

## Compatibility

The wire format and `toBinary` are unchanged. Writers do not impose this reader
limit, so successfully writing a deeper value does not imply that it can be
read back with the default. Existing encoded values within the limit keep their
behavior.

## Tests

`tests/binary_deserialize_test.flow` covers the common contract, including the
Flow fallback on Java and JavaScript, and `deserializeBinary3` with a lower and a
higher limit. `tests/binary_native_test.flow` covers the C++ reader.
`tests/js/binflow_buffer` exercises the JavaScript buffer reader directly with
Haxe and Node.js (`npm test`). Boundary tests cover 2047, 2048, and 2049 levels,
all container kinds, empty containers, mixed nesting, sibling resets, a `List`
of 2047, and printing and writing accepted decoded values.
