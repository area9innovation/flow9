using System;
using System.Text;
using System.Diagnostics;
using System.Globalization;
using System.Collections.Generic;

#if WINDOWS_APP
using Windows.Foundation;
#endif

namespace Area9Innovation.Flow
{
	public class Native : NativeHost
	{
		public Object println(Object arg) {
#if WINDOWS_APP
			Debug.WriteLine(FlowRuntime.toString(arg));
#else
			Console.WriteLine(FlowRuntime.toString(arg));
#endif
			return null;
		}

		public Object deleteNative(Object obj)
		{
			var dis = (obj as IDisposable);
			if (dis != null)
				dis.Dispose();
			return null;
		}

		public Object hostCall(String name, Object[] args) {
			return null;
		}

		public virtual Func0 hostAddCallback(String name, Func0 cb) {
			return null;
		}

		public Object setCurrentDirectory(String path) {
			return null;
		}

		public String getCurrentDirectory() {
			return "";
		}

		public Object setClipboard(String text) {
		    /*StringSelection selection = new StringSelection(text);
		    Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
		    clipboard.setContents(selection, selection);*/

			return null;
		}

		public String getClipboard() {
			/*try {
			    Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
			    String data = (String) clipboard.getData(DataFlavor.stringFlavor);
				return data;
			} catch (UnsupportedFlavorException e) {
				return "";
			} catch (IOException e) {
				return "";
			}*/
			return "";
		}

		public String getClipboardFormat(String mimetype) {
			return "";
		}

		public String getApplicationPath() {
			return "";
		}

		public object[] getApplicationArguments() {
			return empty_arr;
		}

		public String toString(Object value) {
			return FlowRuntime.toString(value);
		}

		public Object gc() {
			System.GC.Collect();
			return null;
		}

		public Object addHttpHeader(String data) {
			return null;
		}

		public String getCgiParameter(String name) {
			return "";
		}

		private static readonly object[] empty_arr = new object[0];

		public Object[] subrange(Object[] arr, int start, int len) {
			if (start + len > arr.Length)
				len = arr.Length - start;
			if (len <= 0)
				return empty_arr;
			object[] dest = new object[len];
			Array.Copy(arr, start, dest, 0, len);
			return dest;
		}

		public bool isArray(Object obj) {
			return FlowRuntime.isArray(obj);
		}

		public bool isSameStructType(Object a, Object b) {
			return a != null && b != null &&
			       a is Struct && b is Struct &&
			       ((Struct)a).getTypeId() == ((Struct)b).getTypeId();
		}

		public bool isSameObj(Object a, Object b) {
			if (a == b)
				return true;
			if (a is int && b is int)
				return (int)a == (int)b;
			if (a is double && b is double)
				return (double)a == (double)b;
			if (a is string && b is string)
				return (string)a == (string)b;
			return false;
		}

		public int length(Object[] arr) {
			return arr.Length;
		}

		public int strlen(String str) {
			return str.Length;
		}

		public int strIndexOf(String str, String substr) {
			return str.IndexOf(substr);
		}

		public int strRangeIndexOf(String str, String substr, int start, int end) {
			if (start < 0) start = 0;
			if (end > str.Length) end = str.Length;
			int count = end - start;
			return (count > 0) ? str.IndexOf(substr, start, count) : -1;
		}

		public String substring(String str, int start, int length) {
			int len = str.Length;
			int end = start+length;
			int len2 = (end > len ? len : end) - start;
			if (len2 < 0)
				len2 = 0;
			return str.Substring(start, len2);
		}

		public String toLowerCase(String str) {
			return str.ToLower();
		}

		public String toUpperCase(String str) {
			return str.ToUpper();
		}

		public Object[] string2utf8(String str) {
			var utf8 = Encoding.UTF8;
			byte[] b = utf8.GetBytes(str);
			Object[] rv = new Object[b.Length];
			for (int i = 0; i < b.Length; i++)
				rv[i] = ((int)b[i]) & 0xFF;
			return rv;
		}

		public Object[] s2a(String str) {
			int l = str.Length;
			Object[] rv = new Object[l];
			for (int i = 0; i < l; i++)
				rv[i] = ((int)str[i])&0xFFFF;
			return rv;
		}

		public String list2string(Struct list) {
			String rv = "";
			for (Struct cur = list;;) {
				Object[] data = cur.getFields();
				if (data.Length == 0)
					break;
				rv = ((String)data[0]) + rv;
				cur = (Struct)data[1];
			}
			return rv;
		}

		public Object[] list2array(Struct list) {
			int count = 0;
			for (Struct cur = list;;) {
				Object[] data = cur.getFields();
				if (data.Length == 0)
					break;
				count++;
				cur = (Struct)data[1];
			}
			Object[] rv = new Object[count];
			for (Struct cur = list;;) {
				Object[] data = cur.getFields();
				if (data.Length == 0)
					break;
				rv[--count] = data[0];
				cur = (Struct)data[1];
			}
			return rv;
		}

		public int bitXor(int a, int b) {
			return a^b;
		}

		public int bitAnd(int a, int b) {
			return a&b;
		}

		public int bitOr(int a, int b) {
			return a|b;
		}

		public int bitNot(int a) {
			return ~a;
		}

		public Object[] concat(Object[] a, Object[] b) {
			Object[] rv = new Object[a.Length + b.Length];
			Array.Copy(a, 0, rv, 0, a.Length);
			Array.Copy(b, 0, rv, a.Length, b.Length);
			return rv;
		}

		public Object[] replace(Object[] a, int i, Object v) {
			if (a == null || i < 0)
				return new Object[0];
			Object[] rv = new Object[a.Length > i ? a.Length : i+1];
			Array.Copy(a, 0, rv, 0, a.Length);
			rv[i] = v;
			return rv;
		}

		public Object[] map(Object[] arr, Func1 clos) {
			Object[] rv = new Object[arr.Length];
			for (int i = 0; i < arr.Length; i++)
				rv[i] = clos(arr[i]);
			return rv;
		}

		public Object iter(Object[] arr, Func1 clos) {
			for (int i = 0; i < arr.Length; i++)
				clos(arr[i]);
			return null;
		}

		public Object[] mapi(Object[] arr, Func2 clos) {
			Object[] rv = new Object[arr.Length];
			for (int i = 0; i < arr.Length; i++)
				rv[i] = clos(i, arr[i]);
			return rv;
		}

		public Object iteri(Object[] arr, Func2 clos) {
			for (int i = 0; i < arr.Length; i++)
				clos(i, arr[i]);
			return null;
		}

		public int iteriUntil(Object[] arr, Func2 clos) {
			for (int i = 0; i < arr.Length; i++)
				if ((bool)clos(i, arr[i]))
					return i;
			return arr.Length;
		}

		public int elemIndex(Object[] arr, Object item, int illegal) {
			for (int i = 0; i < arr.Length; i++)
				if (FlowRuntime.compareByValue(arr[i], item) == 0)
					return i;
			return illegal;
		}

		public object fold(Object[] arr, object init, Func2 clos) {
			for (int i = 0; i < arr.Length; i++)
				init = clos(init, arr[i]);
			return init;
		}

		public object foldi(Object[] arr, object init, Func3 clos) {
			for (int i = 0; i < arr.Length; i++)
				init = clos(i, init, arr[i]);
			return init;
		}

		public Object[] filter(Object[] arr, Func1 test) {
			bool[] tmp = new bool[arr.Length];
			int count = 0;
			for (int i = 0; i < arr.Length; i++)
				if (tmp[i] = (bool)test(arr[i]))
					count++;
			Object[] outv = new Object[count];
			for (int i = 0, j = 0; i < arr.Length; i++)
				if (tmp[i])
					outv[j++] = arr[i];
			return outv;
		}

		public bool exists(Object[] arr, Func1 test) {
			for (int i = 0; i < arr.Length; i++)
				if ((bool)test(arr[i]))
					return true;
			return false;
		}

		private Random rng = new Random();

		public double random() {
			return rng.NextDouble();
		}

		//private Timer timer_obj = null;

		//public void invokeCallback(Runnable cb) {
		//	cb.run();
		//}

		public virtual Object timer(int ms, Func0 cb) {
			/*if (timer_obj == null)
				timer_obj = new Timer(true);

			TimerTask task = new TimerTask() {
				public void run() {
					invokeCallback(new Runnable() {
						public void run() {
							synchronized (runtime) {
								cb.invoke();
							}
						}
					});
				}
			};
			timer_obj.schedule(task, ms);*/

			return null;
		}

		public double sin(double a) {
			return Math.Sin(a);
		}

		public double asin(double a) {
			return Math.Asin(a);
		}

		public double acos(double a) {
			return Math.Acos(a);
		}

		public double atan(double a) {
			return Math.Atan(a);
		}

		public double atan2(double a, double b) {
			return Math.Atan2(a, b);
		}

		public double exp(double a) {
			return Math.Exp(a);
		}

		public double log(double a) {
			return Math.Log(a);
		}

		public Object[] enumFromTo(int from, int to) {
			int n = to - from + 1;
			if (n < 0)
				return new Object[0];
			Object[] rv = new Object[n];
			for (int i = 0; i < n; i++)
				rv[i] = from + i;
			return rv;
		}

		private static readonly DateTime Jan1st1970 = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);

		public double timestamp() {
			return (DateTime.UtcNow - Jan1st1970).TotalMilliseconds;
		}

		private string loader_url = "https://localhost/flow/";
		private Dictionary<string, string> url_args;

		public void setLoaderURL(Uri url)
		{
			loader_url = url.ToString();
			url_args = new Dictionary<string, string>();

			if (url.Query != "")
			{
#if WINDOWS_APP
				var decoder = new WwwFormUrlDecoder(url.Query);

				foreach (var item in decoder)
					url_args.Add(item.Name, item.Value);
#else
				// TODO
#endif
			}
		}

		public Object[][] getAllUrlParameters() {
			if (url_args == null) {
				return new Object[0][];
			}

			object[][] parameters = new object[url_args.Count][];
            for (int j = 0; j < parameters.Length; j++)
            {
                parameters[j] = new object[2];
            }
            int i = 0;
            foreach (var item in url_args) {
				parameters[i][0] = item.Key;
				parameters[i][1] = item.Value;

				i++;
			}

			return parameters;
		}

		public String getUrlParameter(String name) {
			string val;
			if (url_args == null || !url_args.TryGetValue(name, out val))
				val = "";
			return val;
		}

		public String loaderUrl() {
			return loader_url;
		}

		public virtual String getTargetName() {
			return "csharp,mobile,nativevideo";
		}

		public virtual bool setKeyValue(String k, String v) {
			return false;
		}

		public virtual String getKeyValue(String k, String def) {
			return def;
		}

		public virtual object removeKeyValue(String k) {
			return null;
		}

		public virtual object removeAllKeyValues() {
			return null;
		}

		public virtual Object[] getKeysList() {
			return null;
		}

		public Object profileStart(String n) {
			return null;
		}

		public Object profileEnd(String n) {
			return null;
		}

		public Object profileCount(String n, int c) {
			return null;
		}

		public Object profileDump(String n) {
			return null;
		}

		public Object profileReset() {
			return null;
		}

		public Object clearTrace() {
			return null;
		}

		public double getTotalMemoryUsed()
		{
			return (double)GC.GetTotalMemory(false);
		}

		protected static object no_op() { return null; }

		public virtual Func0 addPlatformEventListener(string name, Func0 cb)
		{
			return no_op;
		}

		public virtual Func0 addCameraPhotoEventListener(Func5 cb)
		{
			return no_op;
		}

		public virtual void notifyCameraEvent(int code, string message, string additionalInfo, int width, int height)
		{
			return;
		}

		public Func0 addCrashHandler(Func1 cb)
		{
			return no_op;
		}

		public Object printCallstack() {
#if WINDOWS_APP
#else
			Console.WriteLine(System.Environment.StackTrace);
#endif
			return null;
		}

		public Object captureCallstack() {
			return null;
		}
		public Object captureCallstackItem(int index) {
			return null;
		}
		public Object impersonateCallstackItem(Object item, int index) {
			return null;
		}
		public Object impersonateCallstackFn(Object item, int index) {
			return null;
		}
		public Object impersonateCallstackNone(int index) {
			return null;
		}

		public Object failWithError(String n) {
			throw new Exception("Runtime failure: "+n);
		}

		public Object makeStructValue(String name, Object[] args, Object defval) {
			return runtime.makeStructValue(name, args, (Struct)defval);
		}

		public Object quit(int c) {
#if WINDOWS_APP
#else
			System.Environment.Exit(c);
#endif
			return null;
		}

		public String fromCharCode(int c) {
			return new String(new char[] { (char)c });
		}

		public int getCharCodeAt(String s, int i) {
			return (i>=0 && i < s.Length) ? (int)s[i] : -1;
		}

		public double number2double(Object n) {
			return (n is int) ? (double)(int)n : (double)n;
		}

		public Struct getCurrentDate() {
			DateTime date = DateTime.Now;
			return runtime.makeStructValue("Date", new Object[] { date.Year, date.Month, date.Day }, null);
		}

		public int dayOfWeek(int year, int month, int day)
		{
			DateTime time = new DateTime(year, month, day);
			var wday = time.DayOfWeek;

			// C# enum starts with Sunday
			if (wday == DayOfWeek.Sunday)
				return 6;
			else
				return (int)wday - (int)DayOfWeek.Monday;
		}

		private static readonly DateTime epoch = DateTime.SpecifyKind(new DateTime(1970, 1, 1, 0, 0, 0), DateTimeKind.Utc);
		private static readonly string format_full = "yyyy'-'MM'-'dd HH':'mm':'ss";
		private static readonly string format_date = "yyyy'-'MM'-'dd";
		private static readonly string[] format_any = new string[] { format_full, format_date };

		private double tzOffset = (epoch.AddMilliseconds(100000).ToLocalTime().Subtract(epoch).TotalMilliseconds - epoch.AddMilliseconds(100000).ToUniversalTime().Subtract(epoch).TotalMilliseconds) / 2;

		public double utc2local(double stamp) {
			return stamp + tzOffset;
			//return epoch.AddMilliseconds(stamp).ToLocalTime().Subtract(epoch).TotalMilliseconds;
		}

		public double local2utc(double stamp) {
			return stamp - tzOffset;
			//return epoch.AddMilliseconds(stamp).ToUniversalTime().Subtract(epoch).TotalMilliseconds;
		}

		public String time2string(double msec) {
			return epoch.AddMilliseconds(msec).ToLocalTime().ToString(format_full, CultureInfo.InvariantCulture);
		}

		public double string2time(String tv) {
			DateTime time = DateTime.ParseExact(tv, format_any, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal);
			return time.ToUniversalTime().Subtract(epoch).TotalMilliseconds;
		}

		public virtual object getUrl(String u, String t) {
			// TODO
			return null;
		}

		public String getFileContent(String name) {
			/*try {
				byte[] encoded = Files.readAllBytes(Paths.get(name));
				return new String(encoded, StandardCharsets.UTF_8);
			} catch (IOException e) {
				return "";
			}*/
			return "";
		}

		public String getFileContentBinary(String name)
		{
			return "";
		}

		public object startProcess(string name, object[] args, string cwd, string stdin, Func3 onExit)
		{
			onExit(-1, "", "");
			return null;
		}

		public object runProcess(string name, object[] args, string cwd, Func1 onstdout, Func1 onstderr, Func1 onExit)
		{
			onExit(-1);
			return null;
		}

		public bool startDetachedProcess(string name, object[] args, string cwd)
		{
			return false;
		}

		public object writeProcessStdin(Object process, string arg)
		{
			return null;
		}

		public object killProcess(Object process)
		{
			return null;
		}

		public bool setFileContent(String name, String data) {
			/*Writer writer = null;

			try {
				writer = new BufferedWriter(new OutputStreamWriter(
					new FileOutputStream(name), "utf-8")
				);
				writer.write(data);
			} catch (IOException ex) {
			} finally {
				try {
					writer.close();
					return true;
				} catch (Exception ex) {}
			}*/
			return false;
		}

		private struct BinaryDeserializer
		{
			readonly Native parent;
			readonly string input;
			readonly object defval;

			int char_idx, input_size;
			bool error;

			readonly Struct illegal;

			public BinaryDeserializer(Native parent, string input, object defval)
			{
				this.parent = parent;
				this.input = input;
				this.input_size = input.Length;
				this.defval = defval;

				char_idx = 0;
				error = false;

				illegal = parent.runtime.makeStructValue("IllegalStruct", new object[0], null);

				structPrototype = null;
				structSize = null;
				structFixups = null;
			}

			int readChars(int count)
			{
				int new_idx = char_idx + count;
				if (new_idx < char_idx || new_idx > input_size)
				{
					error = true;
					return -1;
				}

				int cur_idx = char_idx;
				char_idx = new_idx;
				return cur_idx;
			}

			char readChar()
			{
				int idx = readChars(1);
				return (idx < 0) ? (char)0 : input[idx];
			}
			int readInt32()
			{
				int idx = readChars(2);
				return (idx < 0) ? 0 : (((int)input[idx]) | (((int)input[idx + 1]) << 16));
			}
			int readInteger()
			{
				int idx = readChars(1);
				if (idx < 0) return 0;

				int cv = (int)input[idx];
				if (cv == 0xFFF5)
					return readInt32();
				else if (cv <= 0x7FFF)
					return cv;
				else
				{
					error = true;
					return 0;
				}
			}
			int readArraySize()
			{
				int idx = readChars(1);
				if (idx < 0) return 0;

				int cv = (int)input[idx];
				switch (cv)
				{
					case 0xFFF7:
						return 0;
					case 0xFFF8:
						return (int)readChar();
					case 0xFFF9:
						return readInt32();
					default:
						error = true;
						return 0;
				}
			}
			string readString()
			{
				int idx = readChars(1);
				if (idx < 0) return "";

				int len = 0;
				switch ((int)input[idx])
				{
					case 0xFFFA:
						len = (int)readChar();
						break;
					case 0xFFFB:
						len = readInt32();
						break;
					default:
						error = true;
						return "";
				}

				idx = readChars(len);
				if (idx < 0) return "";

				return input.Substring(idx, len);
			}

			private Struct[] structPrototype;
			private int[] structSize;
			private Func1[] structFixups;

			void readStructIndex(Func1 fixups)
			{
				int offset = readInt32();

				if (error || offset < char_idx || offset >= input_size)
				{
					error = true;
					return;
				}

				int old_pos = char_idx;
				char_idx = offset;

				int isize = readArraySize();
				structPrototype = new Struct[isize];
				structSize = new int[isize];
				structFixups = new Func1[isize];

				for (int i = 0; i < isize; i++)
				{
					if (readArraySize() != 2)
					{
						error = true;
						return;
					}

					int fcount = readInteger();
					string name = readString();

					structPrototype[i] = parent.runtime.findStructPrototype(name);
					structSize[i] = fcount;

					if (fixups != null)
					{
						Struct tmp = (Struct)fixups(name);
						object[] data = tmp.getFields();

						// Some(fixup_cb)
						if (data.Length > 0)
							structFixups[i] = (Func1)data[0];
					}
				}

				char_idx = old_pos;
				input_size = offset;
			}

			object readValue()
			{
				int codeval = (int)readChar();
				if (error)
					return defval;

				switch (codeval)
				{
					case 0xFFFF:
						return null;
					case 0xFFFC:
					{
						int idx = readChars(4);
						if (idx < 0) return defval;

						long val = ((long)input[idx] & 0xFFFF) | (((long)input[idx+1] & 0xFFFF) << 16) |
							(((long)input[idx+2] & 0xFFFF) << 32) | ((long)input[idx+3] << 48);
						return BitConverter.Int64BitsToDouble(val);
					}
					case 0xFFFD:
						return false;
					case 0xFFFE:
						return true;
					case 0xFFFA:
					case 0xFFFB:
						char_idx--;
						return readString();
					case 0xFFF6:
						return new Reference(readValue());
					case 0xFFF4:
					{
						int idx = readChar();
						if (error || idx >= structSize.Length)
						{
							error = true;
							return defval;
						}

						int size = structSize[idx];
						object[] arr = new object[size];

						for (int i = 0; i < size; i++)
							arr[i] = readValue();

						// Apply fixup if any
						if (structFixups[idx] != null)
							return structFixups[idx](arr);

						try {
							Struct obj = structPrototype[idx].Clone();
							obj.setFields(arr);
							return obj;
						} catch (Exception) {
							return illegal;
						}
					}
					case 0xFFF7:
					case 0xFFF8:
					case 0xFFF9:
					{
						char_idx--;
						int size = readArraySize();
						if (size > input_size - char_idx)
							error = true;
						if (error)
							return defval;

						object[] arr = new object[size];

						for (int i = 0; i < size; i++)
							arr[i] = readValue();

						return arr;
					}
					case 0xFFF5:
						return readInt32();
					default:
						if (codeval <= 0x7FFF)
							return codeval;
						error = true;
						return defval;
				}
			}

			public object deserialize(Func1 fixups)
			{
			    char_idx = 0;
			    error = false;

				readStructIndex(fixups);
				if (error)
					return defval;

				object rv = readValue();

				if (char_idx < input_size)
					parent.println("Did not understand all!");
				return rv;
			}
		}

		public object fromBinary(string str, object defval, Func1 subs)
		{
			BinaryDeserializer decoder = new BinaryDeserializer(this, str, defval);

			return decoder.deserialize(subs);
		}

		public int stringbytes2int(string data)
		{
			return ((int)data[0] & 0xFFFF) | ((int)data[1] << 16);
		}

		public double stringbytes2double(string data)
		{
			long val = ((long)data[0] & 0xFFFF) | (((long)data[1] & 0xFFFF) << 16) |
				(((long)data[2] & 0xFFFF) << 32) | ((long)data[3] << 48);
			return BitConverter.Int64BitsToDouble(val);
		}
	}
}

