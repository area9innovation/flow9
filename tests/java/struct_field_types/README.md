# Java struct field type tests

Compile and run the runtime harness from the repository root (Java 21+):

```sh
test_dir=$(mktemp -d)
mkdir -p "$test_dir/classes"
javac -cp 'platforms/java/lib/*' -sourcepath platforms/java -d "$test_dir/classes" tests/java/struct_field_types/StructFieldTypesTest.java
java -Xmx256m -Xss256k -cp "$test_dir/classes:platforms/java/lib/*" StructFieldTypesTest
```

`tests/java_struct_field_types.flow` also exercises actual generated struct classes.
The compiler sources must include the new metadata emitter; the committed compiler
jar predates it. Without rebuilding that jar, compile the compiler to temporary
bytecode and use the native runner:

```sh
mkdir -p "$test_dir/obj" "$test_dir/generated"
FLOWC_XMX=1536m bin/flowc1 server=0 "obj=$test_dir/obj" "bytecode=$test_dir/compiler.bytecode" tools/flowc/flowc.flow
QT_QPA_PLATFORM=offscreen bin/flowcpp --batch --max-heap 1536 "$test_dir/compiler.bytecode" -- server=0 "obj=$test_dir/obj" "java=$test_dir/generated" tests/java_struct_field_types.flow
javac -cp 'platforms/java/lib/*' -sourcepath "$test_dir/generated:platforms/java" -d "$test_dir/classes" "$test_dir/generated/tests/java_struct_field_types/java_struct_field_types.java"
java -cp "$test_dir/classes:platforms/java/lib/*" tests.java_struct_field_types.java_struct_field_types
```

Older generated classes remain supported through shallow `RuntimeType` metadata.
Nested validation requires regenerated classes; unconstrained generic/flow fields
intentionally have no payload restriction. Named struct membership continues to
use the generated Java casts, not new recursive struct inspection.
