package com.area9innovation.flow;

public abstract class Struct implements Comparable<Struct>, Cloneable {
	public abstract int getTypeId();
	public abstract String getTypeName();
	public abstract String[] getFieldNames();
	public abstract RuntimeType[] getFieldTypes();
	public abstract Object[] getFields();
	public abstract void setFields(Object[] val);

	public Struct clone() {
		try {
			return (Struct)super.clone();
		} catch (CloneNotSupportedException e) {
			throw new RuntimeException(e);
		}
	}

	public abstract int compareTo(Struct b);

	public String toString() {
		StringBuilder buf = new StringBuilder();

		buf.append(getTypeName());
		buf.append('(');

		RuntimeType[] types = getFieldTypes();
		Object[] values = getFields();

		for (int i = 0; i < values.length; i++) {
			if (i > 0)
				buf.append(", ");

			if (types[i] == RuntimeType.DOUBLE && values[i] instanceof Number)
				buf.append(((Number)values[i]).doubleValue());
			else
				buf.append(FlowRuntime.toString(values[i]));
		}

		buf.append(')');

		return buf.toString();
	}
}
