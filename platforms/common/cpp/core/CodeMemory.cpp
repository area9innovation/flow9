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
    static char empty;
    Start = MakeFlowPtr(start);
    Cursor = Begin = buffer ? buffer + start : &empty;
    Limit = Begin + size;
}

void CodeMemory::OperandOutOfRange()
{
    throw DecodeError("Bytecode operand exceeds the available bytes");
}

FlowPtr CodeMemory::RelativeTarget(FlowPtr base, int offset) const
{
    const int64_t target = int64_t(FlowPtrToInt(base)) + offset;
    if (base < Start || base > GetLastAddr() || target < FlowPtrToInt(Start) || target > FlowPtrToInt(GetLastAddr()))
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
    DecodeFieldType(&res, is_mutable, structname);
    return res;
}

void CodeMemory::DecodeFieldType(std::vector<FieldType> *type, char *is_mutable, std::string *structname)
{
    *is_mutable = false;
    for (;;) {
        unsigned char marker = ReadByte();
        switch (marker) {
        case FTMutable:
            *is_mutable = true;
            break;
        case FTTypedArray: case FTTypedRefTo:
            if (type) type->push_back(FieldType(marker));
            break;
        case FTTypedStruct:
            if (structname)
                *structname = ReadString();
            else
                GetBytes(ReadInt31());
            // Fall through: a typed struct is also a terminal type.
        case FTVoid: case FTBool: case FTInt: case FTDouble: case FTString:
        case FTArray: case FTStruct: case FTRefTo: case FTFlow:
            if (type) type->push_back(FieldType(marker));
            return;
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
        if (DecodeOperands<false>(*out, NULL))
            return true;
        if (out->op == CBreakpoint || out->op == CCodeCoverageTrap)
            return false; // The debugger reparses the operands with the original opcode.
    } catch (const DecodeError &) {
        // Keep the cursor at the start of an undecodable instruction.
    }
    SetPosition(old_pos);
    return false;
}

template<bool indexing>
bool CodeMemory::DecodeOperands(FlowInstruction &insn, std::vector<FlowPtr> *targets)
{
    OpCode opcode = insn.op;

#define SHAPE(sname) if (!indexing) insn.shape = FlowInstruction::sname;

    auto string_operand = [&]() {
        int size = ReadInt31();
        if (indexing) GetBytes(size); else insn.StrValue = ReadString(size);
    };

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
        if (indexing) GetBytes(1); else insn.IntValue = ReadByte();
        break;
    case CInt:
        SHAPE(Int);
        if (indexing) GetBytes(4); else insn.IntValue = ReadInt32();
        break;
    case CDouble:
        SHAPE(Double);
        if (indexing) GetBytes(8); else insn.DoubleVal = ReadDouble();
        break;
    case CString:
    case CNotImplemented:
    case CDebugInfo:
        SHAPE(String);
        string_operand();
        break;
    case CFieldName:
    case CSetMutableName:
    {
        SHAPE(String);
        char *plen = GetBytes(4);
        unsigned len = (unsigned char)plen[0];
        if (indexing) {
            GetBytes(len);
            // These two bytes belong to the current runner (also on raw reload).
            if (plen[2] || plen[3]) plen[2] = plen[3] = 0;
        } else insn.StrValue = ReadString(len);
        break;
    }
    case CWString:
    {
        SHAPE(String);
        int size = static_cast<unsigned char>(ReadByte());
        if (indexing) GetWideBytes(size); else insn.StrValue = encodeUtf8(ReadWideString(size));
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
        if (indexing) GetBytes(4); else insn.IntValue = ReadInt31();
        break;
    case CReserveLocals:
        SHAPE(IntInt);
        if (indexing) GetBytes(8); else {
            insn.IntValue = ReadInt32();
            insn.IntValue2 = ReadInt32();
        }
        break;
    case CGoto:
    case CCodePointer:
    case CIfFalse:
    {
        SHAPE(Ptr);
        int v = ReadInt31();
        insn.PtrValue = RelativeTarget(GetPosition(), v);
        if (indexing) {
            if (opcode == CCodePointer && insn.PtrValue == GetLastAddr())
                throw DecodeError("Invalid bytecode callable address");
            targets->push_back(insn.PtrValue);
        }
        break;
    }
    case CNativeFn:
    case COptionalNativeFn:
    {
        SHAPE(IntString);
        insn.IntValue = ReadInt31();
        string_operand();
        break;
    }
    case CStructDef:
    {
        SHAPE(StructDef);
        insn.IntValue = ReadStructId();
        string_operand();
        insn.IntValue2 = ReadStructFieldCount();

        if (indexing) {
            for (int k = 0; k < insn.IntValue2; ++k) {
                GetBytes(ReadInt31());
                char mut;
                DecodeFieldType(NULL, &mut, NULL);
            }
            break;
        }
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
        if (indexing) {
            if (insn.PtrValue == GetLastAddr()) throw DecodeError("Invalid bytecode callable address");
            targets->push_back(insn.PtrValue);
        }
        break;
    }
    case CSwitch:
    case CSimpleSwitch:
    {
        SHAPE(Switch);
        insn.IntValue = ReadSwitchCount(&insn.IntValue2);

        FlowPtr pos = GetPosition() + insn.IntValue * 8;

        std::unique_ptr<FlowInstruction::Case[]> cases(indexing ? NULL : new FlowInstruction::Case[insn.IntValue]);
        for (int k = 0; k < insn.IntValue; ++k)
        {
            int id = ReadStructId();
            FlowPtr target = RelativeTarget(pos, ReadInt31());
            if (indexing) targets->push_back(target);
            else {
                cases[k].id = id;
                cases[k].target = target;
            }
        }
        if (!indexing) {
            delete[] insn.cases;
            insn.cases = cases.release();
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
        return false;
    }

#undef SHAPE
    return true;
}

void CodeMemory::BuildInstructionIndex(std::vector<bool> &starts)
{
    std::vector<bool> index(size_t(GetSize()) + 1);
    std::vector<FlowPtr> targets;
    FlowInstruction scratch;
    while (!Eof()) {
        index[Cursor - Begin] = true;
        scratch.op = ReadOpcode();
        if (!DecodeOperands<true>(scratch, &targets))
            throw DecodeError("Cannot decode bytecode instruction");
    }
    index.back() = true; // fallthrough and native return, never a callable
    for (FlowPtr target : targets) {
        if (!index[target - Start]) throw DecodeError("Invalid bytecode branch address");
    }
    starts.swap(index);
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
