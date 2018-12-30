#include <stdio.h>
#include <assert.h>
#include <emscripten.h>
#include <string.h>

//////////////////////////////////////////////////////////////////////
//////////////////////// RUNNER COPYPASTA ////////////////////////////

#define _EMPTY
#if !defined(__GNUC__) || (__GNUC__ < 3)
#define likely(form) (form)
#define unlikely(form) (form)
#else
#define likely(form) __builtin_expect(form,1)
#define unlikely(form) __builtin_expect(form,0)
#endif
typedef double FlowDouble;

typedef unsigned short T_GC_Tag;
typedef enum
{
    TVoid           = 0x00, //
    TBool           = 0x01, // +4 : byte
    TInt            = 0x02, // +4 : int
    TDouble         = 0x03, // +4 : double
    TString         = 0x04, // +4: pointer. +8: length, Memory: utf8chars : byte[length]
    TArray          = 0x05, // +4: pointer, +8: length, Memory: values : value[length]
    TStruct         = 0x06, // +4: pointer, +8: kind. Memory: values[length]
    TCodePointer    = 0x0c, // +4: pointer.
    TNativeFn       = 0x14, // +4: int. Index into natives
    TRefTo          = 0x1f, // +4: pointer. Memory: value
    TNative         = 0x20, // +4: pointer to closure + 8: int. Index into nativeValues
    TClosurePointer = 0x22, // +4: pointer to closure + 8: pointer to code, closure memory: -4 n: int, v1 ... vn
    TCapturedFrame  = 0x30, // +4: instruction ptr, +8: impersonate insn
    TGCForwardPtr   = 0x7F01
} DataTag;

#ifdef _MSC_VER
    #define _ALIGNED_4 align(4)
    #define _NO_MSC_ALIGNED_4 _EMPTY
    #define _INLINE __forceinline
    #define _ATTR(...) __declspec(##__VA_ARGS__)
    #define __INLINE_WRAP(content) __forceinline content
    #define _ATTR_WRAP(content, pack, inlined, aligned) inlined _ATTR(aligned) content
#else
    #define _ALIGNED_4 aligned(4)
    #define _NO_MSC_ALIGNED_4 _ALIGNED_4
    #define _INLINE always_inline
    #define _PACK packed
    #define _ATTR(...) __attribute__((##__VA_ARGS__))
    #define __INLINE_WRAP(content) content __attribute__((always_inline))
    #define _ATTR_WRAP(content, pack, inlined, align) content __attribute__((pack, inlined, align))
#endif

typedef unsigned FlowPtr;

#define STACK_SLOT_SIZE 8

#pragma pack(push, 1)
#ifdef _MSC_VER
__declspec(align(4)) struct StackSlot {
#else
struct StackSlot {
#endif

/*
    All non-double values are represented so that they fit into the double NaN space:

    sign | 0x7FF0  | QNaN | tag |             | short   | int     | heap
    -----+---------+------+-----+-------------+---------+---------+---------------------
     *   | != 7ff  | *    | *   | double      | *       | *       | -
     *   |         | *    | 0   | nan/inf     | *       | *       | -
    -----+---------+------+-----+-------------+---------+---------+---------------------
     1   |         | 1    | 7   | TVoid       | -1      | -1      | -
    -----+---------+------+-----+-------------+---------+---------+---------------------
     0   |         | 1    | 6   | TInt        | 0       | int     | -
     1   |         | 1    | 6   | TBool       | 0       | bool    | -
    -----+---------+------+-----+-------------+---------+---------+---------------------
     *   |         | 1    | 5   | TNative     | 0       | id      | -
     *   |         | 1    | 4   | TCapturedFr | sub_id  | codeptr | -
    -----+---------+------+-----+-------------+---------+---------+---------------------
     0   |         | 0    | 1   | TString     | 0       | 0       | -
     0   |         | 0    | 1   | TString     | len     | strptr  | strdata
     1   |         | 0    | 1   | TString     | len>>16 | heap    | ^[len&ffff|gctag][strptr]
    -----+---------+------+-----+-------------+---------+---------+---------------------
     0   |         | 0    | 2   | TArray      | 0       | 0       | -
     0   |         | 0    | 2   | TArray      | len     | heap    | ^[len     |gctag][slots]+
     1   |         | 0    | 2   | TArray      | len>>16 | heap    | ^[len&ffff|gctag][slots]+
    -----+---------+------+-----+-------------+---------+---------+---------------------
     0   |         | 0    | 3   | TRefTo      | id      | heap    | ^[id      |gctag][slot]
     1   |         | 0    | 3   | TRefTo      | id>>16  | heap    | ^[id&ffff |gctag][slot]
    -----+---------+------+-----+-------------+---------+---------+---------------------
     0   |         | 0    | 4   | TCodePtr    | 0       | codeptr | -
     1   |         | 0    | 4   | TClosurePtr | len     | heap    | [codeptr]^[len|gctag][slot]+
    -----+---------+------+-----+-------------+---------+---------+---------------------
     0   |         | 0    | 5   | TNativeFn   | 0       | id      | -
     1   |         | 0    | 5   | TNativeFn   | len     | heap    | [id]^[len|gctag][slot]+
    -----+---------+------+-----+-------------+---------+---------+---------------------
     0   |         | 0    | 6   | TStruct     | id      | heap    | ^[id      |gctag][data]*

     (^ in the heap column marks the location pointed by the address in the slot)
*/

    /* POD types cannot have true private fields, so use naming to make
     * it obvious that the fields shouldn't be accessed in high level code. */
    union
    {
        char Bytes[STACK_SLOT_SIZE];
        int Ints[STACK_SLOT_SIZE/sizeof(int)];
        FlowDouble DoubleVal;
#ifdef __x86_64__
        uint64_t QWordVal;
#endif
        struct
        {
            union
            {
                int IntValue;
                FlowPtr PtrValue;
            };
            unsigned short AuxValue;
            unsigned short Tag;
        };
    } slot_private;

#define MAKE_TAG_AUX_INT(tag,aux) ((tag<<16)|(aux&0xffff))

public:
    static const int MASK_GC_FORWARD_PTR = 0x7ff0da7a;
    static const unsigned short MASK_GC_FORWARD_PTR16 = 0xda7a;

    static const unsigned short TAG_SIGN      = 0x8000;
    static const unsigned short TAG_NAN       = 0x7ff0;
    static const unsigned short TAG_QUIET     = 0x0008;
    static const unsigned short TAG_TYPEMASK  = 0x000f;
    static const unsigned short TAG_NOSIGN    = TAG_NAN | TAG_TYPEMASK;

    static const unsigned short TYPE_VOID     = TAG_QUIET|7;
    static const unsigned short TYPE_INTBOOL  = TAG_QUIET|6;
    static const unsigned short TYPE_NATIVE   = TAG_QUIET|5;
    static const unsigned short TYPE_CAPFRAME = TAG_QUIET|4;

    static const unsigned short TYPE_DOUBLENAN   = TAG_QUIET;
    static const unsigned short TYPE_DOUBLEINF   = 0;

    static const unsigned short TYPE_STRING   = 1;
    static const unsigned short TYPE_ARRAY    = 2;
    static const unsigned short TYPE_REFTO    = 3;
    static const unsigned short TYPE_FLOWCODE = 4;
    static const unsigned short TYPE_NATIVEFN = 5;
    static const unsigned short TYPE_STRUCT   = 6;

    static const unsigned short TAG_DOUBLENAN = TAG_NAN|TAG_QUIET;

    static const unsigned short TAG_VOID      = 0xffff;
    static const unsigned short TAG_INT       = TAG_NAN|TYPE_INTBOOL;
    static const unsigned short TAG_BOOL      = TAG_NAN|TYPE_INTBOOL|TAG_SIGN;
    static const unsigned short TAG_NATIVE    = TAG_NAN|TYPE_NATIVE;
    static const unsigned short TAG_CAPFRAME  = TAG_NAN|TYPE_CAPFRAME;
    static const unsigned short TAG_STRING    = TAG_NAN|TYPE_STRING;
    static const unsigned short TAG_ARRAY     = TAG_NAN|TYPE_ARRAY;
    static const unsigned short TAG_REFTO     = TAG_NAN|TYPE_REFTO;
    static const unsigned short TAG_FLOWCODE  = TAG_NAN|TYPE_FLOWCODE;
    static const unsigned short TAG_NATIVEFN  = TAG_NAN|TYPE_NATIVEFN;
    static const unsigned short TAG_STRUCT    = TAG_NAN|TYPE_STRUCT;

    __INLINE_WRAP(bool CheckTag(unsigned short mask, unsigned short test) const) {
        return (slot_private.Tag & mask) == test;
    }
	__INLINE_WRAP(bool CheckTag(unsigned short test) const) {
        return slot_private.Tag == test;
    }
	__INLINE_WRAP(void FixDoubleNan()) {
        if (unlikely((slot_private.Tag & TAG_NAN) == TAG_NAN))
            if (unlikely(slot_private.Tag & 7))
                slot_private.Tag = TAG_DOUBLENAN;
    }
	__INLINE_WRAP(bool GetSign() const) {
        return (slot_private.Tag & TAG_SIGN) != 0;
    }

public:
    /* Use the IsFoo methods; IsTFoo are there just for the RUNNER_CheckTag macros */
#define TEST_FN(tag, body) \
    bool Is##tag() const { return body; } \
    bool IsT##tag() const { return body; }

    TEST_FN(Void, CheckTag(TAG_NOSIGN, TAG_NAN|TYPE_VOID))
    TEST_FN(Bool, CheckTag(TAG_BOOL))
    TEST_FN(Int, CheckTag(TAG_INT))
    TEST_FN(Double, !CheckTag(TAG_NAN,TAG_NAN)||CheckTag(7,0))
    TEST_FN(String, CheckTag(TAG_NOSIGN, TAG_STRING))
    TEST_FN(Array, CheckTag(TAG_NOSIGN, TAG_ARRAY))
    TEST_FN(Struct, CheckTag(TAG_NOSIGN, TAG_STRUCT))
    TEST_FN(FlowCode, CheckTag(TAG_NOSIGN, TAG_FLOWCODE))
    TEST_FN(CodePointer, CheckTag(TAG_FLOWCODE))
    TEST_FN(ClosurePointer, CheckTag(TAG_FLOWCODE|TAG_SIGN))
    TEST_FN(BytecodeFn, CheckTag(TAG_NOSIGN, TAG_FLOWCODE))
    TEST_FN(NativeFn, CheckTag(TAG_NOSIGN, TAG_NATIVEFN))
    TEST_FN(RefTo, CheckTag(TAG_NOSIGN, TAG_REFTO))
    TEST_FN(Native, CheckTag(TAG_NOSIGN, TAG_NATIVE))
    TEST_FN(CapturedFrame, CheckTag(TAG_NOSIGN, TAG_CAPFRAME))
#undef TEST_FN

    DataTag GetType() const {
        if (!CheckTag(TAG_NAN,TAG_NAN))
            return TDouble;

        switch (slot_private.Tag & TAG_TYPEMASK) {
        case TYPE_VOID: return TVoid;
        case TYPE_INTBOOL: return GetSign() ? TBool : TInt;
        case TYPE_STRING: return TString;
        case TYPE_ARRAY: return TArray;
        case TYPE_STRUCT: return TStruct;
        case TYPE_FLOWCODE: return GetSign() ? TClosurePointer : TCodePointer;
        case TYPE_NATIVEFN: return TNativeFn;
        case TYPE_REFTO: return TRefTo;
        case TYPE_NATIVE: return TNative;
        case TYPE_CAPFRAME: return TCapturedFrame;
        default: return TDouble;
        }
    }

    int GetInt() const { assert(IsInt()); return slot_private.IntValue; }
    void SetIntValue(int v) { assert(IsInt()); slot_private.IntValue = v; }

    double GetDouble() const { assert(IsDouble()); return slot_private.DoubleVal; }
    void SetDoubleValue(FlowDouble v) { assert(IsDouble()); slot_private.DoubleVal = v; FixDoubleNan(); }

    bool GetBool() const { assert(IsBool()); return slot_private.IntValue != 0; }
    void SetBoolValue(bool v) { assert(IsBool()); slot_private.IntValue =  v; }

    int GetStructId() const { assert(IsStruct()); return slot_private.AuxValue; }
    int GetNativeValId() const { assert(IsNative()); return slot_private.IntValue; }

    bool IsClosure() const { return CheckTag(TAG_FLOWCODE|TAG_SIGN) || CheckTag(TAG_NATIVEFN|TAG_SIGN); }
    bool IsNativeClosure() const { return CheckTag(TAG_NATIVEFN|TAG_SIGN); }
    bool IsEmpty() const { assert(IsString() || IsArray()); return slot_private.AuxValue == 0; }

    FlowPtr GetCodePtr() const { assert(IsCodePointer()); return slot_private.PtrValue; }
    FlowPtr GetNativeFnDataPtr() const { assert(CheckTag(TAG_NATIVEFN|TAG_SIGN)); return slot_private.PtrValue+4; }
    FlowPtr GetClosureDataPtr() const { assert(IsClosure()); return slot_private.PtrValue+4; }
    FlowPtr GetCapturedFramePtr() const { assert(IsCapturedFrame()); return slot_private.PtrValue; }

    FlowPtr GetRawRefPtr() const { assert(IsRefTo()); return slot_private.PtrValue+4; }
    FlowPtr GetRawStructPtr() const { assert(IsStruct()); return slot_private.PtrValue; }
    FlowPtr GetInternalArrayPtr() const { assert(IsArray()); return slot_private.PtrValue+4; }

public:
    static StackSlot MakeVoid() {
        StackSlot s; return SetVoid(s);
    }
    static StackSlot &SetVoid(StackSlot &s) {
        s.slot_private.Ints[1] = -1; return s;
    }
    static StackSlot MakeInt(int v) {
        StackSlot s; return SetInt(s,v);
    }
    static StackSlot &SetInt(StackSlot &s, int v) {
        s.slot_private.IntValue = v; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_INT,0); return s;
    }
    static StackSlot MakeBool(int v) {
        StackSlot s; return SetBool(s,v);
    }
    static StackSlot &SetBool(StackSlot &s, int v) {
        s.slot_private.IntValue = v; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_BOOL,0); return s;
    }
    static StackSlot MakeDouble(FlowDouble v) {
        StackSlot s; return SetDouble(s, v);
    }
    static StackSlot &SetDouble(StackSlot &s, FlowDouble v) {
        s.slot_private.DoubleVal = v; s.FixDoubleNan(); return s;
    }
    static StackSlot MakeEmptyArray() {
        StackSlot s; s.slot_private.Ints[0] = 0; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_ARRAY,0); return s;
    }
    static StackSlot &SetEmptyArray(StackSlot &s) {
        s.slot_private.Ints[0] = 0; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_ARRAY,0); return s;
    }
    static StackSlot InternalMakeArray(FlowPtr ptr, unsigned short len_part, bool big) {
        return InternalMakeSlot(ptr, len_part, big ? (TAG_ARRAY|TAG_SIGN) : TAG_ARRAY);
    }
    static StackSlot MakeEmptyString() {
        StackSlot s; s.slot_private.Ints[0] = 0; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_STRING,0); return s;
    }
    static StackSlot &InternalSetString(StackSlot &s, FlowPtr ptr, unsigned short len_part, bool big) {
        return InternalSetSlot(s, ptr, len_part, big ? (TAG_STRING|TAG_SIGN) : TAG_STRING);
    }
    static StackSlot InternalMakeString(FlowPtr ptr, unsigned short len_part, bool big) {
        StackSlot s; return InternalSetString(s, ptr, len_part, big);
    }
    static StackSlot InternalMakeRefTo(FlowPtr ptr, unsigned short id_part, bool big) {
        return InternalMakeSlot(ptr, id_part, big ? (TAG_REFTO|TAG_SIGN) : TAG_REFTO);
    }
    static StackSlot MakeNative(int id) {
        StackSlot s; s.slot_private.IntValue = id; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_NATIVE,0); return s;
    }
    static StackSlot MakeNativeFn(int id) {
        StackSlot s; s.slot_private.IntValue = id; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_NATIVEFN,0); return s;
    }
    static StackSlot InternalMakeNativeClosure(FlowPtr p, unsigned len) {
        return InternalMakeSlot(p, len, TAG_NATIVEFN|TAG_SIGN);
    }
    static StackSlot MakeCodePointer(FlowPtr code) {
        StackSlot s; s.slot_private.PtrValue = code; s.slot_private.Ints[1] = MAKE_TAG_AUX_INT(TAG_FLOWCODE,0); return s;
    }
    static StackSlot InternalMakeClosurePointer(FlowPtr p, unsigned len) {
        return InternalMakeSlot(p, len, TAG_FLOWCODE|TAG_SIGN);
    }
    static StackSlot MakeStruct(FlowPtr p, unsigned short id) {
        return InternalMakeSlot(p, id, TAG_STRUCT);
    }
    static StackSlot &SetStruct(StackSlot &s, FlowPtr p, unsigned short id) {
        return InternalSetSlot(s, p, id, TAG_STRUCT);
    }
    static StackSlot InternalMakeCapturedFrame(FlowPtr pcode, unsigned subid) {
        return InternalMakeSlot(pcode, subid, TAG_CAPFRAME);
    }
    static StackSlot InternalMakeSlot(FlowPtr ptr, unsigned short aux, unsigned short tag) {
        StackSlot s; return InternalSetSlot(s, ptr, aux, tag);
    }
    static StackSlot &InternalSetSlot(StackSlot &s, FlowPtr ptr, unsigned short aux, unsigned short tag) {
        s.slot_private.PtrValue = ptr;
        s.slot_private.AuxValue = aux;
        s.slot_private.Tag = tag;
        return s;
    }
#ifdef _MSC_VER
};
#else
} __attribute__((packed, aligned(4)));
#endif
#pragma pack(pop)

/*
 * Layouts for objects in flow heap.
 */

#pragma pack(push, 1)
union  _ATTR_WRAP(FlowGCHeader{
    int IntVal;
    struct
    {
        union {
            unsigned short DataValue;
            unsigned short StructId;
        };
        T_GC_Tag GC_Tag;
    };
    unsigned char Bytes[4];
}, _PACK, _EMPTY, _ALIGNED_4);

_ATTR_WRAP(struct FlowStringRef {
    FlowGCHeader header;
    FlowPtr dataptr;
}, _PACK, _EMPTY, _ALIGNED_4);

_ATTR_WRAP(struct FlowHeapArray {
    FlowGCHeader header;
    StackSlot data[1];
}, _PACK, _EMPTY, _ALIGNED_4);

_ATTR_WRAP(struct FlowHeapRef {
    FlowGCHeader header;
    StackSlot data;
}, _PACK, _EMPTY, _ALIGNED_4);

_ATTR_WRAP(struct FlowHeapStruct {
    FlowGCHeader header;
    union {
        char data[4];
        FlowPtr fwd_ptr;
    };
}, _PACK, _EMPTY, _ALIGNED_4);
#pragma pack(pop)

//////////////////////////////////////////////////////////////////////

char buffer[65536] __attribute__((aligned(16)));
unsigned buffer_offset = 0;

const char strdata[] = "F\0O\0O\0";

template<class T>
T *alloc_obj(int extra_size = 0)
{
    T *rv = (T*)&buffer[buffer_offset];
    buffer_offset += sizeof(T) + extra_size;
    return rv;
}

extern "C" {
    EMSCRIPTEN_KEEPALIVE
    int test_call(int foo, char *xxx) {
        printf("TEST: %d %s\n", foo, xxx);
        return 0;
    }
}

int main(int argc, char **argv) {
    printf("Hello, world!\n");

    StackSlot str = StackSlot::InternalMakeString(buffer_offset, 3, false);

    memcpy(buffer, strdata, 6);
    buffer_offset += 8; // must be aligned to 4

    StackSlot arr = StackSlot::InternalMakeArray(buffer_offset, 4, false);

    FlowHeapArray *parr = alloc_obj<FlowHeapArray>(sizeof(StackSlot)*3);
    parr->header.DataValue = 4;
    parr->data[0] = str;
    parr->data[1] = StackSlot::MakeInt(1);
    parr->data[2] = StackSlot::MakeDouble(2.5);
    parr->data[3] = StackSlot::MakeBool(true);

    EM_ASM_( proxy_NativeHx_println($0,$1), &buffer, &arr );
    return 0;
}
