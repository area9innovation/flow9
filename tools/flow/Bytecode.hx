class Bytecode {
	// Binary files suck. Anyways, here is a nice hex viewer for windows: http://mh-nexus.de/en/hxd/
	
	// How to read the documentation for opcodes:
	//
	//    CBool = 0x01; // value : byte ( --> bool)
	//
	// This means that in the byte stream, first the hex-byte 0x01 comes, and after that a byte
	// which is the bool constant value. The ( --> bool) is the stack behaviour of this opcode. In this
	// case, it does not expect anything on the stack, but pushes a boolean value to it.
	
	// int is 32 bits
	static inline public var CVoid = 0x00; // ( --> void)
	static inline public var CBool = 0x01; // value : byte ( --> bool)
	static inline public var CInt = 0x02; // value : int ( --> int)
	static inline public var CDouble = 0x03; // value : double ( --> double)
	static inline public var CString = 0x04; // length : int, utf8chars : byte[length] ( --> string)
	static inline public var CArray = 0x05; // length : int ( v1 ... vn --> constantarray ) 
	static inline public var CStruct = 0x06; // kind : int ( v1 ... vn --> struct)
	static inline public var CSetLocal = 0x07; // slot : int ( value --> )
	static inline public var CGetLocal = 0x08; // idnumber : int ( --> value)
	static inline public var CGetGlobal = 0x09; // idnumber : int ( --> value)
	static inline public var CReturn = 0x0a; // ( --> )
	static inline public var CGoto = 0x0b; // offset : int ( --> )
	static inline public var CCodePointer = 0x0c; // offset : int ( --> pointer ) Takes pc, adds offset, and puts that as a pointer to code
	static inline public var CCall = 0x0d; // ( args closure --> result )
	static inline public var CNotImplemented = 0x0e; // message : string
	static inline public var CIfFalse = 0x0f; // ( bool --> )
	static inline public var CNot = 0x10; // ( bool --> bool )
	static inline public var CPlus = 0x11; // ( int/double/string int/double/string --> int/double/string )
	static inline public var CMinus = 0x12; // ( int/double int/double --> int/double )
	static inline public var CLessThan = 0x13; // ( int/double/string int/double/string --> bool )
	static inline public var CNativeFn = 0x14; // args : int, name : string ( args --> value )
	static inline public var CEqual = 0x15; // ( int/double/string int/double/string --> int/double/string )
	static inline public var CNegate = 0x16; // ( int/double --> int/double )
	static inline public var CMultiply = 0x18; // ( int/double int/double --> int/double )
	static inline public var CDivide = 0x19; // ( int/double int/double --> int/double )
	static inline public var CModulo = 0x1a; // ( int/double int/double --> int/double )
	static inline public var CPop = 0x1b; // ( value --> )
	static inline public var CLessEqual = 0x1c; // ( int/double/string int/double/string --> int/double/string )
	static inline public var CArrayGet = 0x1d; // ( array index --> value )
	static inline public var CReserveLocals = 0x1e; // locals : int args : int ( --> )
	static inline public var CRefTo = 0x1f; // ( value --> pointer )
	static inline public var CDebugInfo = 0x20; // name : string ( --> )
	static inline public var CDeref = 0x21; // ( pointer --> value )
	static inline public var CSetRef = 0x22; // ( pointer value --> )
	static inline public var CInt2Double = 0x23; // (int --> double)
	static inline public var CInt2String = 0x24; // (int --> string)
	static inline public var CDouble2Int = 0x25; // (double --> int)
	static inline public var CDouble2String = 0x26; // (string --> int)
	static inline public var CField = 0x27; // index : int (structvalue --> value)
	static inline public var CFieldName = 0x28; // name : string (structvalue --> value)
	static inline public var CStructDef = 0x29; // kind : int, name : string, n : int, name1: string, type1: type ... ( --> )
	static inline public var CGetFreeVar = 0x2a; // index : int ( --> value )
	static inline public var CClosureReturn = 0x2b; // ( --> )
	static inline public var CClosurePointer = 0x2c; // n : int offset : int ( v1 ... vn --> call )
			// Takes pc, adds offset, and puts that as a pointer to code along with a closure pointer
	static inline public var CSwitch = 0x2d; // cases : int, defaultoffset : int, c1 : int, off1 : int, ... cn : int, offn : int
	static inline public var CUncaughtSwitch = 0x2e; // This should crash the execution. Used for the uncatch switches
	static inline public var CTailCall = 0x2f; // ( args closure --> result )

	static inline public var CPlusString = 0x30; // ( string string --> string )
	static inline public var CPlusInt = 0x31; // ( int int --> int )
	static inline public var CMinusInt = 0x32; // ( int int --> int )
	static inline public var CNegateInt = 0x33; // ( int --> int )
	static inline public var CMultiplyInt = 0x34; // ( int int --> int )
	static inline public var CDivideInt = 0x35; // ( int int --> int )
	static inline public var CModuloInt = 0x36; // ( int int --> int )
	static inline public var CSimpleSwitch = 0x37; // same layout as CSwitch; see BytecodeRunner for difference
	static inline public var CWString = 0x38; // length : byte, utf16chars : int16[length] ( --> string)
	static inline public var CLast = 0x39; // Nothing, just sentinel
	static inline public var CBreakpoint = 0x40; // Breakpoint marker in the C++ runner
	// Opcodes for complex types description in the StructDefs
	static inline public var CTypedArray = 0x41;
	static inline public var CTypedStruct = 0x42;
	static inline public var CTypedRefTo = 0x43;
	// like CNativeFn, but replaces top value on stack, or does nothing if no such native
	static inline public var COptionalNativeFn = 0x44;
	// Mutable fields
	static inline public var CSetMutable = 0x45; // index : int (structvalue value -->)
	static inline public var CSetMutableName = 0x46; // name : string (structvalue value -->)
}
