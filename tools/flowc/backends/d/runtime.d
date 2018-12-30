// D runtime starts here
//alias Flow = Variant;
import std.stdio;
import std.functional;

FlowArray concatNative(FlowArray a, FlowArray b) {
  return new FlowArray(a.value ~ b.value);
}

FlowArray enumFromToNative (FlowInteger from, FlowInteger to) {
  // TODO Possibly use iota() function instead.
  int n = to.value - from.value + 1;
  if (n < 0) return new FlowArray([]);
  FlowObject[] rv = new FlowInteger[n];
  for (int i = 0; i < n; i++)
    rv[i] = new FlowInteger(from.value + i);
  return new FlowArray(rv);
}

FlowArray filterNative(FlowArray xs, FlowFunction1 test) {
  import std.algorithm;
  import std.array;
  // Please refer to
  //   http://www.informit.com/articles/printerfriendly/1407357
  //   http://ddili.org/ders/d.en/ranges.html
  //   http://forum.dlang.org/post/op.wclqkysjeav7ka@localhost.localdomain
  // to understand all those tricks behind this.
  //
  // xs[] is a slice (range), which is filtered with test function,
  // which must be passed as pointer (&fn) by caller.
  // The last step is to apply range to source array and return array,
  // not slice from filter result.
  //return std.array.array(std.algorithm.filter!test.value(xs.value));
  // TODO :)
  return new FlowArray([]);
}

// R foldNative(T, R)(T[] xs, R init, R delegate(R a, T b) fn) {
//   R init2 = init;
//   foreach(int i, T item; xs) {
//     init2 = fn(init2, item);
//   }
//   return init2;
// }

FlowObject foldNative(FlowArray xs, FlowObject init, FlowFunction2 fn) {
  FlowObject init2 = init;
  foreach(FlowObject item; xs) {
    init2 = fn(init2, item);
  }
  return init2;
}


FlowObject foldiNative(FlowArray xs, FlowObject init, FlowFunction3 fn) {
  FlowObject init2 = init;
  int i = 0;
  foreach(FlowObject item; xs) {
    init2 = fn(new FlowInteger(i), init2, item);
    i += 1;
  }
  return init2;
}

FlowVoid iterNative(FlowArray xs, FlowFunction1 fn) {
  foreach(FlowObject item; xs) {
    fn(item);
  }
  return new FlowVoid();
}

FlowVoid iteriNative(FlowArray xs, FlowFunction2 fn) {
  int i = 0;
  foreach(FlowObject item; xs) {
    fn(new FlowInteger(i), item);
    i = i + 1;
  }
  return new FlowVoid();
}

FlowInteger iteriUntilNative(FlowArray xs, FlowFunction2 fn) {
  int i = -1;
  foreach(FlowObject item; xs) {
    i += 1;
    auto ii = new FlowInteger(i);
    if ((cast(FlowBool)fn(ii, item)).value) {
      return ii;
    }
  }
  return new FlowInteger(xs.length());
}

FlowArray mapNative(FlowArray xs, FlowFunction1 fn) {
  FlowObject[] res = new FlowObject[xs.length()];
  foreach(int i, FlowObject item; xs.value) {
    res[i] = fn(item);
  }
  return new FlowArray(res);
}

FlowArray mapiNative(FlowArray xs, FlowFunction2 fn) {
  FlowObject[] res = new FlowObject[xs.length()];
  foreach(int i, FlowObject item; xs.value) {
    res[i] = fn(new FlowInteger(i), item);
  }
  return new FlowArray(res);
}

FlowInteger lengthNative(FlowArray a) {
  return new FlowInteger(a.length());
}

FlowArray replaceNative(FlowArray xs, FlowInteger i, FlowObject e) {
  if (i < new FlowInteger(0))
    return new FlowArray([]);
  FlowInteger xsl = new FlowInteger(xs.length());
  FlowObject[] rv = new FlowObject[xsl > i ? xsl.value : i.value + 1];
  // Actual copying
  //rv[0..xs.length] = xs[0..xs.length];
  rv[0..xsl.value] = xs.value[0..xsl.value];
  rv[i.value] = e;
  return new FlowArray(rv);
}

FlowArray subrangeNative(FlowArray xs, FlowInteger index, FlowInteger len) {
  if (index < new FlowInteger(0) || len < new FlowInteger(1) || index >= new FlowInteger(xs.length())) return new FlowArray([]);
  FlowInteger ln = new FlowInteger(len.value);
  FlowInteger end = index + len;
  FlowInteger xsl = new FlowInteger(xs.length());
  if (end > xsl || end < new FlowInteger(0)) {
    ln = xsl - index;
  }
  FlowObject[] rv = new FlowObject[cast(ulong)ln.value];
  rv[] = xs.value[index.value..(index+ln).value];
  return new FlowArray(rv);
}

FlowBool isArrayNative(FlowObject a) {
  auto arr = cast(FlowArray)a;
  return new FlowBool(arr !is null);
}

FlowVoid failWithErrorNative(FlowString s) {
  writeln(s.value);
  // TODO: Does not exit gracefully.
  import std.c.stdlib;
  exit(255);
  return new FlowVoid();
}

string getClipboardNative() {
  writeln("TODO: getClipboardNative stub called");
  return "";
}

string setClipboardNative(string text) {
  writeln("TODO: setClipboardNative stub called");
  return "";
}

string getClipboardFormatNative(string mimetype) {
  writeln("TODO: setClipboardFormatNative stub called");
  return "";
}

FlowVoid gcNative() {
  import core.memory;
  GC.collect();
  return new FlowVoid();
}


FlowInteger bitNotNative(FlowInteger a) {
  return ~a;
}

FlowInteger bitAndNative(FlowInteger a, FlowInteger b) {
  return a & b;
}

FlowInteger bitOrNative(FlowInteger a, FlowInteger b) {
  return a | b;
}

FlowInteger bitXorNative(FlowInteger a, FlowInteger b) {
  return a ^ b;
}

FlowVoid fcPrintlnNative(FlowObject a) {
  auto str = cast(FlowString)a;
  if (str is null)
    writeln(a);
  else
    writeln(str.value);
  return new FlowVoid();
}

bool isSameObjNative(T1, T2)(T1 a, T2 b) {
  // TODO: Probably incorrect
  return a == b;
}
/*
bool isSameStructTypeNative(T1, T2)(T1 a, T2 b) {
  import std.algorithm;
  auto ta = typeid(T1).toString();
  auto tb = typeid(T2).toString();
  auto m = mismatch(ta, tb);
  return (m[0] == "") && (m[1] == "");
}
*/

FlowBool isSameStructTypeNative(FlowObject a, FlowObject b) {
  import std.algorithm;
  FlowStruct ta = cast(FlowStruct)a;
  FlowStruct tb = cast(FlowStruct)b;
  if ((ta is null) || (tb is null)) return new FlowBool(false);
  return new FlowBool((ta.getTypeId() == tb.getTypeId()) && (ta.getTypeId() != -1));
}

void makeStructValueNative(string structname, void*[] args, void* default_value) {
  writeln("TODO: makeStructValueNative stub called");
}

FlowString hostCallNative(FlowString name, FlowArray args) {
  writeln("TODO: hostCallNative stub called");
  return new FlowString("");
}

void quitNative(int exitCode) {
  import std.c.stdlib;
  exit(exitCode);
}

void* captureCallstackNative() {
  writeln("TODO: captureCallstackNative stub called");
  return null;
}

void* captureCallstackItemNative(int index) {
  writeln("TODO: captureCallstackItemNative stub called");
  return null;
}

void clearTraceNative() {
  writeln("TODO: clearTraceNative stub called");
}

void profileStartNative(string bucket) {
  writeln("TODO: profileStartNative stub called");
}

void profileEndNative(string bucket) {
  writeln("TODO: profileEndNative stub called");
}

void profileCountNative (string bucket, double time) {
  writeln("TODO: profileCountNative stub called");
}

void profileDumpNative(string name) {
  writeln("TODO: profileDumpNative stub called");
}

void profileResetNative() {
  writeln("TODO: profileResetNative stub called");
}

FlowString getApplicationPathNative() {
  import std.file;
  return new FlowString(thisExePath());
}

FlowString getCurrentDirectoryNative() {
  import std.file;
  return new FlowString(getcwd());
}

void setCurrentDirectoryNative(string path) {
  import std.file;
  chdir(path);
}

bool setKeyValueNative(string k, string v) {
  writeln("TODO: setKeyValueNative stub called");
  return false;
}

string getKeyValueNative(string k, string def) {
  writeln("TODO: getKeyValueNative stub called");
  return def;
}

void removeKeyValueNative(string k) {
  writeln("TODO: removeKeyValueNative stub called");
}

void printCallstackNative() {
  writeln("TODO: printCallstackNative stub called");
}

void impersonateCallstackItemNative(void* item, int index) {
  writeln("TODO: impersonateCallstackItemNative stub called");
}

double randomNative() {
  import std.random;
  Random gen;
  auto r = uniform(0.0L, 1.0L, gen);
  return r;
}

double number2doubleNative(T)(T a) {
  if (__traits(isArithmetic, a)) {
    return cast(double)a;
  } else {
    // TODO
    // Normally should never happen.
    // Probably Exception should be raised.
    return 0.0;
  }
}

void hostAddCallbackNative (string name, void* delegate()) {
  writeln("TODO: hostAddCallbackNative stub called");
}

string time2stringNative(double time) {
  writeln("TODO: time2stringNative stub called");
  return "";
}

double string2timeNative(string tv) {
  writeln("TODO: string2timeNative stub called");
  return 0.0;
}

double timestampNative() {
  import std.datetime;
  auto tv = Clock.currTime.toTimeVal();
  return (tv.tv_sec + tv.tv_usec * 1.0E-6)*1000.0;
}

void timerNative(int i, void delegate () fn) {
  writeln("TODO: timerNative stub called");
}

FlowString toStringNative(FlowObject a) {
  return new FlowString(a.toString());
}

FlowString getFileContentNative(FlowString name) {
  import std.file;
  import std.utf;
  string result = "";
  try {
    auto txt = readText(name.value);
    return new FlowString(txt);
  }
  catch (Exception e) {
    
  }
  return new FlowString(result);
}

FlowBool setFileContentUTF16Native(FlowString name, FlowString content) {
  writeln("TODO: setFileContentUTF16Native stub called");
  return new FlowBool(true);
}

FlowBool setFileContentNative(FlowString name, FlowString content) {
  import std.utf;
  import std.file;
		   
  try {
    auto c = toUTF8(content.value);
    auto f = File(name.value, "w");
    f.write(c);
    f.close();
  }
  catch(Exception e) {
    return new FlowBool(false);
  }
  return new FlowBool(true);
}

FlowBool setFileContentBytesNative(FlowString name, FlowString content) {
  writeln("TODO: setFileContentBytesNative stub called");
  return new FlowBool(true);
}

string loaderUrlNative() {
  writeln("TODO: loaderUrlNative stub called");
  return "";
}

string getUrlNative(string u, string t) {
  writeln("TODO: getUrlNative stub called");
  return "";
}

string getUrlParameterNative(string name) {
  writeln("TODO: getUrlParameterNative stub called");
  return "";
}

FlowString list2stringNative(List lst) {
  writeln("TODO: list2stringNative stub called");
  return new FlowString("");
}

FlowArray list2arrayNative(List lst) {
  writeln("TODO: list2arrayNative stub called");
  return new FlowArray([]);
}

FlowString fromCharCodeNative(FlowInteger i) {
  writeln("TODO: fromCharCodeNative stub called");
  return new FlowString("");
}

FlowInteger getCharCodeAtNative(FlowString s, FlowInteger i) {
  writeln("TODO: getCharCodeAtNative stub called");
  return new FlowInteger(0);
}

FlowArray s2aNative (FlowString s) {
  writeln("TODO: s2aNative stub called");
  return new FlowArray([]);
}


FlowInteger strIndexOfNative (FlowString str, FlowString substr) {
  writeln("TODO: strIndexOfNative stub called");
  return new FlowInteger(0);
}

FlowArray string2utf8Native(FlowString s) {
  writeln("TODO: string2utf8Native stub called");
  return new FlowArray([]);
}

FlowInteger strlenNative(FlowString str) {
  return str.length();
}

FlowString substringNative(FlowString s, FlowInteger start, FlowInteger len) {
  writeln("TODO: substringNative stub called");
  return new FlowString("");
}

double expNative (double e) {
  import std.math;
  return std.math.exp(e);
}

double logNative (double e) {
  import std.math;
  return std.math.log(e);
}

string getTargetNameNative() {
  return "dlang";
}

FlowString toLowerCaseNative(FlowString s) {
  import std.uni;
  return new FlowString(toLower(s.value));
}

FlowString toUpperCaseNative(FlowString s) {
  import std.uni;
  return new FlowString(toUpper(s.value));
}

FlowArray getAllUrlParametersNative() {
  writeln("TODO: getAllUrlParametersNative stub called");
  return new FlowArray([]);
}

FlowString createDirectoryFlowFileSystem(FlowString dir) {
  import std.file;
  std.file.mkdir(dir.value);
  return new FlowString("");
}

FlowString deleteFileFlowFileSystem(FlowString fname) {
  import std.file;
  std.file.remove(fname.value);
  return new FlowString("");
}

FlowBool fileExistsFlowFileSystem(FlowString fname) {
  import std.file;
  return new FlowBool(std.file.exists(fname.value));
}

double fileModifiedFlowFileSystem(string fname) {
  writeln("TODO: fileModifiedFlowFileSystem stub called");
  return 0.0;
}

FlowBool isDirectoryFlowFileSystem(FlowString fname) {
  import std.file;
  return new FlowBool(std.file.isDir(fname.value));
}

string[] readDirectoryFlowFileSystem(string dname) {
  writeln("TODO: readDirectoryFlowFileSystem stub called");
  return new string[0];
}

FlowString resolveRelativePathFlowFileSystem (FlowString path) {
  writeln("TODO: resolveRelativePathFlowFileSystem stub called");
  return new FlowString("");
}

void startProcessNative (string command, string[] args, string currentWorkingDirectory, string stdin, void delegate (int errorcode, string stdout, string stderr) onExit) {
  writeln("TODO: startProcessNative stub called");
}

string toBinaryNative(T)(T value) {
  writeln("TODO: toBinaryNative stub called");
  return "";
}

FiType getFiExpInfo(FiExp e) {
  if (cast(FiLambda)e) {
    return (cast(FiLambda)e).type;
  } else if (cast(FiCall)e) {
    return (cast(FiCall)e).type;
  } else if (cast(FiVar)e) {
    return (cast(FiVar)e).type;
  } else if (cast(FiLet)e) {
    return (cast(FiLet)e).type;
  } else if (cast(FiIf)e) {
    return (cast(FiIf)e).type;
  } else if (cast(FiSwitch)e) {
    return (cast(FiSwitch)e).type;
  } else if (cast(FiCast)e) {
    return (cast(FiCast)e).type;
  } else if (cast(FiSeq)e) {
    return (cast(FiSeq)e).type;
  } else if (cast(FiCallPrim)e) {
    return (cast(FiCallPrim)e).type;
  } else if (cast(FiRequire)e) {
    return (cast(FiRequire)e).type;
  } else if (cast(FiUnsafe)e) {
    return (cast(FiUnsafe)e).type;
  } else if (cast(FiVoid)e) {
    return new FiTypeVoid();
  } else if (cast(FiDouble)e) {
    return new FiTypeDouble();
  } else if (cast(FiInt)e) {
    return new FiTypeInt();
  } else if (cast(FiString)e) {
    return new FiTypeString();
  } else if (cast(FiBool)e) {
    return new FiTypeBool();
  } else {
    assert(0, "No type found");
  }
}


// End of D runtime
