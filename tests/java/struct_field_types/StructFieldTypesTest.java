import com.area9innovation.flow.*;
import java.util.Arrays;

public final class StructFieldTypesTest {
	private static int checks;
	private static void check(boolean result, String message) {
		checks++;
		if (!result) throw new AssertionError(message);
	}

	private static final class TestStruct extends Struct {
		private final RuntimeType[] types;
		private final FieldType[] descriptors;
		private Object[] fields;
		TestStruct(RuntimeType[] types, FieldType[] descriptors) {
			this.types = types;
			this.descriptors = descriptors;
		}
		public int getTypeId() { return 0; }
		public String getTypeName() { return "Test"; }
		public String[] getFieldNames() { return new String[types.length]; }
		public RuntimeType[] getFieldTypes() { return types; }
		public FieldType[] getFieldTypeDescriptors() { return descriptors; }
		public Object[] getFields() { return fields; }
		public void setFields(Object[] fields) { this.fields = fields; }
		public int compareTo(Struct other) { return 0; }
	}

	public static void main(String[] args) {
		FieldType integer = FieldType.of(RuntimeType.INT);
		FieldType unknown = FieldType.of(RuntimeType.UNKNOWN);
		check(integer.accepts(1), "int");
		check(!integer.accepts(1.0), "double is not an int on Java");
		check(!integer.accepts(null), "null is not an int");
		check(FieldType.of(RuntimeType.VOID).accepts(null), "void");
		check(unknown.accepts(null), "unconstrained null");
		check(unknown.accepts(new Object()), "unconstrained native value");
		check(FieldType.arrayOf(unknown).accepts(new Object[] { 1, "x", null }), "generic array");
		check(FieldType.refTo(unknown).accepts(new Reference<Object>(null)), "generic ref");
		check(!FieldType.refTo(integer).accepts(new Reference<String>("x")), "ref payload");
		check(!FieldType.refTo(integer).accepts(1), "ref shape");
		check(FieldType.of(RuntimeType.STRING).accepts("x"), "string");
		check(!FieldType.of(RuntimeType.STRING).accepts(null), "null is not a string");
		check(FieldType.of(RuntimeType.BOOL).accepts(true), "bool");
		check(FieldType.of(RuntimeType.DOUBLE).accepts(1.0), "double");
		check(!FieldType.of(RuntimeType.DOUBLE).accepts(1), "int is not a double on Java");
		check(!FieldType.of(RuntimeType.BOOL).accepts(1), "int is not a bool");
		check(!FieldType.arrayOf(integer).accepts(new int[] { 1 }), "Flow arrays use boxed elements");
		check(FieldType.arrayOf(FieldType.arrayOf(integer)).accepts(new Object[] { new Object[] { 1 }, new Object[] { 2, 3 } }), "nested array siblings");
		check(!FieldType.arrayOf(FieldType.arrayOf(integer)).accepts(new Object[] { new Object[] { 1 }, new Object[] { "x" } }), "later nested array mismatch");
		check(FieldType.refTo(FieldType.arrayOf(FieldType.refTo(integer))).accepts(new Reference<Object>(new Object[] { new Reference<Integer>(1), new Reference<Integer>(2) })), "mixed array and ref nesting");

		Object[] cycle = new Object[1];
		cycle[0] = cycle;
		check(FieldType.arrayOf(unknown).accepts(cycle), "unconstrained cyclic array");
		check(!FieldType.arrayOf(FieldType.arrayOf(integer)).accepts(cycle), "typed cyclic array mismatch");
		Reference<Object> refCycle = new Reference<Object>(null);
		refCycle.value = refCycle;
		check(FieldType.refTo(unknown).accepts(refCycle), "unconstrained cyclic ref");
		check(!FieldType.refTo(FieldType.refTo(integer)).accepts(refCycle), "typed cyclic ref mismatch");

		Object nested = 1;
		FieldType nestedType = integer;
		for (int i = 0; i < 100000; i++) {
			nested = new Object[] { nested };
			nestedType = FieldType.arrayOf(nestedType);
		}
		check(nestedType.accepts(nested), "100000 array levels without recursion");
		Object nestedRef = 1;
		FieldType nestedRefType = integer;
		for (int i = 0; i < 100000; i++) {
			nestedRef = new Reference<Object>(nestedRef);
			nestedRefType = FieldType.refTo(nestedRefType);
		}
		check(nestedRefType.accepts(nestedRef), "100000 ref levels without recursion");
		Object shared = 1;
		FieldType sharedType = integer;
		for (int i = 0; i < 40; i++) {
			shared = new Object[] { shared, shared };
			sharedType = FieldType.arrayOf(sharedType);
		}
		check(sharedType.accepts(shared), "shared graph is not traversed exponentially");
		Object[] large = new Object[1000000];
		Arrays.fill(large, 1);
		check(FieldType.arrayOf(integer).accepts(large), "large array");
		large[large.length - 1] = "x";
		check(!FieldType.arrayOf(integer).accepts(large), "last element is checked");

		TestStruct fallback = new TestStruct(new RuntimeType[0], null);
		TestStruct prototype = new TestStruct(new RuntimeType[] { RuntimeType.ARRAY }, new FieldType[] { FieldType.arrayOf(integer) });
		FlowRuntime.struct_prototypes = new Struct[] { prototype };
		FlowRuntime.struct_ids.put("Test", 0);
		Object[] fields = new Object[] { new Object[] { 1, 2 } };
		Struct result = FlowRuntime.makeStructValue("Test", fields, fallback);
		check(result != fallback && result != prototype, "success clones the prototype");
		check(result.getFields() == fields && prototype.getFields() == null, "prototype is unchanged");
		check(FlowRuntime.makeStructValue(0, new Object[] { new Object[] { "x" } }, fallback) == fallback, "invalid field gives default");
		check(FlowRuntime.makeStructValue(0, new Object[0], fallback) == fallback, "invalid arity gives default");
		check(FlowRuntime.makeStructValue(-1, fields, fallback) == fallback, "invalid id gives default");
		check(FlowRuntime.makeStructValue("Missing", fields, fallback) == fallback, "missing name gives default");
		FlowRuntime.struct_prototypes[0] = new TestStruct(new RuntimeType[] { RuntimeType.ARRAY }, null);
		check(FlowRuntime.makeStructValue(0, fields, fallback) != fallback, "legacy metadata accepts arrays");
		check(FlowRuntime.makeStructValue(0, new Object[] { 1 }, fallback) == fallback, "legacy metadata checks outer type");
		check(FlowRuntime.makeStructValue(0, new Object[] { new Object[] { "x" } }, fallback) != fallback, "legacy metadata cannot infer element types");
		System.out.println("Java field type harness passed " + checks + " checks");
	}
}
