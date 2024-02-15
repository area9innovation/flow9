package com.area9innovation.flow;

import java.util.concurrent.ConcurrentHashMap;
import java.util.Locale;

import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;

public abstract class FlowRuntime {
	public static Struct[] struct_prototypes;
	public static ConcurrentHashMap<String, Integer> struct_ids = new ConcurrentHashMap<String, Integer>();
	public static String[] program_args;
	private static ConcurrentHashMap<Class, NativeHost> hosts = new ConcurrentHashMap<Class, NativeHost>();

	private static final ThreadLocal<DecimalFormat> decimalFormat = new ThreadLocal<DecimalFormat>(){
        @Override
        protected DecimalFormat initialValue()
        {
			DecimalFormat df = new DecimalFormat("0.0");
			df.setDecimalFormatSymbols(new DecimalFormatSymbols(Locale.US));
			df.setMaximumFractionDigits(340); // DecimalFormat.DOUBLE_FRACTION_DIGITS
			return df;
        }
    };

	public synchronized void start() {
		main();
	}

	protected abstract void main();

	@SuppressWarnings("unchecked")
	protected static final <T extends NativeHost> T getNativeHost(Class<T> cls) {
		T host = (T)hosts.get(cls);
		if (host != null) {
			return host;
		} else {
			try {
				host = cls.getDeclaredConstructor().newInstance();
				if (!cls.isInstance(host)) {
					throw new RuntimeException("Invalid host: " + cls.getName() + " expected, " + host.getClass().getName() + " allocated");
				}
				hosts.put(cls, host);
				host.initialize();
				return host;
			} catch (ReflectiveOperationException e) {
				throw new RuntimeException("Could not instantiate native method host " + cls.getName(), e);
			}
		}
	}

	//@SuppressWarnings("unchecked")
	protected static final <T extends NativeHost> void registerNativeHost(Class<T> cls) {
		try {
			T host = cls.getDeclaredConstructor().newInstance();
			if (!cls.isInstance(host)) {
				throw new RuntimeException("Invalid host: " + cls.getName() + " expected, " + host.getClass().getName() + " allocated");
			}
			hosts.put(cls, host);
			host.initialize();
		} catch (ReflectiveOperationException e)  {
			throw new RuntimeException("Could not instantiate native method host " + cls.getName(), e);
		}
	}

	public static boolean compareEqual(Object a, Object b) {
		if (a == b) return true;
		// void values (null in java backend) may also be compared in the interpreter, so we check this case
		if (a == null || b == null) return false;
		if (a.getClass().isArray() && b.getClass().isArray()) {
			Object[] ao = (Object[])a;
			Object[] bo = (Object[])b;
			if (ao.length != bo.length) return false;
			for (int i = ao.length; i-- != 0;) {
				if (!compareEqual(ao[i], bo[i])) return false;
			}
			return true;
		}
		if (!a.getClass().equals(b.getClass())) return false;
		if (a instanceof Integer || a instanceof Boolean || a instanceof Double || a instanceof String) {
			return a.equals(b);
		}
		if (a instanceof Struct) {
			if (((Struct)a).getTypeId() != ((Struct)b).getTypeId()) return false;
			if (((Struct)a).compareTo(((Struct)b)) != 0) return false;

			return true;
		}
		if (a instanceof Reference) {
			return false;
		}
		return false;
	}
	@SuppressWarnings("unchecked")
	public static int compareByValue(Object o1, Object o2) {
		// Special cases for performance improvement.
		if ((o1 instanceof Integer) && (o2 instanceof Integer)) return ((Integer)o1).compareTo(((Integer)o2));
		if ((o1 instanceof Double)  && (o2 instanceof Double)) return Double.compare((Double)o1, (Double)o2);
		// TODO Use UTF-8 compare?
		if ((o1 instanceof String)  && (o2 instanceof String)) return ((String)o1).compareTo(((String)o2));
		if (o1 == o2)
			return 0;
		if (o1 == null)
			return -1;
		if (o2 == null)
			return 1;

		if (o1 instanceof Comparable) {
			if (!(o2 instanceof Comparable))
				return -1;

			if (o1 instanceof Struct) {
				if (!(o2 instanceof Struct))
					return 1;

				return ((Struct)o1).compareTo((Struct)o2);
			}
			else if (o2 instanceof Struct)
				return -1;

			if (o1.getClass() == o2.getClass())
				return ((Comparable)o1).compareTo(o2);

			RuntimeType t1 = RuntimeType.classify(o1);
			RuntimeType t2 = RuntimeType.classify(o2);

			if (t1 != RuntimeType.UNKNOWN && t2 != RuntimeType.UNKNOWN)
				return t1.compareTo(t2);

			return Integer.valueOf(o1.getClass().hashCode()).compareTo(o2.getClass().hashCode());
		}
		else if (o2 instanceof Comparable)
			return 1;

		if (o1 instanceof Object[]) {
			if (!(o2 instanceof Object[]))
				return 1;

			Object[] arr1 = (Object[])o1;
			Object[] arr2 = (Object[])o2;
			int l1 = arr1.length;
			int l2 = arr2.length;
			int l =  l1 < l2 ? l1 : l2;
			for (int i = 0; i < l; i++) {
				int c = compareByValue(arr1[i], arr2[i]);
				if (c != 0) return c;
			}

			return (l1 == l2) ? 0 : (l1 < l2 ? -1 : 1);
		}
		else if (o2 instanceof Object[])
			return -1;

		if (o1.equals(o2))
			return 0;

		return Integer.valueOf(o1.hashCode()).compareTo(o2.hashCode());
	}

	public static String toString(Object value) {
		if (value == null) {
			return "{}";
		} else if (value instanceof Function) {
			return "<function " + value + ">";
		} else if (value instanceof Double) {
			return doubleToStringInternal((Double)value);
		}

		StringBuilder buf = new StringBuilder();
		toStringAppend(value, buf);
		return buf.toString();
	}

	public static void toStringAppend(Object value, StringBuilder buf) {
		if (value == null) {
			buf.append("{}");
		} else if (value instanceof String) {
			String sv = (String)value;

			buf.append('"');
			for (int i = 0; i < sv.length(); i++) {
				char c = sv.charAt(i);

				switch (c) {
					case '\t':
						buf.append("\\t");
						break;
					case '\r':
						buf.append("\\u000d");
						break;
					case '\n':
						buf.append("\\n");
						break;
					case '\\':
					case '"':
						buf.append('\\');
						buf.append(c);
						break;
					default:
						buf.append(c);
				}

			}
			buf.append('"');
		} else if (value instanceof Object[]) {
			Object[] arr = (Object[])value;

			buf.append("[");
			for (int i = 0; i < arr.length; i++) {
				if (i > 0)
					buf.append(", ");
				toStringAppend(arr[i], buf);
			}
			buf.append("]");
		} else if (value instanceof Function) {
			buf.append("<function " + value + ">");
		} else if (value instanceof Double) {
			buf.append(doubleToStringInternal((Double)value));
		} else if (value instanceof Struct) {
			((Struct)value).toStringAppend(buf);
		} else {
			buf.append(value.toString());
		}
	}

	private static String doubleToStringInternal(double value) {
		return decimalFormat.get().format(value);
	}

	public static String doubleToString(double value) {
		String rstr = doubleToStringInternal(value);
		return rstr.endsWith(".0") ? rstr.substring(0, rstr.length()-2) : rstr;
	}

	public static final Struct makeStructValue(String name, Object[] fields, Struct default_value) {
		Integer id = struct_ids.get(name);
		if (id == null)
			return default_value;

		return makeStructValue(id, fields, default_value);
	}

	public static final Struct makeStructValue(int id, Object[] fields, Struct default_value) {
		try {
			Struct copy = struct_prototypes[id].clone();
			copy.setFields(fields);
			return copy;
		} catch (Exception e) {
			return default_value;
		}
	}

	public static boolean isArray(Object value) {
		return value != null && value instanceof Object[];
	}

	public static Number negate(Object o1) {
		if (o1 instanceof Double)
			return Double.valueOf(-((Number)o1).doubleValue());
		return Integer.valueOf(-((Number)o1).intValue());
	}
	public static Object add(Object o1, Object o2) {
		if (o1 instanceof String || o2 instanceof String)
			return o1.toString() + o2.toString();
		if (o1 instanceof Double || o2 instanceof Double)
			return Double.valueOf(((Number)o1).doubleValue() + ((Number)o2).doubleValue());
		return Integer.valueOf(((Number)o1).intValue() + ((Number)o2).intValue());
	}
	public static Number sub(Object o1, Object o2) {
		if (o1 instanceof Double || o2 instanceof Double)
			return Double.valueOf(((Number)o1).doubleValue() - ((Number)o2).doubleValue());
		return Integer.valueOf(((Number)o1).intValue() - ((Number)o2).intValue());
	}
	public static Number mul(Object o1, Object o2) {
		if (o1 instanceof Double || o2 instanceof Double)
			return Double.valueOf(((Number)o1).doubleValue() * ((Number)o2).doubleValue());
		return Integer.valueOf(((Number)o1).intValue() * ((Number)o2).intValue());
	}
	public static Number div(Object o1, Object o2) {
		if (o1 instanceof Double || o2 instanceof Double)
			return Double.valueOf(((Number)o1).doubleValue() / ((Number)o2).doubleValue());
		return Integer.valueOf(((Number)o1).intValue() / ((Number)o2).intValue());
	}
	public static Number mod(Object o1, Object o2) {
		if (o1 instanceof Double || o2 instanceof Double)
			return Double.valueOf(((Number)o1).doubleValue() % ((Number)o2).doubleValue());
		return Integer.valueOf(((Number)o1).intValue() % ((Number)o2).intValue());
	}
}
