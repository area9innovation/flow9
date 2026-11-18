#include "CodeMemory.h"

#include <cassert>
#include <iomanip>
#include <limits>
#include <memory>

CodeMemory::CodeMemory()
{
    SetBuffer(NULL, 0, 0);
}

void CodeMemory::SetBuffer(char *buffer, int start, int size)
{
    if (start < 0 || size < 0 || (size && !buffer) || size > std::numeric_limits<int>::max() - start)
        throw DecodeError("Invalid bytecode buffer range");
    Buffer = buffer;
    Position = Start = MakeFlowPtr(start);
    End = Start + size;
}

FlowPtr CodeMemory::RelativeTarget(FlowPtr base, int offset) const
{
    const int64_t target = int64_t(FlowPtrToInt(base)) + offset;
    if (base < Start || base > End || target < FlowPtrToInt(Start) || target > FlowPtrToInt(End))
        throw DecodeError("Bytecode target is outside the code range");
    return MakeFlowPtr(unsigned(target));
}

int CodeMemory::ReadStructId()
{
    int id = ReadInt31();
    if (unsigned(id) > std::numeric_limits<uint16_t>::max()) // StackSlot::GetStructId
        throw DecodeError("Invalid bytecode struct id");
    return id;
}

int CodeMemory::ReadStructFieldCount()
{
    const int count = ReadInt31();
    // Each field needs at least a 4-byte name length and a type marker.
    if (!CanRead(count, 5))
        throw DecodeError("Invalid bytecode struct field count");
    return count;
}

int CodeMemory::ReadSwitchCount(int *default_offset)
{
    const int count = ReadInt31();
    // The interpreter uses fall-through for the default, but still consumes its operand.
    const int offset = ReadInt31();
    if (!CanRead(count, 8))
        throw DecodeError("Invalid bytecode switch table size");
    if (default_offset)
        *default_offset = offset;
    return count;
}

unicode_string CodeMemory::ReadWideString(int len)
{
    const char *bytes = GetWideBytes(len);
    unicode_string result(len, 0);
    if (len)
        memcpy(&result[0], bytes, len * 2);
    return result;
}

std::string CodeMemory::ReadString()
{
    int l = ReadInt31();
    if (l)
        return ReadString(l);
    else
        return std::string();
}

std::vector<FieldType> CodeMemory::ReadFieldType(char *is_mutable, std::string *structname)
{
    std::vector<FieldType> res;
    *is_mutable = false;
    for (;;) {
        unsigned char marker = ReadByte();
        switch (marker) {
        case FTMutable:
            *is_mutable = true;
            break;
        case FTTypedArray: case FTTypedRefTo:
            res.push_back(FieldType(marker));
            break;
        case FTTypedStruct:
            if (structname)
                *structname = ReadString();
            else
                GetBytes(ReadInt31());
            // Fall through: a typed struct is also a terminal type.
        case FTVoid: case FTBool: case FTInt: case FTDouble: case FTString:
        case FTArray: case FTStruct: case FTRefTo: case FTFlow:
            res.push_back(FieldType(marker));
            return res;
        default:
            throw DecodeError("Invalid bytecode field type marker");
        }
    }
}

bool CodeMemory::ParseOpcode(FlowInstruction *out, bool reparse)
{
    FlowPtr old_pos = GetPosition();

    try {
        if (!reparse)
            out->op = ReadOpcode();
        if (ParseOpcodeOperands(out))
            return true;
        if (out->op == CBreakpoint || out->op == CCodeCoverageTrap)
            return false; // The debugger reparses the operands with the original opcode.
    } catch (const DecodeError &) {
        // Keep the cursor at the start of an undecodable instruction.
    }
    SetPosition(old_pos);
    return false;
}

bool CodeMemory::ParseOpcodeOperands(FlowInstruction *out)
{
    OpCode opcode = out->op;
    FlowInstruction &insn = *out;

#define SHAPE(sname) insn.shape = FlowInstruction::sname;

    switch (opcode)
    {
    case CVoid:
    case CReturn:
    case CCall:
    case CNot:
    case CPlus:
    case CMinus:
    case CLessThan:
    case CEqual:
    case CNegate:
    case CMultiply:
    case CDivide:
    case CModulo:
    case CPop:
    case CLessEqual:
    case CArrayGet:
    case CRefTo:
    case CDeref:
    case CSetRef:
    case CInt2Double:
    case CInt2String:
    case CDouble2Int:
    case CDouble2String:
    case CClosureReturn:
    case CUncaughtSwitch:
    case CPlusString:
    case CPlusInt:
    case CMinusInt:
    case CNegateInt:
    case CMultiplyInt:
    case CDivideInt:
    case CModuloInt:
    case CLast:
        SHAPE(Atom);
        break;
    case CBool:
        SHAPE(Int);
        insn.IntValue = ReadByte();
        break;
    case CInt:
        SHAPE(Int);
        insn.IntValue = ReadInt32();
        break;
    case CDouble:
        SHAPE(Double);
        insn.DoubleVal = ReadDouble();
        break;
    case CString:
    case CNotImplemented:
    case CDebugInfo:
        SHAPE(String);
        insn.StrValue = ReadString();
        break;
    case CFieldName:
    case CSetMutableName:
    {
        SHAPE(String);
        char *plen = GetBytes(4);
        insn.StrValue = ReadString((unsigned char)plen[0]);
        break;
    }
    case CWString:
    {
        SHAPE(String);
        int size = static_cast<unsigned char>(ReadByte());
        insn.StrValue = encodeUtf8(ReadWideString(size));
        break;
    }
    case CStruct:
        SHAPE(Int);
        insn.IntValue = ReadStructId();
        break;
    case CArray:
    case CField:
    case CSetMutable:
    case CGetFreeVar:
    case CSetLocal:
    case CGetGlobal:
    case CGetLocal:
    case CTailCall:
        SHAPE(Int);
        insn.IntValue = ReadInt31();
        break;
    case CReserveLocals:
        SHAPE(IntInt);
        insn.IntValue = ReadInt32();
        insn.IntValue2 = ReadInt32();
        break;
    case CGoto:
    case CCodePointer:
    case CIfFalse:
    {
        SHAPE(Ptr);
        int v = ReadInt31();
        insn.PtrValue = RelativeTarget(GetPosition(), v);
        break;
    }
    case CNativeFn:
    case COptionalNativeFn:
    {
        SHAPE(IntString);
        insn.IntValue = ReadInt31();
        insn.StrValue = ReadString();
        break;
    }
    case CStructDef:
    {
        SHAPE(StructDef);
        insn.IntValue = ReadStructId();
        insn.StrValue = ReadString();
        insn.IntValue2 = ReadStructFieldCount();

        std::unique_ptr<FlowInstruction::Field[]> fields(new FlowInstruction::Field[insn.IntValue2]);
        for (int k = 0; k < insn.IntValue2; ++k)
        {
            fields[k].name = ReadString();
            fields[k].type = ReadFieldType(&fields[k].is_mutable, NULL);
        }
        delete[] insn.fields;
        insn.fields = fields.release();
        break;
    }
    case CClosurePointer:
    {
        SHAPE(IntPtr);
        insn.IntValue = ReadInt31();
        int v = ReadInt31();
        insn.PtrValue = RelativeTarget(GetPosition(), v);
        break;
    }
    case CSwitch:
    case CSimpleSwitch:
    {
        SHAPE(Switch);
        insn.IntValue = ReadSwitchCount(&insn.IntValue2);

        FlowPtr pos = GetPosition() + insn.IntValue * 8;

        std::unique_ptr<FlowInstruction::Case[]> cases(new FlowInstruction::Case[insn.IntValue]);
        for (int k = 0; k < insn.IntValue; ++k)
        {
            cases[k].id = ReadStructId();
            cases[k].target = RelativeTarget(pos, ReadInt31());
        }
        delete[] insn.cases;
        insn.cases = cases.release();
        break;
    }

    case CBreakpoint:
    {
        return false;
    }

    case CCodeCoverageTrap:
    {
        return false;
    }

    default:
        return false;
    }

#undef SHAPE
    return true;
}

std::ostream &operator<< (std::ostream &out, const FlowInstruction &insn)
{
    std::string name = FlowInstruction::OpCode2String(insn.op);

    if (insn.shape == FlowInstruction::Atom)
        out << name;
    else
        out << std::left << std::setw(18) << name;

    switch (insn.shape)
    {
    case FlowInstruction::Atom:
        break;
    case FlowInstruction::Int:
        out << insn.IntValue;
        break;
    case FlowInstruction::IntInt:
        out << insn.IntValue << ", " << insn.IntValue2;
        break;
    case FlowInstruction::IntPtr:
        out << insn.IntValue << ", ";
        out << stl_sprintf("0x%08x", FlowPtrToInt(insn.PtrValue));
        break;
    case FlowInstruction::Ptr:
        out << stl_sprintf("0x%08x", FlowPtrToInt(insn.PtrValue));
        break;
    case FlowInstruction::Double:
        out << insn.DoubleVal;
        break;
    case FlowInstruction::IntString:
        out << insn.IntValue << ", ";
        printQuotedString(out, insn.StrValue);
        break;
    case FlowInstruction::String:
        printQuotedString(out, insn.StrValue);
        break;
    case FlowInstruction::Switch:
        for (int k = 0; k < insn.IntValue; k++)
            out << (k > 0 ? ", " : "") << insn.cases[k].id
                << stl_sprintf("->0x%08x", FlowPtrToInt(insn.cases[k].target));
        break;
    case FlowInstruction::StructDef:
        out << insn.IntValue << ", ";
        printQuotedString(out, insn.StrValue);
        out << " (";
        for (int k = 0; k < insn.IntValue2; k++) {
            out << (k > 0 ? "," : "") << insn.fields[k].name
                << ":" << (insn.fields[k].is_mutable?"^":"") << int(insn.fields[k].type[0]);
            for (size_t t = 1; t < insn.fields[k].type.size(); t++)
                out << "." << int(insn.fields[k].type[t]);
        }
        out << ")";
        break;
    }

    return out;
}
