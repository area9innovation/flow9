#ifndef _COMMON_TYPES_H_
#define _COMMON_TYPES_H_

#include <stdlib.h>

#include "STLHelpers.h"

// it's required to compile WASM byterunner
#if __EMSCRIPTEN__
#include <emscripten.h>
#endif

#define STACK_SLOT_SIZE 8

#if defined(_WIN64)
#ifndef FLOW_JIT
#define FLOW_JIT
#endif
#ifndef __x86_64__
#define __x86_64__
#endif
#endif

#ifndef FLOW_COMPACT_STRUCTS
#define FLOW_COMPACT_STRUCTS
#endif

#define _EMPTY
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

#ifdef FLOW_SINGLE_FLOAT
typedef float FlowDouble;
#else
typedef double FlowDouble;
#endif

#include "opcodes.h"

// Tags for runtime representations of data
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

// Flow pointer type
#ifdef DEBUG_FLOW
class FlowPtr {
public:
    // A tightened up debug version that allows only a subset of operators.
    // This field is public only to coax GCC into treating StackSlot as POD.
    unsigned value;
public:
    friend inline FlowPtr MakeFlowPtr(unsigned val);
    friend inline unsigned FlowPtrToInt(FlowPtr fp) { return fp.value; }
    FlowPtr operator++ (int) { FlowPtr rv = *this; value++; return rv; }
    FlowPtr &operator++ () { value++; return *this; }
    FlowPtr &operator+= (int delta) { value += delta; return *this; }
    FlowPtr &operator-= (int delta) { value -= delta; return *this; }
    friend inline bool operator<(FlowPtr fp, FlowPtr fp2) { return fp.value < fp2.value; }
    friend inline bool operator<=(FlowPtr fp, FlowPtr fp2) { return fp.value <= fp2.value; }
    friend inline bool operator>(FlowPtr fp, FlowPtr fp2) { return fp.value > fp2.value; }
    friend inline bool operator>=(FlowPtr fp, FlowPtr fp2) { return fp.value >= fp2.value; }
    friend inline bool operator==(FlowPtr fp, FlowPtr fp2) { return fp.value == fp2.value; }
    friend inline bool operator!=(FlowPtr fp, FlowPtr fp2) { return fp.value != fp2.value; }
    friend inline bool operator<(FlowPtr fp, unsigned iv) { return fp.value < iv; }
    friend inline bool operator<=(FlowPtr fp, unsigned iv) { return fp.value <= iv; }
    friend inline bool operator>(FlowPtr fp, unsigned iv) { return fp.value > iv; }
    friend inline bool operator>=(FlowPtr fp, unsigned iv) { return fp.value >= iv; }
    friend inline bool operator==(FlowPtr fp, unsigned iv) { return fp.value == iv; }
    friend inline bool operator!=(FlowPtr fp, unsigned iv) { return fp.value != iv; }
    friend inline FlowPtr operator+(FlowPtr fp, int delta) { fp.value += delta; return fp; }
    friend inline FlowPtr operator-(FlowPtr fp, int delta) { fp.value -= delta; return fp; }
    friend inline int operator-(FlowPtr fp, FlowPtr fp2) { return fp.value - fp2.value; }
};
inline FlowPtr MakeFlowPtr(unsigned val) { FlowPtr fp; fp.value = val; return fp; }
BEGIN_STL_HASH_NAMESPACE
    template <> struct hash< ::FlowPtr> {
        size_t operator() (::FlowPtr x) const {
            return hash<unsigned>()(x.value);
        }
    };
END_STL_HASH_NAMESPACE
#else
typedef unsigned FlowPtr;
#define MakeFlowPtr(x) FlowPtr(x)
#define FlowPtrToInt(x) unsigned(x)
#endif

inline FlowPtr FlowPtrAlignDown(FlowPtr x, int size) {
    return MakeFlowPtr(FlowPtrToInt(x) & ~(size-1));
}
inline FlowPtr FlowPtrAlignUp(FlowPtr x, int size) {
    return MakeFlowPtr(FlowPtrToInt(x+size-1) & ~(size-1));
}

typedef unsigned short T_GC_Tag;

/* Stack Slot - the variant type of the flow bytecode interpreter */

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
    bool operator == (const StackSlot& st) {
      return
              slot_private.Bytes == st.slot_private.Bytes && slot_private.Ints == st.slot_private.Ints && slot_private.DoubleVal == st.slot_private.DoubleVal &&
      #ifdef __x86_64__
              slot_private.QWordVal == st.slot_private.QWordVal &&
      #endif
              slot_private.IntValue == st.slot_private.IntValue && slot_private.PtrValue == st.slot_private.PtrValue &&
              slot_private.AuxValue == st.slot_private.AuxValue && slot_private.Tag == st.slot_private.Tag;
    }
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

#ifdef FLOW_COMPACT_STRUCTS

typedef FlowGCHeader FlowStructHeader;
typedef StackSlot FlowStructArray;
typedef StackSlot FlowStructString;
typedef StackSlot FlowStructRef;

#if 0
union FlowStructHeader {
    int IntVal;
    struct
    {
        unsigned short StructId;
        T_GC_Tag GC_Tag;
    };
    unsigned char Bytes[4];
} _ATTR(packed,_ALIGNED_4);

struct FlowStructArray {
    FlowPtr addr;
    int size;
} _ATTR(packed,_ALIGNED_4);

struct FlowStructString {
    FlowPtr addr;
    int size;
} _ATTR(packed,_ALIGNED_4);

struct FlowStructRef {
    FlowPtr addr;
    int id;
} _ATTR(packed,_ALIGNED_4);
#endif

class GarbageCollector;
class ByteCodeRunner;
typedef StackSlot (*FlowStructFieldGet)(const void*,ByteCodeRunner*);
typedef bool (*FlowStructFieldSet)(void*,const StackSlot &val);
typedef void (*FlowStructFieldGCEnum)(GarbageCollector*,const void*);
typedef void (*FlowStructFieldGCCollect)(GarbageCollector*,void*);

struct FlowStructFieldDef {
    int offset;
    DataTag tag;
    FlowStructFieldGet fn_get;
    FlowStructFieldSet fn_set;
};
struct FlowStructFieldGCDef {
    int offset;
    FlowStructFieldGCEnum    fn_enum;
    FlowStructFieldGCCollect fn_collect;
};
#endif

typedef enum
{
    NoError,
    CallstackFull,
    ClosurestackFull,
    DatastackFull,
    HeapFull,
    InvalidCall,
    UnknownStructDefId,
    InvalidArgument,
    DivideByZerro,
    InvalidOpCode,
    UnknownNativeName,
    InvalidNativeId,
    InvalidFieldName,
    UncaughtSwitch,
    GCFailure,
    StackCorruption
} RuntimeError;

typedef enum
{
    FTVoid  = 0x00,
    FTBool   = 0x01,
    FTInt    = 0x02, 
    FTDouble = 0x03, 
    FTString = 0x04, 
    FTArray  = 0x05, 
    FTStruct = 0x06, 
    FTRefTo  = 0x1f,
    FTTypedArray = 0x41,
    FTTypedStruct = 0x42,
    FTTypedRefTo  = 0x43,
    FTMutable = 0x45,
    FTFlow  = 0xff
} FieldType;

struct StructDef
{
    std::string    Name;
    unicode_string NameU;
    int            StructId;
    int            FieldsCount;
    int            CompareIdx;
#ifdef FLOW_COMPACT_STRUCTS
    int            GCFieldCount;
    int            ByteSize;
    FlowPtr        EmptyPtr;
#endif
    std::vector<std::string> FieldNames; // array of char * pointers to zerro strings
    std::vector< std::vector<FieldType> > FieldTypes;
    std::vector<short> FieldIds;
    std::vector<char> IsMutable;
#ifdef FLOW_COMPACT_STRUCTS
    const FlowStructFieldDef *FieldDefs;
    const FlowStructFieldGCDef *FieldGCDefs;
#endif

    int findField(const char *name, int length);

#ifdef FLOW_COMPACT_STRUCTS
    StructDef() : GCFieldCount(0), ByteSize(4), FieldDefs(NULL), FieldGCDefs(NULL) {}
#endif
};

typedef struct
{
    FlowPtr Start;
    FlowPtr Ephemeral;
    FlowPtr Bound;
} HeapLimits;

struct FlowInstruction
{
    typedef std::map<FlowPtr,FlowInstruction> Map;
    typedef std::pair<const FlowPtr,FlowInstruction> Pair;

    enum Shape {
        Atom,
        Int,
        IntInt,
        Ptr,
        IntPtr,
        Double,
        String,
        IntString,
        Switch,
        StructDef
    } shape;

    OpCode op;

    union {
        struct {
            int IntValue;
            int IntValue2;
            FlowPtr PtrValue;
        };

        FlowDouble DoubleVal;
    };

    std::string StrValue;

    struct Case {
        int id;
        FlowPtr target;
    } *cases;

    struct Field {
        std::string name;
        // For simple type it is type = [field_type]
        // For TypedArray type = [FTTypedArray, type_of_array, ...]
        // For TypedStruct = [FTTypedStruct, struct_id]
        std::vector<FieldType> type;
        char is_mutable;
    } *fields;

    FlowInstruction() : shape(Atom), op(CLast), cases(NULL), fields(NULL) {}
    FlowInstruction(OpCode op) : shape(Atom), op(op), cases(NULL), fields(NULL) {}
    ~FlowInstruction() { delete[] cases; delete[] fields; }

    static const char *OpCode2String(OpCode opcode);
};

std::ostream &operator << (std::ostream &out, const FlowInstruction &insn);

struct ExtendedDebugInfo {
    typedef std::vector<FlowPtr> T_ranges;

    enum LocalType {
        LOCAL_VAR,
        LOCAL_ARG,
        LOCAL_UPVAR
    };

    struct LocalEntry {
        LocalType type;
        int id;
        std::string name;
    };

    struct FunctionEntry {
        std::string name;
        T_ranges ranges;

        int num_args, num_upvars;
        std::vector<LocalEntry> locals;

        std::map<std::string,int> local_name_idx;
        std::map<std::pair<LocalType,int>,int> local_id_idx;

        LocalEntry *find_local(std::string name);
        LocalEntry *find_local(LocalType type, int id);
    };

    typedef std::map<std::string, FunctionEntry> T_functions;
    T_functions functions;
    typedef std::map<FlowPtr, FunctionEntry*> T_function_ranges;
    T_function_ranges function_ranges;

    FunctionEntry *find_function(const std::string &str)
    {
        T_functions::iterator it = functions.find(str);
        return it != functions.end() ? &it->second : NULL;
    }

    FunctionEntry *find_function(FlowPtr fptr) {
        T_function_ranges::iterator it = mapFindLE(function_ranges, fptr);
        return it != function_ranges.end() ? it->second : NULL;
    }

    struct FileEntry;
    struct LineEntry;

    struct ChunkEntry {
        LineEntry *line;
        int char_idx;
        T_ranges ranges;
    };

    typedef std::map<int, ChunkEntry> T_chunks;

    struct LineEntry {
        FileEntry *file;
        int line_idx;
        T_chunks chunks;
    };

    typedef std::map<int, LineEntry> T_lines;

    struct FileEntry {
        std::string name;
        T_lines lines;
    };

    typedef std::map<std::string, FileEntry> T_files;
    T_files files;
    typedef std::map<FlowPtr, ChunkEntry*> T_chunk_ranges;
    T_chunk_ranges chunk_ranges;

    ChunkEntry *find_chunk(FlowPtr fptr) {
        T_chunk_ranges::iterator it = mapFindLE(chunk_ranges, fptr);
        return it != chunk_ranges.end() ? it->second : NULL;
    }

    void clear();

    // Load debug info from a file
    bool load_file(const std::string &fname);
    // Compute what possible from disassembled code
    void load_code(FlowInstruction::Map &insns);

    std::string getFunctionLocation(FlowPtr addr, bool only_line = false);

private:
    void addFunctionRange(FlowPtr pc, const std::string &name);
    void addSourceRange(FlowPtr pc, const std::string &file, int line, int byte);
    void nestFunctions(std::map<FlowPtr,bool> &ftable, const std::string global);
};

struct FlowStackFrame {
    int index;
    unsigned stack_place;

    FlowPtr insn;
    unsigned frame;
    FlowPtr closure;

    ExtendedDebugInfo::FunctionEntry *function;
    ExtendedDebugInfo::ChunkEntry *chunk;
    int special_id;

    FlowPtr impersonate_insn;
    ExtendedDebugInfo::FunctionEntry *impersonate_function;
    ExtendedDebugInfo::ChunkEntry *impersonate_chunk;
};

typedef void (*Func)();

template<class T, unsigned MinSize>
class FlowStack
{
    T *buf;
    unsigned pos;
    unsigned limit;

    friend class FlowJitProgram;

    void grow(unsigned new_sz) {
        while (new_sz > limit)
            limit *= 2;
        buf = (T*)realloc(buf, sizeof(T)*limit);
    }

public:
    FlowStack() : buf(NULL) { clear(); }
    ~FlowStack() { free(buf); }

    void swap(FlowStack<T,MinSize> &other) {
        std::swap(buf, other.buf);
        std::swap(pos, other.pos);
        std::swap(limit, other.limit);
    }

    void clear() {
        buf = (T*)realloc(buf, sizeof(T)*MinSize);
        pos = 0; limit = MinSize;
    }

    void resize(unsigned size) {
        if (size > limit) grow(size);
        pos = size;
    }
    void reserve(unsigned size) {
        if (size > limit) grow(size);
    }

    bool empty() const { return pos == 0; }
    unsigned size() const { return pos; }
    unsigned capacity() const { return limit; }

    T &operator[] (unsigned i) { return buf[i]; }
    T &top(unsigned off = 0) { return buf[pos-1-off]; }
    const T &operator[] (unsigned i) const { return buf[i]; }
    const T &top(unsigned off = 0) const { return buf[pos-1-off]; }

    __INLINE_WRAP(T *push_ptr(unsigned sz = 1)) {
        unsigned nend = pos+sz;
        if (nend > limit) grow(nend);
        T *rv = buf+pos; pos = nend;
        return rv;
    }

	__INLINE_WRAP(T *pop_ptr(unsigned sz = 1)) {
        pos -= sz;
        return buf+pos;
    }

    void push_all(const FlowStack<T,MinSize> &other, unsigned skip = 0) {
        unsigned amount = std::max(skip,other.size()) - skip;
        memcpy(push_ptr(amount), other.buf, amount*sizeof(T));
    }

	__INLINE_WRAP(void push_back(const T &v)) { *push_ptr() = v; }
	__INLINE_WRAP(T &pop()) { return *pop_ptr(); }
};


#include "nativefunction.h"

#endif
