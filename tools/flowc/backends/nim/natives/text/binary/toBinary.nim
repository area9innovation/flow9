# native toBinary : (value : flow) -> string = Native.toBinary
import tables
import strutils
import unicode

proc writeCharValue(c: int32, buf: var RtString) =
  let c1 = c and 0xffff
  when use16BitString:
    let c2: int16 = cast[int16](cast[uint16](c1))
    let ch = Utf16Char(c2)
    buf.add(ch)
  else:
    buf.add(cast[Rune](c1))

proc writeBinaryInt32(i: int32, buf: var RtString ) =
  let lowC = int16(i and 0xffff)
  let highC = int16(i shr 16)
  writeCharValue(lowC, buf)
  writeCharValue(highC, buf)

proc writeBinaryValue(value: Flow, buf: var RtString, structIdxs: var Table[int32, int32], structDefs: var seq[Flow]) =
  if value == nil:
    writeCharValue(0xffff, buf)
  else:
    case value.tp:
    of rtVoid: echo("Not implemented: toBinary of Void")
    of rtBool:
      let b = value.bool_v
      writeCharValue(if b: 0xFFFE else: 0xFFFD, buf)
    of rtInt:
      let int_value = value.int_v
      if (int_value and 0xFFFF8000) != 0:
        writeCharValue(0xFFF5, buf)
        writeBinaryInt32(int_value, buf)
      else:
        writeCharValue(int_value, buf)
    of rtDouble:
      writeCharValue(0xFFFC, buf)
      let bb = cast[array[0..7, int16]](value.double_v)
      var i = 0
      while (i < 4):
        writeCharValue(int32(bb[i]), buf)
        inc(i)
    of rtString:
      let s = value.string_v
      let str_len = rt_string_len(s)
      if str_len > 65535:
        writeCharValue(0xFFFB, buf)
        writeBinaryInt32(str_len, buf)
      else:
        writeCharValue(0xFFFA, buf)
        writeCharValue(str_len, buf)
      var i = 0i32
      while i < str_len:
        let v = rt_string_char_code(s, i)
        writeCharValue(v, buf)
        inc(i)
    of rtNative: echo("Not implemented: toBinary of Native: " & rt_string_to_utf8(rt_to_string(value)))
    of rtArray:
      let arr = value.array_v
      let l = int32(arr.len)
      if l == 0:
        writeCharValue(0xFFF7, buf)
      else:
        if l > 65535:
          writeCharValue(0xFFF9, buf)
          writeBinaryInt32(l, buf)
        else:
          writeCharValue(0xFFF8, buf)
          writeCharValue(l, buf)
        for v in arr:
          writeBinaryValue(v, buf, structIdxs, structDefs) 
    of rtFunc: echo("Not implemented: toBinary of " & rt_string_to_utf8(rt_to_string(value)))
    of rtStruct:
      let struct_id = value.str_id

      var struct_idx = 0i32
      if structIdxs.hasKey(struct_id):
        struct_idx = structIdxs[struct_id]
      else:
        struct_idx = int32(structDefs.len)
        structIdxs[struct_id] = struct_idx
        structDefs.add(value)

      writeCharValue(0xFFF4, buf)
      writeCharValue(struct_idx, buf);
      for field in value.str_args:
        writeBinaryValue(field, buf, structIdxs, structDefs)
    else: echo("Not implemented: toBinary of Native: " & rt_string_to_utf8(rt_to_string(value)))

proc $F_0(toBinary)*(value : Flow): RtString =
  var structIdxs = initTable[int32, int32]()
  var structDefs = newSeq[Flow]()

  var buf = rt_empty_string()
  writeBinaryValue(value, buf, structIdxs, structDefs)
  var buf2 = rt_empty_string()
  writeBinaryInt32(rt_string_len(buf) + 2, buf2)

  if structDefs.len == 0:
    writeCharValue(0xFFF7, buf)
  else:
    if structDefs.len > 65535:
      writeCharValue(0xFFF9, buf)
      writeBinaryInt32(int32(structDefs.len), buf)
    else:
      writeCharValue(0xFFF8, buf)
      writeCharValue(int32(structDefs.len), buf)

    for struct_def in structDefs:
      case struct_def.tp:
        of rtStruct:
          writeCharValue(0xFFF8, buf)
          writeCharValue(0x0002, buf)
          writeCharValue(int32(struct_def.str_args.len), buf)
          let s = rt_struct_id_to_name(struct_def.str_id)
          let str_len = rt_string_len(s)
          writeCharValue(0xFFFA, buf)
          writeCharValue(str_len, buf)
          var i = 0i32
          while i < str_len:
            let v = rt_string_char_code(s, i)
            writeCharValue(v, buf)
            inc(i)
        else: discard

  result = buf2 & buf