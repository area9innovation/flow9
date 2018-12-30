class BytecodeUtil {
	static public function opname(opcode : Int) : String {
		return switch (opcode) {
		case Bytecode.CVoid: "Void";
		case Bytecode.CBool: "Bool";
		case Bytecode.CInt: "Int";
		case Bytecode.CDouble: "Double";
		case Bytecode.CString: "String";
		case Bytecode.CWString: "WString";
		case Bytecode.CArray: "Array";
		case Bytecode.CStruct: "Struct";
		case Bytecode.CSetLocal: "SetLocal";
		case Bytecode.CGetLocal: "GetLocal";
		case Bytecode.CGetGlobal: "GetGlobal";
		case Bytecode.CReturn: "Return";
		case Bytecode.CPop: "Pop";
		case Bytecode.CGoto: "Goto";
		case Bytecode.CCodePointer: "CodePointer";
		case Bytecode.CCall: "Call";
		case Bytecode.CNotImplemented: "NotImplemented";
		case Bytecode.CIfFalse: "IfFalse";
		case Bytecode.CNot: "Not";
		case Bytecode.CNegate: "Negate";
		case Bytecode.CNegateInt: "NegateInt";
		case Bytecode.CMultiply: "Multiply";
		case Bytecode.CMultiplyInt: "MultiplyInt";
		case Bytecode.CDivide: "Divide";
		case Bytecode.CDivideInt: "DivideInt";
		case Bytecode.CModulo: "Modulo";
		case Bytecode.CModuloInt: "ModuloInt";
		case Bytecode.CPlus: "Plus";
		case Bytecode.CPlusInt: "PlusInt";
		case Bytecode.CPlusString: "PlusString";
		case Bytecode.CMinus: "Minus";
		case Bytecode.CMinusInt: "MinusInt";
		case Bytecode.CEqual: "Equal";
		case Bytecode.CLessThan: "LessThan";
		case Bytecode.CLessEqual: "LessEqual";
		case Bytecode.CNativeFn: "NativeFn";
		case Bytecode.COptionalNativeFn: "OptionalNativeFn";
		case Bytecode.CArrayGet: "ArrayGet";
		case Bytecode.CReserveLocals: "ReserveLocals";
		case Bytecode.CRefTo: "RefTo";
		case Bytecode.CDeref: "Deref";
		case Bytecode.CSetRef: "SetRef";
		case Bytecode.CInt2Double: "Int2Double";
		case Bytecode.CInt2String: "Int2String";
		case Bytecode.CDouble2Int: "Double2Int";
		case Bytecode.CDouble2String: "Double2String";
		case Bytecode.CField: "Field";
		case Bytecode.CFieldName: "FieldName";
		case Bytecode.CSetMutable: "SetMutable";
		case Bytecode.CSetMutableName: "SetMutableName";
		case Bytecode.CStructDef: "StructDef";
		case Bytecode.CGetFreeVar: "GetFreeVar";
		case Bytecode.CDebugInfo: "DebugInfo --------------------- ";
		case Bytecode.CClosureReturn: "ClosureReturn";
		case Bytecode.CClosurePointer: "ClosurePointer";
		case Bytecode.CSwitch: "Switch";
		case Bytecode.CSimpleSwitch: "SimpleSwitch";
		case Bytecode.CUncaughtSwitch: "UncaughtSwitch";
		case Bytecode.CTailCall: "TailCall";
		case Bytecode.CLast: "Last";
		default: "?";
		}
	}


	public static function skipCommand (code: CodeMemory) {
		var skipString = function() { code.skipString(code.readInt31()); }
		var skipWideString = function() {code.skipString(code.readByte() * 2); }
		var skipSwitch = function()  {
			var n = code.readInt31();
			code.skipInt();
			for (i in 0...n) {
				code.skipInt();
				code.skipInt();
			}
		}
		switch (code.readByte()) {
			case Bytecode.CVoid: {}
			case Bytecode.CBool: code.skipByte();
			case Bytecode.CInt: code.skipInt(); 
			case Bytecode.CDouble: code.skipDouble(); 
			case Bytecode.CString: skipString();
			case Bytecode.CWString: skipWideString();
			case Bytecode.CArray: code.skipInt();
			case Bytecode.CStruct: code.skipInt();
			case Bytecode.CSetLocal: code.skipInt();
			case Bytecode.CGetLocal: code.skipInt();
			case Bytecode.CGetGlobal: code.skipInt();
			case Bytecode.CReturn: {}
			case Bytecode.CGoto: code.skipInt();
			case Bytecode.CCodePointer: code.skipInt();
			case Bytecode.CCall: {}
			case Bytecode.CNotImplemented: skipString();
			case Bytecode.CIfFalse: code.skipInt();
			case Bytecode.CNot: {}
			case Bytecode.CNegate: {}
			case Bytecode.CNegateInt: {}
			case Bytecode.CMultiply: {}
			case Bytecode.CMultiplyInt: {}
			case Bytecode.CDivide: {}
			case Bytecode.CDivideInt: {}
			case Bytecode.CModulo: {}
			case Bytecode.CModuloInt: {}
			case Bytecode.CPlus: {}
			case Bytecode.CPlusInt: {}
			case Bytecode.CPlusString: {}
			case Bytecode.CMinus: {}
			case Bytecode.CMinusInt: {}
			case Bytecode.CEqual: {}
			case Bytecode.CLessThan: {}
			case Bytecode.CLessEqual: {}
			case Bytecode.CNativeFn: code.skipInt(); skipString();
			case Bytecode.COptionalNativeFn: code.skipInt(); skipString();
			case Bytecode.CPop: {}
			case Bytecode.CArrayGet: {}
			case Bytecode.CReserveLocals: code.skipInt(); code.skipInt();
			case Bytecode.CRefTo: {}
			case Bytecode.CDeref: {}
			case Bytecode.CSetRef: {}
			case Bytecode.CInt2Double: {}
			case Bytecode.CInt2String: {}
			case Bytecode.CDouble2Int: {}
			case Bytecode.CDouble2String: {}
			case Bytecode.CField: code.skipInt();
			case Bytecode.CFieldName: skipString();
			case Bytecode.CSetMutable: code.skipInt();
			case Bytecode.CSetMutableName: skipString();
			case Bytecode.CStructDef: {
				code.skipInt();
				skipString();
				var n = code.readInt31();
				for (i in 0...n) {
					skipString();
					// Skip type of field
					var eot = false;
					do { 
						var b = code.readByte();
						if ( b == Bytecode.CTypedStruct) skipString();
						if ( b != Bytecode.CTypedArray && b != Bytecode.CTypedRefTo && b != Bytecode.CSetMutable) eot = true;
					} while (!eot);
				}
 			}
			case Bytecode.CGetFreeVar: code.skipInt();
			case Bytecode.CDebugInfo: skipString();
			case Bytecode.CClosureReturn: {}
			case Bytecode.CClosurePointer: code.skipInt(); code.skipInt();
			case Bytecode.CSwitch: skipSwitch();
			case Bytecode.CSimpleSwitch: skipSwitch();
			case Bytecode.CUncaughtSwitch: {}
			case Bytecode.CTailCall: code.skipInt();
			case Bytecode.CLast: {}
		}
	}
}
