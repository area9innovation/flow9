import sequtils
import typetraits
import strutils
import unicode
import math
import asyncdispatch

# Runtime for NIM backend

proc rt_escape(s: string): string = 
  var r: string = ""
  for ch in s:
    case ch:
    of '\n': r.add("\\n")
    of '\t': r.add("\\t")
    of '\r': r.add("\\r")
    of '\\': r.add("\\\\")
    of '"': r.add("\\\"")
    else: r.add(ch)
  return r

#[ General conversions ]#

  # to_string conversions
proc rt_to_string*(): string = "{}"
proc rt_to_string*(x: int32): string = intToStr(x)
proc rt_to_string*(x: float): string = formatFloat(x)
proc rt_to_string*(x: bool): string = return if (x): "true" else: "false"
proc rt_to_string*(x: string): string = "\"" & x.rt_escape & "\""

  # to_bool conversions
proc rt_to_bool*(x: int32): bool = x != 0
proc rt_to_bool*(x: float): bool = x != 0.0
proc rt_to_bool*(x: bool): bool = x
proc rt_to_bool*(x: string): bool = x != "false"

  # to_int conversions
proc rt_to_int*(x: int32): int32 = x
proc rt_to_int*(x: float): int32 = int32(round(x))
proc rt_to_int*(x: bool): int32 = return if x: 1 else: 0
proc rt_to_int*(x: string): int32 = int32(parseInt(x))

  # to_double conversions
proc rt_to_double*(x: int32): float = float(x)
proc rt_to_double*(x: float): float = x
proc rt_to_double*(x: bool): float = return if x: 1.0 else: 0.0
proc rt_to_double*(x: string): float = parseFloat(x)

#[ Runtime type ids ]#

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

  FlowField* = object
    name*: string
    val*: Flow

  Flow* = ref object
    case tp*: RtType
    of rtVoid:   discard
    of rtBool:   bool_v:   bool
    of rtInt:    int_v:    int32
    of rtDouble: double_v: float
    of rtString: string_v: string
    of rtNative: native_v: Native
    of rtArray:  array_v:  seq[Flow]
    of rtFunc:   func_v:   proc(x: seq[Flow]): Flow
    of rtStruct:
      str_id: int32
      str_name: string
      str_fields: seq[FlowField]

  Struct* = ref object of RootObj
    id: int32

  Native* = ref object of RootObj
    what: string
    val: RootObj

  # to_string conversions
proc rt_to_string*(x: Struct): string
proc rt_to_string*[R](fn: proc(): R): string = "<function>"
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
  of rtBool:   return rt_to_string(f.bool_v)
  of rtInt:    return rt_to_string(f.int_v)
  of rtDouble: return rt_to_string(f.double_v)
  of rtString: return rt_to_string(f.string_v)
  of rtNative: return rt_to_string(f.native_v)
  of rtArray:  return rt_to_string(f.array_v)
  of rtFunc:   return "<function>"
  of rtStruct:
    var s = f.str_name & "("
    for i in 0..f.str_fields.len - 1:
        if i > 0:
           s.add(", ")
        s.add(rt_to_string(f.str_fields[i].val))
    s.add(")")
    return s

  # to_flow conversions
proc rt_to_flow*(): Flow = Flow(tp: rtVoid)
proc rt_to_flow*(b: bool): Flow = Flow(tp: rtBool, bool_v: b)
proc rt_to_flow*(i: int32): Flow = Flow(tp: rtInt, int_v: i)
proc rt_to_flow*(d: float): Flow = Flow(tp: rtDouble, double_v: d)
proc rt_to_flow*(s: string): Flow = Flow(tp: rtString, string_v: s)
proc rt_to_flow*(f: Flow): Flow = f
proc rt_to_flow*(n: Native): Flow = Flow(tp: rtNative, native_v: n)
proc rt_to_flow*(x: Struct): Flow
proc rt_to_flow*[T](arr: seq[T]): Flow =
  var flow_seq = newSeq[Flow](arr.len)
  for i in 0..arr.len - 1:
    flow_seq[i] = rt_to_flow(arr[i])
  Flow(tp: rtArray, array_v: flow_seq)

proc rt_to_flow*[R](fn: proc(): R): Flow =
  Flow(
    tp: rtFunc, 
    func_v: proc(x: seq[Flow]): Flow =
      let y: R = fn()
      return rt_to_flow(y)
  )

  # to_void conversions
proc rt_to_void*(x: Flow): void = 
  case x.tp:
  of rtVoid: discard
  else: assert(false, "illegal conversion")

proc rt_to_bool*(x: Flow): bool =
  case x.tp:
  of rtInt:    return rt_to_bool(x.int_v)
  of rtBool:   return rt_to_bool(x.bool_v)
  of rtDouble: return rt_to_bool(x.double_v)
  of rtString: return rt_to_bool(x.string_v)
  else: assert(false, "illegal conversion")

proc rt_to_int*(x: Flow): int32 =
  case x.tp:
  of rtInt:    return rt_to_int(x.int_v)
  of rtBool:   return rt_to_int(x.bool_v)
  of rtDouble: return rt_to_int(x.double_v)
  of rtString: return rt_to_int(x.string_v)
  else: assert(false, "illegal conversion")

proc rt_to_double*(x: Flow): float =
  case x.tp:
  of rtInt:    return rt_to_double(x.int_v)
  of rtBool:   return rt_to_double(x.bool_v)
  of rtDouble: return rt_to_double(x.double_v)
  of rtString: return rt_to_double(x.string_v)
  else: assert(false, "illegal conversion")

proc rt_to_native*(x: Flow): Native =
  case x.tp:
  of rtNative: return x.native_v
  else: assert(false, "illegal conversion")

proc rt_get_flow_field*(x: Flow, field_name: string): Flow =
  case x.tp:
  of rtStruct:
    for field in x.str_fields:
      if field.name == field_name:
        return field.val
    assert(false, "flow struct " & x.str_name & "  has no field " & field_name)
  else: assert(false, "attempt to get field of non-struct: " & rt_to_string(x))

#[

	Doesn't work: complains that
		field.val = v
	can't be assigned to

proc rt_set_flow_field*(x: Flow, field_name: string, v: Flow): void =
  case x.tp:
  of rtStruct:
    for field in x.str_fields:
      if field.name == field_name:
        field.val = v
    assert(false, "flow struct " & x.str_name & "  has no field " & field_name)
  else: assert(false, "attempt to get field of non-struct: " & rt_to_string(x))
]#
