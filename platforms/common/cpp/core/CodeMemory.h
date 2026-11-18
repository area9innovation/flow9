#ifndef _CODE_MEMORY_H_
#define _CODE_MEMORY_H_

#include "ByteMemory.h"
#include <stdexcept>

#ifdef _MSC_VER
#define _ALIGNED_4 align(4)
#define _ATTR(...) __declspec(##__VA_ARGS__)
#define __INLINE_WRAP(content) __forceinline content
#define _ATTR_PACK
#else
#define _ALIGNED_4 aligned(4)
#define _PACK packed
#define _ATTR(...) __attribute__((##__VA_ARGS__))
#define __INLINE_WRAP(content) content __attribute__((always_inline))
#define _ATTR_PACK __attribute__((packed))
#endif

// Unaligned memory access hack
#pragma pack(push,1)
union PackedVals {
    char bv;
    unsigned char ubv;
    unsigned short usv;
    int iv;
    unsigned uv;
    double dv;
} _ATTR_PACK;
#pragma pack(pop)

class CodeMemory
{
private:
    char *Buffer;
    FlowPtr Position, Start, End;
   
    PackedVals *GetItemPtr(int size) {
        return reinterpret_cast<PackedVals*>(GetBytes(size));
    }

public:
    struct DecodeError : std::runtime_error {
        explicit DecodeError(const char *message) : std::runtime_error(message) {}
    };

    CodeMemory();
    CodeMemory(char *buffer, int start, int size) {
        SetBuffer(buffer, start, size);
    }

    void SetBuffer(char *buffer, int start, int size);

    __INLINE_WRAP(void SetPosition(FlowPtr position)) {
        if (position >= Start && position <= End)
            Position = position;
    }
    void ResetPosition()  { Position = Start; }
    FlowPtr GetPosition() { return Position; }
    int GetSize()         { return End - Start; }
    FlowPtr GetLastAddr() { return End; }

    bool Eof() { return Position >= End; }
    bool CanRead(int count, int width = 1) const {
        // SetBuffer, SetPosition and GetBytes maintain Start <= Position <= End.
        return count >= 0 && width > 0
            && unsigned(count) <= (FlowPtrToInt(End) - FlowPtrToInt(Position)) / unsigned(width);
    }

    FlowPtr RelativeTarget(FlowPtr base, int offset) const;
    int ReadStructId();
    int ReadStructFieldCount();
    int ReadSwitchCount(int *default_offset = NULL);

    char ReadByte() {
        return GetItemPtr(1)->bv;
    }

    OpCode ReadOpcode() {
        const uint8_t opcode = static_cast<uint8_t>(ReadByte());
        if (opcode > CCodeCoverageTrap)
            throw DecodeError("Invalid bytecode opcode");
        return static_cast<OpCode>(opcode);
    }

    unsigned ReadInt32() {
        return GetItemPtr(4)->uv;
    }

    int ReadInt31() {
        return GetItemPtr(4)->iv;
    }

    void SkipInt() {
        GetBytes(4);
    }

    FlowDouble ReadDouble() {
#ifdef IOS
        double d;
        memcpy(&d, &GetItemPtr(8)->dv, 8);
        return FlowDouble(d);
#else
        return FlowDouble(GetItemPtr(8)->dv);
#endif
    }
    
    const char *GetWideBytes(int len) {
        if (!CanRead(len, 2))
            throw DecodeError("Invalid UTF-16 string length");
        return GetBytes(len * 2);
    }

    unicode_string ReadWideString(int len);

    std::string ReadString(int len) {
        const char *bytes = GetBytes(len);
        return len ? std::string(bytes, len) : std::string();
    }

    std::string ReadString();
    std::vector<FieldType> ReadFieldType(char *is_mutable, std::string *structname);

    char *GetBytes(int len) {
        // SetBuffer limits the range to INT_MAX, so a negative len fails too.
        if (unlikely(unsigned(len) > unsigned(End - Position)))
            throw DecodeError("Bytecode operand exceeds the available bytes");
        char *bytes = (len || Buffer) ? Buffer + FlowPtrToInt(Position) : NULL;
        Position += len;
        return bytes;
    }

    bool ParseOpcode(FlowInstruction *out, bool reparse = false);

private:
    bool ParseOpcodeOperands(FlowInstruction *out);
};

#endif
