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
import system/widestrs

import "flow_lib/httpServer_type"

# Runtime for NIM backend

#[ Flow string: either a UTF-16 string of UTF-8 ]#

const use16BitString* = when defined UTF8: false else: true

when use16BitString:
  type RtString* = seq[Utf16Char]
else:
  type RtString* = string

const
  uni_halfShift* = 10
  uni_halfBase* = 0x0010000
  uni_halfMask* = 0x3FF

  UNI_MAX_BMP* = 0x0000FFFF
  UNI_MAX_UTF16* = 0x0010FFFF

  UNI_SUR_HIGH_START* = 0xD800
  UNI_SUR_HIGH_END* = 0xDBFF
  UNI_SUR_LOW_START* = 0xDC00
  UNI_SUR_LOW_END* = 0xDFFF
  UNI_REPL* = 0xFFFD

# Convert the utf8, implementation is adapted from lib/system/widestrs.nim
proc rt_utf8_to_utf16*(s: string): RtString =
  result = newSeqOfCap[Utf16Char](s.len)
  for r in runes(s):
    let ch = int32(r)
    if ch <= UNI_MAX_BMP or ch > UNI_MAX_UTF16:
      result.add(cast[Utf16Char](uint16(ch)))
    else:
      let ch = ch - uni_halfBase
      result.add(cast[Utf16Char](uint16((ch shr uni_halfShift) + UNI_SUR_HIGH_START)))
      result.add(cast[Utf16Char](uint16((ch and uni_halfMask) + UNI_SUR_LOW_START)))

proc rt_utf8_to_string*(s: string): RtString =
  when use16BitString: rt_utf8_to_utf16(s)
  else: return s

template `==`*(a: Utf16Char, b: Utf16Char): bool = cast[uint16](a) == cast[uint16](b)
template `!=`*(a: Utf16Char, b: Utf16Char): bool = cast[uint16](a) != cast[uint16](b)
template `<`*(a: Utf16Char, b: Utf16Char): bool = cast[uint16](a) < cast[uint16](b)
template `<=`*(a: Utf16Char, b: Utf16Char): bool = cast[uint16](a) <= cast[uint16](b)
template `>`*(a: Utf16Char, b: Utf16Char): bool = cast[uint16](a) > cast[uint16](b)
template `>=`*(a: Utf16Char, b: Utf16Char): bool = cast[uint16](a) >= cast[uint16](b)

proc rt_empty_string*(): RtString = return when use16BitString: @[] else: ""

template rt_concat_strings*(s1: RtString, s2: RtString): RtString =
  when use16BitString:
    sequtils.concat(s1, s2)
  else:
    s1 & s2

template rt_string_len*(s: RtString): int32 =
  when use16BitString: int32(s.len) else: int32(s.len)

template rt_string_char_code*(s: RtString, i: int32): int32 =
  when use16BitString: int32(cast[uint16](s[i])) else: int32(s[i])

when use16BitString:
  proc `&`(s1: RtString, s2: RtString): RtString = return rt_concat_strings(s1, s2)

proc rt_glue_strings*(ss: seq[RtString], sep: RtString): RtString =
  when use16BitString:
    var len = 0
    for x in ss:
      len += x.len
    result = newSeqOfCap[Utf16Char](len)
    var first = true
    for x in ss:
      if not first:
        result.add(sep)
      first = false
      result.add(x)
  else:
    return ss.join(sep)

template rt_utf16char_to_int*(arg: Utf16Char): int32 = int32(cast[uint16](arg))

template rt_binary_ones*(n: untyped): untyped = ((1 shl n)-1)

# Convert the utf8, implementation is adapted from lib/system/widestrs.nim
proc rt_convert_string_to_utf8*[T](s: RtString, ret: var T): void =
  var i = 0
  while i < s.len:
    var ch = rt_utf16char_to_int(s[i])
    inc i
    if ch >= UNI_SUR_HIGH_START and ch <= UNI_SUR_HIGH_END:
      if i < s.len:
        # If the 16 bits following the high surrogate are in the source buffer...
        let ch2 = rt_utf16char_to_int(s[i])

        # If it's a low surrogate, convert to UTF32:
        if ch2 >= UNI_SUR_LOW_START and ch2 <= UNI_SUR_LOW_END:
          ch = (((ch and uni_halfMask) shl uni_halfShift) + (ch2 and uni_halfMask)) + uni_halfBase
          inc i
        else:
          #invalid UTF-16
          discard
      else:
        # Illegal utf8 sequence
        discard
    elif ch >= UNI_SUR_LOW_START and ch <= UNI_SUR_LOW_END:
      #invalid UTF-16
      discard
    if ch < 0x80:
      ret.add chr(ch)
    elif ch < 0x800:
      ret.add chr((ch shr 6) or 0xc0)
      ret.add chr((ch and 0x3f) or 0x80)
    elif ch < 0x10000:
      ret.add chr((ch shr 12) or 0xe0)
      ret.add chr(((ch shr 6) and 0x3f) or 0x80)
      ret.add chr((ch and 0x3f) or 0x80)
    elif ch <= 0x10FFFF:
      ret.add chr((ch shr 18) or 0xf0)
      ret.add chr(((ch shr 12) and 0x3f) or 0x80)
      ret.add chr(((ch shr 6) and 0x3f) or 0x80)
      ret.add chr((ch and 0x3f) or 0x80)
    else:
      # replacement char(in case user give very large number):
      ret.add chr(0xFFFD shr 12 or 0b1110_0000)
      ret.add chr(0xFFFD shr 6 and rt_binary_ones(6) or 0b10_0000_00)
      ret.add chr(0xFFFD and rt_binary_ones(6) or 0b10_0000_00)

proc rt_string_to_utf8*(s: RtString): string =
  when use16BitString:
    # Guess length
    var ret: string = newStringOfCap(s.len * 3)
    rt_convert_string_to_utf8[string](s, ret)
    return ret
  else: return s

proc rt_escape*(s: RtString): RtString =
  when use16BitString:
    var escaped_len = s.len
    for ch in s:
      case ch:
      of Utf16Char('\n'): inc escaped_len
      of Utf16Char('\t'): inc escaped_len
      of Utf16Char('\r'): inc escaped_len
      of Utf16Char('\\'): inc escaped_len
      of Utf16Char('"'):  inc escaped_len
      else: discard
    var r: RtString = newSeq[Utf16Char](escaped_len)
    var i = 0
    for ch in s:
      case ch:
      of Utf16Char('\n'): r[i] = Utf16Char('\\'); inc i; r[i] = Utf16Char('n'); inc i
      of Utf16Char('\t'): r[i] = Utf16Char('\\'); inc i; r[i] = Utf16Char('t'); inc i
      of Utf16Char('\r'): r[i] = Utf16Char('\\'); inc i; r[i] = Utf16Char('r'); inc i
      of Utf16Char('\\'): r[i] = Utf16Char('\\'); inc i; r[i] = Utf16Char('\\'); inc i
      of Utf16Char('"'):  r[i] = Utf16Char('\\'); inc i; r[i] = Utf16Char('"'); inc i
      else: r[i] = ch; inc i
    return r
  else:
    var escaped_len = s.len
    for ch in s:
      case ch:
      of '\n': inc escaped_len
      of '\t': inc escaped_len
      of '\r': inc escaped_len
      of '\\': inc escaped_len
      of '"':  inc escaped_len
      else: discard
    var r = newStringOfCap(escaped_len)
    for ch in s:
      case ch:
      of '\n': r.add("\\n")
      of '\t': r.add("\\t")
      of '\r': r.add("\\u000d")
      of '\\': r.add("\\\\")
      of '"':  r.add("\\\"")
      else: r.add(ch)
    return r

proc rt_unescape*(s: RtString): RtString =
  when use16BitString:
    var unescaped_len = s.len
    var k = 0
    while k < s.len:
      if s[k] == Utf16Char('\\'):
        if k + 1 < s.len:
          case s[k]:
          of Utf16Char('n'):  dec unescaped_len; inc k
          of Utf16Char('t'):  dec unescaped_len; inc k
          of Utf16Char('r'):  dec unescaped_len; inc k
          of Utf16Char('\\'): dec unescaped_len; inc k
          of Utf16Char('"'):  dec unescaped_len; inc k
          else: discard
          inc k
        else: inc k
      else: inc k
    var r: RtString = newSeq[Utf16Char](unescaped_len)
    var j = 0
    for i in 0 ..< unescaped_len:
      let ch = s[j]
      if ch == Utf16Char('\\'):
        if j + 1 < s.len:
          case s[j + 1]:
          of Utf16Char('n'):  r[i] = Utf16Char('\n'); inc j
          of Utf16Char('t'):  r[i] = Utf16Char('\t'); inc j
          of Utf16Char('r'):  r[i] = Utf16Char('\r'); inc j
          of Utf16Char('\\'): r[i] = Utf16Char('\\'); inc j
          of Utf16Char('"'):  r[i] = Utf16Char('"');  inc j
          else: r[i] = ch
        else: r[i] = ch
      else: r[i] = ch
      inc j
    return r
  else:
    var unescaped_len = s.len
    var k = 0
    while k < s.len:
      if s[k] == '\\':
        if k + 1 < s.len:
          case s[k]:
          of 'n':  dec unescaped_len; inc k
          of 't':  dec unescaped_len; inc k
          of 'r':  dec unescaped_len; inc k
          of '\\': dec unescaped_len; inc k
          of '"':  dec unescaped_len; inc k
          else: discard
          inc k
        else: inc k
      else: inc k
    var r: RtString = newStringOfCap(unescaped_len)
    var j = 0
    for i in 0 ..< unescaped_len:
      let ch = s[j]
      if ch == '\\':
        if j + 1 < s.len:
          case s[j + 1]:
          of 'n':  r.add('\n'); inc j
          of 't':  r.add('\t'); inc j
          of 'r':  r.add('\r'); inc j
          of '\\': r.add('\\'); inc j
          of '"':  r.add('"');  inc j
          else: r.add(ch)
        else: r.add(ch)
      else: r.add(ch)
      inc j
    return r

when use16BitString:
  proc hash(s: RtString): Hash =
    var h: Hash = 0
    for ch in s:
      h = h !& rt_utf16char_to_int(ch)
    return !$h

  proc rt_runtime_error*(what: string): void =
    assert(false, "runtime error: " & what)

  proc `==`*(a: RtString, b: RtString): bool =
    if a.len != b.len: return false
    else:
      for i in 0 ..< a.len:
        if a[i] != b[i]: return false
      return true
  proc `!=`*(a: RtString, b: RtString): bool =
    return not (a == b)
  proc `<`*(a: RtString, b: RtString): bool =
    var i = 0
    while true:
      if a.len == i:
        if b.len == i: return false else: return true
      elif b.len == i: return false
      elif a[i] < b[i]: return true
      elif a[i] > b[i]: return false
      inc i
  proc `<=`*(a: RtString, b: RtString): bool =
    return a < b or a == b
  proc `>`*(a: RtString, b: RtString): bool =
    return b < a
  proc `>=`*(a: RtString, b: RtString): bool =
    return a > b or a == b

proc rt_runtime_error*(what: RtString): void =
  assert(false, "runtime error: " & rt_string_to_utf8(what))

#[ General conversions ]#

  # to_string conversions
proc rt_to_string*(): RtString = rt_utf8_to_string("{}")
proc rt_to_string*(x: int32): RtString = rt_utf8_to_string(intToStr(x))
proc rt_to_string*(x: float): RtString =
  var x = formatFloat(x)
  x.trimZeros()
  return rt_utf8_to_string(x)
proc rt_to_string*(x: bool): RtString = return rt_utf8_to_string(if (x): "true" else: "false")
proc rt_to_string*(x: RtString): RtString = x

proc rt_to_string_quot*(): RtString = rt_to_string()
proc rt_to_string_quot*(x: int32): RtString = rt_to_string(x)
proc rt_to_string_quot*(x: float): RtString = rt_to_string(x)
proc rt_to_string_quot*(x: bool): RtString = rt_to_string(x)
proc rt_to_string_quot*(x: RtString): RtString = rt_utf8_to_string("\"") & rt_escape(x) & rt_utf8_to_string("\"")

  # to_bool conversions
proc rt_to_bool*(x: int32): bool = x != 0
proc rt_to_bool*(x: float): bool = x != 0.0
proc rt_to_bool*(x: bool): bool = x
proc rt_to_bool*(x: RtString): bool = x != rt_utf8_to_string("false")

  # to_int conversions
proc rt_to_int*(x: int32): int32 = x
proc rt_to_int*(x: float): int32 = int32(round(x))
proc rt_to_int*(x: bool): int32 = return if x: 1 else: 0
proc rt_to_int*(x: RtString): int32 = int32(parseInt(rt_string_to_utf8(x)))

  # to_double conversions
proc rt_to_double*(x: int32): float = float(x)
proc rt_to_double*(x: float): float = x
proc rt_to_double*(x: bool): float = return if x: 1.0 else: 0.0
proc rt_to_double*(x: RtString): float = parseFloat(rt_string_to_utf8(x))

#[ General comparison ]#
proc rt_compare*(x: int32, y: int32): int32 = return if x < y: -1 elif x > y: 1 else: 0
proc rt_compare*(x: float, y: float): int32 = return if x < y: -1 elif x > y: 1 else: 0
proc rt_compare*(x: bool, y: bool): int32 = return if x < y: -1 elif x > y: 1 else: 0
when use16BitString:
  proc rt_compare*(a: RtString, b: RtString): int32 =
    var i = 0
    while true:
      if a.len == i:
        if b.len == i: return 0 else: return -1
      elif b.len == i: return 1
      elif a[i] < b[i]: return -1
      elif a[i] > b[i]: return 1
      inc i
else:
  proc rt_compare*(x: RtString, y: RtString): int32 = return if x < y: -1 elif x > y: 1 else: 0

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
    case tp*: RtType
    # Atiomic types
    of rtVoid:   discard
    of rtBool:   bool_v*:   bool
    of rtInt:    int_v*:    int32
    of rtDouble: double_v*: float
    of rtString: string_v*: RtString
    of rtNative: native_v*: Native
    # Composite types
    of rtRef:    ref_v*:    Flow
    of rtArray:  array_v*:  seq[Flow]
    of rtFunc:   func_v*:   proc(x: seq[Flow]): Flow
    of rtStruct:
      str_id*: int32
      str_args*: seq[Flow]

  Ref*[T] = ref object of Flow
    val*: T

  Struct* = ref object of RootObj
    str_id*: int32

#[ Native Types ]#
  NativeType* = enum
    ntProcess,
    ntFlow,
    ntHttpServer
  Native* = ref object 
    case ntp*: NativeType
    of ntProcess: p*: Process
    of ntHttpServer: s*: FlowHttpServer
    of ntFlow: flow_v*: Flow

proc makeHttpServerNative*(srv : FlowHttpServer) : Native =
  Native(ntp: ntHttpServer, s : srv)

# Flow type traits
template rt_type_is_flow*(X: typedesc[Flow]): bool = true
template rt_type_is_flow*(X: typedesc): bool = false

# Array type traits
template rt_type_is_array*[T](X: typedesc[seq[T]]): bool = true
template rt_type_is_array*(X: typedesc): bool = false
template rt_type_de_array*[T](X: typedesc[seq[T]]): typedesc[T] = typedesc[T]

type StructDef* = tuple[name: RtString, fields: seq[RtString]]

# Struct index
var id2struct*: seq[StructDef]
var struct2id*: Table[RtString, int32]

proc rt_register_struct*(name0: string, fields0: seq[string]): void =
  let name = rt_utf8_to_string(name0)
  let fields = map(fields0, rt_utf8_to_string)
  if not struct2id.hasKey(name):
    let id: int32 = int32(id2struct.len)
    id2struct.add((name, fields))
    struct2id[name] = id
  else:
    echo "struct " & name0 & " is aleady registered"

proc rt_struct_name_to_id*(name: RtString): int32 =
  if struct2id.hasKey(name):
    return struct2id[name]
  else:
    return -1
proc rt_struct_id_to_fields*(id: int32): seq[RtString] =
  return if id < id2struct.len: id2struct[id].fields else: @[]
proc rt_struct_id_to_name*(id: int32): RtString =
  return if id < id2struct.len: id2struct[id].name else: rt_empty_string()
proc rt_struct_name_to_fields*(name: RtString): seq[RtString] =
  return rt_struct_id_to_fields(rt_struct_name_to_id(name))
proc rt_struct_name_wrapper*[R](v: R, name: RtString): RtString = name
proc rt_flow_struct_name*(f: Flow): RtString = rt_struct_id_to_name(f.str_id)

# to_string conversions
proc rt_to_string*(f: Flow): RtString
# this function quotes all strings in ".."
proc rt_to_string_quot*(f: Flow): RtString
proc rt_to_string*(x: Native): RtString =
  case x.ntp:
  of ntProcess:    return rt_utf8_to_string("process")
  of ntHttpServer: return rt_utf8_to_string("http server")
  of ntFlow:       return rt_to_string(x.flow_v)
proc rt_to_string_quot*(x: Native): RtString =
  case x.ntp:
  of ntProcess:    return rt_utf8_to_string("process")
  of ntHttpServer: return rt_utf8_to_string("http server")
  of ntFlow:       return rt_to_string_quot(x.flow_v)

proc rt_to_string*[T](x: Ref[T]): RtString = return rt_utf8_to_string("ref ") & rt_to_string_quot(x.val)
proc rt_to_string_quot*[T](x: Ref[T]): RtString = return rt_utf8_to_string("ref ") & rt_to_string_quot(x.val)
proc rt_to_string*[T](x: seq[T]): RtString =
  var s = rt_utf8_to_string("[")
  for i in 0..x.len - 1:
    if i > 0:
      s.add(rt_utf8_to_string(", "))
    s.add(rt_to_string_quot(x[i]))
  s.add(rt_utf8_to_string("]"))
  return s
proc rt_to_string_quot*[T](x: seq[T]): RtString =
  var s = rt_utf8_to_string("[")
  for i in 0..x.len - 1:
    if i > 0:
      s.add(rt_utf8_to_string(", "))
    s.add(rt_to_string_quot(x[i]))
  s.add(rt_utf8_to_string("]"))
  return s


# this function quotes all strings in ".."
proc rt_to_string_quot*(f: Flow): RtString =
  case f.tp:
  of rtVoid:   return rt_to_string()
  of rtBool:   return rt_to_string(f.bool_v)
  of rtInt:    return rt_to_string(f.int_v)
  of rtDouble:
    # NOTE: toString(42.0) == "42.0" BUT cast(42.0: double -> string) == "42"
    var x = formatFloat(f.double_v)
    x.trimZeros()
    if not x.contains('.'): x.add(".0")
    return rt_utf8_to_string(x)
  of rtString: return rt_utf8_to_string("\"") & rt_escape(f.string_v) & rt_utf8_to_string("\"")
  of rtNative: return rt_to_string(f.native_v)
  of rtRef:    return rt_utf8_to_string("ref ") & rt_to_string_quot(f.ref_v)
  of rtArray:
    var s = rt_utf8_to_string("[")
    for i in 0..f.array_v.len - 1:
      if i > 0:
        s.add(rt_utf8_to_string(", "))
      s.add(rt_to_string_quot(f.array_v[i]))
    s.add(rt_utf8_to_string("]"))
    return s
  of rtFunc:   return rt_utf8_to_string("<function>")
  of rtStruct:
    var s = rt_struct_id_to_name(f.str_id) & rt_utf8_to_string("(")
    for i in 0..f.str_args.len - 1:
        if i > 0:
           s.add(rt_utf8_to_string(", "))
        s.add(rt_to_string_quot(f.str_args[i]))
    s.add(rt_utf8_to_string(")"))
    return s

# this function keeps toplevel strings as is and quotes strings in components in ".."
proc rt_to_string*(f: Flow): RtString =
  return if f.tp == rtString: f.string_v else: rt_to_string_quot(f)

# to_flow conversions
proc rt_to_flow*(): Flow = Flow(tp: rtVoid)
proc rt_to_flow*(b: bool): Flow = Flow(tp: rtBool, bool_v: b)
proc rt_to_flow*(i: int32): Flow = Flow(tp: rtInt, int_v: i)
proc rt_to_flow*(d: float): Flow = Flow(tp: rtDouble, double_v: d)
proc rt_to_flow*(s: RtString): Flow = Flow(tp: rtString, string_v: s)
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
  else: rt_runtime_error("illegal conversion of " & rt_string_to_utf8(rt_to_string(x)) & " to void")

proc rt_to_bool*(x: Flow): bool =
  case x.tp:
  of rtInt:    return rt_to_bool(x.int_v)
  of rtBool:   return rt_to_bool(x.bool_v)
  of rtDouble: return rt_to_bool(x.double_v)
  of rtString: return rt_to_bool(x.string_v)
  else: rt_runtime_error("illegal conversion of " & rt_string_to_utf8(rt_to_string(x)) & " to bool")

proc rt_to_int*(x: Flow): int32 =
  case x.tp:
  of rtInt:    return rt_to_int(x.int_v)
  of rtBool:   return rt_to_int(x.bool_v)
  of rtDouble: return rt_to_int(x.double_v)
  of rtString: return rt_to_int(x.string_v)
  else: rt_runtime_error("illegal conversion of " & rt_string_to_utf8(rt_to_string(x)) & " to int")

proc rt_to_double*(x: Flow): float =
  case x.tp:
  of rtInt:    return rt_to_double(x.int_v)
  of rtBool:   return rt_to_double(x.bool_v)
  of rtDouble: return rt_to_double(x.double_v)
  of rtString: return rt_to_double(x.string_v)
  else: rt_runtime_error("illegal conversion of " & rt_string_to_utf8(rt_to_string(x)) & " to double")

proc rt_to_native*(x: Flow): Native =
  return if x.tp == rtNative: x.native_v else: Native(ntp: ntFlow, flow_v: x)

proc rt_get_flow_field*(x: Flow, field_name: RtString): Flow =
  case x.tp:
  of rtStruct:
    let fields = rt_struct_id_to_fields(x.str_id)
    var i = 0
    for arg in x.str_args:
      if fields[i] == field_name:
        return arg
      i += 1
    rt_runtime_error("flow struct " & rt_string_to_utf8(rt_struct_id_to_name(x.str_id)) & "  has no field " & rt_string_to_utf8(field_name))
  else: rt_runtime_error("attempt to get field of non-struct: " & rt_string_to_utf8(rt_to_string(x)))

proc rt_set_flow_field*(s: Flow, field: RtString, val: Flow): void =
  if s.tp == rtStruct:
    let s_fields = rt_struct_id_to_fields(s.str_id)
    var i = 0
    for f in s_fields:
      if f == field:
        break
      i += 1
    if i != s_fields.len:
      s.str_args[i] = val

# Table for implicit natives, which are called via `hostCall`

var name2func*: Table[RtString, proc(args: seq[Flow]): Flow]

# Such definition of getOs makes it compliant to `getFlowOs` from sys/target
name2func[rt_utf8_to_string("getOs")] = proc(args: seq[Flow]): Flow = rt_to_flow(rt_utf8_to_string(title(hostOS) & " other"))
name2func[rt_utf8_to_string("getVersion")] = proc(args: seq[Flow]): Flow = rt_to_flow(rt_empty_string())
name2func[rt_utf8_to_string("getUserAgent")] = proc(args: seq[Flow]): Flow = rt_to_flow(rt_empty_string())
name2func[rt_utf8_to_string("getBrowser")] = proc(args: seq[Flow]): Flow = rt_to_flow(rt_empty_string())
name2func[rt_utf8_to_string("getResolution")] = proc(args: seq[Flow]): Flow = rt_to_flow(rt_empty_string())
name2func[rt_utf8_to_string("getDeviceType")] = proc(args: seq[Flow]): Flow = rt_to_flow(rt_empty_string())

# different libraries for different platforms
macro importPlatformLib(
  arg: static[string]): untyped = newTree(nnkImportStmt, newLit(arg)
)

const winHtppServer = "flow_lib/createHttpServerNative_win"
const unixHtppServer = "flow_lib/createHttpServerNative_unix"
const httpServerLib = when defined windows: winHtppServer else: unixHtppServer
importPlatformLib(httpServerLib)