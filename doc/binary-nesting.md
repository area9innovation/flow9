# Binary deserialization nesting

The Flow fallback in `lib/text/binary.flow`, the JavaScript `JSBinflowBuffer`
reader, and the C++ binary reader accept at most **512 nested containers** in
the encoded value. This follows the JSON reader's 512-container precedent and
keeps accepted nesting conservative for the recursive binary writers and value
printers.

- Every array, struct, and ref adds one level. Empty arrays and zero-field
  structs count too.
- A scalar root has depth zero; a container root has depth one. A scalar inside
  512 containers is accepted, but another container at that point is not.
- Mixed container kinds share the same budget. Siblings do not accumulate depth.
- The struct-definition footer is separate from the value's depth.
- The limit is on the encoded structure before constructor fixups. User-supplied
  fixups remain responsible for the values they return.

Input beyond the limit follows the existing damaged-input path and returns the
caller's default value. This intentionally replaces the iterative readers'
previous acceptance of arbitrarily deep values. In particular, linked lists
count one struct per link (including their terminator), plus any enclosing
containers; arrays can represent long sequences without this nesting cost.

The wire format and `toBinary` are unchanged. Writers do not impose this reader
limit, so successfully writing a deeper value does not imply that it can be
read back. Existing encoded values within the limit keep their behavior.

`tests/binary_deserialize_test.flow` covers the common contract, including the
Flow fallback on Java and JavaScript. `tests/js/binflow_buffer` exercises the
JavaScript buffer reader directly with Haxe and Node.js (`npm test`). Boundary
tests cover 511, 512, and 513 levels, all container kinds, empty containers, mixed
nesting, sibling resets, and printing and writing accepted decoded values.
