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

  # Compile time type kinds
  CtType* = enum
    # Atiomic types
    ctVoid, ctBool, ctInt, ctDouble, ctString, ctNative, ctFlow,
    # Composite types
    ctRef, ctArray, ctFunc, ctStruct, ctUnion

  # A complex type descriptor.
  AlType* = tuple[op: CtType, args: seq[int32], name: string]

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
      tp_id: int32
      str_id: int32
      str_name: string
      str_args: seq[Flow]

  Void* = ref object of Flow
  Bool* = ref object of Flow
    val: bool
  Int* = ref object of Flow
    val: int32
  Double* = ref object of Flow
    val: float
  String* = ref object of Flow
    val: string

  Ref*[T] = ref object of Flow
    val: T

  Array*[T] = ref object of Flow
    val: seq[T]

  Struct* = ref object of RootObj
    tp_id: int32
    str_id: int32

  Struct0* = ref object of Struct

  Struct1*[A1] = ref object of Struct
    arg1: A1

  Struct2*[A1, A2] = ref object of Struct
    arg1: A1
    arg2: A2

  Struct3*[A1, A2, A3] = ref object of Struct
    arg1: A1
    arg2: A2
    arg3: A2

  Func0*[R] = ref object of Flow
    fn: proc(): R

  Func1*[R, A1] = ref object of Flow
    fn: proc(a1: A1): R

  Func2*[R, A1, A2] = ref object of Flow
    fn: proc(a1: A1, a2: A2): R

  Func3*[R, A1, A2, A3] = ref object of Flow
    fn: proc(a1: A1, a2: A2, a3: A3): R

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

# Type index oprations
var id2type*: seq[AlType]
var type2id*: Table[AlType, int32]
var id2fields*: seq[seq[string]]
var struct2id*: Table[string, int32]

proc rt_type_id_to_string*(id: int32): string =
  let tp = id2type[id]
  case tp.op:
  of ctRef:    return "ref " & rt_type_id_to_string(tp.args[0])
  of ctArray:  return "[" & rt_type_id_to_string(tp.args[0]) & "]"
  of ctFunc:   return "(" & map(tp.args[1..tp.args.len - 1], proc (arg: int32): string = rt_type_id_to_string(arg)).join(", ") & ") -> " & rt_type_id_to_string(tp.args[0])
  of ctStruct: return tp.name & "(" & map(tp.args[1..tp.args.len - 1], proc (arg: int32): string = rt_type_id_to_string(arg)).join(", ") & ")"
  else: tp.name

proc rt_type_id_to_struct_id*(id: int32): int32 =
  return id2type[id].args[0]

proc rt_find_type_id*(tp: AlType): int32 =
  return if type2id.hasKey(tp): type2id[tp] else: -1

proc rt_register_type*(tp: AlType): void =
  if not type2id.hasKey(tp):
    let id: int32 = int32(id2type.len)
    id2type.add(tp)
    type2id[tp] = id
  else:
    #echo "type is aleady registered: " & rt_type_id_to_string(type2id[tp])
    discard

proc hash*(tp: AlType): Hash =
  var h: Hash = 0
  h = h !& hash(tp.op)
  for arg in tp.args:
    h = h !& hash(arg)
  result = !$h

proc rt_register_struct*(name: string, fields: seq[string]): void =
  if not struct2id.hasKey(name):
    let id: int32 = int32(id2fields.len)
    id2fields.add(fields)
    struct2id[name] = id
  else:
    echo "struct " & name & " is aleady registered"

proc rt_struct_name_to_id*(name: string): int32 =
  if struct2id.hasKey(name):
    return struct2id[name]
  else:
    return -1

proc rt_struct_id_to_fields*(id: int32): seq[string] =
  return if id < id2fields.len: id2fields[id] else: @[]

proc rt_struct_name_to_fields*(name: string): seq[string] =
  return rt_struct_id_to_fields(rt_struct_name_to_id(name))

proc rt_type_id*(f: Flow): int32 =
  case f.tp:
  of rtVoid:   return 0i32
  of rtBool:   return 1i32
  of rtInt:    return 2i32
  of rtDouble: return 3i32
  of rtString: return 4i32
  of rtNative: return 5i32
  of rtRef:
    let r_type = rt_type_id(f.ref_v)
    return rt_find_type_id((ctRef, @[r_type], ""))
  of rtArray:
    if f.array_v.len == 0:
      echo "type of an empty array can't be resolved at runtime"
      return -1i32
    else:
      let el_type = rt_type_id(f.array_v[0])
      return rt_find_type_id((ctArray, @[el_type], ""))
  of rtFunc:
    echo "type of a function can't be resolved at runtime"
    return -1i32
  of rtStruct: return f.str_id

# to_string conversions
proc rt_to_string*(f: Flow): string
# this function quotes all strings in ".."
proc rt_to_string_quot*(f: Flow): string
proc rt_to_string*[R](fn: proc(): R): string = "<function>"
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
    var s = f.str_name & "("
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

proc rt_to_flow*[R](fn: proc(): R): Flow =
  Flow(
    tp: rtFunc, 
    func_v: proc(x: seq[Flow]): Flow =
      let y: R = fn()
      return rt_to_flow(y)
  )


#proc rt_to_af*(x: Flow): seq[Flow] = x.array_v
#proc rt_to_aaf*(x: Flow): seq[seq[Flow]] = map(x.array_v, rt_to_af)
#proc rt_to_rf*(x: Flow): Ref[Flow] = Ref[Flow](val: x.ref_v)
#proc rt_to_rrf*(x: Flow): Ref[Flow] = Ref[Flow](val: rt_to_rf(x.ref_v))

proc rt_compare*(x: Flow, y: Flow): int32
proc rt_compare*(x: Native, y: Native): int32 =
  case x.ntp:
  of ntProcess: return rt_compare(addr(x.p), addr(y.p))
  of ntHttpServer: return rt_compare(addr(x.s), addr(y.s))
  of ntFlow:    return rt_compare(x.flow_v, y.flow_v)

proc rt_compare*[T](x: Ref[T], y: Ref[T]): int32 = rt_compare(x.val, y.val)
proc rt_compare*[T](x: openArray[T], y: openArray[T]): int32 =
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
proc rt_compare*[R](x: var proc(): R, y: var proc(): R): int32 = rt_compare(addr(x), addr(y))
proc rt_compare*[R, A1](x: var proc(a1: A1): R, y: var proc(a1: A1): R): int32 = rt_compare(addr(x), addr(y))
proc rt_compare*[R, A1, A2](x: var proc(a1: A1, a2: A2): R, y: var proc(a1: A1, a2: A2): R): int32 = rt_compare(addr(x), addr(y))
proc rt_compare*[R, A1, A2, A3](x: var proc(a1: A1, a2: A2, a3: A3): R, y: var proc(a1: A1, a2: A2, a3: A3): R): int32 = rt_compare(addr(x), addr(y))
proc rt_compare*[R, A1, A2, A3, A4](x: var proc(a1: A1, a2: A2, a3: A3, a4: A4): R, y: var proc(a1: A1, a2: A2, a3: A3, a4: A4): R): int32 = rt_compare(addr(x), addr(y))

#[
proc rt_to_flow_runtime_struct*(x: Struct): Flow =
  if x.id >= id2type.len:
    assert(false, "type index " & intToStr(x.id) & " is out of bounds: " & intToStr(id2type.len))
  let tp = id2type[x.id]
  let struct_id = tp.args[0]
  return Flow(tp: rtVoid)
]#

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
  return if x.tp == rtNative: x.native_v else: Native(ntp: ntFlow, flow_v: x)

proc rt_get_flow_field*(x: Flow, field_name: string): Flow =
  case x.tp:
  of rtStruct:
    let fields = rt_struct_name_to_fields(x.str_name)
    var i = 0
    for arg in x.str_args:
      if fields[i] == field_name:
        return arg
      i += 1
    assert(false, "flow struct " & x.str_name & "  has no field " & field_name)
  else: assert(false, "attempt to get field of non-struct: " & rt_to_string(x))

proc rt_set_flow_field*(s: Flow, field: string, val: Flow): void =
  if s.tp == rtStruct:
    let s_fields = rt_struct_name_to_fields(s.str_name)
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