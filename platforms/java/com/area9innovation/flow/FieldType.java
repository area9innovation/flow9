package com.area9innovation.flow;

import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.IdentityHashMap;

// Unlike RuntimeType, this metadata retains array elements, reference payloads and
// the struct or union a field names. Type parameters, flow and other unconstrained
// fields use UNKNOWN.
public final class FieldType {
	private final RuntimeType type;
	private final FieldType element;
	// STRUCT only: the struct or union the field names, or null for any struct.
	private final String name;
	// A typed array or ref, whose contents must be checked too.
	private final boolean open;
	// Type ids that name allows, resolved on first use.
	private volatile int[] allowed;

	private static final int[] ANY_STRUCT = new int[0];
	private static final FieldType[] SHALLOW = new FieldType[RuntimeType.values().length];
	static {
		for (RuntimeType t : RuntimeType.values()) SHALLOW[t.ordinal()] = new FieldType(t, null, null);
	}

	// Rechecking a shared leaf array shorter than this is cheaper than remembering it.
	private static final int MEMO_MIN_LENGTH = 32;

	private FieldType(RuntimeType type, FieldType element, String name) {
		this.type = type;
		this.element = element;
		this.name = name;
		this.open = element != null && element.type != RuntimeType.UNKNOWN;
	}

	public static FieldType of(RuntimeType type) {
		return SHALLOW[type.ordinal()];
	}

	public static FieldType arrayOf(FieldType element) {
		return new FieldType(RuntimeType.ARRAY, element, null);
	}

	public static FieldType refTo(FieldType element) {
		return new FieldType(RuntimeType.REF, element, null);
	}

	// A struct, or any member of a union, by its flow name.
	public static FieldType named(String name) {
		return new FieldType(RuntimeType.STRUCT, null, name);
	}

	private static final class ArrayCheck {
		final Object[] values;
		final FieldType element;
		int index;

		ArrayCheck(Object[] values, FieldType element) {
			this.values = values;
			this.element = element;
			this.index = 1;
		}
	}

	public boolean accepts(Object value) {
		if (!matches(value)) return false;
		if (!open) return true;
		if (!element.open) return contentsMatch(value);
		return acceptsNested(value);
	}

	// The value's own shape, without its contents.
	private boolean matches(Object value) {
		switch (type) {
			case UNKNOWN: return true;
			case VOID: return value == null;
			case BOOL: return value instanceof Boolean;
			case INT: return value instanceof Integer;
			case DOUBLE: return value instanceof Double;
			case STRING: return value instanceof String;
			case STRUCT: return value instanceof Struct && isAllowed((Struct)value);
			case ARRAY: return value instanceof Object[];
			case REF: return value instanceof Reference;
			default: return false;
		}
	}

	// For an open type whose element is not open: one pass, no allocation.
	private boolean contentsMatch(Object value) {
		return type == RuntimeType.REF ? element.matches(((Reference<?>)value).value) : element.matchesAll((Object[])value);
	}

	private boolean matchesAll(Object[] values) {
		switch (type) {
			case UNKNOWN: return true;
			case BOOL: for (Object v : values) if (!(v instanceof Boolean)) return false; return true;
			case INT: for (Object v : values) if (!(v instanceof Integer)) return false; return true;
			case DOUBLE: for (Object v : values) if (!(v instanceof Double)) return false; return true;
			case STRING: for (Object v : values) if (!(v instanceof String)) return false; return true;
			default: for (Object v : values) if (!matches(v)) return false; return true;
		}
	}

	private boolean isAllowed(Struct value) {
		if (name == null) return true;
		int[] ids = allowed;
		if (ids == null) {
			ids = resolve(name);
			if (FlowRuntime.struct_prototypes != null) allowed = ids;
		}
		if (ids == ANY_STRUCT) return true;
		int id = value.getTypeId();
		return ids.length == 1 ? ids[0] == id : Arrays.binarySearch(ids, id) >= 0;
	}

	// A name the runtime does not know accepts any struct, as the generated casts do.
	private static int[] resolve(String name) {
		Struct[] prototypes = FlowRuntime.struct_prototypes;
		if (prototypes == null) return ANY_STRUCT;
		String[] members = FlowRuntime.union_members.get(name);
		if (members == null) members = new String[] { name };
		int[] ids = new int[members.length];
		int count = 0;
		for (String member : members) {
			Integer index = FlowRuntime.struct_ids.get(member);
			if (index != null && index < prototypes.length) ids[count++] = prototypes[index].getTypeId();
		}
		if (count == 0) return ANY_STRUCT;
		ids = Arrays.copyOf(ids, count);
		Arrays.sort(ids);
		return ids;
	}

	// Every descent goes one level down the type, so the walk ends even on cyclic
	// values. Containers of containers are remembered, so shared values are not
	// walked exponentially; leaf arrays only when long.
	private boolean acceptsNested(Object root) {
		ArrayDeque<ArrayCheck> arrays = new ArrayDeque<ArrayCheck>();
		IdentityHashMap<Object, Object> visited = new IdentityHashMap<Object, Object>();
		FieldType expected = this;
		Object value = root;
		while (true) {
			if (!expected.matches(value)) return false;
			if (expected.open && !(expected.remembers(value) && seen(visited, value, expected))) {
				if (!expected.element.open) {
					if (!expected.contentsMatch(value)) return false;
				} else if (expected.type == RuntimeType.REF) {
					expected = expected.element;
					value = ((Reference<?>)value).value;
					continue;
				} else {
					Object[] values = (Object[])value;
					if (values.length > 0) {
						arrays.push(new ArrayCheck(values, expected.element));
						expected = expected.element;
						value = values[0];
						continue;
					}
				}
			}
			while (!arrays.isEmpty() && arrays.peek().index == arrays.peek().values.length) arrays.pop();
			if (arrays.isEmpty()) return true;
			ArrayCheck next = arrays.peek();
			expected = next.element;
			value = next.values[next.index++];
		}
	}

	private boolean remembers(Object value) {
		return element.open || (type == RuntimeType.ARRAY && ((Object[])value).length >= MEMO_MIN_LENGTH);
	}

	// One entry per container: the type it was checked against, or a set of them in
	// the rare case of one container checked against several types.
	@SuppressWarnings("unchecked")
	private static boolean seen(IdentityHashMap<Object, Object> visited, Object value, FieldType type) {
		Object previous = visited.putIfAbsent(value, type);
		if (previous == null) return false;
		if (previous == type) return true;
		if (previous instanceof FieldType) {
			IdentityHashMap<FieldType, Boolean> types = new IdentityHashMap<FieldType, Boolean>();
			types.put((FieldType)previous, Boolean.TRUE);
			types.put(type, Boolean.TRUE);
			visited.put(value, types);
			return false;
		}
		return ((IdentityHashMap<FieldType, Boolean>)previous).put(type, Boolean.TRUE) != null;
	}
}
