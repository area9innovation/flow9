import BytecodeWriter;

class BytecodeDisassembler {
	private var normalize : Bool;
	
	public function new(bytes : BytesInput, debugInfo : DebugInfo) {
		memory = new ByteMemory(bytes.size);
		code = new CodeMemory(bytes, memory, 0);
		normalize = false;
	}
	
	public function disassemble(?names : Names = null, ?normalize : Bool = false) : Void {
		print("Disassembly:");
		this.names = names;
		this.normalize = normalize;
		while (!code.eof()) {
			disassembleInstruction();
		}
		print("");
	}

	function decodeOffset(offs : Int, ?base : Int = -1) {
		if (normalize && names != null) {
			return '.+' + offs;
		} else {
			if (base == -1) {
				base = code.getPosition();
			}
			return StringTools.hex(base + offs, 4);
		}
	}
	
	function decodeStructName(no : Int) {
		if (normalize && names != null) {
			return names.structs.keyi(no);
		} else {
			return StringTools.hex(no);
		}
	}
	function decodeGlobalName(no : Int) {
		if (normalize && names != null) {
			return names.toplevelAndOuter.keyi(no);
		} else {
			return StringTools.hex(no);
		}
	}
	function disassembleInstruction() : Void {
		var pc = code.getPosition();
		var opcode = code.readByte();
		var s = "";
		if (debugInfo != null) {
			s += debugInfo.getPosition(pc);
		}
		if (!normalize) {
			s += StringTools.hex(pc, 4) + ": ";
		}
		s += opcode2string(opcode) + " ";
		s += switch (opcode) {
			case Bytecode.CVoid: "";
			case Bytecode.CBool: if (code.readByte() == 0) "false" else "true";
			case Bytecode.CInt: '' + code.readInt32();
			case Bytecode.CDouble: '' + code.readDouble();
			case Bytecode.CString: readString();
			case Bytecode.CWString: readWideString();
			case Bytecode.CArray: '' + code.readInt31();
			case Bytecode.CStruct: decodeStructName(code.readInt31());
			case Bytecode.CSetLocal: '' + code.readInt32();
			case Bytecode.CGetLocal: '' + code.readInt32();
			case Bytecode.CGetGlobal: decodeGlobalName(code.readInt31());
			case Bytecode.CReturn: '';
			case Bytecode.CGoto: {
				var v = code.readInt31();
				//'+' + v + " to " + 
				decodeOffset(v);
			}
			case Bytecode.CCodePointer: {
				var v = code.readInt31();
				//'+' + v + " to " + 
				decodeOffset(v);
			}
			case Bytecode.CCall: "";
			case Bytecode.CNotImplemented: readString();
			case Bytecode.CIfFalse: {
				var v = code.readInt31();
				//'+' + v + " to " + 
				decodeOffset(v);
			}
			case Bytecode.CNot: "";
			case Bytecode.CNegate: "";
			case Bytecode.CNegateInt: "";
			case Bytecode.CMultiply: "";
			case Bytecode.CMultiplyInt: "";
			case Bytecode.CDivide: "";
			case Bytecode.CDivideInt: "";
			case Bytecode.CModulo: "";
			case Bytecode.CModuloInt: "";
			case Bytecode.CPlus: "";
			case Bytecode.CPlusInt: "";
			case Bytecode.CPlusString: "";
			case Bytecode.CMinus: "";
			case Bytecode.CMinusInt: "";
			case Bytecode.CEqual: "";
			case Bytecode.CLessThan: "";
			case Bytecode.CLessEqual: "";
			case Bytecode.CNativeFn: code.readInt31() + " " + readString();
			case Bytecode.COptionalNativeFn: code.readInt31() + " " + readString();
			case Bytecode.CPop: "";
			case Bytecode.CArrayGet: "";
			case Bytecode.CReserveLocals: code.readInt31() + ' ' + code.readInt32();
			case Bytecode.CRefTo: "";
			case Bytecode.CDeref: "";
			case Bytecode.CSetRef: "";
			case Bytecode.CInt2Double: "";
			case Bytecode.CInt2String: "";
			case Bytecode.CDouble2Int: "";
			case Bytecode.CDouble2String: "";
			case Bytecode.CField: '' + code.readInt31();
			case Bytecode.CFieldName: readString();
			case Bytecode.CSetMutable: '' + code.readInt31();
			case Bytecode.CSetMutableName: readString();
			case Bytecode.CStructDef: {
				var id = code.readInt31();
				var r = readString() + "[" + id + "](";
				var n = code.readInt31();
				var sep = "";
				for (i in 0...n) {
					r += sep + readString();
					sep = ", ";
					// Skip type of field
					var eot = false;
					do { 
						var b = code.readByte();
						if ( b == Bytecode.CTypedStruct) readString();
						if ( b != Bytecode.CTypedArray && b != Bytecode.CTypedRefTo && b != Bytecode.CSetMutable) eot = true;
					} while (!eot);

				}
				r + ")";
			}
			case Bytecode.CGetFreeVar: '' + code.readInt31();
			case Bytecode.CDebugInfo: readString();
			case Bytecode.CClosureReturn: "";
			case Bytecode.CClosurePointer: {
				var n = code.readInt31();
				var v = code.readInt31();
				//'+' + v + " to " + 
				'' + n + ' ' + decodeOffset(v);
			}
			case Bytecode.CSwitch: {
				var n = code.readInt31();
				var end = code.readInt31();
				var pos = code.getPosition() + n * 8;
				var po = function(o) { return decodeOffset(o, pos); };
				var r = 'end:' + po(end);
				var sep = " ";
				for (i in 0...n) {
					var c = code.readInt31();
					var off = code.readInt31();
					r += sep + decodeStructName(c) + ': ' + po(off);
					sep = ", ";
				}
				r;
			}
			case Bytecode.CSimpleSwitch: {
				// same format as CSwitch;
				var n = code.readInt31();
				var end = code.readInt31();
				var pos = code.getPosition() + n * 8;
				var po = function(o) { return decodeOffset(o, pos); };
				var r = 'end:' + po(end);
				var sep = " ";
				for (i in 0...n) {
					var c = code.readInt31();
					var off = code.readInt31();
					r += sep + decodeStructName(c) + ': ' + po(off);
					sep = ", ";
				}
				r;
			}
			case Bytecode.CUncaughtSwitch: "";
			case Bytecode.CTailCall: '' + code.readInt32();
			case Bytecode.CLast: "";
         	default: "?";
		}
		print(s);
	}

	static public function opcode2string(c) {
		return "0x" + StringTools.hex(c, 2) + " " + BytecodeUtil.opname(c);
	}

	inline function readString() : String {
		var l = code.readInt31();
		return code.readString(l);
	}

	inline function readWideString() : String {
		var l = code.readByte();
		return code.readWideString(l);
	}

	function print(s : String) {
		if (s.length > 100) {
			s = s.substr(0, 99);
		}
		#if (flash)
			flash.external.ExternalInterface.call("console.log", s);
		#elseif js
			trace(s);
		#else
			Sys.println(s);
		#end
	}
	
	var memory : ByteMemory;
	var code : CodeMemory;
	var debugInfo : DebugInfo;
	var names : Names;
}
