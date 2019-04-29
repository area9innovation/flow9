#ifndef _OPCODES_H_
#define _OPCODES_H_

typedef enum
{
    // How to read the documentation for opcodes:
    //
    //  CBool = 0x01; // value : byte ( --> bool)
    //
    // This means that in the byte stream, first the hex-byte 0x01 comes, and after that a byte
    // which is the bool constant value. The ( --> bool) is the stack behaviour of this opcode. In this
    // case, it does not expect anything on the stack, but pushes a boolean value to it.

    // int is 32 bits
    CVoid                       = 0x00, // ( --> void)
    CBool                       = 0x01, // value : byte ( --> bool)
    CInt                        = 0x02, // value : int ( --> int)
    CDouble                     = 0x03, // value : double ( --> double)
    CString                     = 0x04, // length : int, utf8chars : byte[length] ( --> string)
    CArray                      = 0x05, // length : int ( v1 ... vn --> constantarray )
    CStruct                     = 0x06, // kind : int ( v1 ... vn --> struct)
    CSetLocal                   = 0x07, // slot : int ( value --> )
    CGetLocal                   = 0x08, // idnumber : int ( --> value)
    CGetGlobal                  = 0x09, // idnumber : int ( --> value)
    CReturn                     = 0x0a, // ( --> )
    CGoto                       = 0x0b, // offset : int ( --> )
    CCodePointer                = 0x0c, // offset : int ( --> pointer ) Takes pc, adds offset, and puts that as a pointer to code
    CCall                       = 0x0d, // ( --> )
    CNotImplemented             = 0x0e, // message : string
    CIfFalse                    = 0x0f, // ( bool --> )
    CNot                        = 0x10, // ( bool --> bool )
    CPlus                       = 0x11, // ( int/double/string int/double/string --> int/double/string )
    CMinus                      = 0x12, // ( int/double int/double --> int/double )
    CLessThan                   = 0x13, // ( int/double/string int/double/string --> bool )
    CNativeFn                   = 0x14, // args : int, name : string ( args --> value )
    CEqual                      = 0x15, // ( int/double/string int/double/string --> int/double/string )
    CNegate                     = 0x16, // ( int/double --> int/double )
    CMultiply                   = 0x18, // ( int/double int/double --> int/double )
    CDivide                     = 0x19, // ( int/double int/double --> int/double )
    CModulo                     = 0x1a, // ( int/double int/double --> int/double )
    CPop                        = 0x1b, // ( value --> )
    CLessEqual                  = 0x1c, // ( int/double/string int/double/string --> int/double/string )
    CArrayGet                   = 0x1d, // ( array index --> value )
    CReserveLocals              = 0x1e, // nlocals : int, args : int ( --> void*nlocals )
    CRefTo                      = 0x1f, // ( value --> pointer )
    CDebugInfo                  = 0x20, // name : string ( --> )
    CDeref                      = 0x21, // ( pointer --> value )
    CSetRef                     = 0x22, // ( pointer value --> )
    CInt2Double                 = 0x23, // (int --> double)
    CInt2String                 = 0x24, // (int --> string)
    CDouble2Int                 = 0x25, // (double --> int)
    CDouble2String              = 0x26, // (string --> int)
    CField                      = 0x27, // index : int (structvalue --> value)
    CFieldName                  = 0x28, // name : string (structvalue --> value)
    CStructDef                  = 0x29, // name : string n : int name1: string ... ( --> )
    CGetFreeVar                 = 0x2a, // index : int ( --> value )
    CClosureReturn              = 0x2b, // ( --> )
    CClosurePointer             = 0x2c, // n : int offset : int ( v1 ... vn --> call ) Takes pc, adds offset, and puts that as a pointer to code aint with a closure pointer
    CSwitch                     = 0x2d, // cases : int, defaultoffset : int, c1 : int, off1 : int, ... cn : int, offn : int
    CUncaughtSwitch             = 0x2e, // This should crash the execution. Used for the uncatch switches
    CTailCall                   = 0x2f, // Tail call
    CPlusString                 = 0x30, // ( string string --> string )
    CPlusInt                    = 0x31, // ( int int --> int )
    CMinusInt                   = 0x32, // ( int int --> int )
    CNegateInt                  = 0x33, // ( int --> int )
    CMultiplyInt                = 0x34, // ( int int --> int )
    CDivideInt                  = 0x35, // ( int int --> int )
    CModuloInt                  = 0x36, // ( int int --> int )
    CSimpleSwitch               = 0x37, // like switch
    CWString                    = 0x38, // length : byte, utf16chars : wchar[length] ( --> string)
    CLast                       = 0x39, // Nothing, just sentinel
    CBreakpoint                 = 0x40, // Breakpoint marker. The real opcode is saved in a map.
    // Opcodes for complex types description in the StructDefs
    CTypedArray                 = 0x41,
    CTypedStruct                = 0x42,
    CTypedRefTo                 = 0x43,
    // like CNativeFn, but replaces top value on stack, or does nothing if no such native
    COptionalNativeFn           = 0x44,
    // Mutable fields
    CSetMutable                 = 0x45, // index : int (structvalue value -->)
    CSetMutableName             = 0x46, // name : string (structvalue value -->)
    CCodeCoverageTrap                   // Code coverage trap. Like breakpoint, but records a profiling sample.
} OpCode;

#endif
