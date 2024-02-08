#ifndef _BYTECODERUNNER_H_
#define _BYTECODERUNNER_H_

#include "opcodes.h"
#include "CodeMemory.h"
#include <string.h>
#include <stdarg.h>
#include <assert.h>
#include "CommonTypes.h"
#ifndef _MSC_VER
#include <unistd.h>
#define _INLINE_FORCE(content) content __attribute__((always_inline))
#else
#define _INLINE_FORCE(content) __forceinline content
#endif

#ifndef FLOW_EMBEDDED
#define FLOW_INSTRUCTION_PROFILING
#define FLOW_DEBUGGER
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
#define FLOW_GARBAGE_PROFILING
#endif

#define FLOW_TIME_PROFILING

#ifdef QT_CORE_LIB
#define FLOW_QT_BACKEND
#else
#define FLOW_PTHREAD
#endif

//#define FLOW_PTHREAD

#ifdef FLOW_PTHREAD
#include <pthread.h>
#else
#ifdef FLOW_TIME_PROFILING
#include <QThread>
#include <QMutex>
#endif
#endif

#ifdef FLOW_QT_BACKEND
#include <QDebug>
#include <QFile>
#include <QString>
#include <QUrl>
#include <QCryptographicHash>
#endif

/*
#include <QMap>
#include <QString>
#include <QHash>
#include <QVector>
#include <QUrl>
#include <QFile>
*/

#ifdef FLOW_DEBUGGER
class FlowDebuggerBase;
#endif

/*
#define FLOW_NATIVE_OVERRIDES \
    OVERRIDE(elemIndex, 3) \
    OVERRIDE(exists, 2) \
    OVERRIDE(find, 2) \
    OVERRIDE(lookupTree, 2) \
    OVERRIDE(setTree, 3) \
    OVERRIDE(rebalancedTree, 4) \
    OVERRIDE(treeLeftRotation, 1) \
    OVERRIDE(treeRightRotation, 1)
*/

#define MIN_MMAP_SIZE (128*1024)

extern unsigned int EPHEMERAL_HEAP_SIZE;
extern unsigned int MAX_EPHEMERAL_ALLOC;

class AddrIntervalSet
{
public:
    typedef std::map<FlowPtr,bool> T_bounds;
private:
    T_bounds bounds;
public:
    const T_bounds &raw_bounds() { return bounds; }

    unsigned size() { return bounds.size()/2; }
    bool empty() { return bounds.empty(); }
    void clear() { bounds.clear(); }

    // Logarithmic lookup cost
    bool contains(FlowPtr ptr) const {
        T_bounds::const_iterator it = bounds.upper_bound(ptr);
        return it != bounds.end() && it->second;
    }

    typedef std::pair<FlowPtr,FlowPtr> range_type;
    bool getInterval(FlowPtr point, range_type *output) const;
    bool listIntervals(FlowPtr start, FlowPtr end, std::vector<range_type> *output) const;

    int getTotalSize(int align = 1);

    void addInterval(FlowPtr start, FlowPtr end);
};

class NativeProgram;

#ifdef FLOW_JIT
class FlowJitProgram;
#endif

enum PlatformEvent {
    PlatformEventUnknown = 0,
    PlatformApplicationSuspended = 1,
    PlatformApplicationResumed = 2,
    PlatformNetworkOffline = 3,
    PlatformNetworkOnline = 4,
    PlatformLowMemory = 5,
    PlatformDeviceBackButton = 6,
    PlatformApplicationUserIdle = 7,
    PlatformApplicationUserActive = 8
};

class ByteCodeRunner : public LocalRootHost
{
public:
    ByteCodeRunner();
    ByteCodeRunner(std::string bytecode_file);
    ByteCodeRunner(const char *bytecode_buffer, int bytecode_length);
    ~ByteCodeRunner();

    /// functions to allow for ByteCodeRunner instance re-use
    void Init(const char *bytecode_buffer, int bytecode_length);
    void Init(std::string bytecode_file);
    void Init(NativeProgram *code);
#ifdef FLOW_JIT
    void Init(FlowJitProgram *code);
#endif

    void ReloadBytecode();

    void ResetState() { Reset(false); }

    void RunMain();

    void SetExtendedDebugInfo(ExtendedDebugInfo *dinfo);

    bool Disassemble(std::map<FlowPtr,FlowInstruction> *pmap, FlowPtr position, unsigned size);
    void Disassemble(ostream &out, FlowPtr position, unsigned size);

    void enableGCStressTest();

    HeapLimits GetHeapLimits(bool high);
    void UpdateHeapLimits(bool high);
    void ResetRefMask(FlowPtr ref_end, FlowPtr big_pos);

    ByteMemory *GetMemory() const { return const_cast<ByteMemory*>(&Memory); }

    FlowPtr CodeStartPtr() const { return MakeFlowPtr(0); }
    int     CodeSize() const { return NativeReturnInsn - CodeStartPtr(); }

    void setBytecodeFilename(std::string filename) { BytecodeFilename = filename; }

    typedef STL_HASH_MAP<unicode_string, unicode_string> T_UrlParameters;
    unicode_string &getUrlString() { return UrlString; }
    void setUrlString(unicode_string url) { UrlString = url; }
    T_UrlParameters &getUrlParameterMap() { return UrlParameters; }

#ifdef FLOW_QT_BACKEND
    void setUrl(QUrl url);
    void setUrlParameter(QString key, QString value);
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
    void BeginInstructionProfile(const char *file, unsigned step);
    void BeginMemoryProfile(const char *file, unsigned step);
    void BeginCoverageProfile(const char *file);
#ifdef FLOW_GARBAGE_PROFILING
    void BeginGarbageProfile(int stack);
#endif
#endif

#ifdef FLOW_TIME_PROFILING
    void BeginTimeProfile(const char *file, unsigned step);
#endif

    void StopProfiling();

    void ClaimInstructionsSpent(int amount, int special = -1)
    {
#ifdef FLOW_INSTRUCTION_PROFILING
#ifdef FLOW_DEBUGGER
        if (DbgInsnTrap) return;
#endif
        if (amount > 0 && ProfileICStep > 0)
            DoClaimInstructionsSpent(amount,special);
#else
        (void*)&amount; (void*)&special;
#endif
    }

    bool IsProfiling() {
#ifdef FLOW_TIME_PROFILING
        if (ProfileTimeStep > 0)
            return true;
#endif
#ifdef FLOW_INSTRUCTION_PROFILING
        if (ProfileMemStep > 0 || ProfileICStep > 0 || ProfileCodeCoverage)
            return true;
#endif
        return false;
    }

    bool IsDebugging() {
#ifdef FLOW_DEBUGGER
        if (DebuggerPtr)
            return true;
#endif
        return false;
    }

    struct CallFrame {
        FlowPtr last_pc;
        FlowPtr last_closure;
        int last_frame;
#ifdef FLOW_DEBUGGER
        FlowPtr impersonate_pc;
        bool is_closure;
#endif
    };

    typedef FlowVMemStack<StackSlot> TDataStack;
    typedef FlowStack<CallFrame,256> TCallStack;

    _INLINE_FORCE(NativeProgram *getProgram()) { return Program; }

#ifndef _MSC_VER
    static struct tm tzOffsetInfo;
#endif
    bool isInitializing() {
        return !initializationComplete;
    }
private:
    friend class GarbageCollector;
    friend class ByteCodeProfileClock;
    friend class Debugger;
    friend class FlowDebuggerBase;
    friend class HeapWalker;

    void Reset(bool inDestructor);
    void DoInit(const char *bytecode_buffer_or_fn, int bytecode_length, bool from_file);

    // Byterunner initialization flag
    bool initializationComplete;

    typedef STL_HASH_SET<int> T_LiveTable;
    int DeleteDeadNativeVals(const T_LiveTable &live_vals, int valbarrier);
    void DeleteDeadNativeFuns(const T_LiveTable &live_funcs);

    FlowPtr getLastCodeAddress();
    void initStructures();

    /* High-throughput variables.
     *
     * On ARM fields past a certain offset into the
     * object require an additional ADD instruction
     * to access. Therefore, most important fields
     * must be put near the beginning.
     *
     * This is beneficial even on Intel CPUs because
     * offsets below 128 bytes can be encoded using a
     * shorter instruction length.
     */

#ifdef FLOW_JIT
    // Pointer to the current JIT call frame (see rCFrame).
    void *JitCallFrame;

    // Array of code pointers for calling TNativeFn values from JIT code.
    // Unlike the NativeFunction::func_ pointer that uses C++ calling
    // convention, these use the JIT calling convention.
    typedef FlowStack<void*,128> T_JitFuncs;
    T_JitFuncs JitFuncs;
#endif

    // Error state; if nonzero, execution has fatally failed
    RuntimeError LastError;

    TDataStack                 DataStack;

    FlowPtr hp;          // Heap pointer. Points to last used address in fast gc heap. The heap grows from end of memory down
    FlowPtr hpbound;     // Hard bound on the fast heap size
    FlowPtr hp_ref_base; // Base of the ref array
    FlowPtr hp_ref_end;  // End of the ref array
    FlowPtr hp_big_pos;  // Big allocation pointer
    FlowPtr hp_big_end;  // End of current heap

    ByteMemory Memory;    // The memory used at run time
    CodeMemory Code;      // The bytecode we run
    FlowPtr closurepointer; // The current closure pointer

    // Stacks
    unsigned                   FramePointer;
    TCallStack                 CallStack;

    // The overall memory layout
    FlowPtr HeapStart;

    FlowPtr LastInstructionPtr;

    // For flow programs compiled to C++
    friend class NativeProgram;
    NativeProgram *Program;

#ifdef FLOW_JIT
    friend class FlowJitProgram;
    FlowJitProgram *JitProgram;
#endif

#ifdef FLOW_DEBUGGER
    FlowDebuggerBase *DebuggerPtr;
    bool DbgInsnTrap, DbgCallTrap, DbgReturnTrap;
    FlowPtr ImpersonateInsn;
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
    unsigned InstructionCount;
    unsigned ProfileICBarrier;
    FlowPtr ProfileMemBarrier;
#endif

#if defined(FLOW_TIME_PROFILING) || defined(FLOW_DEBUGGER)
    volatile unsigned ProfileTimeCount;
#endif

    bool gcStressTestEnabled;

    // When a native is called, this is assigned a reference to the invoked NativeFunction.
    // It is used by some of the more complicated subclasses of NativeFunction.
    friend class NativeFunction;
    NativeFunction *CurNativeFn;

    // Table of struct field counts for faster access
    typedef FlowStack<unsigned, 128> T_StructSizes;
    T_StructSizes StructSizes;

    // Table of native functions. Note how it is an array grown at the end instead
    // of map, so continuously allocating new native functions is inefficient.
    typedef FlowStack<NativeFunction*, 128> T_Natives;
    T_Natives Natives;

    unsigned NativeCallDepth;

    inline NativeFunction *lookupNativeFn(int id) {
        return likely(unsigned(id) < Natives.size()) ? Natives[id] : NULL;
    }

    /* End of high-throughput vars */

    /* Heap structure

       {hpbound} [ ... {hp} ephemeral ] {hp_ref_base} [ refs... ] {hp_ref_end} ... {hp_big_pos} [ ...objects ]
     */

    FlowPtr HeapEnd;
    FlowPtr NativeReturnInsn;

    T_GC_Tag NextGCTag;

    // Which part of the memory is the current heap? Half the memory is reserved for garbage collection, so we track which
    // half is active here. If high is true, memory grows from the end down
    bool highHeap;

    // Mask of refs in hp_ref_base..hp_ref_end recently written to
    static const unsigned int REF_MASK_STEP = 100;
    std::vector<bool> RefWriteMask;

    // Tables of updated slots and structs.
    AddrIntervalSet SlotWriteSet;
#ifdef FLOW_COMPACT_STRUCTS
    std::vector<FlowPtr> StructWriteSet;
#endif

    // GC write barrier notification
    void RegisterWrite(FlowPtr slot);
    void RegisterWrite(FlowPtr start, unsigned count);

    // Next id value for a ref object
    int NextRefId;

    // Table for RegisterRoot
    typedef STL_HASH_MAP<int, StackSlot> T_NativeRoots;
    T_NativeRoots NativeRoots;
    int nNativeRoots;

    // Program launch url and parameters
    unicode_string UrlString;
    T_UrlParameters UrlParameters;

    // Code-address of all top-level functions
    typedef STL_HASH_MAP<int, int> T_Toplevel;
    T_Toplevel Toplevel; // to do

    // Struct definition data
    std::vector<StructDef> StructDefs;
    typedef STL_HASH_MAP<std::string, int> T_StructNameIds;
    T_StructNameIds StructNameIds;

#ifdef FLOW_COMPACT_STRUCTS
    std::vector<FlowStructFieldDef*> AutoStructFields;
    std::vector<FlowStructFieldGCDef*> AutoStructGCFields;
#endif

    // For efficient handling of certain structs from native code
    typedef std::pair<int*,int> T_KnownStructTableItem;
    typedef STL_HASH_MAP<std::string, T_KnownStructTableItem> T_KnownStructTable;
    T_KnownStructTable KnownStructTable;

    void RegisterStructDef(unsigned id, const StructDef &def);

#ifdef FLOW_NATIVE_OVERRIDES
    typedef std::pair<NativeFunctionPtr,int> T_NativeOverridesItem;
    typedef STL_HASH_MAP<std::string, T_NativeOverridesItem> T_NativeOverrides;
    T_NativeOverrides NativeOverrides;
#endif

#define FLOW_KNOWN_STRUCTS \
    STRUCT(Cons, 2) \
    STRUCT(EmptyList, 0) \
    STRUCT(None, 0) \
    STRUCT(Some, 1) \
    STRUCT(TreeNode, 5) \
    STRUCT(TreeEmpty, 0)
#define STRUCT(name,size) int name ## StructId;
    FLOW_KNOWN_STRUCTS
#undef STRUCT

    // For optimization of opcodes that access fields by name
    std::vector<std::string> FieldRefNames;
    std::map<std::string,int> FieldRefIds;

    // Debugger data
    std::map<FlowPtr, std::string> DebugFnInfo;
    std::vector<std::string> DebugFnList;

    ExtendedDebugInfo *ExtDbgInfo;

#ifdef FLOW_DEBUGGER
    std::map<FlowPtr, OpCode> BreakpointOpcodeBackup;
#endif

    // Profiler
    FILE *ProfileStream;

#ifdef FLOW_TIME_PROFILING
#ifdef FLOW_PTHREAD
    pthread_t ProfileClock;
    pthread_mutex_t ProfileClockMutex;
    static void* ProfileClockThread(void *bcr);
#else
    QThread *ProfileClock;
    QMutex *ProfileClockMutex;
#endif
    unsigned ProfileTimeStep;
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
    bool ProfileCodeCoverage;
    std::vector<char> CoverageCodeBackup;

    unsigned ProfileMemStep, ProfileICStep;

#ifdef FLOW_GARBAGE_PROFILING
    // Tracking of allocation context
    struct AllocationInfo {
        FlowPtr alloc_addr;
        std::string stack_buf;
        unsigned size, generation;
        AllocationInfo(FlowPtr alloc, unsigned size, int generation) :
            alloc_addr(alloc), size(size), generation(generation)
        {}
    };
    bool DoProfileGarbage;
    int MaxGarbageStack, LastDumpID;
    std::vector<AllocationInfo> ProfileHeapObjects;
#endif
#endif

    void ProfileOpenFile(const char *name);
    void ProfileDumpStack(int samples, TCallStack &stack, FlowPtr cur_pos);

#if defined(FLOW_INSTRUCTION_PROFILING) || defined(FLOW_DEBUGGER)
    void ProfileICEvent(bool in_compare);
#endif

#ifdef FLOW_INSTRUCTION_PROFILING
    void DoClaimInstructionsSpent(int amount, int special);
    void ProfileMemEvent(unsigned size, bool big = false);
#endif

#if defined(FLOW_TIME_PROFILING) || defined(FLOW_DEBUGGER)
    void ProfileTimeEvent();
#endif

#ifdef FLOW_TIME_PROFILING
    int ProfileGetTimeSamples();
#endif

    void run();

#if COMPILED
	void runOpcode(OpCode opcode);
#endif

    void DoGetLocal(int local) {
        Push(DataStack[FramePointer + local]);
    }

    void DoNativeCall(const StackSlot &arg);
    _INLINE_FORCE(void DoCall());
    _INLINE_FORCE(bool DoTailCall(int locals));
    _INLINE_FORCE(void DoReturn(bool closure));
    _INLINE_FORCE(void DoEqual());
    _INLINE_FORCE(void DoLessThan());
    _INLINE_FORCE(void DoLessEqual());
    _INLINE_FORCE(void DoNot());
    _INLINE_FORCE(void DoArrayGet());
    _INLINE_FORCE(void DoRefTo());
    _INLINE_FORCE(void DoDeref());
    _INLINE_FORCE(void DoSetRef());
    _INLINE_FORCE(void DoInt2Double());
    _INLINE_FORCE(void DoDouble2Int());
    _INLINE_FORCE(void DoField(int i));
    _INLINE_FORCE(void DoSetMutable(int i));
    int LookupFieldName(const StackSlot &struct_ref, char const * n, int length, short *idx, StructDef **pdef);
    void DoFieldName(char const * n, int length, short *idx);
    void DoSetMutableName(char const * n, int length, short *idx);

public:
    void DoPlus(StackSlot &inout, const StackSlot &in2);
    static void DoPlusString(ByteCodeRunner *self, StackSlot &inout, const StackSlot &in2);
    void DoPlusString(StackSlot &inout, const StackSlot &in2) { DoPlusString(this, inout, in2); }
    void DoMinus(StackSlot &inout, const StackSlot &in2);
    void DoMultiply(StackSlot &inout, const StackSlot &in2);
    void DoDivide(StackSlot &inout, const StackSlot &in2);
    void DoModulo(StackSlot &inout, const StackSlot &in2);
    void DoNegate(StackSlot &inout);

    static StackSlot DoInt2String(ByteCodeRunner *self, const StackSlot &arg);
    static StackSlot DoDouble2String(ByteCodeRunner *self, const StackSlot &arg);

    static int Compare(ByteCodeRunner *runner, const StackSlot &slot1, const StackSlot &slot2);
    int Compare(const StackSlot &slot1, const StackSlot &slot2) { return Compare(this, slot1, slot2); }
    int Compare(FlowPtr a1, FlowPtr a2);
    int CompareFlowString(FlowPtr p1, int l1, FlowPtr p2, int l2);

    bool CompareByRef(const StackSlot &slot1, const StackSlot &slot2);

    bool DoSubstring(StackSlot *pdata, int idx, unsigned size);

private:
    bool is_raw_bytecode;
    std::string BytecodeFilename;

    std::string LastErrorDescr;
    std::string LastErrorInfo;

    void DoReportError(RuntimeError code);

    typedef std::map< PlatformEvent, std::vector<int> > T_PlatformEventListeners;
    typedef std::vector<int> T_CustomFileTypeHandlers;

    T_PlatformEventListeners PlatformEventListeners;
    static StackSlot removePlatformEventListener(ByteCodeRunner*, StackSlot*, void*);

    T_CustomFileTypeHandlers CustomFileTypeHandlers;
    static StackSlot removeCustomFileTypeHandler(ByteCodeRunner*, StackSlot*, void*);

    typedef std::vector<int> T_CameraEventListeners;
    T_CameraEventListeners CameraEventListeners;
    static StackSlot removeCameraEventListener(ByteCodeRunner*, StackSlot*, void*);

    typedef std::vector<int> T_CameraVideoEventListeners;
    T_CameraVideoEventListeners CameraVideoEventListeners;
    static StackSlot removeCameraVideoEventListener(ByteCodeRunner*, StackSlot*, void*);

    typedef std::vector<int> T_TakeAudioEventListeners;
    T_TakeAudioEventListeners TakeAudioEventListeners;
    static StackSlot removeTakeAudioEventListener(ByteCodeRunner*, StackSlot*, void*);
public:
    ostream flow_out, flow_err;

    bool NotifyStubs;
    std::set<std::string> TargetTokens;

    void ReportError(RuntimeError code, const char *msg, ...);
    void ReportTagError(const StackSlot &slot, DataTag expected, const char *varname, const char *msg, ...);
    void ReportStructError(const StackSlot &slot, int expected_id, const char *varname, const char *msg, ...);
    void ReportFieldNameError(const StackSlot &slot, const char *fname, const char *place);

	_INLINE_FORCE(bool IsErrorReported()) { return unlikely(LastError != NoError); }

    std::string GetLastErrorMsg() { return LastErrorDescr; }
    std::string GetLastErrorInfo() { return LastErrorInfo; }

    // returns true when at least one listener asks to cancel default action and pretends to handle situation itself
    bool NotifyPlatformEvent(PlatformEvent event);
    void NotifyCustomFileTypeOpened(unicode_string path);
    void NotifyCameraEvent(int code, std::string message, std::string additionalInfo, int width, int height);
    void NotifyCameraEventVideo(int code, std::string message, std::string additionalInfo, int width, int height, int duration, unsigned size);
    void NotifyCameraEventAudio(int code, std::string message, std::string additionalInfo, int duration, unsigned size);
private:
    friend class BinaryDeserializer;

#ifdef FLOW_MMAP_HEAP
    // Memory mapped areas
    typedef std::pair<FlowPtr,int> RootExtentInfo;
    struct MappedAreaInfo {
        typedef shared_ptr<MappedAreaInfo> Ptr;

        FlowPtr start;
        size_t length;
        std::string filename;

        // Binary decoding of a mapped file into a mapped area can produce refs.
        // These have to be treated as GC roots.
        std::vector<RootExtentInfo> ref_roots;

        std::vector<Ptr> depends;

        MappedAreaInfo(FlowPtr start, size_t length) : start(start), length(length) {}
    };
    typedef std::map<FlowPtr, MappedAreaInfo::Ptr> T_MappedAreas;
    T_MappedAreas MappedAreas;

    MappedAreaInfo::Ptr FindMappedArea(FlowPtr ptr) {
        T_MappedAreas::iterator it = mapFindLE(MappedAreas, ptr);
        if (it != MappedAreas.end() && unsigned(ptr - it->first) < (unsigned)it->second->length)
            return it->second;
        else
            return MappedAreaInfo::Ptr();
    }

    FlowPtr MapStringPtr;
    FlowPtr MapAreaBase;
    std::map<std::string, StackSlot> MappedFiles;
#endif

    FlowPtr AllocateInner(unsigned size); // called if out of heap

    // Heap allocation
    FlowPtr Allocate(unsigned size)
    {
        //if (rand() % 30 == 0) ForceGC(0, rand()%3 == 0); // GC stress testing
        FlowPtr nhp = FlowPtrAlignDown(hp - size, 4);
        if (likely(nhp >= hpbound)) {
            if (unlikely(nhp > hp)) goto slow_path;
            if (unlikely(unsigned(size) > MAX_EPHEMERAL_ALLOC)) goto slow_path;
            hp = nhp;
#ifdef FLOW_INSTRUCTION_PROFILING
            if (unlikely(hp <= ProfileMemBarrier))
                ProfileMemEvent(size);
#endif
            return hp;
        } else {
    slow_path:
            return AllocateInner(size);
        }
    }

    FlowPtr AllocateClosureBuffer(int code, unsigned short length, StackSlot *data);
    StackSlot AllocateKnownStruct(const char *name, unsigned size, int id, StackSlot *data);

    unicode_char *AllocateStringBuffer(StackSlot *out, unsigned length);
    FlowPtr *AllocateStringRef(StackSlot *out, unsigned length);

    StackSlot AllocateUninitializedArray(unsigned length);
    StackSlot AllocateUninitializedClosure(unsigned short length, FlowPtr code);

public:
    StackSlot AllocateRawStruct(StructDef &def, bool clear = true);
    StackSlot AllocateRawStruct(int id, bool clear = true) { return AllocateRawStruct(StructDefs[id], clear); }


    bool IsMappedArea(FlowPtr ptr) {
        return unsigned(ptr - HeapStart) >= MAX_HEAP_SIZE;
    }

#ifdef FLOW_COMPACT_STRUCTS
    template<class T>
    T *AllocateRawStruct(StackSlot *out, unsigned short id) {
        FlowPtr buf = Allocate(sizeof(T));
        FlowGCHeader *phdr = Memory.GetObjectPointer(buf, true);
        phdr->IntVal = id;
        StackSlot::InternalSetSlot(*out, buf, id, StackSlot::TAG_STRUCT);
        return (T*)phdr;
    }

    template<class T>
    T *AllocateRawClosure(StackSlot *out, unsigned short id, int funcid) {
        FlowPtr buf = Allocate(sizeof(T) + 4) + 4;
        FlowGCHeader *phdr = Memory.GetObjectPointer(buf, true);
        phdr->IntVal = id;
        reinterpret_cast<int*>(phdr)[-1] = funcid;
        StackSlot::InternalSetSlot(*out, buf, 0, StackSlot::TAG_NATIVEFN|StackSlot::TAG_SIGN);
        return (T*)phdr;
    }

    void RegisterWrite(FlowStructHeader *ptr, FlowPtr base);
    void RegisterWrite(FlowStructHeader *ptr) {
        if (unlikely(ptr->GC_Tag))
            RegisterWrite(ptr, MakeFlowPtr((char*)ptr - Memory.GetRawPointer(MakeFlowPtr(0),0,false)));
    }
#endif

    StackSlot AllocateString(const unicode_char *str, int length);
    StackSlot AllocateString(const unicode_string &str) {
        return AllocateString(str.data(), str.size());
    }

    StackSlot AllocateString(const char *str) {
        return AllocateString(parseUtf8(str, strlen(str)));
    }

#ifdef FLOW_QT_BACKEND
    StackSlot AllocateString(const QString& str);
#endif

    StackSlot LoadFileAsString(std::string filename, bool temporary = false);
    void InvalidateFileCache(std::string filename);

    StackSlot AllocateRef(const StackSlot &value);
    StackSlot AllocateArray(int length, StackSlot *data = NULL);
    StackSlot AllocateStruct(const char *name, unsigned size);

    unsigned GetStringSize(const StackSlot &str) {
        assert(str.IsString());
        return GetSplitAuxValue(str);
    }
    FlowPtr GetStringAddr(const StackSlot &str) {
        assert(str.IsString());
        return str.GetSign() ? Memory.GetFlowPtr(str.slot_private.PtrValue+4) : str.slot_private.PtrValue;
    }
    const unicode_char *GetStringPtr(const StackSlot &str) {
#ifdef DEBUG_FLOW
        return (unicode_char*)Memory.GetRawPointer(GetStringAddr(str), GetStringSize(str) * FLOW_CHAR_SIZE, false);
#else
        return (unicode_char*)Memory.GetRawPointer(GetStringAddr(str), 0, false);
#endif
    }
    const unicode_char *GetStringPtrSize(const StackSlot &str, unsigned *psize) {
        unsigned size = *psize = GetStringSize(str);
        return size ? (unicode_char*)Memory.GetRawPointer(GetStringAddr(str), size * FLOW_CHAR_SIZE, false) : NULL;
    }

    unicode_string GetString(const StackSlot &str);
#ifdef FLOW_QT_BACKEND
    QString GetQString(const StackSlot &str);
#endif

private:
    StackSlot *GetMemorySlotWritePtr(FlowPtr ptr, unsigned count) {
        if (ptr >= hp_big_pos) RegisterWrite(ptr, count);
        return (StackSlot*)Memory.GetRawPointer(ptr, count*STACK_SLOT_SIZE, true);
    }
    void SetMemorySlot(FlowPtr ptr, int index, const StackSlot &val) {
        FlowPtr slot = ptr + index*STACK_SLOT_SIZE;
        Memory.SetStackSlot(slot, val);
        if (slot > hp_ref_base) RegisterWrite(slot);
    }
    unsigned GetSplitAuxValue(const StackSlot &str) {
        return str.GetSign() ? (str.slot_private.AuxValue<<16)|Memory.GetUInt16(str.slot_private.PtrValue) : str.slot_private.AuxValue;
    }

public:
    const StackSlot *GetArraySlotPtr(const StackSlot &arr, unsigned count) {
        return (StackSlot*)Memory.GetRawPointer(arr.GetInternalArrayPtr(), count*STACK_SLOT_SIZE, false);
    }
    const StackSlot &GetArraySlot(const StackSlot &arr, unsigned index) {
        return Memory.GetStackSlot(arr.GetInternalArrayPtr() + index*STACK_SLOT_SIZE);
    }
    StackSlot *GetArrayWritePtr(const StackSlot &arr, unsigned count) {
        return GetMemorySlotWritePtr(arr.GetInternalArrayPtr(), count);
    }
    void SetArraySlot(const StackSlot &arr, int index, const StackSlot &val) {
        SetMemorySlot(arr.GetInternalArrayPtr(), index, val);
    }

    const StackSlot *GetClosureSlotPtr(const StackSlot &arr, unsigned count) {
        return (StackSlot*)Memory.GetRawPointer(arr.GetClosureDataPtr(), count*STACK_SLOT_SIZE, false);
    }
    const StackSlot &GetClosureSlot(const StackSlot &arr, int index) {
        return Memory.GetStackSlot(arr.GetClosureDataPtr() + index*STACK_SLOT_SIZE);
    }
    StackSlot *GetClosureWritePtr(const StackSlot &arr, unsigned count) {
        return GetMemorySlotWritePtr(arr.GetClosureDataPtr(), count);
    }
    void SetClosureSlot(const StackSlot &arr, int index, const StackSlot &val) {
        SetMemorySlot(arr.GetClosureDataPtr(), index, val);
    }

    const StackSlot &GetRefTarget(const StackSlot &ref) {
        return Memory.GetStackSlot(ref.GetRawRefPtr());
    }
    void SetRefTarget(const StackSlot &ref, const StackSlot &val) {
        SetMemorySlot(ref.GetRawRefPtr(), 0, val);
    }
    unsigned GetRefId(const StackSlot &ref) {
        assert(ref.IsRefTo());
        return GetSplitAuxValue(ref);
    }

    void CopySlots(FlowPtr target, FlowPtr src, unsigned count) {
        Memory.Copy(src, target, count*STACK_SLOT_SIZE);
        if (unlikely(target >= hp_big_pos)) RegisterWrite(target, count);
    }
    void CopySlots(FlowPtr target, const StackSlot *src, unsigned count) {
        Memory.SetBytes(target, src, count*STACK_SLOT_SIZE);
        if (unlikely(target >= hp_big_pos)) RegisterWrite(target, count);
    }
    void CopyArraySlots(const StackSlot &target, int toff, const StackSlot &src, int soff, unsigned count) {
        CopySlots(target.GetInternalArrayPtr() + toff*STACK_SLOT_SIZE, src.GetInternalArrayPtr() + soff*STACK_SLOT_SIZE, count);
    }
    void CopyArraySlots(const StackSlot &target, int toff, const StackSlot *src, unsigned count) {
        CopySlots(target.GetInternalArrayPtr() + toff*STACK_SLOT_SIZE, src, count);
    }

    // These are type-specific:
    inline int GetClosureSize(const StackSlot &arr) {
        FlowPtr ptr = arr.GetClosureDataPtr();
        return ptr != MakeFlowPtr(0) ? Memory.GetInt32(ptr - 4) : 0;
    }
    inline unsigned GetArraySize(const StackSlot &arr) {
        assert(arr.IsArray());
        return GetSplitAuxValue(arr);
    }

    inline int GetStructSize(const StackSlot &arr) {
        int id = arr.GetStructId();
        if (unsigned(id) >= StructSizes.size())
            return -1;
        else
            return StructSizes[id];
    }

    int GetNativeFnId(const StackSlot &ref) {
        assert(ref.IsNativeFn());
        return ref.GetSign() ? Memory.GetInt32(ref.slot_private.PtrValue-4) : ref.slot_private.IntValue;
    }
    FlowPtr GetCodePointer(const StackSlot &ref) {
        assert(ref.IsFlowCode());
        return ref.GetSign() ? Memory.GetFlowPtr(ref.slot_private.PtrValue-4) : ref.slot_private.PtrValue;
    }

#ifndef FLOW_COMPACT_STRUCTS
    const StackSlot &GetStructSlot(const StackSlot &str, int index) {
        return GetArraySlot(str, index);
    }
    void SetStructSlot(const StackSlot &str, int index, const StackSlot &val) {
        SetArraySlot(str, index, val);
    }
    void StructSlotPack(const StackSlot &str, const StackSlot *src, int start, unsigned count) {
        CopyArraySlots(str, start, src, count);
    }
    void StructSlotUnpack(const StackSlot &str, StackSlot *tgt, int start, unsigned count) {
        memcpy(tgt, GetArraySlotPtr(str, count) + start, count*STACK_SLOT_SIZE);
    }
#else
    FlowStructHeader *GetStructPtr(const StackSlot &str) {
        return Memory.GetStructPointer(str.GetRawStructPtr(), false);
    }
    FlowStructHeader *GetStructPtr(FlowPtr str) {
        return Memory.GetStructPointer(str, false);
    }
    FlowStructHeader *GetClosureStructPtr(const StackSlot &str) {
        assert(str.IsNativeClosure() && str.slot_private.AuxValue == 0);
        return Memory.GetStructPointer(str.slot_private.PtrValue, false);
    }
    const StackSlot GetStructSlot(const StackSlot &str, int index) {
        const FlowStructFieldDef &fd = StructDefs[str.GetStructId()].FieldDefs[index];
        FlowStructHeader *ph = Memory.GetStructPointer(str.GetRawStructPtr(), false);
        return fd.fn_get(ph->Bytes + fd.offset, this);
    }
    void SetStructSlot(const StackSlot &str, int index, const StackSlot &val) {
        const FlowStructFieldDef &fd = StructDefs[str.GetStructId()].FieldDefs[index];
        FlowStructHeader *ph = Memory.GetStructPointer(str.GetRawStructPtr(), true);
        if (unlikely(!fd.fn_set(ph->Bytes+fd.offset, val)))
            ReportTagError(val, fd.tag, StructDefs[str.GetStructId()].FieldNames[index].c_str(), "SetStructSlot");
        else if (unlikely(ph->GC_Tag))
            RegisterWrite(ph, str.GetRawStructPtr());
    }
    void StructSlotPack(const StackSlot &str, const StackSlot *src, int start, unsigned count);
    void StructSlotUnpack(const StackSlot &str, StackSlot *tgt, int start, unsigned count);
#endif

    inline const std::string & GetStructName(const StackSlot &strct) {
        int id = strct.GetStructId();
        assert (unsigned(id) < StructSizes.size());
        return StructDefs[id].Name;
    }
    inline const unicode_string & GetStructNameU(const StackSlot &strct) {
        int id = strct.GetStructId();
        assert (unsigned(id) < StructSizes.size());
        return StructDefs[id].NameU;
    }

private:
    friend class ByteCodeRunnerNativeContext;
    friend class FlowStackSnapshot;

	static const int MAX_NATIVE_ARGS = 20;

    static const unsigned MAX_NATIVE_CALLS = 5000;
    static const unsigned MAX_CALL_STACK = 65536;
    static const unsigned MAX_DATA_STACK = 1048576;

    static const unsigned CALL_STACK_FP_BIT = 0x80000000;

private:
    void StackError(RuntimeError error, bool overflow = true);

    // Code stack operations
    CallFrame *CallStackPush(FlowPtr addr);
    CallFrame *CallStackPop();

    // Low-level data stack access
    _INLINE_FORCE(StackSlot *GetStackSlotPtr(int offset)) {
        return &DataStack.top(offset);
    }

    inline void PushDataStackSlot(int offset);

    FlowPtr MoveStackToHeap(int num_slots, bool with_size);
    void MoveStructToStack(StackSlot str, unsigned count);

protected:
    const StackSlot &GetStackSlotRef(int offset) {
        return DataStack.top(offset);
    }

    _INLINE_FORCE(void Push(const StackSlot &value))
    {
        if (likely(DataStack.size() < MAX_DATA_STACK))
            DataStack.push_back(value);
        else
            StackError(DatastackFull);
    }

    // Simple data push operations
	_INLINE_FORCE(void PushVoid()) {
        Push(StackSlot::MakeVoid());
    }

	_INLINE_FORCE(void PushInt(int value)) {
        Push(StackSlot::MakeInt(value));
    }

	_INLINE_FORCE(void PushBool(int value)) {
        Push(StackSlot::MakeBool(value));
    }

	_INLINE_FORCE(void PushDouble(FlowDouble value))
    {
        Push(StackSlot::MakeDouble(value));
    }

    void Push(const char *str)
    {
        Push(AllocateString(str));
    }

#ifdef FLOW_QT_BACKEND
    void Push(const QString &str)
    {
        Push(AllocateString(str));
    }
#endif

    void Push(const unicode_string &str)
    {
        Push(AllocateString(str));
    }

    // Pop operations
    void DiscardStackSlots(int num)
    {
        if (likely(DataStack.size() >= unsigned(num)))
            DataStack.pop_ptr(num);
        else
            StackError(DatastackFull, false);
    }

    void DiscardInnerStackSlots(int num)
    {
        DataStack.top(num) = DataStack.top(0);
        DiscardStackSlots(num);
    }

	_INLINE_FORCE(StackSlot PopStackSlot())
    {
        if (likely(!DataStack.empty())) {
            return DataStack.pop();
        } else {
            StackError(DatastackFull, false);
            return StackSlot::MakeVoid();
        }
    }

    int PopStackInt();
    FlowDouble PopStackDouble();

	_INLINE_FORCE(void PushFromMemory(FlowPtr a))
    {
        Push(Memory.GetStackSlot(a));
    }

private:
    // The native values we get are kept here
    int NextNativeIdx, NativeValueBudget, NativeGCGenBarrier;
    typedef STL_HASH_MAP<int, AbstractNativeValue*> T_NativeValues;
    T_NativeValues NativeValues;

    friend class FlowNativeObject;

    StackSlot AllocNativeObj(AbstractNativeValue *nv);
    AbstractNativeValue *GetNativeObj(NativeValueTypeBase *tag, const StackSlot &slot, bool fno = false);

public:
    template<class T>
    DISABLE_IF_FLOW_NOBJ_PTR(T,StackSlot) AllocNative(const T &value) {
        return AllocNativeObj(new NativeValue<T>(this, value));
    }

    template<class T>
    ENABLE_IF_FLOW_NOBJ_PTR(T,StackSlot) AllocNative(T value) {
        return value->getFlowValue();
    }

protected:
    template<class T>
    DISABLE_IF_FLOW_NOBJ_PTR(T,void) PushNative(const T &value) {
        Push(AllocNativeObj(new NativeValue<T>(this, value)));
    }

    template<class T>
    ENABLE_IF_FLOW_NOBJ_PTR(T,void) PushNative(T value) {
        Push(value->getFlowValue());
    }

public:
    template<class T>
    DISABLE_IF_FLOW_NOBJ_PTR(T,T) &GetNative(const StackSlot &slot) {
        return static_cast<NativeValue<T>*>(GetNativeObj(FLOW_VALUE_TYPE(T), slot))->getValue();
    }

    template<class T>
    ENABLE_IF_FLOW_NOBJ_PTR(T,T) GetNative(const StackSlot &slot) {
        AbstractNativeValue *av = GetNativeObj(FLOW_VALUE_TYPE(T), slot, true);
        return av ? static_cast<T>(static_cast<FlowNativeValue*>(av)->getValue()) : NULL;
    }

    bool DeleteNative(const StackSlot &slot);

    bool DeleteNative(FlowNativeObject *obj) {
        return DeleteNative(obj->getFlowValue());
    }

private:
    friend class NativeMethodHost;

    int NumFullGCs;

    // Native functions at the start of the list that should never be GCd
    unsigned NumFrozenNativeFNs;
#ifdef FLOW_COMPACT_STRUCTS
    // Native functions at the start of the list that use struct-like layouts
    unsigned NumCompactNativeFNs;
#endif
    // Number of data stack entries that are made read-only to protect globals
    unsigned NumFrozenDataStack;

    // Hosts provide native implementations to the runner
    typedef std::vector<NativeMethodHost*> T_NativeHosts;
    T_NativeHosts NativeHosts;

    /*
     * Deferred queue implements the deferred() function.
     *
     * The actual problem it solves is that to avoid flicker
     * it is often necessary to ensure that deferred updates
     * complete before the screen is redrawn. This can't be
     * done if the updates are implemented via regular timer,
     * so a special high priority queue is used for short
     * timeouts.
     */
    int DeferredQueueLockCount;
    std::list<StackSlot> DeferredActionQueue;

    // Table of native closures that accept a certain number of arguments and return a constant.
    typedef std::vector<StackSlot> T_ConstClosureCache;
    T_ConstClosureCache ConstClosureCache;

    typedef std::vector<int> T_FlowCrashHandlers;
    T_FlowCrashHandlers FlowCrashHandlers;
    static StackSlot removeCrashHandler(ByteCodeRunner*, StackSlot*, void*);
    void callFlowCrashHandlers(std::string msg);

protected:
    StackSlot AllocNativeFn(NativeFunction *fn, FlowPtr cp);
    NativeFunction *MakeNativeFunction(const char *name, int num_args, bool optional);

public:
    // Copy the closure reference
    StackSlot AllocateClosure(const StackSlot &base, unsigned short num_upvals, StackSlot *upval_data = NULL)
    {
        if (base.IsNativeFn())
        {
            FlowPtr arr = AllocateClosureBuffer(GetNativeFnId(base), num_upvals, upval_data); // ALLOC
            return StackSlot::InternalMakeNativeClosure(arr, num_upvals);
        }
        else
        {
            assert(base.IsFlowCode());
            FlowPtr arr = AllocateClosureBuffer(FlowPtrToInt(GetCodePointer(base)), num_upvals, upval_data); // ALLOC
            return StackSlot::InternalMakeClosurePointer(arr, num_upvals);
        }
    }

    // Stop GC of currently allocated native functions
    void FreezeNativeFunctions(bool compact = false);

    // Make some special case native closures
    StackSlot AllocateNativeClosure(NativeClosurePtr ptr, const char *name, int num_args, void *data, int num_slots, ...);
    StackSlot AllocateConstClosure(int num_args, StackSlot value);

    // Invoke OnHostEvent of all attached native method hosts
    void NotifyHostEvent(NativeMethodHost::HostEvent type);

    // Register the action to be called later
    void AddDeferredAction(const StackSlot &cb) {
        DeferredActionQueue.push_back(cb);
    }

    static StackSlot RemoveDeferredAction(ByteCodeRunner *const RUNNER, StackSlot *const pRunnerArgs__, void *) {
        const StackSlot &cb = pRunnerArgs__[0];

        RUNNER->DeferredActionQueue.remove(cb);

        return cb;
    }

    double DeferredQueueTimeout; // <= 0 - no timeout

    void RunDeferredActions();

    // Prevents deferred actions from being called while active, and runs them on scope exit
    class LockDeferred {
        ByteCodeRunner *runner;
    public:
        LockDeferred(ByteCodeRunner *runner) : runner(runner) { runner->DeferredQueueLockCount++; }
        ~LockDeferred() { if (--runner->DeferredQueueLockCount <= 0) runner->RunDeferredActions(); }
    };

private:
    bool EvalFunctionStack(const StackSlot &func, int args_num);

    FlowPtr BacktrackCall(FlowPtr val);

public:
    StackSlot EvalFunction(const StackSlot &func, int args_num, ...);
    StackSlot EvalFunctionArr(const StackSlot &func, int args_num, StackSlot *args);

    // func_and_args is an array, containing the function at index 0, and arguments after it.
    // the arguments part may be overwritten by the callee; the function item is preserved.
	_INLINE_FORCE(StackSlot FastEvalFunction(StackSlot *func_and_args, int args_num))
    {
        // Fast-track path for native-to-native calls, allowing branch prediction to kick in
        if (likely(func_and_args[0].IsNativeFn())) {
            NativeFunction *p = lookupNativeFn(GetNativeFnId(func_and_args[0]));
            if (unlikely(!p)) goto slow_path;
            if (unlikely(p->num_args_ != args_num)) goto slow_path;
            // this call is what must be inlined per call site for branch prediction
            return (CurNativeFn = p)->func_(this, func_and_args+1);
        } else {
    slow_path:
            return EvalFunctionArr(func_and_args[0], args_num, func_and_args+1);
        }
    }

    const std::vector<StructDef> &GetStructDefs() { return StructDefs; }
    const StructDef & GetStructDef(int struct_id) {
        assert (unsigned(struct_id) < StructSizes.size());
        return StructDefs[struct_id];
    }

    int FindStructId(const std::string &name, int num_fields);
    bool VerifyStruct(const StackSlot &arr, int struct_id);

    StackSlot MakeStruct(const std::string& name, int fields_num, const StackSlot * fields);

    FlowPtr FunctionToAddress(const char *name);
    std::string AddressToFunction(FlowPtr pc);

    void ParseCallStack(std::vector<FlowStackFrame> *vec, const TCallStack &CallStack, FlowPtr cur_insn, ExtendedDebugInfo *dbg = NULL);

    void PrintCallStack(ostream &out, bool with_args = false);
    void PrintCallStackLine(ostream &out, const FlowStackFrame &frame, bool with_args);

    void ForceGC(unsigned ensure_space = 0, bool full = false);
    void PrintDataStack();

    bool PrintData(ostream &out, const StackSlot &slot, int max_depth = -1, int max_count = -1);
    void PrintData(ostream &out, FlowPtr addr) {
        PrintData(out, Memory.GetStackSlot(addr));
    }

    // A table of arbitrary global roots for cases where implementing flowGCObject is cumbersome.
    int RegisterRoot(StackSlot root);
    StackSlot LookupRoot(int i);
    void ReleaseRoot(int i);

    // Lists
#define STRUCT(name,size) bool Is##name##Struct(const StackSlot &slot) { \
        return slot.IsStruct() && slot.GetStructId() == name##StructId; \
    }
    FLOW_KNOWN_STRUCTS
#undef STRUCT

    StackSlot GetConsItem(const StackSlot &cons) {
        return GetStructSlot(cons, 0);
    }

    void StructTypeError(const StackSlot &slot, const char *fn, const char *tname, int struct_id);

#define STRUCT(name,size) bool Verify##name(const StackSlot &slot, const char *fn) { \
        if (unlikely(!slot.IsStruct() || slot.GetStructId() != name##StructId || name##StructId < 0)) {\
            StructTypeError(slot, fn, #name, name##StructId); return false; \
        } else return true; \
    }
    FLOW_KNOWN_STRUCTS
#undef STRUCT

#define STRUCT(name,size) StackSlot Allocate##name##Struct(StackSlot *data = NULL) { \
        return AllocateKnownStruct(#name,size,name##StructId,data); \
    }
    FLOW_KNOWN_STRUCTS
#undef STRUCT

    // More convenient version for Some(x)
    StackSlot AllocateSomeStruct(StackSlot data);

public:
    static StackSlot println(ByteCodeRunner*,StackSlot*);

private:
    static StackSlot const_closure(ByteCodeRunner*,StackSlot*);

    static bool isValueFitInType(ByteCodeRunner*, const std::vector<FieldType> &type, const StackSlot &value, int ti);

    // Is used by both natives strIndexOf & strRangeIndexOf
    static int strRangeIndexOf(const unicode_char *pstr, const unicode_char *psub, unsigned l1, unsigned l2, unsigned start, unsigned end);
    static StackSlot setFileContentHelper(ByteCodeRunner*,StackSlot*,void (*processor)(int nbytes, const unicode_char * pdata, uint8_t * bytes));
 public:
    static StackSlot mapi(ByteCodeRunner*,StackSlot*);
    static StackSlot map(ByteCodeRunner*,StackSlot*);
    static StackSlot iter(ByteCodeRunner*,StackSlot*);
    static StackSlot iteri(ByteCodeRunner*,StackSlot*);
    static StackSlot fold(ByteCodeRunner*,StackSlot*);
    static StackSlot foldi(ByteCodeRunner*,StackSlot*);
    static StackSlot filter(ByteCodeRunner*,StackSlot*);
    static StackSlot gc(ByteCodeRunner*,StackSlot*);
    static StackSlot subrange(ByteCodeRunner*,StackSlot*);
    static StackSlot length(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeStrlen(ByteCodeRunner*,StackSlot*);
    static StackSlot strIndexOf(ByteCodeRunner*,StackSlot*);
    static StackSlot strContainsAt(ByteCodeRunner*,StackSlot*);
    static StackSlot strRangeIndexOf(ByteCodeRunner*,StackSlot*);
    static StackSlot substring(ByteCodeRunner*,StackSlot*);
    static StackSlot concat(ByteCodeRunner*,StackSlot*);
    static StackSlot replace(ByteCodeRunner*,StackSlot*);
    static StackSlot s2a(ByteCodeRunner*,StackSlot*);
    static StackSlot bitXor(ByteCodeRunner*,StackSlot*);
    static StackSlot bitAnd(ByteCodeRunner*,StackSlot*);
    static StackSlot bitOr(ByteCodeRunner*,StackSlot*);
    static StackSlot bitShl(ByteCodeRunner*,StackSlot*);
    static StackSlot bitUshr(ByteCodeRunner*,StackSlot*);
    static StackSlot bitNot(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeTimestamp(ByteCodeRunner*,StackSlot*);
    static StackSlot random(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeSrand(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeSin(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeAsin(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeAcos(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeAtan(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeAtan2(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeExp(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeLog(ByteCodeRunner*,StackSlot*);
    static StackSlot NativePrintCallStack(ByteCodeRunner*,StackSlot*);
    static StackSlot NativeGetTargetName(ByteCodeRunner*,StackSlot*);
    static StackSlot failWithError(ByteCodeRunner*,StackSlot*);
    static StackSlot setKeyValue(ByteCodeRunner*,StackSlot*);
    static StackSlot getKeyValue(ByteCodeRunner*,StackSlot*);
    static StackSlot removeAllKeyValues(ByteCodeRunner*,StackSlot*);
    static StackSlot getKeysList(ByteCodeRunner*,StackSlot*);
    static StackSlot removeKeyValue(ByteCodeRunner*,StackSlot*);
    static StackSlot generate(ByteCodeRunner*,StackSlot*);
    static StackSlot enumFromTo(ByteCodeRunner*,StackSlot*);
    static StackSlot toLowerCase(ByteCodeRunner*,StackSlot*);
    static StackSlot toUpperCase(ByteCodeRunner*,StackSlot*);
    static StackSlot toString(ByteCodeRunner*,StackSlot*);
    static StackSlot makeStructValue(ByteCodeRunner*,StackSlot*);
    static StackSlot extractStructArguments(ByteCodeRunner*,StackSlot*);
    static StackSlot getDataTagForValue(ByteCodeRunner*,StackSlot*);
    static StackSlot getFileContent(ByteCodeRunner*,StackSlot*);
    static StackSlot setFileContent(ByteCodeRunner*,StackSlot*);
    static StackSlot setFileContentUTF16(ByteCodeRunner*,StackSlot*);
    static StackSlot getFileContentBinary(ByteCodeRunner*,StackSlot*);
    static StackSlot setFileContentBinary(ByteCodeRunner*,StackSlot*);
    static StackSlot setFileContentBytes(ByteCodeRunner*,StackSlot*);
    static StackSlot getBytecodeFilename(ByteCodeRunner*,StackSlot*);
    static StackSlot loaderUrl(ByteCodeRunner*,StackSlot*);
    static StackSlot getUrlParameter(ByteCodeRunner*,StackSlot*);
    static StackSlot getAllUrlParameters(ByteCodeRunner*,StackSlot*);
    static StackSlot preloadMediaUrl(ByteCodeRunner*,StackSlot*);
    static StackSlot fromCharCode(ByteCodeRunner*,StackSlot*);
    static StackSlot string2time(ByteCodeRunner*,StackSlot*);
    static StackSlot time2string(ByteCodeRunner*,StackSlot*);
    static StackSlot utc2local(ByteCodeRunner*,StackSlot*);
    static StackSlot local2utc(ByteCodeRunner*,StackSlot*);
    static StackSlot dayOfWeek(ByteCodeRunner*,StackSlot*);
    static StackSlot number2double(ByteCodeRunner*,StackSlot*);
    static StackSlot getCharCodeAt(ByteCodeRunner*,StackSlot*);
    static StackSlot string2utf8(ByteCodeRunner*,StackSlot*);
    static StackSlot list2array(ByteCodeRunner*,StackSlot*);
    static StackSlot list2string(ByteCodeRunner*,StackSlot*);
    static StackSlot isArray(ByteCodeRunner*,StackSlot*);
    static StackSlot isSameStructType(ByteCodeRunner*,StackSlot*);
    static StackSlot isSameObj(ByteCodeRunner*,StackSlot*);
    static StackSlot iteriUntil(ByteCodeRunner*,StackSlot*);
    static StackSlot toBinary(ByteCodeRunner*,StackSlot*);
    static StackSlot fromBinary(ByteCodeRunner*,StackSlot*);
    static StackSlot fromBinary2(ByteCodeRunner*,StackSlot*);
    static StackSlot stringbytes2double(ByteCodeRunner*,StackSlot*);
    static StackSlot stringbytes2int(ByteCodeRunner*,StackSlot*);
    static StackSlot getCurrentDate(ByteCodeRunner*,StackSlot*);
    static StackSlot captureCallstack(ByteCodeRunner*,StackSlot*);
    static StackSlot captureCallstackItem(ByteCodeRunner*,StackSlot*);
    static StackSlot impersonateCallstackItem(ByteCodeRunner*,StackSlot*);
    static StackSlot impersonateCallstackFn(ByteCodeRunner*,StackSlot*);
    static StackSlot impersonateCallstackNone(ByteCodeRunner*,StackSlot*);
    static StackSlot callstack2string(ByteCodeRunner*,StackSlot*);
    static StackSlot elemIndex(ByteCodeRunner*,StackSlot*);
    static StackSlot exists(ByteCodeRunner*,StackSlot*);
    static StackSlot find(ByteCodeRunner*,StackSlot*);
    static StackSlot getTotalMemoryUsed(ByteCodeRunner*,StackSlot*);
    static StackSlot addCrashHandler(ByteCodeRunner*,StackSlot*);
    static StackSlot deleteNative(ByteCodeRunner*,StackSlot*);
    static StackSlot addPlatformEventListener(ByteCodeRunner*,StackSlot*);
    static StackSlot addCustomFileTypeHandler(ByteCodeRunner*,StackSlot*);
    static StackSlot addCameraPhotoEventListener(ByteCodeRunner*,StackSlot*);
    static StackSlot addCameraVideoEventListener(ByteCodeRunner*,StackSlot*);
    static StackSlot addTakeAudioEventListener(ByteCodeRunner*,StackSlot*);
    static StackSlot md5(ByteCodeRunner*,StackSlot*);
	static StackSlot fileChecksum(ByteCodeRunner*,StackSlot*);
	static StackSlot readBytes(ByteCodeRunner*,StackSlot*);
	static StackSlot readUntil(ByteCodeRunner*,StackSlot*);
	static StackSlot print(ByteCodeRunner*,StackSlot*);
private:
    static StackSlot fast_lookupTree(ByteCodeRunner*,StackSlot*);
    static StackSlot fast_setTree(ByteCodeRunner*,StackSlot*);
    static StackSlot fast_rebalancedTree(ByteCodeRunner*,StackSlot*);
    static StackSlot fast_treeLeftRotation(ByteCodeRunner*,StackSlot*);
    static StackSlot fast_treeRightRotation(ByteCodeRunner*,StackSlot*);
#ifdef FLOW_NATIVE_OVERRIDES
#define OVERRIDE(name,args) static StackSlot override_##name(ByteCodeRunner*,StackSlot*);
    FLOW_NATIVE_OVERRIDES
#undef OVERRIDE
#endif
};

inline NativeFunction *NativeFunction::get_self(ByteCodeRunner *runner) {
    return runner->CurNativeFn;
}

template<class T>
StackSlot MethodNative<T>::thunk(ByteCodeRunner *runner, StackSlot *args)
{
    MethodNative<T> *self = (MethodNative<T>*)get_self(runner);
    return ((self->Host)->*(self->Func))(runner, args);
}

template<class T>
StackSlot ObjectMethodNative<T>::thunk(ByteCodeRunner *runner, StackSlot *args)
{
    ObjectMethodNative<T> *self = (ObjectMethodNative<T>*)get_self(runner);
    T *Host = runner->GetNative<T*>(args[0]);
    if (!Host) return StackSlot::MakeVoid(); // type error should already have been signalled
    return (Host->*(self->Func))(runner, args+1);
}

#ifdef FLOW_DEBUGGER
class FlowDebuggerBase
{
    friend class ByteCodeRunner;

    ByteCodeRunner *runner;
    FlowInstruction::Map insn_table;

    ExtendedDebugInfo our_dbg_info, *active_dbg_info;

    std::map<int, FlowInstruction*> structs;
    std::map<std::string, int> globals;
    std::vector<std::string> global_vars;

protected:
    ByteCodeRunner *getFlowRunner() { return runner; }
    const FlowInstruction::Map &insns() { return insn_table; }
    const std::map<FlowPtr,OpCode> &breakpoints() { return runner->BreakpointOpcodeBackup; }
    ByteMemory &memory() { return runner->Memory; }

    typedef ByteCodeRunner::TDataStack TDataStack;
    TDataStack &data_stack() { return runner->DataStack; }
    typedef ByteCodeRunner::TCallStack TCallStack;
    TCallStack &call_stack() { return runner->CallStack; }

    unsigned frame_pointer() { return runner->FramePointer; }
    FlowPtr closure_pointer() { return runner->closurepointer; }

    int findGlobalByName(const std::string &name);
    FlowInstruction *findStructDef(int id);

    const std::vector<std::string> &global_names() { return global_vars; }

    virtual void onRunnerInit();
    virtual void onRunnerReset();

    virtual void onBreakpointTrap(FlowPtr insn) = 0;
    virtual void onInsnTrap(FlowPtr insn) = 0;
    virtual void onCallTrap(FlowPtr insn, bool tail) = 0;
    virtual void onReturnTrap(FlowPtr insn) = 0;
    virtual void onAsyncInterrupt(FlowPtr insn) = 0;
    virtual void onError(RuntimeError err, FlowPtr insn) = 0;

    FlowPtr SetBreakpoint(FlowPtr addr, bool enable);

    void SetTraps(bool insn_trap, bool call_trap, bool return_trap) {
        runner->DbgInsnTrap = insn_trap;
        runner->DbgCallTrap = call_trap;
        runner->DbgReturnTrap = return_trap;
#ifdef FLOW_INSTRUCTION_PROFILING
        if (insn_trap) runner->ProfileICBarrier = runner->InstructionCount+1;
#endif
    }

    bool InsnTrapActive() { return runner->DbgInsnTrap; }
    bool CallTrapActive() { return runner->DbgCallTrap; }
    bool ReturnTrapActive() { return runner->DbgReturnTrap; }

    bool AsyncInterruptPending() { return runner->ProfileTimeCount != 0; }
    void SetAsyncInterrupt(bool enable) { runner->ProfileTimeCount = enable?1:0; }

    ExtendedDebugInfo *DebugInfo() { return active_dbg_info; }

    FlowPtr GetCodePosition() { return runner->Code.GetPosition(); }
    FlowPtr GetLastInstruction() { return runner->LastInstructionPtr; }
    FlowPtr GetNativeReturnInstruction() { return runner->NativeReturnInsn; }

public:
    FlowDebuggerBase(ByteCodeRunner *runner);
    virtual ~FlowDebuggerBase();
};
#endif

/*
 * RAII helper for pushing a fake 'special id' frame on the call stack for profiling purposes.
 */
class ByteCodeRunnerNativeContext
{
    ByteCodeRunner *runner;
    FlowPtr tag, last_insn;
public:
    static FlowPtr MakeTag(int id) {
        return MakeFlowPtr(unsigned(-1-id));
    }

    ByteCodeRunnerNativeContext(ByteCodeRunner *runner, int id) : runner(runner) {
        tag = MakeTag(id);
        last_insn = runner->LastInstructionPtr;
        if (runner->IsErrorReported())
            return;
#ifdef FLOW_TIME_PROFILING
        if (runner->ProfileTimeCount)
            runner->ProfileTimeEvent();
#endif
        runner->CallStackPush(last_insn);
        runner->LastInstructionPtr = tag;
    }

    ~ByteCodeRunnerNativeContext()
    {
        if (runner->IsErrorReported())
            return;
#ifdef FLOW_TIME_PROFILING
        if (runner->ProfileTimeCount)
            runner->ProfileTimeEvent();
#endif
        ByteCodeRunner::CallFrame *frame = runner->CallStackPop(); (void)&frame;
        assert(frame && frame->last_pc == last_insn);
        runner->LastInstructionPtr = last_insn;
    }
};

class FlowStackSnapshot : public FlowNativeObject {
    ByteCodeRunner::TCallStack CallStack;

#ifdef FLOW_TIME_PROFILING
    void doClaimTime(int code);
#endif
public:
    FlowStackSnapshot(ByteCodeRunner *owner, unsigned skip = 0) : FlowNativeObject(owner) {
        CallStack.push_all(owner->CallStack, skip);
    }

    const ByteCodeRunner::TCallStack &getCallStack() { return CallStack; }

    DEFINE_FLOW_NATIVE_OBJECT(FlowStackSnapshot, FlowNativeObject);

    void claimElapsedTime(int code) {
#ifdef FLOW_TIME_PROFILING
        if (getFlowRunner()->ProfileTimeCount)
            doClaimTime(code);
#endif
    }

    std::string toString();
};

#if defined(FLOW_TIME_PROFILING) && !defined(FLOW_PTHREAD)
/*
 * Thread that counts out time for time profiling and notifies the main thread via volatile field update.
 */
class ByteCodeProfileClock : public QThread
{
    Q_OBJECT

    ByteCodeRunner *runner;
    QMutex *mutex;

public:
    ByteCodeProfileClock(ByteCodeRunner *owner);

protected:
    void run();
};
#endif

#endif
