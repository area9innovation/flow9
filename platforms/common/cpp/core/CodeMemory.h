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
    int pair[2];
    unsigned uv;
    double dv;
} _ATTR_PACK;
#pragma pack(pop)

class CodeMemory
{
private:
    char *Begin, *Cursor, *Limit;
    FlowPtr Start;
   
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
        unsigned offset = FlowPtrToInt(position) - FlowPtrToInt(Start);
        if (offset <= unsigned(GetSize())) Cursor = Begin + offset;
    }
    void ResetPosition()        { Cursor = Begin; }
    FlowPtr GetPosition() const { return Start + int(Cursor - Begin); }
    int GetSize() const         { return int(Limit - Begin); }
    FlowPtr GetLastAddr() const { return Start + GetSize(); }

    bool Eof() const { return Cursor == Limit; }
    bool CanRead(int count, int width = 1) const {
        return count >= 0 && width > 0 && unsigned(count) <= unsigned(Limit - Cursor) / unsigned(width);
    }

    FlowPtr RelativeTarget(FlowPtr base, int offset) const;
    int ReadStructId();
    int ReadStructFieldCount();
    const PackedVals *ReadSwitchTable(int &count, int *default_offset = NULL) {
        static_assert(sizeof(PackedVals) == 8, "Switch entries are pairs of int32");
        const PackedVals *header = GetItemPtr(8);
        count = header->pair[0];
        if (!CanRead(count, 8)) throw DecodeError("Invalid bytecode switch table size");
        if (default_offset) *default_offset = header->pair[1];
        return GetItemPtr(count * 8);
    }

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
        if (unlikely(unsigned(len) > unsigned(Limit - Cursor))) OperandOutOfRange();
        char *bytes = Cursor;
        Cursor += len;
        return bytes;
    }

    bool ParseOpcode(FlowInstruction *out, bool reparse = false);

    // For an executable image only, on a fresh reader excluding the runner's
    // return sentinel. Validate static edges and reset embedded field caches.
    void BuildInstructionIndex(std::vector<bool> &starts);

private:
    [[noreturn]] static void OperandOutOfRange();
    void DecodeFieldType(std::vector<FieldType> *type, char *is_mutable, std::string *structname);
    template<bool indexing>
    bool DecodeOperands(FlowInstruction &insn, std::vector<FlowPtr> *targets);
};

#endif
