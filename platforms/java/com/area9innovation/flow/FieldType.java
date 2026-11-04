package com.area9innovation.flow;

import java.util.ArrayDeque;
import java.util.IdentityHashMap;

// Unlike RuntimeType, this metadata retains array elements and reference payloads.
// Type parameters, flow and other unconstrained fields use UNKNOWN.
public final class FieldType {
	private final RuntimeType type;
	private final FieldType element;

	private FieldType(RuntimeType type, FieldType element) {
		this.type = type;
		this.element = element;
	}

	public static FieldType of(RuntimeType type) {
		return new FieldType(type, null);
	}

	public static FieldType arrayOf(FieldType element) {
		return new FieldType(RuntimeType.ARRAY, element);
	}

	public static FieldType refTo(FieldType element) {
		return new FieldType(RuntimeType.REF, element);
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

	private static boolean seen(IdentityHashMap<Object, IdentityHashMap<FieldType, Boolean>> visited, Object value, FieldType type) {
		IdentityHashMap<FieldType, Boolean> types = visited.get(value);
		if (types == null) {
			types = new IdentityHashMap<FieldType, Boolean>();
			visited.put(value, types);
		}
		return types.put(type, Boolean.TRUE) != null;
	}

	// Keep one cursor per open array, not one task per element. Remember each
	// (container, expected type) pair so shared values are checked only once.
	// Structs are deliberately opaque: named membership still uses generated casts.
	public boolean accepts(Object value) {
		FieldType expected = this;
		ArrayDeque<ArrayCheck> arrays = new ArrayDeque<ArrayCheck>();
		IdentityHashMap<Object, IdentityHashMap<FieldType, Boolean>> visited = new IdentityHashMap<Object, IdentityHashMap<FieldType, Boolean>>();
		while (true) {
			switch (expected.type) {
				case UNKNOWN: break;
				case VOID: if (value != null) return false; break;
				case BOOL: if (!(value instanceof Boolean)) return false; break;
				case INT: if (!(value instanceof Integer)) return false; break;
				case DOUBLE: if (!(value instanceof Double)) return false; break;
				case STRING: if (!(value instanceof String)) return false; break;
				case STRUCT: if (!(value instanceof Struct)) return false; break;
				case ARRAY: {
					if (!(value instanceof Object[])) return false;
					Object[] values = (Object[])value;
					if (expected.element != null && expected.element.type != RuntimeType.UNKNOWN && values.length > 0 && !seen(visited, value, expected)) {
						arrays.push(new ArrayCheck(values, expected.element));
						expected = expected.element;
						value = values[0];
						continue;
					}
					break;
				}
				case REF:
					if (!(value instanceof Reference)) return false;
					if (expected.element != null && expected.element.type != RuntimeType.UNKNOWN && !seen(visited, value, expected)) {
						expected = expected.element;
						value = ((Reference<?>)value).value;
						continue;
					}
					break;
			}
			while (!arrays.isEmpty() && arrays.peek().index == arrays.peek().values.length) arrays.pop();
			if (arrays.isEmpty()) return true;
			ArrayCheck next = arrays.peek();
			expected = next.element;
			value = next.values[next.index++];
		}
	}
}
