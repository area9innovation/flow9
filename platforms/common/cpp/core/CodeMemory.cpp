#include "CodeMemory.h"

#include <cassert>
#include <iomanip>

CodeMemory::CodeMemory()
{
    SetBuffer(NULL, 0, 0);
}

void CodeMemory::SetBuffer(char *buffer, int start, int size)
{
    Buffer = buffer;
    Position = Start = MakeFlowPtr(start);
    End = Start + size;
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
    bool eot = false;
    *is_mutable = false;
    do {
        FieldType ft = (FieldType)(unsigned char)ReadByte();
        if (ft == FTMutable) {
            *is_mutable = true;
            continue;
        }
        res.push_back(ft);
        if (ft == FTTypedStruct) {
            std::string name = ReadString();
            if (structname)
                *structname = name;
        }
        if (ft != FTTypedArray && ft != FTTypedRefTo) eot = true;
    } while (!eot);
    return res;
}

bool CodeMemory::ParseOpcode(FlowInstruction *out, bool reparse)
{
    FlowPtr old_pos = GetPosition();

    if (!reparse)
        out->op = (OpCode)ReadByte();

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
        int size = ReadByte();
        insn.StrValue = encodeUtf8(ReadWideString(size));
        break;
    }
    case CArray:
    case CStruct:
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
        insn.PtrValue = (GetPosition() + v);
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
        insn.IntValue = ReadInt31();
        insn.StrValue = ReadString();
        insn.IntValue2 = ReadInt31();

        insn.fields = new FlowInstruction::Field[insn.IntValue2];
        for (int k = 0; k < insn.IntValue2; ++k)
        {
            insn.fields[k].name = ReadString();
            insn.fields[k].type = ReadFieldType(&insn.fields[k].is_mutable, NULL);
        }
        break;
    }
    case CClosurePointer:
    {
        SHAPE(IntPtr);
        insn.IntValue = ReadInt31();
        int v = ReadInt31();
        insn.PtrValue = (GetPosition() + v);
        break;
    }
    case CSwitch:
    case CSimpleSwitch:
    {
        SHAPE(Switch);
        insn.IntValue = ReadInt31();
        insn.IntValue2 = ReadInt31();

        FlowPtr pos = GetPosition() + insn.IntValue * 8;

        insn.cases = new FlowInstruction::Case[insn.IntValue];
        for (int k = 0; k < insn.IntValue; ++k)
        {
            insn.cases[k].id = ReadInt31();
            insn.cases[k].target = (pos + ReadInt31());
        }
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
        SetPosition(old_pos);
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
    case FlowInstruction::Ptr:
        out << stl_sprintf("0x%08x", FlowPtrToInt(insn.PtrValue));
        break;
    case FlowInstruction::Double:
        out << insn.DoubleVal;
        break;
    case FlowInstruction::IntString:
        out << insn.IntValue << ", ";
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
