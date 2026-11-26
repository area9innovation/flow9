# Java struct field type tests

Compile and run the runtime harness from the repository root (Java 21+):

```sh
test_dir=$(mktemp -d)
mkdir -p "$test_dir/classes"
javac -cp 'platforms/java/lib/*' -sourcepath platforms/java -d "$test_dir/classes" tests/java/struct_field_types/StructFieldTypesTest.java
java -Xmx256m -Xss256k -cp "$test_dir/classes:platforms/java/lib/*" StructFieldTypesTest
```

`tests/java_struct_field_types.flow` exercises actual generated struct classes.
For a compiler release, test the JAR that will ship: with the candidate at
`tools/flowc/flowc.jar`, generate classes in a fresh directory using `bin/flowc1`:

```sh
mkdir -p "$test_dir/obj" "$test_dir/generated"
bin/flowc1 server=0 "obj=$test_dir/obj" "java=$test_dir/generated" tests/java_struct_field_types.flow
```

For source development with a bootstrap JAR that predates the metadata emitter,
use this alternative generation step. It tests the compiler sources, not the shipping JAR:

```sh
mkdir -p "$test_dir/obj" "$test_dir/generated"
FLOWC_XMX=1536m bin/flowc1 server=0 "obj=$test_dir/obj" "bytecode=$test_dir/compiler.bytecode" tools/flowc/flowc.flow
QT_QPA_PLATFORM=offscreen bin/flowcpp --batch --max-heap 1536 "$test_dir/compiler.bytecode" -- server=0 "obj=$test_dir/obj" "java=$test_dir/generated" tests/java_struct_field_types.flow
```

After either generation step, compile and run the generated program:

```sh
javac -cp 'platforms/java/lib/*' -sourcepath "$test_dir/generated:platforms/java" -d "$test_dir/classes" "$test_dir/generated/tests/java_struct_field_types/java_struct_field_types.java"
java -cp "$test_dir/classes:platforms/java/lib/*" tests.java_struct_field_types.java_struct_field_types
```

Older generated classes remain supported through shallow `RuntimeType` metadata.
Nested validation requires regenerated classes; an incremental build regenerates
struct classes whose descriptors predate the current form. Unconstrained
generic/flow fields intentionally have no payload restriction.

A field that names a struct or a union accepts only that struct or the union's
members (`FieldType.named`, resolved through `FlowRuntime.union_members`, which
the generated `Structs.init` fills). Type arguments such as the `int` in
`Maybe<int>` are not checked, and struct contents are not inspected: each struct
was checked when it was built. Runtime code that builds fields of the right types
itself uses `FlowRuntime.makeStructValueUnchecked`.
