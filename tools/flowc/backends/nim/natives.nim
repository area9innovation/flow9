import std/times
import std/random

#[
    Native definitions
]#

proc println2*[T](x : T): void =
  let s: string = when x is Flow:
    if x.tp == rtString: x.string_v else: rt_to_string(x)
  else: rt_to_string(x)
  echo s

# Get a subrange of an array from index
# if index < 0 or length < 1 it returns an empty array
proc subrange*[T](s: seq[T], index: int32, length : int32): seq[T] {.inline.} =
  s[index, index + len]

proc length*[T](s: seq[T]): int32 {.inline.} =
  cast[int32](len(s))

proc concat*[T](s1, s2: seq[T]): seq[T] {.inline.} =
  sequtils.concat(s1, s2)

proc map*[T, S](s: seq[T], op: proc (x: T): S): seq[S] {.inline.} =
  sequtils.map(s, op)

# Replace a given element in an array with a new value. Makes a copy
#native replace : ([?], int32, ?) -> [?] = Native.replace;
proc replace*[T](s: seq[T], i: int32, v: T): seq[T] =
  #if i < 0 or s == nil:
  if i < 0 or len(s) == 0:
    return @[]
  else:
    var s1 = s & @[] # Copy of s
    if cast[int32](len(s1)) > i:
      s1[i] = v
    else:
      add(s1, v) # Append item to the end of array, increasing length
    return s1

# Apply a function which takes an index and each element of an array to give a new array
proc mapi*[T, S](s: seq[T], op: proc (i: int32, v: T): S): seq[S] =
  var rv: seq[S] = newSeq[S](length(s))
  var i : int32 = 0
  while i < s.len:
    rv[i] = op(i, s[i])
    inc i
  #for i in 0 .. s.len-1:
  #  rv[i] = op(i, s[i])
  return rv

proc enumFromTo*(f: int32, t: int32): seq[int32] =
  var n: int32 = t - f + 1
  var rv: seq[int32]

  if (n < 0):
    rv = @[]
    return rv

  for i in 0 .. n-1:
    rv.add(f + i)

  return rv

# Apply a collecting function.  This is a left fold, i.e., it folds with the start of
# the array first, i.e., fold([x1, x2, x3], x0, o) = ((x0 o x1) o x2) o x3
proc fold*[T, S](arr: seq[T], init: S, op: proc(acc: S, v: T): S): S =
  var ini = init
  for x in arr:
    ini = op(ini, x)
  return ini

# Apply a collecting function which takes an index, initial value and each element
proc foldi*[T, S](xs: seq[T], init: S, fn: proc(idx: int32, acc: S, v: T): S): S =
  var ini = init
  for i in 0..length(xs) - 1:
    ini = fn(i, ini, xs[i])
  return ini

# Creates a new array, whose elements are selected from 'a' with a condition 'test'.
proc filter*[T](a: seq[T]; test: proc (v: T): bool): seq[T] =
  return sequtils.filter(a, test)

# Apply a function which takes an index and each element of an array until it returns true
# Returns index of last element function was applied to.
proc iteriUntil*[T](a: seq[T], op: proc(idx: int32, v: T): bool): int32 =
  for i in 0..length(a) - 1:
    if op(i, a[i]):
      return i
  return length(a)

# Apply a function to each element of an array
proc iter*[T](a: seq[T], op: proc (v: T): void): void =
  for x in a:
    op(x)
  return

# Apply a function to each element of an array
proc iteri*[T](a: seq[T], op: proc (idx : int32, v: T): void): void =
  for i in 0..length(a) - 1:
    op(i, a[i])
  return

proc isSameStructType*[T1, T2](a: T1, b: T2): bool =
  when (a is Struct) and (b is Struct):
    return a.id == b.id
  else:
    return false

proc getUrlParameter*(name: string): string =
  echo "TODO: Implement getUrlParameter"
  ""

proc toString*[T](x: T): string =
  when x is Flow:
    if x.tp == rtString:
      return x.string_v
    else:
      return rt_to_string(x)
  else:
    return rt_to_string(x)

proc toString2*(x: Flow): string =
  if x.tp == rtString:
    return x.string_v
  else:
    return rt_to_string(x)

proc strlen*(s: string): int32 =
  return cast[int32](len(s));

proc clipLenToRange(start: int32, leng: int32, size: int32): int32 =
  var leng1 = leng
  var send = start + leng
  if send > size or send  < 0:
    leng1 = size - start
  return leng1

proc substring*(str: string, start: int32, leng: int32): string =
  var slen = leng
  var sstart = start
  var strlen = cast[int32](len(str))
  if slen < 0:
    if (sstart < 0) :
      slen = 0
    else:
      var smartLen1 = slen + sstart
      if smartLen1 >= 0:
        slen = 0
      else:
        var smartLen2 = smartLen1 + strlen
        if (smartLen2 <= 0):
          slen = 0
        else:
          slen = smartLen2

  if (sstart < 0):
    var smartStart = sstart + strlen
    if (smartStart > 0):
      sstart = smartStart
    else:
      sstart = 0
  else:
    if (sstart >= strlen):
      slen = 0

    if (slen < 1):
      return "";

  slen = clipLenToRange(start, slen, strlen)
  return substr(str, sstart, sstart + slen - 1)

proc strIndexOf*(s: string, sub: string): int32 =
  return cast[int32](strutils.find(s, sub, 0))

proc toLowerCase*(s: string): string =
  return unicode.toLower(s)

proc toUpperCase*(s: string): string =
  return unicode.toLower(s)

proc getCharCodeAt*(s: string, i: int32): int32 =
  if i >= 0 and i < cast[int32](len(s)):
    return cast[int32](unicode.runeAt(s, i))
  else:
    return -1

func fromCharCode*(code: int32): string =
  return unicode.toUTF8(cast[Rune](code))

proc strsubsmart*(s: string, start: int32, fl0wlen: int32): string =
    if start >= 0 and fl0wlen > 0:
      substring(s, start, fl0wlen)
    else:
      var slen: int32 =
        strlen(s)
      var trueStart: int32 = (
        if start >= 0: (
          start
        ) else: (
          var ss: int32 =
            slen+start;
          if ss >= 0: (
            ss
          ) else:
            0
          )
        )
      var trueLength: int32 =
        if fl0wlen > 0:
          fl0wlen
        else:
          slen + fl0wlen - trueStart
      substring(s, trueStart, trueLength)

proc list2array*[T](list: Struct): seq[T] =
  var p = list
  var r = newSeq[T]()

  while true:
    if cast[StructType](p.id) == st_EmptyList:
      break
    else:
      let cons = Cons[T](p)
      r = @[cons.head] & r
      p = cons.tail
  return r

proc list2string*(list: Struct): string =
  var p = list
  var r = ""

  while true:
    if cast[StructType](p.id) == st_EmptyList:
      break
    else:
      let cons = Cons[string](p)
      r.add(cons.head)
      p = cons.tail
  return r

proc bitAnd*(x: int32, y: int32): int32 =
  return x and y

proc bitOr*(x: int32, y: int32): int32 =
  return x or y

proc bitNot*(x: int32): int32 =
  return not x

proc getKeyValueN*(key : string, defaultValue : string): string =
  echo "TODO: Implement getKeyValueN in Nim"
  return defaultValue

# native hostCall : io (name: string, args: [flow]) -> flow = Native.hostCall;

proc hostCall*(name: string, args: seq[Flow]): Flow =
  echo("hostCall of $name is not implemented")
  return Flow(tp: rtVoid)

#native quit : io (code : int32) -> void = Native.quit; - is already defined

#native timestamp : io () -> double = Native.timestamp;

proc timestamp*(): float =
  return round(epochTime() * 1000.0)

#native exp : (double) -> double = Native.exp; - is already defined


#native log : (double) -> double = Native.log;

func log*(x: float): float =
  return ln(x)

#native getAllUrlParametersArray : io () -> [[string]] = Native.getAllUrlParameters;

proc getAllUrlParametersArray*(): seq[seq[string]] =
  return newSeq[seq[string]]()

#native getTargetName : io () -> string = Native.getTargetName;
proc getTargetName*(): string =
  return "nim"

#native fail : io (msg : string) -> void = Native.failWithError;
proc fail*(error : string): void =
  echo "Runtime failure: " & error
  quit(0)

#native fail0 : io (msg : string) -> ? = Native.failWithError;
proc fail0*[T](error : string): T =
  echo "Runtime failure: " & error
  quit(0)

proc getFileContent*(path : string): string =
  # TODO: Handle exceptions
  return readFile(path)

proc setFileContent*(path : string, content : string): bool =
  # TODO: Handle exceptions and return false when problems
  writeFile(path, content)
  return true

proc fileExists*(path : string): bool =
  return fileExists(path)

proc printCallstack*(): void =
  echo getStackTrace()

proc loaderUrl*(): string =
  return ""

# STUBS FROM HERE

proc makeStructValue*(structname : string, args : seq[Flow], default_value : Flow): Flow =
  echo "TODO: Implement makeStructValue " & structname
  return default_value

# format : "2012-10-01 18:05:40"
proc string2time*(time : string): float =
  let dt = parse(time, "yyyy-MM-dd HH:mm:ss")
  return toUnixFloat(toTime(dt)) * 1000.0

# time is given in milliseconds since epoch 1970 in UTC
proc time2string*(time : float): string =
  let dt = local(fromUnixFloat(time / 1000.0))
  return dt.format("yyyy-MM-dd HH:mm:ss")

proc s2a*(s : string): seq[int32] =
  echo "Implement s2a"
  return @[]

proc string2utf8*(s : string): seq[int] =
  echo "Implement string2utf8"
  return @[]

proc httpCustomRequestNative*(url : string, method_0 : string, headers : seq[seq[string]], 
    parameters : seq[seq[string]], data : string, responseEncoding : string, 
    onResponse : proc (responseStatus : int, responseData : string, responseHeaders : seq[seq[string]]) : void, async : bool): void =
  echo "TODO: Implement httpCustomRequestNative"

# initialized with current timestamp
var randState = initRand()
proc random*(): float =
    # is 1 included?
    # randomize(234) // add to main ?
    # var r = initRand()
    # return r.rand(1.0)
    return randState.rand(1.0)
