import sequtils
import typetraits
import strutils
import unicode
import math
import tables
import hashes
import asyncdispatch
import osproc
import macros
import "flow_lib/httpServer_type"

# Runtime for NIM backend

{.experimental: "overloadableEnums".}

proc rt_runtime_error*(what: string): void =
  assert(false, "runtime error: " & what)

proc rt_escape(s: string): string = 
  var r: string = ""
  for ch in s:
    case ch:
    of '\n': r.add("\\n")
    of '\t': r.add("\\t")
    of '\r': r.add("\\u000d")
    of '\\': r.add("\\\\")
    of '"':  r.add("\\\"")
    else: r.add(ch)
  return r

#[ General conversions ]#

  # to_string conversions
proc rt_to_string*(): string = "{}"
proc rt_to_string*(x: int32): string = intToStr(x)
proc rt_to_string*(x: float): string =
  var x = formatFloat(x)
  x.trimZeros()
  return x
proc rt_to_string*(x: bool): string = return if (x): "true" else: "false"
proc rt_to_string*(x: string): string = x

proc rt_to_string_quot*(): string = "{}"
proc rt_to_string_quot*(x: int32): string = intToStr(x)
proc rt_to_string_quot*(x: float): string = rt_to_string(x)
proc rt_to_string_quot*(x: bool): string = rt_to_string(x)
proc rt_to_string_quot*(x: string): string = '"' & rt_escape(x) & '"'

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

#[ General comparison ]#
proc rt_compare*(x: int32, y: int32): int32 = return if x < y: -1 elif x > y: 1 else: 0
proc rt_compare*(x: float, y: float): int32 = return if x < y: -1 elif x > y: 1 else: 0
proc rt_compare*(x: bool, y: bool): int32 = return if x < y: -1 elif x > y: 1 else: 0
proc rt_compare*(x: string, y: string): int32 = return if x < y: -1 elif x > y: 1 else: 0
proc rt_compare*[T](x: ptr T, y: ptr T): int32 = return if x < y: -1 elif x > y: 1 else: 0

proc rt_equal*[T](x: T, y: T): bool = rt_compare(x, y) == 0
proc rt_nequal*[T](x: T, y: T): bool = rt_compare(x, y) != 0

type
  # Basic runtime type kinds
  RtType* = enum
    # Atiomic types
    rtVoid, rtBool, rtInt, rtDouble, rtString, rtNative,
    # Composite types
    rtRef, rtArray, rtFunc, rtStruct

#[ Representation of a dynamic type ]#

  Flow* = ref object of RootObj
    #tp: int32
    case tp*: RtType
    # Atiomic types
    of rtVoid:   discard
    of rtBool:   bool_v:   bool
    of rtInt:    int_v:    int32
    of rtDouble: double_v: float
    of rtString: string_v: string
    of rtNative: native_v: Native
    # Composite types
    of rtRef:    ref_v:    Flow
    of rtArray:  array_v:  seq[Flow]
    of rtFunc:   func_v:   proc(x: seq[Flow]): Flow
    of rtStruct:
      str_id: int32
      str_args: seq[Flow]

  Ref*[T] = ref object of Flow
    val: T

  Struct* = ref object of RootObj
    str_id: int32

#[ Native Types ]#
  NativeType* = enum
    ntProcess,
    ntFlow,
    ntHttpServer
  Native* = ref object 
    case ntp*: NativeType
    of ntProcess: p: Process
    of ntHttpServer: s: FlowHttpServer
    of ntFlow: flow_v: Flow
    what: string
proc makeHttpServerNative*(srv : FlowHttpServer) : Native =
  Native(what : "HttpServer", ntp: ntHttpServer, s : srv)

# Function type traits/utils
$A_0

# Flow type traits
template rt_type_is_flow*(X: typedesc[Flow]): bool = true
template rt_type_is_flow*(X: typedesc): bool = false

# Array type traits
template rt_type_is_array*[T](X: typedesc[seq[T]]): bool = true
template rt_type_is_array*(X: typedesc): bool = false
template rt_type_de_array*[T](X: typedesc[seq[T]]): typedesc[T] = typedesc[T]

type StructDef* = tuple[name: string, fields: seq[string]]

# Struct index
var id2struct*: seq[StructDef]
var struct2id*: Table[string, int32]

proc rt_register_struct*(name: string, fields: seq[string]): void =
  if not struct2id.hasKey(name):
    let id: int32 = int32(id2struct.len)
    id2struct.add((name, fields))
    struct2id[name] = id
  else:
    echo "struct " & name & " is aleady registered"

proc rt_struct_name_to_id*(name: string): int32 =
  if struct2id.hasKey(name):
    return struct2id[name]
  else:
    return -1
proc rt_struct_id_to_fields*(id: int32): seq[string] =
  return if id < id2struct.len: id2struct[id].fields else: @[]
proc rt_struct_id_to_name*(id: int32): string =
  return if id < id2struct.len: id2struct[id].name else: ""
proc rt_struct_name_to_fields*(name: string): seq[string] =
  return rt_struct_id_to_fields(rt_struct_name_to_id(name))
proc rt_struct_name_wrapper*[R](v: R, name: string): string = name
proc rt_flow_struct_name*(f: Flow): string = rt_struct_id_to_name(f.str_id)

# to_string conversions
proc rt_to_string*(f: Flow): string
# this function quotes all strings in ".."
proc rt_to_string_quot*(f: Flow): string
proc rt_to_string*(x: Native): string =
  case x.ntp:
  of ntProcess: return "process"
  of ntHttpServer: return "http server"
  of ntFlow:    return rt_to_string(x.flow_v)
proc rt_to_string_quot*(x: Native): string =
  case x.ntp:
  of ntProcess: return "process"
  of ntHttpServer: return "http server"
  of ntFlow:    return rt_to_string_quot(x.flow_v)

proc rt_to_string*[T](x: Ref[T]): string = return "ref " & rt_to_string_quot(x.val)
proc rt_to_string_quot*[T](x: Ref[T]): string = return "ref " & rt_to_string_quot(x.val)
proc rt_to_string*[T](x: seq[T]): string =
  var s = "["
  for i in 0..x.len - 1:
    if i > 0:
      s.add(", ")
    s.add(rt_to_string_quot(x[i]))
  s.add("]")
  return s
proc rt_to_string_quot*[T](x: seq[T]): string =
  var s = "["
  for i in 0..x.len - 1:
    if i > 0:
      s.add(", ")
    s.add(rt_to_string_quot(x[i]))
  s.add("]")
  return s


# this function quotes all strings in ".."
proc rt_to_string_quot*(f: Flow): string =
  case f.tp:
  of rtVoid:   return rt_to_string()
  of rtBool:   return rt_to_string(f.bool_v)
  of rtInt:    return rt_to_string(f.int_v)
  of rtDouble: return rt_to_string(f.double_v)
  of rtString: return "\"" & rt_escape(f.string_v) & "\""
  of rtNative: return rt_to_string(f.native_v)
  of rtRef:    return "ref " & rt_to_string_quot(f.ref_v)
  of rtArray:
    var s = "["
    for i in 0..f.array_v.len - 1:
      if i > 0:
        s.add(", ")
      s.add(rt_to_string_quot(f.array_v[i]))
    s.add("]")
    return s
  of rtFunc:   return "<function>"
  of rtStruct:
    var s = rt_struct_id_to_name(f.str_id) & "("
    for i in 0..f.str_args.len - 1:
        if i > 0:
           s.add(", ")
        s.add(rt_to_string_quot(f.str_args[i]))
    s.add(")")
    return s

# this function keeps toplevel strings as is and quotes strings in components in ".."
proc rt_to_string*(f: Flow): string =
  return if f.tp == rtString: f.string_v else: rt_to_string_quot(f)

# to_flow conversions
proc rt_to_flow*(): Flow = Flow(tp: rtVoid)
proc rt_to_flow*(b: bool): Flow = Flow(tp: rtBool, bool_v: b)
proc rt_to_flow*(i: int32): Flow = Flow(tp: rtInt, int_v: i)
proc rt_to_flow*(d: float): Flow = Flow(tp: rtDouble, double_v: d)
proc rt_to_flow*(s: string): Flow = Flow(tp: rtString, string_v: s)
proc rt_to_flow*(f: Flow): Flow = f
proc rt_to_flow*(n: Native): Flow =
  return if n.ntp == ntFlow: return n.flow_v else: Flow(tp: rtNative, native_v: n)
proc rt_to_flow*[T](rf: Ref[T]): Flow = Flow(tp: rtRef, ref_v: rt_to_flow(rf.val))
proc rt_to_flow*[T](arr: seq[T]): Flow =
  var flow_seq = newSeq[Flow](arr.len)
  for i in 0..arr.len - 1:
    flow_seq[i] = rt_to_flow(arr[i])
  Flow(tp: rtArray, array_v: flow_seq)

proc rt_compare*(x: Flow, y: Flow): int32
proc rt_compare*(x: Native, y: Native): int32 =
  case x.ntp:
  of ntProcess: return rt_compare(addr(x.p), addr(y.p))
  of ntHttpServer: return rt_compare(addr(x.s), addr(y.s))
  of ntFlow:    return rt_compare(x.flow_v, y.flow_v)

proc rt_compare*[T](x: Ref[T], y: Ref[T]): int32 = rt_compare(x.val, y.val)
proc rt_compare*[T](x: seq[T], y: seq[T]): int32 =
  if x.len < y.len: return -1
  elif x.len > y.len: return 1
  else:
    for i in 0 .. x.len - 1:
      let c = rt_compare(x[i], y[i])
      if c != 0:
        return c
    return 0
proc rt_compare*(x: Flow, y: Flow): int32 =
  if x.tp < y.tp: return -1
  elif x.tp > y.tp: return 1
  else:
    case x.tp:
    of rtVoid:   return 0
    of rtBool:   return rt_compare(x.bool_v, y.bool_v)
    of rtInt:    return rt_compare(x.int_v, y.int_v)
    of rtDouble: return rt_compare(x.double_v, y.double_v)
    of rtString: return rt_compare(x.string_v, y.string_v)
    of rtNative: return rt_compare(addr(x.native_v), addr(y.native_v))
    of rtRef:    return rt_compare(x.ref_v, y.ref_v)
    of rtArray:  return rt_compare(x.array_v, y.array_v)
    of rtFunc:   return rt_compare(addr(x.func_v), addr(y.func_v))
    of rtStruct:
      if x.str_id < y.str_id: return -1
      elif x.str_id > y.str_id: return 1
      else:
        for i in 0 .. x.str_args.len - 1:
          let c = rt_compare(x.str_args[i], y.str_args[i])
          if c != 0:
            return c
        return 0

# General comparison of all other values - by address
proc rt_compare*[R](x: var R, y: var R): int32 = rt_compare(addr(x), addr(y))

# to_void conversions
proc rt_to_void*(x: Flow): void = 
  case x.tp:
  of rtVoid: discard
  else: rt_runtime_error("illegal conversion of " & rt_to_string(x) & " to void")

proc rt_to_bool*(x: Flow): bool =
  case x.tp:
  of rtInt:    return rt_to_bool(x.int_v)
  of rtBool:   return rt_to_bool(x.bool_v)
  of rtDouble: return rt_to_bool(x.double_v)
  of rtString: return rt_to_bool(x.string_v)
  else: rt_runtime_error("illegal conversion of " & rt_to_string(x) & " to bool")

proc rt_to_int*(x: Flow): int32 =
  case x.tp:
  of rtInt:    return rt_to_int(x.int_v)
  of rtBool:   return rt_to_int(x.bool_v)
  of rtDouble: return rt_to_int(x.double_v)
  of rtString: return rt_to_int(x.string_v)
  else: rt_runtime_error("illegal conversion of " & rt_to_string(x) & " to int")

proc rt_to_double*(x: Flow): float =
  case x.tp:
  of rtInt:    return rt_to_double(x.int_v)
  of rtBool:   return rt_to_double(x.bool_v)
  of rtDouble: return rt_to_double(x.double_v)
  of rtString: return rt_to_double(x.string_v)
  else: rt_runtime_error("illegal conversion of " & rt_to_string(x) & " to double")

proc rt_to_native*(x: Flow): Native =
  return if x.tp == rtNative: x.native_v else: Native(ntp: ntFlow, flow_v: x)

proc rt_get_flow_field*(x: Flow, field_name: string): Flow =
  case x.tp:
  of rtStruct:
    let fields = rt_struct_id_to_fields(x.str_id)
    var i = 0
    for arg in x.str_args:
      if fields[i] == field_name:
        return arg
      i += 1
    rt_runtime_error("flow struct " & rt_struct_id_to_name(x.str_id) & "  has no field " & field_name)
  else: rt_runtime_error("attempt to get field of non-struct: " & rt_to_string(x))

proc rt_set_flow_field*(s: Flow, field: string, val: Flow): void =
  if s.tp == rtStruct:
    let s_fields = rt_struct_id_to_fields(s.str_id)
    var i = 0
    for f in s_fields:
      if f == field:
        break
      i += 1
    if i != s_fields.len:
      s.str_args[i] = val

# Implicit natives, which are called via `hostCall`
proc getOs*(): string = hostOS & "," & hostCPU
proc getVersion*(): string = ""
proc getUserAgent*(): string = ""
proc getBrowser*(): string = ""
proc getResolution*(): string = ""
proc getDeviceType*(): string = ""

# different libraries for different platforms
macro importPlatformLib(
  arg: static[string]): untyped = newTree(nnkImportStmt, newLit(arg)
)

const winHtppServer = "flow_lib/createHttpServerNative_win"
const unixHtppServer = "flow_lib/createHttpServerNative_unix"
const httpServerLib = when defined windows: winHtppServer else: unixHtppServer
importPlatformLib(httpServerLib)