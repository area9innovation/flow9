import sequtils
import typetraits
import strutils
import unicode
import math

# Runtime for NIM backend

type
  RtType* = enum
    rtVoid,
    rtBool,
    rtInt,
    rtDouble,
    rtString,
    rtNative,
    rtArray,
    rtFunc,
    rtStruct

#[ Representation of a dynamic type ]#

  Flow* = ref object
    case tp*: RtType
    of rtVoid:   discard
    of rtBool:   valBool: bool
    of rtInt:    valInt: int
    of rtDouble: valDouble: float
    of rtString: valString: string
    of rtNative: valNative: Native
    of rtArray:  valArray: seq[Flow]
    of rtFunc:   valFunc: proc(x: seq[Flow]): Flow
    of rtStruct:
      idStruct: int
      nameStruct: string
      valFields: seq[Flow]

  Struct* = ref object of RootObj
    id: int

  Native* = ref object of RootObj
    what: string
    val: RootObj

#[ General conversions ]#

proc rt_to_string*(): string = "{}"
proc rt_to_string*(x: int): string = intToStr(x)
proc rt_to_string*(x: float): string = formatFloat(x)
proc rt_to_string*(x: bool): string = return if (x): "true" else: "false"
proc rt_to_string*(x: string): string = x
proc rt_to_string*(x: Native): string = x.what & ":" & $(x.val)
proc rt_to_string*[T](x: seq[T]): string = 
  var s = "["
  for i in 0..x.len - 1:
    if i > 0:
      s.add(", ")
    s.add(rt_to_string(x[i]))
  s.add("]")
  return s
proc rt_to_string*(f: Flow): string = 
  case f.tp:
  of rtVoid:   return rt_to_string()
  of rtBool:   return rt_to_string(f.valBool)
  of rtInt:    return rt_to_string(f.valInt)
  of rtDouble: return rt_to_string(f.valDouble)
  of rtString: return "\"" & rt_to_string(f.valString) & "\""
  of rtNative: return rt_to_string(f.valNative)
  of rtArray:  return rt_to_string(f.valArray)
  of rtFunc:   return "<function>"
  of rtStruct:
    var s = f.nameStruct & "("
    for i in 0..f.valFields.len - 1:
        if i > 0:
           s.add(", ")
        s.add(rt_to_string(f.valFields[i]))
    s.add(")")
    return s

proc rt_to_flow*(): Flow = Flow(tp: rtVoid)
proc rt_to_flow*(b: bool): Flow = Flow(tp: rtBool, valBool: b)
proc rt_to_flow*(i: int): Flow = Flow(tp: rtInt, valInt: i)
proc rt_to_flow*(d: float): Flow = Flow(tp: rtDouble, valDouble: d)
proc rt_to_flow*(s: string): Flow = Flow(tp: rtString, valString: s)
proc rt_to_flow*(n: Native): Flow = Flow(tp: rtNative, valNative: n)
proc rt_to_flow*[T](arr: seq[T]): Flow = Flow(tp: rtArray, valArray: map(arr, rt_to_flow))

proc rt_to_void*(x: Flow): void = 
  if x.tp == rtVoid:
    discard
  else:
    assert(false, "illegal conversion")

proc rt_to_bool*(x: int): bool = x != 0
proc rt_to_bool*(x: float): bool = x != 0.0
proc rt_to_bool*(x: bool): bool = x
proc rt_to_bool*(x: string): bool = x != "false"
proc rt_to_bool*(x: Flow): bool =
  if x.tp == rtInt:
    return rt_to_bool(x.valInt)
  elif x.tp == rtBool:
    return rt_to_bool(x.valBool)
  elif x.tp == rtDouble:
    return rt_to_bool(x.valDouble)
  elif x.tp == rtString:
    return rt_to_bool(x.valString)
  else:
    assert(false, "illegal conversion")

proc rt_to_int*(x: int): int = x
proc rt_to_int*(x: float): int = int(round(x))
proc rt_to_int*(x: bool): int = return if x: 1 else: 0
proc rt_to_int*(x: string): int = parseInt(x)
proc rt_to_int*(x: Flow): int =
  if x.tp == rtInt:
    return rt_to_int(x.valInt)
  elif x.tp == rtBool:
    return rt_to_int(x.valBool)
  elif x.tp == rtDouble:
    return rt_to_int(x.valDouble)
  elif x.tp == rtString:
    return rt_to_int(x.valString)
  else:
    assert(false, "illegal conversion")

proc rt_to_double*(x: int): float = float(x)
proc rt_to_double*(x: float): float = x
proc rt_to_double*(x: bool): float = return if x: 1.0 else: 0.0
proc rt_to_double*(x: string): float = parseFloat(x)
proc rt_to_double*(x: Flow): float =
  if x.tp == rtInt:
    return rt_to_double(x.valInt)
  elif x.tp == rtBool:
    return rt_to_double(x.valBool)
  elif x.tp == rtDouble:
    return rt_to_double(x.valDouble)
  elif x.tp == rtString:
    return rt_to_double(x.valString)
  else:
    assert(false, "illegal conversion")

proc rt_to_native*(x: Flow): Native =
  if x.tp == rtNative:
    return x.valNative
  else:
    assert(false, "illegal conversion")
