#ifndef _CODE_MEMORY_H_
#define _CODE_MEMORY_H_

#include "ByteMemory.h"

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
        PackedVals *p = (PackedVals*)(Buffer + FlowPtrToInt(Position));
        Position += size;
#ifdef DEBUG_FLOW
        assert(Position <= End);
#endif
        return p;
    }

public:
    CodeMemory();
    CodeMemory(char *buffer, int start, int size) {
        SetBuffer(buffer, start, size);
    }

    void SetBuffer(char *buffer, int start, int size);

    __INLINE_WRAP(void SetPosition(FlowPtr position)) {
        if (position <= End)
            Position = position;
    }
    void ResetPosition()  { Position = Start; }
    FlowPtr GetPosition() { return Position; }
    int GetSize()         { return End - Start; }
    FlowPtr GetLastAddr() { return End; }

    bool Eof() { return Position >= End; }

    char ReadByte() {
        return GetItemPtr(1)->bv;
    }

    unsigned ReadInt32() {
        return GetItemPtr(4)->uv;
    }

    int ReadInt31() {
        return GetItemPtr(4)->iv;
    }

    void SkipInt() {
        Position += 4;
    }

    // Partial reads for constrained values:
    int ReadInt31_8() {
        return GetItemPtr(4)->ubv;
    }

    int ReadInt31_16() {
        return GetItemPtr(4)->usv;
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
    
    unicode_string ReadWideString(int len) {
        unicode_string rv((unicode_char*)(Buffer + FlowPtrToInt(Position)), len);
        Position += len * 2;
        return rv;
    }

    std::string ReadString(int len) {
        return std::string(&GetItemPtr(len)->bv, len);
    }

    std::string ReadString();
    std::vector<FieldType> ReadFieldType(char *is_mutable, std::string *structname);

    char *GetBytes(int len) {
        return &GetItemPtr(len)->bv;
    }

    bool ParseOpcode(FlowInstruction *out, bool reparse = false);
};

#endif
