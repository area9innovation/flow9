using System;
using System.Collections.Generic;
using System.Text;
using System.Reflection;
using System.Diagnostics;

namespace Area9Innovation.Flow
{
	public delegate NativeHost IHostFactory(Type ctype);

	public delegate object Func0();
	public delegate object Func1(object a0);
	public delegate object Func2(object a0, object a1);
	public delegate object Func3(object a0, object a1, object a2);
	public delegate object Func4(object a0, object a1, object a2, object a3);
	public delegate object Func5(object a0, object a1, object a2, object a3, object a4);
	public delegate object Func6(object a0, object a1, object a2, object a3, object a4, object a5);

	public abstract class NativeHost {
		protected FlowRuntime runtime;
		protected virtual void initialize() {}
		protected virtual void terminate() {}

		internal void Init(FlowRuntime rt) {
			runtime = rt;
			initialize();
		}

		internal void Terminate() {
			terminate();
		}

		public NativeHost() {}
	}

	public enum RuntimeType {
		VOID, BOOL, INT, DOUBLE, STRING, REF, STRUCT, ARRAY, UNKNOWN
	};

	public static class RuntimeTypeUtil {
		private static Dictionary<Type, RuntimeType> type_map = new Dictionary<Type, RuntimeType>();

		static RuntimeTypeUtil() {
			type_map.Add(typeof(bool), RuntimeType.BOOL);
			type_map.Add(typeof(int), RuntimeType.INT);
			type_map.Add(typeof(double), RuntimeType.DOUBLE);
			type_map.Add(typeof(String), RuntimeType.STRING);
			type_map.Add(typeof(object[]), RuntimeType.ARRAY);
			type_map.Add(typeof(Reference), RuntimeType.REF);
		}

		public static RuntimeType classify(object v) {
			if (v == null)
				return RuntimeType.VOID;

			if (v is Struct)
			    return RuntimeType.STRUCT;

			RuntimeType rt;
			if (!type_map.TryGetValue(v.GetType(), out rt))
				rt = RuntimeType.UNKNOWN;

			return rt;
		}
	}

	public sealed class Reference : IComparable {
		private int uid;
		public object value;

		private static int next_uid = 0;

		public Reference(object init) {
			this.uid = next_uid++;
			this.value = init;
		}

		public int CompareTo(object other) {
			return uid - ((Reference)other).uid;
		}

		public override String ToString() {
			return "ref " + FlowRuntime.toString(value);
		}
	}

	public abstract class Struct : IComparable {
		public abstract int getTypeId();
		public abstract String getTypeName();
		public abstract String[] getFieldNames();
		public abstract RuntimeType[] getFieldTypes();
		public abstract Object[] getFields();
		public abstract void setFields(Object[] val);

		public virtual Struct Clone() {
			return (Struct)MemberwiseClone();
		}

		public abstract int CompareTo(object b);

		public override String ToString() {
			StringBuilder buf = new StringBuilder();
			String name = getTypeName();

			buf.Append(name);

			if (name == "DLink") {
				buf.Append("(...)");
				return buf.ToString();
			}

			buf.Append('(');

			RuntimeType[] types = getFieldTypes();
			Object[] values = getFields();

			for (int i = 0; i < values.Length; i++) {
				if (i > 0)
					buf.Append(", ");

				if (types[i] == RuntimeType.DOUBLE && (values[i] is int || values[i] is double))
					buf.Append(FlowRuntime.doubleToStringWithDot((double)values[i]));
				else
					buf.Append(FlowRuntime.toString(values[i]));
			}

			buf.Append(')');

			return buf.ToString();
		}
	}

	public sealed class SingletonStruct : Struct {
		private int id;
		private String name;
		private String name_rep;

		private SingletonStruct(int id, String name) {
			this.id = id;
			this.name = name;
			this.name_rep = name+"()";
		}

		private static Dictionary<String,SingletonStruct> cache = new Dictionary<String,SingletonStruct>();

		public static SingletonStruct make(int id, String name) {
			String key = id + ":" + name;
			SingletonStruct item;
			if (!cache.TryGetValue(key, out item))
				cache.Add(key, item = new SingletonStruct(id, name));
			return item;
		}

		private static String[] no_names = new String[] {};
		private static RuntimeType[] no_types = new RuntimeType[] {};
		private static Object[] no_fields = new Object[] {};

		public override int getTypeId() {
			return id;
		}
		public override String getTypeName() {
			return name;
		}
		public override String[] getFieldNames() {
			return no_names;
		}
		public override RuntimeType[] getFieldTypes() {
			return no_types;
		}
		public override Object[] getFields() {
			return no_fields;
		}
		public override void setFields(Object[] data) {
			if (data.Length != 0)
				throw new IndexOutOfRangeException("No fields in "+name);
		}
		public override Struct Clone() {
			return this;
		}
		public override String ToString() {
			return name_rep;
		}
		public override int CompareTo(object other) {
			return id - ((Struct)other).getTypeId();
		}
	}
	public abstract class FlowRuntime
	{
		private IHostFactory host_factory;
		private Struct[] struct_prototypes;
		private Dictionary<String,int> struct_ids;
		private Dictionary<Type,NativeHost> hosts;

		private bool is_running = true;
		private int deferred_depth;
		private List<Func0> deferred_queue;

		public bool IsRunning { get { return is_running; } }

		public struct DeferredContext : IDisposable
		{
			private FlowRuntime runtime;
			private int depth;

			public DeferredContext(FlowRuntime runtime)
			{
				this.runtime = runtime;
				depth = ++runtime.deferred_depth;
			}
			public void Dispose()
			{
				if (runtime.deferred_depth != depth)
					throw new Exception("Invalid deferred depth");
				if (--runtime.deferred_depth <= 0)
					runtime.flushDeferred();
			}
		}

		protected FlowRuntime(Struct[] structs) {
			struct_prototypes = structs;
			struct_ids = new Dictionary<String,int>();
			hosts = new Dictionary<Type,NativeHost>();
			deferred_queue = new List<Func0>();

			for (int i = 0; i < structs.Length; i++)
				struct_ids.Add(structs[i].getTypeName(), i);
		}

		public void start(IHostFactory factory) {
			host_factory = factory;
			main();
		}

		public void terminate()
		{
			is_running = false;
			deferred_queue.Clear();

			foreach (var host in hosts.Values)
				host.Terminate();
		}

		protected abstract void main();

		public bool queueDeferred(Func0 cb)
		{
			if (deferred_depth <= 0)
				return false;

			if (is_running)
				deferred_queue.Add(cb);
			return true;
		}

		private void flushDeferred()
		{
			deferred_depth = 1;

			while (deferred_queue.Count > 0)
			{
				var old = deferred_queue;
				deferred_queue = new List<Func0>();

				foreach (var cb in old)
				{
					try
					{
						cb();
					}
					catch (Exception e)
					{
						Debug.WriteLine(e.ToString());
					}
				}
			}

			if (deferred_depth != 1)
				throw new Exception("Invalid depth in flushDeferred");
			deferred_depth = 0;
		}

		private NativeHost getNativeHost(Type cls) {
			NativeHost host;
			if (hosts.TryGetValue(cls, out host))
				return host;

			try {
				if (host_factory != null)
					host = host_factory(cls);
				if (host == null)
					host = (NativeHost)Activator.CreateInstance(cls);

#if WINDOWS_APP
				Type host_type = host.GetType();
				if (host_type != cls && !host.GetType().GetTypeInfo().IsSubclassOf(cls))
#else
				if (!cls.IsInstanceOfType(host))
#endif
					throw new Exception("Invalid host: "+cls.Name+" expected, "+host.GetType().Name+" allocated");

				hosts.Add(cls, host);
				host.Init(this);
				return host;
			} catch (Exception e) {
				throw new Exception("Could not instantiate native method host "+cls.Name, e);
			}
		}

		public T getNativeHost<T>() where T : NativeHost {
			return (T)getNativeHost(typeof(T));
		}

		public static Delegate createHostDelegate(Type dtype, NativeHost host, String name)
		{
#if WINDOWS_APP
			MethodInfo invoke_method = dtype.GetTypeInfo().GetDeclaredMethod("Invoke");

			ParameterInfo[] parms = invoke_method.GetParameters();
			Type[] ptypes = new Type[parms.Length];
			for (int i = 0; i < parms.Length; i++)
				ptypes[i] = parms[i].ParameterType;

			MethodInfo tgt_method = host.GetType().GetRuntimeMethod(name, ptypes);
			if (tgt_method == null)
				return null;

			return tgt_method.CreateDelegate(dtype, host);
#else
			return Delegate.CreateDelegate(dtype, host, false, false);
#endif
		}

		public static int compareByValue(object o1, object o2) {
			if (o1 == o2)
				return 0;
			if (o1 == null)
				return -1;
			if (o2 == null)
				return 1;

			IComparable c1 = (o1 as IComparable);
			if (c1 != null) {
				if (!(o2 is IComparable))
					return -1;

				if (o1 is Struct) {
					if (!(o2 is Struct))
						return 1;

					return c1.CompareTo((Struct)o2);
				}
				else if (o2 is Struct)
					return -1;

				if (o1.GetType() == o2.GetType())
				{
					if (o1 is String)
						return String.Compare((string)o1, (string)o2, StringComparison.Ordinal);

					return c1.CompareTo(o2);
				}

				RuntimeType t1 = RuntimeTypeUtil.classify(o1);
				RuntimeType t2 = RuntimeTypeUtil.classify(o2);

				if (t1 != RuntimeType.UNKNOWN && t2 != RuntimeType.UNKNOWN)
					return t1.CompareTo(t2);

				return ((int)(o1.GetType().GetHashCode())).CompareTo(o2.GetType().GetHashCode());
			}
			else if (o2 is IComparable)
				return 1;

			if (o1 is object[]) {
				if (!(o2 is object[]))
					return 1;

				object[] arr1 = (object[])o1;
				object[] arr2 = (object[])o2;
				int l1 = arr1.Length;
				int l2 = arr2.Length;
				int l =  l1 < l2 ? l1 : l2;
				for (int i = 0; i < l; i++) {
					int c = compareByValue(arr1[i], arr2[i]);
					if (c != 0) return c;
				}

				return (l1 == l2) ? 0 : (l1 < l2 ? -1 : 1);
			}
			else if (o2 is object[])
				return -1;

			if (o1 == o2)
				return 0;

			if (o1 is Delegate)
			{
				if (o1.Equals(o2))
					return 0;
				else
					return 1;
			}

			return ((int)o1.GetHashCode()).CompareTo(o2.GetHashCode());
		}

		public static int compareStrings(string a, string b)
		{
			return String.Compare(a, b, StringComparison.Ordinal);
		}

		public static String toString(Object val) {
			if (val == null)
				return "{}";

			if (val is String) {
				StringBuilder buf = new StringBuilder();
				String sv = (String)val;

				buf.Append('"');
				for (int i = 0; i < sv.Length; i++) {
					char c = sv[i];

					switch (c) {
						case '\t':
							buf.Append("\\t");
							break;
						case '\n':
							buf.Append("\\n");
							break;
						case '\\':
						case '"':
							buf.Append('\\');
							buf.Append(c);
							break;
						default:
							buf.Append(c);
							break;
					}

				}
				buf.Append('"');

				return buf.ToString();
			}

			if (val is object[]) {
				StringBuilder buf = new StringBuilder();
				Object[] arr = (Object[])val;

				buf.Append("[");
				for (int i = 0; i < arr.Length; i++) {
					if (i > 0)
						buf.Append(", ");
					buf.Append(toString(arr[i]));
				}
				buf.Append("]");

				return buf.ToString();
			}

			if (val is Delegate)
				return "<function>";

			if (val is double)
				return doubleToStringWithDot((double)val);

			if (val is bool)
				return ((bool)val) ? "true" : "false";

			return val.ToString();
		}

		public static String doubleToStringWithDot(double val)
		{
			String rstr = val.ToString();
			if (rstr.IndexOf('.') < 0)
				rstr += ".0";
			return rstr;
		}

		public static String doubleToString(double val) {
			String rstr = val.ToString();
			return rstr.EndsWith(".0") ? rstr.Substring(0, rstr.Length - 2) : rstr;
		}

		internal Struct findStructPrototype(string name)
		{
			int id;
			if (!struct_ids.TryGetValue(name, out id))
				return null;

			return struct_prototypes[id];
		}

		public Struct makeStructValue(String name, object[] fields, Struct default_value) {
			int id;
			if (!struct_ids.TryGetValue(name, out id))
				return default_value;

			return makeStructValue(id, fields, default_value);
		}

		public Struct makeStructValue(int id, object[] fields, Struct default_value) {
			try {
				Struct copy = struct_prototypes[id].Clone();
				copy.setFields(fields);
				return copy;
			} catch (Exception) {
				return default_value;
			}
		}

		public static bool isArray(object val) {
			return val != null && val is object[];
		}

		public static object negate(object o1) {
			if (o1 is double)
				return -((double)o1);
			return -((int)o1);
		}
		public static object add(object o1, object o2) {
			if (o1 is String || o2 is String)
				return o1.ToString() + o2.ToString();
			if (o1 is double || o2 is double)
				return ((double)o1) + ((double)o2);
			return ((int)o1) + ((int)o2);
		}
		public static object sub(object o1, object o2) {
			if (o1 is double || o2 is double)
				return ((double)o1) - ((double)o2);
			return ((int)o1) - ((int)o2);
		}
		public static object mul(object o1, object o2) {
			if (o1 is double || o2 is double)
				return ((double)o1) * ((double)o2);
			return ((int)o1) * ((int)o2);
		}
		public static object div(object o1, object o2) {
			if (o1 is double || o2 is double)
				return ((double)o1) / ((double)o2);
			return ((int)o1) / ((int)o2);
		}
		public static object mod(object o1, object o2) {
			if (o1 is double || o2 is double)
				return ((double)o1) % ((double)o2);
			return ((int)o1) % ((int)o2);
		}
	}
}

