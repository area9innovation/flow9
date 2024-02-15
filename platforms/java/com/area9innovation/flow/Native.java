package com.area9innovation.flow;

import java.util.*;
import java.io.Writer;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.BufferedWriter;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.InvalidPathException;
import java.awt.datatransfer.DataFlavor;
import java.awt.Toolkit;
import java.awt.datatransfer.StringSelection;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.UnsupportedFlavorException;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.CharsetDecoder;
import java.io.FileInputStream;
import java.io.File;
import java.nio.charset.CodingErrorAction;
import java.net.URLDecoder;
import java.io.PrintStream;
import java.io.UnsupportedEncodingException;
import java.nio.charset.CharsetEncoder;
import java.nio.file.StandardOpenOption;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.function.Function;
import java.lang.Runtime;
import java.lang.ClassCastException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.io.OutputStream;
import java.io.InputStream;
import java.math.BigInteger;
import java.security.*;
import java.time.format.DateTimeFormatter;
import java.time.LocalDateTime;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.concurrent.ConcurrentHashMap;
import com.sun.management.OperatingSystemMXBean;
import java.time.format.FormatStyle;
import java.time.ZonedDateTime;

public class Native extends NativeHost {
	private static final int NTHREDS = 16;
	private static MessageDigest md5original = null;
	private static ExecutorService threadpool = Executors.newFixedThreadPool(NTHREDS);
	private static OperatingSystemMXBean osBean = java.lang.management.ManagementFactory.getPlatformMXBean(OperatingSystemMXBean.class);

	public Native() {
		try {
			md5original = MessageDigest.getInstance("MD5");
		} catch (NoSuchAlgorithmException e) {
			md5original = null;
		}
	}

	public void initialize() {
		Integer emptyList_id = FlowRuntime.struct_ids.get("EmptyList");
		if (emptyList_id != null) {
			emptyList = FlowRuntime.struct_prototypes[emptyList_id];
		}
	}

	public static final Object println(Object arg) {
		String s = "";
		if (arg instanceof String) {
			s = arg.toString();
		} else {
			s = FlowRuntime.toString(arg);
		}

		try {
			synchronized (System.out) {
				PrintStream out = new PrintStream(System.out, true, "UTF-8");
				out.println(s);
			}
		} catch(UnsupportedEncodingException e) {
		}
		return null;
	}

	public static final Object failWithError(String msg) {
		try {
			PrintStream out = new PrintStream(System.out, true, "UTF-8");
			out.println("Runtime failure: " + msg);
			Thread.dumpStack();
		} catch(UnsupportedEncodingException e) {
		}
		System.exit(255);
		return null;
	}

	public static final Object hostAddCallback(String name, Func0<Object> cb) {
		return null;
	}

	public static final Object setClipboard(String text) {
		StringSelection selection = new StringSelection(text);
		Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
		clipboard.setContents(selection, selection);

		return null;
	}

	public static final Object setCurrentDirectory(String path) {
		return null;
	}

	public static final String getCurrentDirectory() {
		return Paths.get(".").toAbsolutePath().normalize().toString();
	}

	public static final String getClipboard() {
		try {
			Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
			String data = (String) clipboard.getData(DataFlavor.stringFlavor);
			return data;
		} catch (UnsupportedFlavorException e) {
			return "";
		} catch (IOException e) {
			return "";
		}
	}

	public static final Object getClipboardToCB(Func1<Object, String> cb) {
		try {
			Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
			String data = (String) clipboard.getData(DataFlavor.stringFlavor);
			cb.invoke(data);
			return null;
		} catch (UnsupportedFlavorException e) {
			return null;
		} catch (IOException e) {
			return null;
		}
	}

	public static final String getClipboardFormat(String mimetype) {
		return "";
	}

	public static final String getApplicationPath() {
		File currentJavaJarFile = new File(Native.class.getProtectionDomain().getCodeSource().getLocation().getPath());
		String currentJavaJarFilePath = currentJavaJarFile.getAbsolutePath();
		return currentJavaJarFilePath;
	}

	public static final String toString(Object value) {
		return FlowRuntime.toString(value);
	}

	public static final String toBinary(Object value) {
		Map<Integer, Integer> structIdxs = new HashMap<Integer, Integer>();
		List<Struct> structDefs = new ArrayList<Struct>();

		StringBuilder buf = new StringBuilder();
		writeBinaryValue(value, buf, structIdxs, structDefs);
		StringBuilder buf2 = new StringBuilder();
		writeBinaryInt32(buf.length() + 2, buf2);

		if (structDefs.size() == 0) {
			writeCharValue(0xFFF7, buf);
		} else {
			if (structDefs.size() > 65535) {
				writeCharValue(0xFFF9, buf);
				writeBinaryInt32(structDefs.size(), buf);
			} else {
				writeCharValue(0xFFF8, buf);
				writeCharValue(structDefs.size(), buf);
			}
		}
		for (Struct struct_def : structDefs) {
			writeCharValue(0xFFF8, buf); writeCharValue(0x0002, buf);
			writeCharValue(struct_def.getFields().length, buf);

			String s = struct_def.getTypeName();
			int str_len = s.length();
			writeCharValue(0xFFFA, buf);
			writeCharValue(str_len, buf);
			for (int i = 0; i < str_len; i++) {
				char v = s.charAt(i);
				writeCharValue(v, buf);
			}
		}
		return buf2.toString() + buf.toString();
	}

	final static void writeCharValue(int c, StringBuilder buf) {
		buf.append(Character.toChars(c & 0xffff));
	}

	final static void writeBinaryInt32(int i, StringBuilder buf) {
		short low = (short) (i & 0xffff);
		short high = (short) (i >> 16);
		writeCharValue(low, buf);
		writeCharValue(high, buf);
	}

	final static void writeBinaryValue(Object value, StringBuilder buf, Map<Integer, Integer> structIdxs, List<Struct> structDefs) {
		if (value == null) {
			writeCharValue(0xffff, buf);
		} else if (value instanceof String) {
			String s = (String) value;
			int str_len = s.length();
			if (str_len > 65535) {
				writeCharValue(0xFFFB, buf);
				writeBinaryInt32(str_len, buf);
			} else {
				writeCharValue(0xFFFA, buf);
				writeCharValue(str_len, buf);
			}
			for (int i = 0; i < str_len; i++) {
				char v = s.charAt(i);
				writeCharValue(v, buf);
			}
		} else if (value instanceof Object[]) {
			Object[] arr = (Object[])value;
			int l = arr.length;
			if (l == 0) {
				writeCharValue(0xFFF7, buf);
			} else {
				if (l > 65535) {
					writeCharValue(0xFFF9, buf);
					writeBinaryInt32(l, buf);
				} else {
					writeCharValue(0xFFF8, buf);
					writeCharValue(l, buf);
				}
				for (int i = 0; i < arr.length; i++) {
					writeBinaryValue(arr[i], buf, structIdxs, structDefs);
				}
			}
		} else if (value instanceof Function) {
			System.out.println("Not implemented: toBinary of " + value);
		} else if (value instanceof Double) {
			writeCharValue(0xFFFC, buf);

			java.nio.ByteBuffer bb = java.nio.ByteBuffer.allocate(8).order(java.nio.ByteOrder.LITTLE_ENDIAN);
			bb.putDouble((Double)value);
			for (int i = 0; i < 8; i += 2) {
				writeCharValue(bb.getShort(i), buf);
			}
		} else if (value instanceof Integer) {
			Integer int_value = (Integer) value;
			if ((int_value & 0xFFFF8000) != 0) {
				writeCharValue(0xFFF5, buf);
				writeBinaryInt32(int_value, buf);
			} else {
				writeCharValue(int_value, buf);
			}
		} else if (value instanceof Boolean) {
			Boolean b = (Boolean) value;
			writeCharValue(b ? 0xFFFE : 0xFFFD, buf);
		} else if (value instanceof Struct) {
			Struct s = (Struct) value;
			int struct_id = s.getTypeId();

			Object[] struct_fields = s.getFields();
			RuntimeType[] field_types = s.getFieldTypes();
			int fields_count = struct_fields.length;

			int struct_idx = 0;
			if (structIdxs.containsKey(struct_id)) {
				struct_idx = structIdxs.get(struct_id);
			} else {
				struct_idx = structDefs.size();
				structIdxs.put(struct_id, struct_idx);
				structDefs.add(s);
			}

			writeCharValue(0xFFF4, buf);
			writeCharValue(struct_idx, buf);

			for (int i=0; i < fields_count; ++i)  {
				writeBinaryValue(struct_fields[i], buf, structIdxs, structDefs);
			}
		} else {
			System.out.println("Not implemented: toBinary of " + value);
		}
	}

	public static final double stringbytes2double(String s) {
		int l = java.lang.Math.min(s.length(), 4);
		java.nio.ByteBuffer bb = java.nio.ByteBuffer.allocate(8);
		for (int i = 0; i < l; i++) {
			char v = s.charAt(i);
			byte b0 = (byte) (v & 0xff);
			byte b1 = (byte) (v >>> 8);
			bb.put(2*i, b0);
			bb.put(2*i + 1, b1);
		}
		return bb.order(java.nio.ByteOrder.LITTLE_ENDIAN).getDouble(0);
	}

	public static final int stringbytes2int(String s) {
		int l = java.lang.Math.min(s.length(), 2);
		java.nio.ByteBuffer bb = java.nio.ByteBuffer.allocate(4);
		for (int i = 0; i < l; i++) {
			char v = s.charAt(i);
			byte b0 = (byte) (v & 0xff);
			byte b1 = (byte) (v >> 8);
			bb.put(2*i, b0);
			bb.put(2*i + 1, b1);
		}
		return bb.order(java.nio.ByteOrder.LITTLE_ENDIAN).getInt(0);
	}

	public static final String fromBinary(String s, Object defvalue, Object fixups) {
		return s;
	}

	public static final Object gc() {
		System.gc();
		return null;
	}

	public static final Object addHttpHeader(String data) {
		return null;
	}

	public static final String getCgiParameter(String name) {
		return "";
	}

	public static final Object[] subrange(Object[] arr, int start, int len) {
		// Make sure we are within bounds
		if (start < 0 || len < 1 || start >= arr.length) return new Object[0];
		len = clipLenToRange(start, len, arr.length);
		return Arrays.copyOfRange(arr, start, start + len);
	}

	private static final int clipLenToRange(int start, int len, int size) {
		int end = start + len;
		if (end > size || end  < 0) {
			len = size - start;
		}
		return len;
	}

	public static final boolean isArray(Object obj) {
		return FlowRuntime.isArray(obj);
	}

	public static final boolean isSameStructType(Object a, Object b) {
		return a != null && b != null &&
			   a instanceof Struct && b instanceof Struct &&
			   ((Struct)a).getTypeId() == ((Struct)b).getTypeId();
	}

	public static final boolean isSameObj(Object a, Object b) {
		if (a == b)
			return true;
		if (a instanceof Number || a instanceof String)
			return b != null && a.getClass() == b.getClass() && a.equals(b);
		return false;
	}

	public static final int length(Object[] arr) {
		return arr.length;
	}

	public static final int strlen(String str) {
		return str.length();
	}

	public static final int strIndexOf(String str, String substr) {
		return str.indexOf(substr);
	}

	public static final String strReplace(String s, String old, String _new) {
		return s.replace(old, _new);
	}

	public static final int strRangeIndexOf(String str, String substr, Integer start, Integer end) {
		if (str == "" || start < 0)
			return -1;
		end = (end > str.length() || end < 0) ? str.length() : end;

		if (end >= str.length())
			return str.indexOf(substr, start);

		end -= substr.length() - 1;
		// TODO: possibly way to speedup this is to eliminate cycle
		for (int i = start; i < end; i++)
			if (str.startsWith(substr, i))
				return i;
		return -1;
	}

	public static final boolean strContainsAt(String str, Integer index, String substr) {
		return str.regionMatches(index, substr, 0, substr.length());
	}

	public static final String substring(String str, int start, int len) {
		int strlen = str.length();
		if (len < 0) {
			if (start < 0) len = 0;
			else {
				int smartLen1 = len + start;
				if (smartLen1 >= 0) len = 0;
				else {
					int smartLen2 = smartLen1 + strlen;
					if (smartLen2 <= 0) len = 0;
					else len = smartLen2;
				}
			}
		}
		if (start < 0) {
			int smartStart = start + strlen;
			if (smartStart > 0) start = smartStart;
			else start = 0;
		} else if (start >= strlen) {
			len = 0;
		}

		if (len < 1) return "";

		len = clipLenToRange(start, len, strlen);

		return str.substring(start, start + len);
	}

	public static final String toLowerCase(String str) {
		return str.toLowerCase();
	}

	public static final String toUpperCase(String str) {
		return str.toUpperCase();
	}

	public static final Object[] string2utf8(String str) {
		ArrayList<Integer> bytesList = new ArrayList<Integer>();
		// We know we need at least this
		bytesList.ensureCapacity(str.length());

		for(int i = 0; i < str.length(); i++) {
			int x = str.codePointAt(i);

			if (x <= 0x7F) {
			bytesList.add(x);
			} else if (x <= 0x7FF) {
			int b2 = x & 0x3F;
			int b1 = (x >> 6) & 0x3F;

			bytesList.add(0xC0 | b1);
			bytesList.add(0x80 | b2);
			} else if (x <= 0xFFFF) {
			int b3 = x & 0x3F;
			int b2 = (x >> 6) & 0x3F;
			int b1 = (x >> 12) & 0x3F;

			bytesList.add(0xE0 | b1);
			bytesList.add(0x80 | b2);
			bytesList.add(0x80 | b3);
			} else if (x <= 0x1FFFFF) {
			int b4 = x & 0x3F;
			int b3 = (x >> 6) & 0x3F;
			int b2 = (x >> 12) & 0x3F;
			int b1 = (x >> 18) & 0x3F;

			bytesList.add(0xF0 | b1);
			bytesList.add(0x80 | b2);
			bytesList.add(0x80 | b3);
			bytesList.add(0x80 | b4);
			// Surrogate pair
			++i;
			} else if (x <= 0x3FFFFFF) {
			int b5 = x & 0x3F;
			int b4 = (x >> 6) & 0x3F;
			int b3 = (x >> 12) & 0x3F;
			int b2 = (x >> 18) & 0x3F;
			int b1 = (x >> 24) & 0x3F;

			bytesList.add(0xF8 | b1);
			bytesList.add(0x80 | b2);
			bytesList.add(0x80 | b3);
			bytesList.add(0x80 | b4);
			bytesList.add(0x80 | b5);
			// Surrogate pair
			++i;
			} else {
			}
		}
		return bytesList.toArray();
	}

	private static final String utf82string(byte[] bytes) {
		StringBuilder str = new StringBuilder();
		Integer len = bytes.length;

		for(int i = 0; i<len; i++) {
			byte b1 = bytes[i];

			if ((b1 & 0xFC) == 0xF8 && i < len - 4) {
			byte b2 = bytes[i+1];
			byte b3 = bytes[i+2];
			byte b4 = bytes[i+3];
			byte b5 = bytes[i+4];
			i = i+4;

			int h1 = (b1 & 0x3) << 24;
			int h2 = (b2 & 0x3F) << 18;
			int h3 = (b3 & 0x3F) << 12;
			int h4 = (b4 & 0x3F) << 6;
			int h5 = 0x3F & b5;

			int h = h1 | h2 | h3 | h4 | h5;

			char[] cs = Character.toChars(h);

			// Surrogate pair
			str.append(cs[0]);
			str.append(cs[1]);
			} else if ((b1 & 0xF8) == 0xF0 && i < len - 3) {
			byte b2 = bytes[i+1];
			byte b3 = bytes[i+2];
			byte b4 = bytes[i+3];
			i = i+3;

			int h1 = (b1 & 0x7) << 18;

			int h2 = (b2 & 0x3F) << 12;
			int h3 = (b3 & 0x3F) << 6;
			int h4 = 0x3F & b4;

			int h = h1 | h2 | h3 | h4;

			char[] cs = Character.toChars(h);

			// Surrogate pair
			str.append(cs[0]);
			str.append(cs[1]);
			} else if ((b1 & 0xF0) == 0xE0 && i < len - 2) {
			byte b2 = bytes[i+1];
			byte b3 = bytes[i+2];
			i = i+2;

			int h1 = (b1 & 0xF) << 12;
			int h2 = (b2 & 0x3F) << 6;
			int h3 = 0x3F & b3;

			int h = h1 | h2 | h3;

			char[] cs = Character.toChars(h);

			str.append(cs[0]);
			} else if ((b1 & 0xE0) == 0xC0 && i < len - 1) {
			byte b2 = bytes[i+1];
			i = i+1;

			int h1 = (b1 & 0x1F) << 6;
			int h2 = 0x3F & b2;
			int h = h1 | h2;

			char[] cs = Character.toChars(h);

			str.append(cs[0]);
			} else {
			int h = b1 & 0xff;
			char[] cs = Character.toChars(h);

			str.append(cs[0]);
			}
		}

		return str.toString();
	}

	public static final Object[] s2a(String str) {
		int l = str.length();
		Object[] rv = new Object[l];
		for (int i = 0; i < l; i++)
			rv[i] = Integer.valueOf(str.charAt(i)&0xFFFF);
		return rv;
	}

	public static final String list2string(Struct list) {
		int len = 0;
		int cnt = 0;
		String rv = "";
		for (Struct cur = list;;) {
			Object[] data = cur.getFields();
			if (data.length == 0) break;

			rv = (String)data[0];
			len += rv.length();
			cnt++;
			cur = (Struct)data[1];
		}

		// It's worth to define this string buffer before ll array
		// to reserve a good block of memory when result string is longer than 300M
		// And that is why we use a string buffer instead of String.join("", ll)
		StringBuffer sb = new StringBuffer(len); // StringBuffer uses less memory than a StringBuilder
		String[] ll = new String[cnt];
		Struct cur = list;
		// Load data from Cons'es to array in direct order
		for (int i = cnt-1; i >= 0; i--) {
			Object[] data = cur.getFields();
			ll[i] = (String)data[0];
			cur = (Struct)data[1];
		}
		for (int i = 0; i < cnt; i++) {
			sb.append(ll[i]);
		}
		return sb.toString();
	}

	public static final Object headList(Struct list, Object _default) {
		Object[] data = list.getFields();
		if (data.length == 0) {
			return _default;
		} else {
			return data[0];
		}
	}

	public static Struct emptyList;

	public static final Struct tailList(Struct list) {
		Object[] data = list.getFields();
		if (data.length == 0) {
			return emptyList;
		} else {
			return (Struct)data[1];
		}
	}

	public static final Object[] list2array(Struct list) {
		int count = 0;
		for (Struct cur = list;;) {
			Object[] data = cur.getFields();
			if (data.length == 0)
				break;
			count++;
			cur = (Struct)data[1];
		}
		Object[] rv = new Object[count];
		for (Struct cur = list;;) {
			Object[] data = cur.getFields();
			if (data.length == 0)
				break;
			rv[--count] = data[0];
			cur = (Struct)data[1];
		}
		return rv;
	}

	public static final int genericCompare(Object o1, Object o2) {
		return FlowRuntime.compareByValue(o1, o2);
	}

	public static final int bitXor(int a, int b) {
		return a^b;
	}

	public static final int bitAnd(int a, int b) {
		return a&b;
	}

	public static final int bitOr(int a, int b) {
		return a|b;
	}

	public static final int bitNot(int a) {
		return ~a;
	}

	public static final int bitShl(int a, int n) {
		return a << n;
	}

	public static final int bitUshr(int a, int n) {
		return a >>> n;
	}

	public static final Object[] concat(Object[] a, Object[] b) {
		Object[] rv = Arrays.copyOf(a, a.length + b.length);
		System.arraycopy(b, 0, rv, a.length, b.length);
		return rv;
	}

	public static final Integer elemIndex(Object[] a, Object elem, Integer illegal) {
	if (elem == null) {
		for (Integer i = 0; i < a.length; i++)
			if (a[i] == null)
				return i;
		} else {
			for (Integer i = 0; i < a.length; i++)
				if (a[i] == elem || elem.equals(a[i]) || FlowRuntime.compareByValue(elem, a[i]) == 0)
				return i;
	}

	return illegal;
	}
	public static final Object[] replace(Object[] a, int i, Object v) {
		if (a == null || i < 0)
			return new Object[0];
		Object[] rv = Arrays.copyOf(a, a.length > i ? a.length : i+1);
		rv[i] = v;
		return rv;
	}

	@SuppressWarnings("unchecked")
	public static final <T1,T2> Object[] map(Object[] arr, Func1<T1,T2> clos) {
		Object[] rv = new Object[arr.length];
		for (int i = 0; i < arr.length; i++)
			rv[i] = clos.invoke((T2)arr[i]);
		return rv;
	}

	@SuppressWarnings("unchecked")
	public static final <T> Object iter(Object[] arr, Func1<Object,T> clos) {
		for (int i = 0; i < arr.length; i++)
			clos.invoke((T)arr[i]);
		return null;
	}

	@SuppressWarnings("unchecked")
	public static final <T1,T2> Object[] mapi(Object[] arr, Func2<T1,Integer,T2> clos) {
		Object[] rv = new Object[arr.length];
		for (int i = 0; i < arr.length; i++)
			rv[i] = clos.invoke(i, (T2)arr[i]);
		return rv;
	}

	@SuppressWarnings("unchecked")
	public static final <T> T for_(T v, Func1<Boolean,T> pred, Func1<T,T> fn) {
		for (; pred.invoke(v); v = fn.invoke(v));
		return v;
	}

	@SuppressWarnings("unchecked")
	public static final <T> Object iteri(Object[] arr, Func2<Object,Integer,T> clos) {
		for (int i = 0; i < arr.length; i++)
			clos.invoke(i, (T)arr[i]);
		return null;
	}

	@SuppressWarnings("unchecked")
	public static final <T> int iteriUntil(Object[] arr, Func2<Boolean,Integer,T> clos) {
		for (int i = 0; i < arr.length; i++)
			if (clos.invoke(i, (T)arr[i]))
				return i;
		return arr.length;
	}

	@SuppressWarnings("unchecked")
	public static final <T1,T2> T1 fold(Object[] arr, T1 init, Func2<T1,T1,T2> clos) {
		for (int i = 0; i < arr.length; i++)
			init = clos.invoke(init, (T2)arr[i]);
		return init;
	}

	@SuppressWarnings("unchecked")
	public static final <T1,T2> T1 foldi(Object[] arr, T1 init, Func3<T1,Integer,T1,T2> clos) {
		for (int i = 0; i < arr.length; i++)
			init = clos.invoke(i, init, (T2)arr[i]);
		return init;
	}

	@SuppressWarnings("unchecked")
	public static final <T> Object[] filter(Object[] arr, Func1<Boolean,T> test) {
		boolean[] tmp = new boolean[arr.length];
		int count = 0;
		for (int i = 0; i < arr.length; i++)
			if (tmp[i] = test.invoke((T)arr[i]))
				count++;
		Object[] out = new Object[count];
		for (int i = 0, j = 0; i < arr.length; i++)
			if (tmp[i])
				out[j++] = arr[i];
		return out;
	}

	private static int some_struct_id = -1;

	@SuppressWarnings("unchecked")
	public static final <T> Object[] filtermapi(Object[] arr, Func2<Struct,Integer,T> test) {
		if (some_struct_id == -1) {
			// Init a 'Some' struct id, if it's not setup yet.
			some_struct_id = FlowRuntime.struct_ids.get("Some");
		}
		Object[] tmp = new Object[arr.length];
		int count = 0;
		for (int i = 0; i < arr.length; i++) {
			Struct test_result = test.invoke(i, (T)arr[i]);
			if (test_result.getTypeId() == some_struct_id) {
				// 'Some' struct has only one field.
				tmp[i] = test_result.getFields()[0];
				count++;
			}
		}
		Object[] out = new Object[count];
		for (int i = 0, j = 0; i < arr.length; i++) {
			if (tmp[i] != null) {
				out[j++] = tmp[i];
			}
		}
		return out;
	}

	@SuppressWarnings("unchecked")
	public static final <T> Struct mapiM(Object[] arr, Func2<Struct,Integer,T> test) {
		if (some_struct_id == -1) {
			// Init a 'Some' struct id, if it's not setup yet.
			some_struct_id = FlowRuntime.struct_ids.get("Some");
		}
		Object[] res = new Object[arr.length];
		for (int i = 0; i < arr.length; i++) {
			Struct test_result = test.invoke(i, (T)arr[i]);
			if (test_result.getTypeId() == some_struct_id) {
				// 'Some' struct has only one field.
				res[i] = test_result.getFields()[0];
			} else {
				return test_result;
			}
		}
		return FlowRuntime.makeStructValue(some_struct_id, new Object[] { res }, null);
	}

	@SuppressWarnings("unchecked")
	public static final <T> boolean exists(Object[] arr, Func1<Boolean,T> test) {
		for (int i = 0; i < arr.length; i++)
			if (test.invoke((T)arr[i]))
				return true;
		return false;
	}

	public static final double random() {
		return Math.random();
	}

	public static final Func0<Double> randomGenerator(Integer seed) {
		return new Func0<Double>() {
			Random generator = new Random(seed);
			public Double invoke() {
				return generator.nextDouble();
			}
		};
	}

	private static void cancelTimer(Timer timer) {
		timer.cancel();
	}

	public static void invokeCallback(Runnable cb) {
		cb.run();
	}

	public static final Timer scheduleTimerTask(int ms, final Func0<Object> cb) {
		Timer timer = new Timer(true);
		TimerTask task = new TimerTask() {
			public void run() {
				invokeCallback(new Runnable() {
					public void run() {
						try {
							cb.invoke();
						} catch (Exception ex) {
							System.err.println(ex.getMessage());
							cancelTimer(timer);
							throw ex;
						}
					}
				});
			}
		};
		timer.schedule(task, ms);
		return timer;
	}

	public static final Object timer(int ms, final Func0<Object> cb) {
		scheduleTimerTask(ms, cb);
		return null;
	}

	public static final Object sustainableTimer(Integer ms, final Func0<Object> cb) {
		Timer timer = new Timer(false);
		TimerTask task = new TimerTask() {
			public void run() {
				invokeCallback(new Runnable() {
					public void run() {
						cb.invoke();
						timer.cancel();
					}
				});
			}
		};
		timer.schedule(task, ms);
		return null;
	}

	public static final Func0<Object> interruptibleTimer(int ms, final Func0<Object> cb) {
		Timer timer = scheduleTimerTask(ms, cb);

		return new Func0<Object>() {
			public Object invoke() {
				cancelTimer(timer);
				return null;
			}
		};
	}

	public static final double sin(double a) {
		return Math.sin(a);
	}

	public static final double asin(double a) {
		return Math.asin(a);
	}

	public static final double acos(double a) {
		return Math.acos(a);
	}

	public static final double atan(double a) {
		return Math.atan(a);
	}

	public static final double atan2(double a, double b) {
		return Math.atan2(a, b);
	}

	public static final double exp(double a) {
		return Math.exp(a);
	}

	public static final double log(double a) {
		return Math.log(a);
	}

	public static final <T> Object[] generate(int from, int to, Func1<T, Integer> fn) {
		int n = to - from;
		if (n <= 0)
			return new Object[0];
		Object[] rv = new Object[n];
		for (int i = 0; i < n; i++)
			rv[i] = fn.invoke(from + i);
		return rv;
	}

	public static final Object[] enumFromTo(int from, int to) {
		int n = to - from + 1;
		if (n <= 0)
			return new Object[0];
		Object[] rv = new Object[n];
		for (int i = 0; i < n; i++)
			rv[i] = from + i;
		return rv;
	}

	public static final double timestamp() {
		return System.currentTimeMillis();
	}

	public static final String getLocalTimezoneId() {
		return ZoneId.systemDefault().getId();
	}

	public static final String getTimezoneTimeString(double utcStamp, String timezoneId, String language) {
		long utcMillis = Double.valueOf(utcStamp).longValue();
		Instant instant = Instant.ofEpochMilli(utcMillis);

		if (timezoneId.equals("")) {
			timezoneId = "UTC";
		}

		ZoneId zoneId = ZoneId.of(timezoneId);
		ZonedDateTime date = ZonedDateTime.ofInstant(instant, zoneId);

		DateTimeFormatter dtf = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT, FormatStyle.LONG).withLocale(Locale.forLanguageTag(language));

		return date.format(dtf);
	}

	public static final double getTimezoneOffset(double utcStamp, String timezoneId) {
		if (timezoneId.equals("")) {
			return 0;
		}
		long utcMillis = Double.valueOf(utcStamp).longValue();
		TimeZone tz = TimeZone.getTimeZone(timezoneId);
		return tz.getOffset(new Date(utcMillis).getTime());
	}

	public static Object[][] getAllUrlParameters() {
		String[] args = FlowRuntime.program_args;

		Object[][] parameters = new Object[args.length][2];

		for (int i = 0; i < args.length; i++) {
			String p = args[i];

			int pos = p.indexOf("=");
			if (pos >= 0) {
				parameters[i][0] = p.substring(0, pos);
				parameters[i][1] = p.substring(pos + 1);
			} else {
				parameters[i][0] = p;
				parameters[i][1] = "";
			}
		}

		return parameters;
	}

	public static String getUrlParameter(String name) {
		String[] args = FlowRuntime.program_args;

		for (String p : args) {
			if (p.startsWith(name + "=")) {
				String arg = p.substring(name.length() + 1);
				return arg;
			}
		}

		return "";
	}

	public static boolean removeUrlParameter(String name) {
		String[] args = FlowRuntime.program_args;
		int index = 0;
		for (String p : args) {
			if (p.startsWith(name + "=")) {
				break;
			} else {
				++index;
			}
		}
		if (index == args.length) {
			return false;
		} else {
			FlowRuntime.program_args = new String[args.length - 1];
			for (int i = 0; i < args.length; ++ i) {
				if (i < index) {
					FlowRuntime.program_args[i] = args[i];
				} else if (index < i){
					FlowRuntime.program_args[i - 1] = args[i];
				}
			}
			return true;
		}
	}

	public static final String loaderUrl() {
		return "";
	}

	public static final String getTargetName() {
		String osName = System.getProperty("os.name").toLowerCase();
		int space_ind = osName.indexOf(" ");
		osName = osName.substring(0, space_ind == -1 ? osName.length() : space_ind);
		return  osName + ",java";
	}

	public static final boolean setKeyValue(String k, String v) {
		return false;
	}

	public static final String getKeyValue(String k, String def) {
		return def;
	}

	public static final Object removeKeyValue(String k) {
		return null;
	}

	public static final Object removeAllKeyValues() {
		return null;
	}

	public static final Object[] getKeysList() {
		return new Object[0];
	}

	public static final Object clearTrace() {
		return null;
	}

	public static final Object printCallstack() {
		Thread.dumpStack();
		return null;
	}

	public static final Object captureCallstack() {
		return Thread.currentThread().getStackTrace();
	}
	public static final String captureStringCallstack() {
		return callstack2string(captureCallstack());
	}
	public static final String callstack2string(Object obj) {
		if (obj instanceof StackTraceElement[]) {
			StackTraceElement[] stack = (StackTraceElement[])obj;
			StringBuilder sb = new StringBuilder();
			for (StackTraceElement el : stack) {
				sb.append(el.toString() + "\n");
			}
			return sb.toString();
		} else {
			return new String();
		}
	}
	public static final Object captureCallstackItem(int index) {
		return Thread.currentThread().getStackTrace()[index];
	}
	public static final Object impersonateCallstackItem(Object item, int index) {
		return null;
	}
	public static final Object impersonateCallstackFn(Object item, int index) {
		return null;
	}
	public static final Object impersonateCallstackNone(int index) {
		return null;
	}

	public static final Object makeStructValue(String name, Object[] args, Object defval) {
		return FlowRuntime.makeStructValue(name, args, (Struct)defval);
	}

	public static final Object[] extractStructArguments(Object val) {
		if (val instanceof Struct) {
			return ((Struct) val).getFields();
		} else return new Object[0];
	}

	public static final String extractStructName(Object val) {
		if (val instanceof Struct) {
			return ((Struct) val).getTypeName();
		} else return "";
	}

	public static final boolean isStructName(String name) {
		return FlowRuntime.struct_ids.containsKey(name);
	}

	public static final int extractFuncArity(Object x) {
		int arity = extractRealFuncArity(x);
		if (arity != -1) {
			return arity;
		} else if (x instanceof String) {
			String fn_name = (String)x;
			if (!host_call_funcs.containsKey(fn_name)) {
				// Guess the arity of function, thus pass -1 as arity.
				addHostCall(fn_name);
			}
			Object fn = host_call_funcs.get(fn_name);
			if (fn instanceof Integer) {
				// Integer type indicate absence of such function
				return -1;
			} else {
				return extractRealFuncArity(fn);
			}
		} else {
			// Not a function
			return -1;
		}
	}

	private static final int extractRealFuncArity(Object fn) {
		if (fn instanceof Func0) {
			return 0;
		} else if (fn instanceof Func1) {
			return 1;
		} else if (fn instanceof Func2) {
			return 2;
		} else if (fn instanceof Func3) {
			return 3;
		} else if (fn instanceof Func4) {
			return 4;
		} else if (fn instanceof Func5) {
			return 5;
		} else if (fn instanceof Func6) {
			return 6;
		} else if (fn instanceof Func7) {
			return 7;
		} else if (fn instanceof Func8) {
			return 8;
		} else if (fn instanceof Func9) {
			return 9;
		} else if (fn instanceof Func10) {
			return 10;
		} else if (fn instanceof Func11) {
			return 11;
		} else if (fn instanceof Func12) {
			return 12;
		} else {
			// TODO: add more arities
			return -1;
		}
	}

	public static final String[] structFieldNames(String name) {
		Integer struct_id = FlowRuntime.struct_ids.get(name);
		if (struct_id == null) {
			return new String[0];
		} else {
			Struct struct = FlowRuntime.struct_prototypes[struct_id];
			return struct.getFieldNames();
		}
	}

	private static ConcurrentHashMap<String, Method> field_setters = null;

	public static final Object setMutableField(Object obj, String field, Object value) {
		if (field_setters == null) {
			field_setters = new ConcurrentHashMap<String, Method>();
		}
		try {
			if (obj instanceof Struct) {
				Struct struct = (Struct)obj;
				String key = struct.getTypeName() + "-" + field;
				Method setter = null;
				if (!field_setters.contains(key)) {
					for (Method meth : struct.getClass().getMethods()) {
						if (meth.getName().equals("set_" + field)) {
							setter = meth;
							break;
						}
					}
					if (setter != null) {
						field_setters.put(key, setter);
					}
				} else {
					setter = field_setters.get(key);
				}
				if (setter != null) {
					setter.invoke(struct, value);
				} else {
					System.out.println("Failed to set a field " + field + " in struct " + struct.getTypeName());
				}
			}
		} catch (IllegalAccessException ex) {
			System.out.println(ex.getMessage());
			System.exit(255);
		} catch (InvocationTargetException ex) {
			System.out.println(ex.getMessage());
			System.exit(255);
		}
		return null;
	}

	// What is the type tag for this value?
	// 0: void, 1: bool, 2: int, 3: double, 4 : string, 5: array, 6: struct, 12: code pointer, 20: native function
	// 31: reference, 32: native value, 34: closure pointer, 48: captured frame
	public static final int getDataTagForValue(Object x) {
		if (x == null) {
			return 0;
		} else if (x instanceof Boolean) {
			return 1;
		} else if (x instanceof Integer) {
			return 2;
		} else if (x instanceof Double) {
			return 3;
		} else if (x instanceof String) {
			return 4;
		} else if (x.getClass().isArray()) {
			return 5;
		} else if (x instanceof Struct) {
			return 6;
		} else if (x instanceof Reference) {
			return 31;
		} else if (x.getClass().getName().contains("$$Lambda$")) {
			return 34;
		} else {
			return 32;
		}
	}

	public static final Object voidValue() {
		return null;
	}

	public static final Object quit(int c) {
		System.exit(c);
		return null;
	}

	public static final String fromCharCode(int codePoint) {
		return new String(Character.toChars(codePoint));
	}

	public static final int getCharCodeAt(String s, int i) {
		return (i>=0 && i < s.length()) ? (int)s.charAt(i) : -1;
	}

	public static final double number2double(Object n) {
		return ((Number)n).doubleValue();
	}

	public static final Struct getCurrentDate() {
		GregorianCalendar date = new GregorianCalendar();
		return FlowRuntime.makeStructValue(
				"Date",
				new Object[] {
					date.get(Calendar.YEAR),
					date.get(Calendar.MONTH) + 1,
					date.get(Calendar.DAY_OF_MONTH)
				},
				null
			);
	}

	// Monday is 0
	public static final int dayOfWeek(int year, int month, int day) {
		Calendar c = Calendar.getInstance();
		c.set(year, month - 1, day);
		return (c.get(Calendar.DAY_OF_WEEK) - (Calendar.SUNDAY + 1) + 7) % 7;
	}

	public static final double utc2local(double stamp) {
		final long millis = Double.valueOf(stamp).longValue();
		final int tzOffset = TimeZone.getDefault().getOffset(millis);
		return millis + tzOffset;
	}

	public static final double local2utc(double stamp) {
		final long millis = Double.valueOf(stamp).longValue();
		final int tzOffset = TimeZone.getDefault().getOffset(millis);
		return millis - tzOffset;
	}

	static private final DateTimeFormatter dateFormat = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

	public static final String time2string(double time) {
		long millis = Double.valueOf(time).longValue();
		return LocalDateTime.ofInstant(Instant.ofEpochMilli(millis), ZoneId.systemDefault()).format(dateFormat);
	}

	public static final double string2time(String tv) {
		try {
			return LocalDateTime.parse(tv, dateFormat).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
		} catch (DateTimeParseException  e) {
			System.err.println(e.toString());
			return 0;
		}
	}

	public static final String getUrl(String u, String t) {
		// TODO
		return "";
	}

	public static final String getFileContent(String name) {
		String result = "";
		try {
			byte[] bytes = Files.readAllBytes(Paths.get(name));
			result = utf82string(bytes);
		} catch (IOException e) {
		} catch (InvalidPathException e) {
		}
		return result;
	}

	public static final byte[] string2utf8Bytes(String data) {
		Object[] intsArray = string2utf8(data);
		byte[] bytesArray = new byte[intsArray.length];
		for(int i = 0; i < intsArray.length; i++) {
			Integer a =  (Integer)intsArray[i];
			// We know that 'a' is already a byte,
			// so instead of using expensive '.valueOf()'
			// use cheaper '% 256'.
			// int b = Integer.valueOf(a);
			int b = a % 256;
			byte c = (byte)b;

			bytesArray[i] = c;//(byte)(Integer.valueOf((Integer)bytes[i]));
		}
		return bytesArray;
	}

	public static final boolean setFileContent(String name, String data) {
		try {
			byte[] bytes = string2utf8Bytes(data);
			Files.write(Paths.get(name), bytes, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
		} catch (IOException ex) {
			return false;
		}
		return true;
	}

	public static final boolean setFileContentUTF16(String name, String data) {
		Writer writer = null;

		try {
			writer = new BufferedWriter(new OutputStreamWriter(
				new FileOutputStream(name), "UTF-16LE")
			);
			writer.write('\ufeff' + data);
		} catch (IOException ex) {
		} finally {
			try {
				writer.close();
				return true;
			} catch (Exception ex) {}
		}
		return false;
	}


	public static final String getFileContentBinary(String name) {
		try {
			byte[] bytes = Files.readAllBytes(Paths.get(name));
			return new String(bytes, StandardCharsets.ISO_8859_1);
		} catch (IOException e) {
			return "";
		}
	}

	public static final boolean setFileContentBytes(String name, String data) {
		Writer writer = null;

		try {
			writer = new BufferedWriter(new OutputStreamWriter(
				new FileOutputStream(name), StandardCharsets.ISO_8859_1)
			);
			char[] bytes = new char[data.length()];
			for (int i = 0; i < bytes.length; i++) {
				int cp =  Character.codePointAt(data, i);
				bytes[i] = (char)(cp % 256);
			}
			writer.write(bytes);
		} catch (IOException ex) {
		} finally {
			try {
				writer.close();
				return true;
			} catch (Exception ex) {}
		}
		return false;
	}

	public static final boolean setFileContentBinary(String name, String data) {
		Writer writer = null;

		try {
			writer = new BufferedWriter(new OutputStreamWriter(
				new FileOutputStream(name), StandardCharsets.ISO_8859_1)
			);
			char[] bytes = new char[data.length()];
			for (int i = 0; i < bytes.length; i++) {
				int cp =  Character.codePointAt(data, i / 2);
				bytes[i] = (char)((i%2 == 0) ? (cp % 256) : ((cp >> 8) % 256));
			}
			writer.write(bytes);
		} catch (IOException ex) {
		} finally {
			try {
				writer.close();
				return true;
			} catch (Exception ex) {}
		}
		return false;
	}

	public static final Object fast_max(Object aa, Object ab) {
		// Flow uses generic version of max(), which fallback
		// to compareByValue(). Add special cases for int and double.
		// Got ~1-2% of performance.
		if ((aa instanceof Double) && (ab instanceof Double)) {
			if ((Double) aa > (Double) ab) return aa; else return ab;
		} else if ((aa instanceof Integer) && (ab instanceof Integer)) {
			if ((Integer) aa > (Integer) ab) return aa; else return ab;
		} else if ((FlowRuntime.compareByValue(aa,ab)>0))
			return aa; else return ab;
	}

	private final static String exceptionStackTrace(Throwable ex) {
		StringWriter stackTrace = new StringWriter();
		ex.printStackTrace(new PrintWriter(stackTrace));
		return stackTrace.toString();
	}

	private static final class ProcessRunner implements Runnable {

		private final String[] cmd;
		private final String cwd;
		private final String stdin;
		private final Func3<Object, Integer, String, String> onExit;

		public ProcessRunner(String[] cmd, String cwd, String stdin, Func3<Object, Integer, String, String> onExit) {
			this.cmd = cmd;
			this.cwd = cwd;
			this.onExit = onExit;
			this.stdin = stdin;
		}

		private class StreamReader implements Runnable {
			String name;
			InputStream is;
			String contents;
			Thread thread;
			StreamReader errReader;

			public StreamReader(String name, InputStream is) {
				this.name = name;
				this.is = is;
				errReader = this;
				contents = new String();
				thread = new Thread(this);
				thread.start();
			}
			public StreamReader(String name, InputStream is, StreamReader errReader) {
				this.name = name;
				this.is = is;
				this.errReader = errReader;
				contents = new String();
				thread = new Thread(this);
				thread.start();
			}
			public void run() {
				try {
					InputStreamReader isr = new InputStreamReader(is);
					BufferedReader br = new BufferedReader(isr);
					while (!thread.isInterrupted()) {
						String s = br.readLine();
						if (s == null) break;
						contents += s + "\n";
					}
				} catch (Exception ex) {
					errReader.contents += exceptionStackTrace(ex) + "\n";
				}
			}
			public void close() {
				try {
					thread.join(250);
					is.close();
				} catch (Exception ex) {
					errReader.contents += exceptionStackTrace(ex) + "\n";
				}
			}
		}

		@Override
		public void run() {
			StreamReader stderr = null;
			StreamReader stdout = null;
			try {
				Process process = Runtime.getRuntime().exec(this.cmd, null, new File(this.cwd));
				stderr = new StreamReader("stderr", process.getErrorStream());
				stdout = new StreamReader("stdout", process.getInputStream(), stderr);

				process.getOutputStream().write(this.stdin.getBytes());
				process.getOutputStream().flush();

				// We wait for the process to finish before we collect the output!
				process.waitFor();

				stdout.close();
				stderr.close();
				onExit.invoke(process.exitValue(), stdout.contents, stderr.contents);
			} catch (Exception ex) {
				String cmd_str = "";
				for (String c : this.cmd) {
					cmd_str += c + " ";
				}
				String err_str = "";
				if (stderr != null) {
					err_str += stderr.contents + "\n";
				}
				err_str += "while executing:\n" + cmd_str + "\n";
				err_str += exceptionStackTrace(ex);
				onExit.invoke(-200, "", err_str);
			}
		}
	}

	public static final String md5(String contents) {
		MessageDigest messageDigest = null;
		byte[] digest = new byte[0];

		try {
			if (md5original != null) {
			messageDigest = (MessageDigest) md5original.clone();
			messageDigest.reset();
			messageDigest.update(contents.getBytes("UTF-8"));
			digest = messageDigest.digest();
			} else {
			return "";
			}
		} catch (CloneNotSupportedException e) {
			e.printStackTrace();
		} catch (Exception e) {
			e.printStackTrace();
		}

		BigInteger bigInt = new BigInteger(1, digest);
		String md5Hex = bigInt.toString(16);

		while( md5Hex.length() < 32 ){
			md5Hex = "0" + md5Hex;
		}

		return md5Hex;
	}

	public static String fileChecksum(String filename) {
		try {
			InputStream fis =  new FileInputStream(filename);
			byte[] buffer = new byte[1024];
			MessageDigest md = MessageDigest.getInstance("MD5");
			int numRead;
			do {
				numRead = fis.read(buffer);
				if (numRead > 0) {
					md.update(buffer, 0, numRead);
				}
			} while (numRead != -1);

			fis.close();

			byte[] digest = new byte[0];
			digest = md.digest();

			BigInteger bigInt = new BigInteger(1, digest);
			String md5Hex = bigInt.toString(16);

			while( md5Hex.length() < 32 ){
				md5Hex = "0" + md5Hex;
			}

			return md5Hex;
		} catch (IOException e) {
			return "";
		} catch (InvalidPathException e) {
			return "";
		} catch (Exception e) {
			e.printStackTrace();
			return "";
		}
	}

	// Launch a system process
	public static final Object startProcess(String command, Object[] args, String currentWorkingDirectory, String stdin,
					 Func3<Object, Integer, String, String> onExit) {

	try {
		String[] cmd = new String[args.length + 1];
		cmd[0] = command;
		for (int i = 0; i < args.length; i++) {
		cmd[i+1] = (String)args[i];
		}

		ProcessRunner ps = new ProcessRunner(cmd, currentWorkingDirectory, stdin, onExit);
		Future future = threadpool.submit(ps);
	} catch (Exception ex) {
		onExit.invoke(-200, "", "while starting:\n" + command + "\noccured:\n" + exceptionStackTrace(ex));
	}
	return null;
	}

	private static final class ProcessStarter implements Runnable {

		private final String[] cmd;
		private final String cwd;
		private final Func1<Object, String> onOut;
		private final Func1<Object, String> onErr;
		private final Func1<Object, Integer> onExit;
		private StreamReader stdout;
		private StreamReader stderr;
		private ExitHandler  exit;
		private Process process;
		private int exitCode = 0;

		public ProcessStarter(
			String[] cmd,
			String cwd,
			Func1<Object, String> onOut,
			Func1<Object, String> onErr,
			Func1<Object, Integer> onExit
		) {
			this.cmd = cmd;
			this.cwd = cwd;
			this.onOut = onOut;
			this.onErr = onErr;
			this.onExit = onExit;
		}

		private class StreamReader implements Runnable {
			String name;
			InputStream is;
			Thread thread;
			private final Func1<Object, String> callback;
			private final Func1<Object, String> onErr;

			public StreamReader(String name, InputStream is, Func1<Object, String> callback, Func1<Object, String> onErr) {
				this.name = name;
				this.is = is;
				this.callback = callback;
				this.onErr = onErr;
				thread = new Thread(this);
				thread.start();
			}
			public void run() {
				try {
					InputStreamReader isr = new InputStreamReader(is);
					BufferedReader br = new BufferedReader(isr);
					while (!thread.isInterrupted()) {
						String s = br.readLine();
						if (s == null) break;
						callback.invoke(s);
					}
				} catch (Exception ex) {
					onErr.invoke("Problem reading stream " + name + ":\n" + exceptionStackTrace(ex));
				}
			}
			public void close() {
				try {
					thread.join(250);
					is.close();
				} catch (Exception ex) {
					onErr.invoke("Problem closing stream " + name + ":\n" + exceptionStackTrace(ex));
				}
			}
		}

		private class ExitHandler implements Runnable {
			Process process;
			Thread thread;
			StreamReader out;
			StreamReader err;
			private final Func1<Object, Integer> callback;
			private final Func1<Object, String> onErr;

			public ExitHandler(Process process, Func1<Object, Integer> callback, Func1<Object, String> onErr, StreamReader out, StreamReader err) {
				this.process = process;
				this.callback = callback;
				this.out = out;
				this.err = err;
				this.onErr = onErr;
				thread = new Thread(this);
				thread.start();
			}
			public void run() {
				try {
					while (process.isAlive()) {
						thread.sleep(250);
					}
					err.close();
					out.close();
					exitCode = process.exitValue();
					callback.invoke(exitCode);
				} catch (InterruptedException ex) {
					onErr.invoke(exceptionStackTrace(ex));
				}
			}
		}

		public void writeStdin(String in) {
			try {
				if (process != null && process.isAlive()) {
					process.getOutputStream().write(in.getBytes());
					process.getOutputStream().flush();
				}
			} catch (IOException ex) {
				onErr.invoke(exceptionStackTrace(ex));
			}
		}

		public void kill() {
			try {
				stdout.close();
				stderr.close();
				process.waitFor(100, TimeUnit.MILLISECONDS);
				if (process != null && process.isAlive()) {
					process.destroy();
					process.waitFor(250, TimeUnit.MILLISECONDS);
					if (process.isAlive()) {
						process.destroyForcibly();
						process.waitFor();
					}
				}
				process = null;
			} catch (InterruptedException ex) {
				onErr.invoke(exceptionStackTrace(ex));
			}
		}

		@Override
		public void run() {
			try {
				exitCode = 0;
				process = Runtime.getRuntime().exec(this.cmd, null, new File(this.cwd));
				stdout = new StreamReader("stdout", process.getInputStream(), onOut, onOut);
				stderr = new StreamReader("stderr", process.getErrorStream(), onErr, onOut);
				exit   = new ExitHandler(process, onExit, onErr, stdout, stderr);
			} catch (IOException ex) {
				String cmd_str = "";
				for (String c : this.cmd) {
					cmd_str += c + " ";
				}
				onErr.invoke("while executing:\n" + cmd_str + "\n" + exceptionStackTrace(ex));
				exitCode = -200;
				onExit.invoke(exitCode);
			}
		}

		public int waitFor() {
			try {
				if (stdout != null && stdout.thread != null) {
					stdout.thread.join();
				}
				if (stderr != null && stderr.thread != null) {
					stderr.thread.join();
				}
				if (exit != null && exit.thread != null) {
					exit.thread.join();
				}
				if (process != null) {
					exitCode = process.waitFor();
				}
			} catch (InterruptedException e) {
				e.printStackTrace();
				exitCode = 1;
			}
			return exitCode;
		}
	}

	public static final Object runSystemProcess(String command, Object[] args, String currentWorkingDirectory,
					Func1<Object, String> onOut, Func1<Object, String> onErr, Func1<Object, Integer> onExit) {
		try {
			String[] cmd = new String[args.length + 1];
			cmd[0] = command;
			for (int i = 0; i < args.length; i++) {
				cmd[i+1] = (String)args[i];
			}
			ProcessStarter runner = new ProcessStarter(cmd, currentWorkingDirectory, onOut, onErr, onExit);
			Future future = threadpool.submit(runner);

			return runner;
		} catch (Exception ex) {
			onErr.invoke("while starting:\n" + command + "\noccured:\n" + exceptionStackTrace(ex));
			onExit.invoke(-200);
			return null;
		}
	}

	public static final int execSystemProcess(String command, Object[] args, String currentWorkingDirectory,
					Func1<Object, String> onOut, Func1<Object, String> onErr) {
		try {
			String[] cmd = new String[args.length + 1];
			cmd[0] = command;
			for (int i = 0; i < args.length; i++) {
				cmd[i+1] = (String)args[i];
			}
			ProcessStarter runner = new ProcessStarter(cmd, currentWorkingDirectory, onOut, onErr,
				new Func1<Object, Integer>()  {
					@Override
					public Object invoke(Integer code) { return null; }
				}
			);
			runner.run();
			return runner.waitFor();
		} catch (Exception ex) {
			onErr.invoke("while execution of:\n" + command + "\noccured:\n" + exceptionStackTrace(ex));
			return 1;
		}
	}

	public static final Object writeProcessStdin(Object process, String arg) {
		((ProcessStarter)process).writeStdin(arg);
		return null;
	}

	public static final Object killProcess(Object process) {
		((ProcessStarter)process).kill();
		return null;
	}

	public static final boolean startDetachedProcess(String command, Object[] args, String currentWorkingDirectory) {
		return false;
	}

	public static final Object[] concurrent(Boolean fine, Object[] tasks) {
		List<Callable<Object>> tasks2 = new ArrayList<Callable<Object>>();

		for (int i = 0; i < tasks.length; i++) {
			@SuppressWarnings("unchecked")
			Func0<Object> task = (Func0<Object>) tasks[i];
			tasks2.add(new Callable<Object>() {
				@Override
				public Object call() throws Exception {
					try {
						return task.invoke();
					} catch (OutOfMemoryError e) {
						// This is brutal, but there is no memory to print anything
						// so better to stop than to hang in infinite loop.
						System.exit(255);
						return null;
					}
				}
			});
		}

		Object[] resArr = new Object[0];

		try {
			List<Object> res = new ArrayList<Object>();
			for (Future<Object> future : threadpool.invokeAll(tasks2)) {
				res.add(future.get());
			}
			resArr = res.toArray();
		} catch (InterruptedException e) {
			e.printStackTrace();
		} catch (ExecutionException e) {
			e.printStackTrace();
		}

		return resArr;
	}

	public static final Object concurrentAsyncCallback(
		Func2<Object, String, Func1<Object, Object>> task,
		Func1<Object, Object> onDone,
		Func1<Object, String> onFail
	) {
		// thread #1
		CompletableFuture.supplyAsync(() -> {
			// thread #2
			Thread thread = Thread.currentThread();
			// For some reason it does not help catching exception (e.g. ClassCastException)
			//setUncaughtExceptionHandler(thread, onFail);
			CompletableFuture<Object> completableFuture = new CompletableFuture<Object>();
			String threadId = Long.toString(thread.getId());
			try {
				task.invoke(threadId, (res) -> {
					// thread #2
					completableFuture.complete(res);
					return null;
				});
			} catch (RuntimeException ex) {
				Throwable e = ex;
				e.printStackTrace();
				while (e.getCause() != null) {
					e = e.getCause();
					System.out.println("Cause:");
					e.printStackTrace();
				}
				return onFail.invoke("Thread #" + threadId + " failed: " + e.getMessage());
			} catch (Exception e) {
				e.printStackTrace();
				return onFail.invoke("Thread #" + threadId + " failed: " + e.getMessage());
			}
			Object result = null;
			try {
				result = completableFuture.get();
			} catch (InterruptedException e) {
				e.printStackTrace();
			} catch (ExecutionException e) {
				e.printStackTrace();
			}
			return result;
		}, threadpool)
		.exceptionally(ex -> {
			ex.printStackTrace();
			Thread thread = Thread.currentThread();
			String threadId = Long.toString(thread.getId());
			return onFail.invoke("Thread #" + threadId + " failed: " + ex.getMessage());
		})
		.thenApply(result -> {
			// thread #2
			return onDone.invoke(result);
		});

		return null;
	}

	private static final void setUncaughtExceptionHandler(Thread thread, Func1<Object, String> onException) {
		Thread.UncaughtExceptionHandler h = new Thread.UncaughtExceptionHandler() {
			@Override
			public void uncaughtException(Thread th, Throwable ex) {
				if (onException != null) {
					onException.invoke(ex.toString());
				} else {
					System.out.println("Uncaught exception: " + ex);
				}
			}
		};
		thread.setUncaughtExceptionHandler(h);
	}

	public static final String getThreadId() {
		return Long.toString(Thread.currentThread().getId());
	}

	public static final Object initConcurrentHashMap() {
		return new ConcurrentHashMap();
	}

	public static final Object setConcurrentHashMap(Object map, Object key, Object value) {
		@SuppressWarnings("unchecked")
		ConcurrentHashMap<Object, Object> concurrentMap = (ConcurrentHashMap<Object, Object>) map;
		concurrentMap.put(key, value);
		return null;
	}

	public static final Object getConcurrentHashMap(Object map, Object key, Object defval) {
		ConcurrentHashMap concurrentMap = (ConcurrentHashMap) map;
		return concurrentMap.containsKey(key) ? concurrentMap.get(key) : defval;
	}

	@SuppressWarnings("unchecked")
	public static final Object setAllConcurrentHashMap(Object map1, Object map2) {
		ConcurrentHashMap<Object, Object> concurrentMap1 = (ConcurrentHashMap<Object, Object>) map1;
		ConcurrentHashMap<Object, Object> concurrentMap2 = (ConcurrentHashMap<Object, Object>) map2;
		concurrentMap1.putAll(concurrentMap2);
		return null;
	}

	public static final Boolean containsConcurrentHashMap(Object map, Object key) {
		ConcurrentHashMap concurrentMap = (ConcurrentHashMap) map;
		return concurrentMap.containsKey(key);
	}

	public static final Object[] valuesConcurrentHashMap(Object map) {
		ConcurrentHashMap concurrentMap = (ConcurrentHashMap) map;
		return concurrentMap.values().toArray();
	}

	public static final Object removeConcurrentHashMap(Object map, Object key) {
		ConcurrentHashMap concurrentMap = (ConcurrentHashMap) map;
		concurrentMap.remove(key);
		return null;
	}

	public static final Object[] keysConcurrentHashMap(Object map) {
		@SuppressWarnings("unchecked")
		ConcurrentHashMap<Object, Object> concurrentMap = (ConcurrentHashMap<Object, Object>) map;
		ArrayList<Object> ret = new ArrayList<Object>();
		for (Enumeration<Object> e = concurrentMap.keys(); e.hasMoreElements();) {
			ret.add(e.nextElement());
		}
		return ret.toArray();
	}

	public static final int sizeConcurrentHashMap(Object map) {
		ConcurrentHashMap concurrentMap = (ConcurrentHashMap) map;
		return concurrentMap.size();
	}

	public static final Object clearConcurrentHashMap(Object map) {
		ConcurrentHashMap concurrentMap = (ConcurrentHashMap) map;
		concurrentMap.clear();
		return null;
	}

	// TODO: why don't we use threadpool here?
	public static final Object concurrentAsyncOne(Boolean fine, Func0<Object> task, Func1<Object,Object> callback) {
		CompletableFuture.supplyAsync(() -> {
			return task.invoke();
		}).thenApply(result -> {
			return callback.invoke(result);
		});
		return null;
	}

	public static synchronized final int atomicRefIntAddition(Reference<Integer> rv, Integer delta) {
	  int result = rv.value;
	  rv.value = result + delta;
	  return result;
	}

	public static final Func0<Object> addCameraPhotoEventListener(Func5<Object, Integer, String, String, Integer, Integer> cb) {
		// not implemented yet for java
		return null;
	}
	public static final Func0<Object> addCameraVideoEventListener(Func7<Object, Integer, String, String, Integer, Integer, Integer, Integer> cb) {
		// not implemented yet for java
		return null;
	}
	//native addPlatformEventListenerNative : (event : string, cb : () -> bool) -> ( () -> void ) = Native.addPlatformEventListener;
	public static final Func0<Object> addPlatformEventListener (String event, Func0<Boolean> cb) {
	return null;
	}

	public static final int availableProcessors() {
		return Runtime.getRuntime().availableProcessors();
	}

	public static final Object setThreadPoolSize(int threads) {
		threadpool = Executors.newFixedThreadPool(threads);
		return null;
	}

	public static final String readBytes(int n) {
		byte[] input = new byte[n];
		try {
			int have_read = 0;
			while (have_read < n) {
				int read_bytes = System.in.read(input, have_read, n - have_read);
				if (read_bytes == -1) {
					break;
				}
				have_read += read_bytes;
			}
		} catch (IOException e) {
			e.printStackTrace();
		}
		try {
			return new String(input, "UTF-8");
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
			return new String();
		}
	}

	public static final String readUntil(String str_pattern) {
		byte[] pattern = str_pattern.getBytes();
		ArrayList<Byte> line = new ArrayList<Byte>();
		int pos = 0;
		try {
			while (true) {
				int ch = System.in.read();
				if (ch == -1) {
					break;
				} else {
					line.add(Byte.valueOf((byte)ch));
					if (ch == pattern[pos]) {
						pos += 1;
						if (pos == pattern.length) {
							break;
						}
					} else {
						pos = 0;
					}
				}
			}
		} catch (IOException e) {
			e.printStackTrace();
		}
		byte[] bytes = new byte[line.size()];
		for (int i = 0; i < line.size(); ++ i) {
			bytes[i] = line.get(i).byteValue();
		}
		try {
			return new String(bytes, "UTF-8");
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
			return new String();
		}
	}

	public static final Object print(String s) {
		try{
			synchronized (System.out) {
				PrintStream out = new PrintStream(System.out, true, "UTF-8");
				out.print(s);
				out.flush();
			}
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		}
		return null;
	}

	// Memory statistics:
	public static final double totalMemory() {
		return (double)(Runtime.getRuntime().totalMemory());
	}
	public static final double freeMemory() {
		return (double)(Runtime.getRuntime().freeMemory());
	}
	public static final double maxMemory() {
		return (double)(Runtime.getRuntime().maxMemory());
	}

	// CPU load
	public static final double getProcessCpuLoad() {
		return osBean.getProcessCpuLoad();
	}

	// Vector natives:
	public static final Object makeVector(Integer capacity) {
		return new ArrayList(capacity);
	}
	public static final Object getVector(Object v, Integer i) {
		ArrayList vector = (ArrayList)v;
		return vector.get(i.intValue());
	}
	public static final Object setVector(Object v, Integer i, Object x) {
		@SuppressWarnings("unchecked")
		ArrayList<Object> vector = (ArrayList<Object>)v;
		vector.set(i.intValue(), x);
		return null;
	}
	public static final Object addVector(Object v, Object x) {
		@SuppressWarnings("unchecked")
		ArrayList<Object> vector = (ArrayList<Object>)v;
		vector.add(x);
		return null;
	}
	public static final Object removeVector(Object v, Integer i) {
		ArrayList vector = (ArrayList)v;
		vector.remove(i.intValue());
		return null;
	}
	public static final int sizeVector(Object v) {
		ArrayList vector = (ArrayList)v;
		return vector.size();
	}
	public static final Object clearVector(Object v) {
		ArrayList vector = (ArrayList)v;
		vector.clear();
		return null;
	}
	public static final Object shrinkVector(Object v, Integer size) {
		ArrayList vector = (ArrayList)v;
		int i = vector.size();
		while (i > size) {
			vector.remove(--i);
		}
		return null;
	}
	public static final Object subVector(Object v, Integer index, Integer len) {
		@SuppressWarnings("unchecked")
		ArrayList<Object> vector = (ArrayList<Object>)v;
		ArrayList<Object> sub = new ArrayList<Object>(len);
		for (int i = index; i < index + len; ++ i) {
			sub.add(vector.get(i));
		}
		return sub;
	}
	public static final Object[] vector2array(Object v) {
		ArrayList vector = (ArrayList)v;
		return vector.toArray();
	}
	public static final Object array2vector(Object[] a) {
		return new ArrayList<Object>(Arrays.asList(a));
	}

	public static final <RT> Func0<RT> synchronizedConstFn(Object lock, Func0<RT> fn) {
		return new Func0<RT>() {
			@Override
			public RT invoke() {
				synchronized (lock) {
					return fn.invoke();
				}
			}
		};
	}
	public static final <RT, A1> Func1<RT, A1> synchronizedUnaryFn(Object lock, Func1<RT, A1> fn) {
		return new Func1<RT, A1>() {
			@Override
			public RT invoke(A1 arg1) {
				synchronized (lock) {
					return fn.invoke(arg1);
				}
			}
		};
	}
	public static final <RT, A1, A2> Func2<RT, A1, A2> synchronizedBinaryFn(Object lock, Func2<RT, A1, A2> fn) {
		return new Func2<RT, A1, A2>() {
			@Override
			public RT invoke(A1 arg1, A2 arg2) {
				synchronized (lock) {
					return fn.invoke(arg1, arg2);
				}
			}
		};
	}
	public static final <RT, A1, A2, A3> Func3<RT, A1, A2, A3> synchronizedTernaryFn(Object lock, Func3<RT, A1, A2, A3> fn) {
		return new Func3<RT, A1, A2, A3>() {
			@Override
			public RT invoke(A1 arg1, A2 arg2, A3 arg3) {
				synchronized (lock) {
					return fn.invoke(arg1, arg2, arg3);
				}
			}
		};
	}

	public static final String urlDecode(String s) {
		try {
			return URLDecoder.decode(s, "UTF-8");
		} catch (UnsupportedEncodingException | IllegalArgumentException e) {
			System.out.println(e.toString());
			return "";
		}
	}

	private static ConcurrentHashMap<String, Object> host_call_funcs = new ConcurrentHashMap<String, Object>();

	// Make calls via reflection.
	// Formats of a called method name:
	//   p1.p2.p3.Class.method
	//   NativeHost.method
	//   Module_<m>.f_<method>  - functions generated by flowc from sources
	@SuppressWarnings (value="unchecked")
	public static final Object hostCall(String name, Object[] args) {
		if (!host_call_funcs.containsKey(name)) {
			addHostCall(name);
		}
		Object fn = host_call_funcs.get(name);
		if (fn instanceof Integer) {
			// Native / runtime function is not found.
			// Integer value is a marker of absence of a function.
			return new String("runtime error: Native / runtime function " + name + " is not found");
		} else {
			if (args.length == 0) {
				return ((Func0)fn).invoke();
			} else if (args.length == 1) {
				return ((Func1)fn).invoke(args[0]);
			} else if (args.length == 2) {
				return ((Func2)fn).invoke(args[0], args[1]);
			} else if (args.length == 3) {
				return ((Func3)fn).invoke(args[0], args[1], args[2]);
			} else if (args.length == 4) {
				return ((Func4)fn).invoke(args[0], args[1], args[2], args[3]);
			} else if (args.length == 5) {
				return ((Func5)fn).invoke(args[0], args[1], args[2], args[3], args[4]);
			} else if (args.length == 6) {
				return ((Func6)fn).invoke(args[0], args[1], args[2], args[3], args[4], args[5]);
			} else if (args.length == 7) {
				return ((Func7)fn).invoke(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
			} else if (args.length == 8) {
				return ((Func8)fn).invoke(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
			} else if (args.length == 9) {
				return ((Func9)fn).invoke(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
			} else if (args.length == 10) {
				return ((Func10)fn).invoke(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
			} else if (args.length == 11) {
				return ((Func11)fn).invoke(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10]);
			} else {
				// Arity is not implemented yet
				return new String("runtime error: Arity " + args.length + " of function " + name +  " in hostCall is not implemented yet.");
			}
		}
	}

	public static final boolean hostCallExists(String name) {
		if (host_call_funcs.containsKey(name)) {
			Object fn = host_call_funcs.get(name);
			// Check that object is not integer. Integer value marks absent host call name.
			return !(fn instanceof Integer);
		} else {
			return addHostCall(name) != null;
		}
	}

	private static final Class loadHostCallClass(String class_path) {
		try {
			return Class.forName(class_path);
		} catch (ClassNotFoundException e1) {
			try {
				return Class.forName("com.area9innovation.flow." + class_path);
			} catch (ClassNotFoundException e2) {
				System.out.println("Class: " + class_path + " was not found");
				return null;
			}
		}
	}

	private static final Method findHostCall(String name) {
		String[] parts = name.split("\\.");
		if (parts.length < 2) {
			// Search for a proper method in all loaded classes.
			for (Class cls: LoadedClassesAgent.getAllLoadedClasses()) {
				String class_name = cls.getName();
				if (class_name.contains("$") || class_name.contains("[") || !class_name.contains("Module_")) {
					// Skip all modules except for generated by flowc.
					// Also skip lambdas and inner classes.
					continue;
				}
				String meth_name = "f_" + name;
				for (Method meth : cls.getMethods()) {
					if (meth.getName().equals(meth_name)) {
						int modifiers = meth.getModifiers();
						if (java.lang.reflect.Modifier.isStatic(modifiers) && java.lang.reflect.Modifier.isPublic(modifiers)) {
							return meth;
						}
					}
				}
			}
			// Try most common natives.
			return findHostCall("Native." + name);
		} else {
			String class_path = "";
			for (int i = 0; i < parts.length - 1; ++ i) {
				class_path += (i == 0) ? parts[i] : "." + parts[i];
			}
			Class cls = loadHostCallClass(class_path);
			if (cls != null) {
				boolean is_module = cls.getName().contains("Module_");
				String meth_name = is_module ? "f_" + parts[parts.length - 1] : parts[parts.length - 1];
				for (Method meth : cls.getMethods()) {
					if (meth.getName().equals(meth_name)) {
						int modifiers = meth.getModifiers();
						if (java.lang.reflect.Modifier.isStatic(modifiers) && java.lang.reflect.Modifier.isPublic(modifiers)) {
							return meth;
						}
					}
				}
			}
			// Method is not found
			return null;
		}
	}

	private static final Method addHostCall(String name) {
		Method meth = findHostCall(name);
		if (meth == null) {
			// Host call is not found - put Integer value to mark int.
			host_call_funcs.put(name, Integer.valueOf(0));
		} else {
			int arity = meth.getParameterCount();
			try {
				if (arity == 0) {
					host_call_funcs.put(name, (Func0)(() -> {
						try {
							return meth.invoke(null);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 1) {
					host_call_funcs.put(name, (Func1)((Object a1) -> {
						try {
							return meth.invoke(null, a1);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 2) {
					host_call_funcs.put(name, (Func2)((Object a1, Object a2) -> {
						try {
							return meth.invoke(null, a1, a2);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 3) {
					host_call_funcs.put(name, (Func3)((Object a1, Object a2, Object a3) -> {
						try {
							return meth.invoke(null, a1, a2, a3);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 4) {
					host_call_funcs.put(name, (Func4)((Object a1, Object a2, Object a3, Object a4) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 5) {
					host_call_funcs.put(name, (Func5)((Object a1, Object a2, Object a3, Object a4, Object a5) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 6) {
					host_call_funcs.put(name, (Func6)((Object a1, Object a2, Object a3, Object a4, Object a5, Object a6) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5, a6);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								"arg 6: " + a6 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 7) {
					host_call_funcs.put(name, (Func7)((Object a1, Object a2, Object a3, Object a4, Object a5, Object a6, Object a7) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5, a6, a7);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								"arg 6: " + a6 + "\n" +
								"arg 7: " + a7 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 8) {
					host_call_funcs.put(name, (Func8)((Object a1, Object a2, Object a3, Object a4, Object a5, Object a6, Object a7, Object a8) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5, a6, a7, a8);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								"arg 6: " + a6 + "\n" +
								"arg 7: " + a7 + "\n" +
								"arg 8: " + a8 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 9) {
					host_call_funcs.put(name, (Func9)((Object a1, Object a2, Object a3, Object a4, Object a5, Object a6, Object a7, Object a8, Object a9) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5, a6, a7, a8, a9);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								"arg 6: " + a6 + "\n" +
								"arg 7: " + a7 + "\n" +
								"arg 8: " + a8 + "\n" +
								"arg 9: " + a9 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 10) {
					host_call_funcs.put(name, (Func10)((Object a1, Object a2, Object a3, Object a4, Object a5, Object a6, Object a7, Object a8, Object a9, Object a10) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								"arg 6: " + a6 + "\n" +
								"arg 7: " + a7 + "\n" +
								"arg 8: " + a8 + "\n" +
								"arg 9: " + a9 + "\n" +
								"arg 10: " + a10 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 11) {
					host_call_funcs.put(name, (Func11)((Object a1, Object a2, Object a3, Object a4, Object a5, Object a6, Object a7, Object a8, Object a9, Object a10, Object a11) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								"arg 6: " + a6 + "\n" +
								"arg 7: " + a7 + "\n" +
								"arg 8: " + a8 + "\n" +
								"arg 9: " + a9 + "\n" +
								"arg 10: " + a10 + "\n" +
								"arg 11: " + a11 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else if (arity == 12) {
					host_call_funcs.put(name, (Func12)((Object a1, Object a2, Object a3, Object a4, Object a5, Object a6, Object a7, Object a8, Object a9, Object a10, Object a11, Object a12) -> {
						try {
							return meth.invoke(null, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12);
						} catch (ReflectiveOperationException e) {
							System.err.println(
								"at calling " + name + ":\n" +
								"arg 1: " + a1 + "\n" +
								"arg 2: " + a2 + "\n" +
								"arg 3: " + a3 + "\n" +
								"arg 4: " + a4 + "\n" +
								"arg 5: " + a5 + "\n" +
								"arg 6: " + a6 + "\n" +
								"arg 7: " + a7 + "\n" +
								"arg 8: " + a8 + "\n" +
								"arg 9: " + a9 + "\n" +
								"arg 10: " + a10 + "\n" +
								"arg 11: " + a11 + "\n" +
								"arg 12: " + a12 + "\n" +
								exceptionStackTrace(e)
							);
							return null;
						}
					}));
				} else {
					// Not implemented yet
					host_call_funcs.put(name, Integer.valueOf(0));
				}
			} catch (java.lang.IllegalArgumentException ex) {
				System.err.println("While adding a function: " + name + "\n" + ex.getMessage());
				host_call_funcs.put(name, Integer.valueOf(0));
			}
		}
		return meth;
	}

	public static final String toStringForJson(String value) {
		String sv = value;
		// Make room for some escape
		StringBuilder buf = new StringBuilder(sv.length() + 20);
		buf.append('"');
		for (int i = 0; i < sv.length(); i++) {
			char c = sv.charAt(i);
			switch (c) {
				// In JSON all control charters must be escaped.
				case 0x00: buf.append("\\u0000"); break;	// Do not allow 0 in strings
				case 0x01: buf.append("\\u0001"); break;
				case 0x02: buf.append("\\u0002"); break;
				case 0x03: buf.append("\\u0003"); break;
				case 0x04: buf.append("\\u0004"); break;
				case 0x05: buf.append("\\u0005"); break;
				case 0x06: buf.append("\\u0006"); break;
				case 0x07: buf.append("\\u0007"); break;	// Terminal bell, \a
				case 0x08: buf.append("\\u0008"); break;	// Backspace \b
				case '\t': buf.append("\\t"); break;
				case '\n': buf.append("\\n"); break;
				case 0x0b: buf.append("\\u000b"); break;	// Vertical Tab \v
				case 0x0c: buf.append("\\u000c"); break;	// Formfeed \f
				case '\r': buf.append("\\u000d"); break;	// Keep the flow tradition of not using \r
				case 0x0e: buf.append("\\u000e"); break;
				case 0x0f: buf.append("\\u000f"); break;
				case 0x10: buf.append("\\u0010"); break;
				case 0x11: buf.append("\\u0011"); break;
				case 0x12: buf.append("\\u0012"); break;
				case 0x13: buf.append("\\u0013"); break;
				case 0x14: buf.append("\\u0014"); break;
				case 0x15: buf.append("\\u0015"); break;
				case 0x16: buf.append("\\u0016"); break;
				case 0x17: buf.append("\\u0017"); break;
				case 0x18: buf.append("\\u0018"); break;
				case 0x19: buf.append("\\u0019"); break;
				case 0x1a: buf.append("\\u001a"); break;
				case 0x1b: buf.append("\\u001b"); break;
				case 0x1c: buf.append("\\u001c"); break;
				case 0x1d: buf.append("\\u001d"); break;
				case 0x1e: buf.append("\\u001e"); break;
				case 0x1f: buf.append("\\u001f"); break;
				case '\\': buf.append("\\\\"); break;
				case '"': buf.append("\\\""); break;
				default: buf.append(c); break;
			}
		}
		buf.append('"');
		return buf.toString();
	}
}

