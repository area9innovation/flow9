# native toBinary : (value : flow) -> string = Native.toBinary
import tables
import strutils
import unicode

proc writeCharValue(c : int, buf : var string) =
  buf.add(cast[Rune](c and 0xffff))

proc writeBinaryInt32(i : int, buf : var string ) =
  let lowC = (int16) (i and 0xffff)
  let highC = (int16) (i shr 16)
  writeCharValue(lowC, buf)
  writeCharValue(highC, buf)

proc writeBinaryValue(value: Flow, buf: var string, structIdxs: var Table[int32, int], structDefs: var seq[Flow]) =
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
        writeCharValue(int(bb[i]), buf)
        inc(i)
    of rtString:
      let s = value.string_v
      let str_len = s.len
      if str_len > 65535:
        writeCharValue(0xFFFB, buf)
        writeBinaryInt32(str_len, buf)
      else:
        writeCharValue(0xFFFA, buf)
        writeCharValue(str_len, buf)
      var i = 0
      while i < str_len:
        let v = s[i].ord
        writeCharValue(v, buf)
        inc(i)
    of rtNative: echo("Not implemented: toBinary of Native: " & rt_to_string(value))
    of rtArray:
      let arr = value.array_v
      let l = arr.len
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
    of rtFunc: echo("Not implemented: toBinary of " & rt_to_string(value))
    of rtStruct:
      let struct_id = value.str_id

      var struct_idx = 0
      if structIdxs.hasKey(struct_id):
        struct_idx = structIdxs[struct_id]
      else:
        struct_idx = structDefs.len
        structIdxs[struct_id] = struct_idx
        structDefs.add(value)

      writeCharValue(0xFFF4, buf)
      writeCharValue(struct_idx, buf);
      for field in value.str_args:
        writeBinaryValue(field, buf, structIdxs, structDefs)
    else: echo("Not implemented: toBinary of Native: " & rt_to_string(value))

proc $F_0(toBinary)*(value : Flow): string =
  var structIdxs = initTable[int32, int]()
  var structDefs = newSeq[Flow]()

  var buf = ""
  writeBinaryValue(value, buf, structIdxs, structDefs)
  var buf2 = ""
  writeBinaryInt32(buf.runeLen + 2, buf2)

  if structDefs.len == 0:
    writeCharValue(0xFFF7, buf)
  else:
    if structDefs.len > 65535:
      writeCharValue(0xFFF9, buf)
      writeBinaryInt32(structDefs.len, buf)
    else:
      writeCharValue(0xFFF8, buf)
      writeCharValue(structDefs.len, buf)

    for struct_def in structDefs:
      case struct_def.tp:
        of rtStruct:
          writeCharValue(0xFFF8, buf)
          writeCharValue(0x0002, buf)
          writeCharValue(struct_def.str_args.len, buf)
          let s = struct_def.str_name
          let str_len = s.len
          writeCharValue(0xFFFA, buf)
          writeCharValue(str_len, buf)
          var i =0
          while i < str_len:
            let v = s[i].ord
            writeCharValue(v, buf)
            inc(i)
        else: discard

  result = buf2 & buf