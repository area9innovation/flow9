Serialization compiler
----------------------

This is a backend, producing Google protocol-buffer 3 format of flow types, 
so we can get efficient code generated for serialization in various languages.

protocol-buffer: Has a .proto format already defining the data structure, plus 
compilers for Java, C++, Python, Java Lite, Ruby, JavaScript, Objective-C, C#, Go.


Protocol-buffer does not have any type info, and can only be serialized and
deserialized correctly if you have the schema.



Test with something like

flowc tools/flowc/sandbox/incremental_types.flow protobuf=types.proto protobuf-types=FcSerializedModule

TODO:
- Recursively extract types mentioned in the listed types.


Other serialization compilers to consider
----------------------------------------

A shootout goes on here:
https://github.com/eishay/jvm-serializers/wiki


https://github.com/pascaldekloe/colfer
Seems to win in speed tests

flow serialized format - having a compiler which compiles a given flow type
to a series of functions, which can serialize and deserialize data of those
types into the flow string format. This is useful to generate strongly
typed code which can serialize, thus avoiding the use of the flow type.
This is important for the performant c++ fastflow backend.

binflow - the same for the binary format.

thrift: http://thrift.apache.org/
  Has an IDL language as well.
  Has C++, java, python, PHP/Ruby support
  Has versioning.

  There are two different binary encodings:
  More verbose, but seems useful
  https://github.com/apache/thrift/blob/master/doc/specs/thrift-binary-protocol.md

  Using varints and zigzags for signed ints: Probably slow to decode
  https://github.com/apache/thrift/blob/master/doc/specs/thrift-compact-protocol.md


Avro: https://avro.apache.org/docs/current/
Another alternative. Contains the schema inside the binary itself.
Uses zigzag varints for integers.
Seems like a good candidate.
https://avro.apache.org/docs/current/spec.html#binary_encoding




json - we have this partially in Datawarp.

bson - some binary verison of JSON might be more performant.
Does not have native array type, which sucks.

haxe format - this has lookup tables for identical structs, and is
relatively compact.


xml: sucks.

soap: XML-based.

CORBA. Overdesigned.
COM. Urgh

Pillar: Lightweight and high-performance, but missing versioning and abstraction.


https://arrow.apache.org/
Has a binary layout for memory:
https://arrow.apache.org/docs/memory_layout.html


