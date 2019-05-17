#ifndef _BYTE_MEMORY_H_
#define _BYTE_MEMORY_H_

#include <memory.h>
#include "CommonTypes.h"
#include "MemoryArea.h"

extern unsigned int MIN_HEAP_SIZE ;
extern unsigned int MAX_HEAP_SIZE ;

#ifdef FLOW_EMBEDDED
#define FILE_MAP_MEMORY_SIZE (128 * 1048576)
#else
#define FILE_MAP_MEMORY_SIZE (256 * 1048576)
#endif

#ifdef __x86_64__
/* In 64-bit mode reserve full 4GB of address space. */
#define MAX_MEMORY_SIZE 0xffffffffU
#else
#define MAX_MEMORY_SIZE (MAX_HEAP_SIZE + FILE_MAP_MEMORY_SIZE)
#endif

#if !defined(WIN32)
#define FLOW_MMAP_HEAP
#endif

class ByteMemory : protected MemoryArea
{
    friend class CodeMemory;
    friend class FlowJitProgram;
    
    char *Buffer;
    size_t BufferSize;

    void ReportFailure(FlowPtr ptr, size_t size, bool write);

#if defined(DEBUG_FLOW) && !defined(__x86_64__)
    char *VerifyAccess(FlowPtr ptr, size_t size, bool write) {
#else
    char *VerifyAccess(FlowPtr ptr, size_t, bool) {
#endif
        unsigned iptr = FlowPtrToInt(ptr);
#if defined(DEBUG_FLOW) && !defined(__x86_64__)
        size_t end = iptr + size;
#ifdef FLOW_MMAP_HEAP
        if (unlikely(end > size_t(MAX_MEMORY_SIZE) || end < iptr))
#else
        if (unlikely(end > BufferSize || end < iptr))
#endif
            ReportFailure(ptr, size, write);
#endif
        return Buffer + iptr;
    }
public:
    ByteMemory(size_t size = 1024);
    ~ByteMemory();

    void SetSize(size_t size);
    void CommitRange(FlowPtr start, FlowPtr end);
    void DecommitRange(FlowPtr start, FlowPtr end);
        
    size_t GetMemSize() { return BufferSize; }
    size_t PageSize() { return MemoryArea::page_size(); }

    bool MapFile(FlowPtr start, size_t length, std::string filename, size_t offset = 0, bool writable = false);

    void Clear();

    bool IsValid(FlowPtr ptr, size_t size)
    {
        unsigned iptr = FlowPtrToInt(ptr);
        size_t end = iptr + size;
        return !(end > BufferSize || end < iptr);
    }

    char *GetRawPointer(FlowPtr ptr, size_t size, bool for_write) {
        return VerifyAccess(ptr, size, for_write);
    }

    FlowGCHeader *GetObjectPointer(FlowPtr ptr, bool for_write) {
        return (FlowGCHeader*)VerifyAccess(ptr, 4, for_write);
    }

#ifdef FLOW_COMPACT_STRUCTS
    FlowStructHeader *GetStructPointer(FlowPtr ptr, bool for_write) {
        return (FlowStructHeader*)VerifyAccess(ptr, 4, for_write);
    }
#endif

    char GetByte(FlowPtr addr)                 { return *VerifyAccess(addr, 1, false); }
    void SetByte(FlowPtr addr, char val)       { *VerifyAccess(addr, 1, true) = val; }

    unicode_char GetChar(FlowPtr addr)         { return *(unicode_char*)VerifyAccess(addr, sizeof(unicode_char), false); }

    unsigned short GetUInt16(FlowPtr addr)           { return *(unsigned short*)VerifyAccess(addr, sizeof(short), false); }

    int GetInt32(FlowPtr addr)                 { return *(int*)VerifyAccess(addr, sizeof(int), false); }
    void SetInt32(FlowPtr addr, int val)       { *(int*)VerifyAccess(addr, sizeof(int), true) = val; }
        
    FlowPtr GetFlowPtr(FlowPtr addr)           { return *(FlowPtr*)VerifyAccess(addr, sizeof(int), false); }
    void SetFlowPtr(FlowPtr addr, FlowPtr val) { *(FlowPtr*)VerifyAccess(addr, sizeof(int), true) = val; }

/*
    double GetDouble(FlowPtr addr)             { return *(double*)VerifyAccess(addr, sizeof(double), false); }
    void SetDouble(FlowPtr addr, double val)   { *(double*)VerifyAccess(addr, sizeof(double), true) = val; }
*/

    void Copy(FlowPtr from, FlowPtr to, size_t size) {
        if (unlikely(size == 0)) return;
        memmove(VerifyAccess(to,size,true), VerifyAccess(from,size,false), size);
    }

    void FillBytes(FlowPtr addr, int val, size_t size) {
        if (unlikely(size == 0)) return;
        memset(VerifyAccess(addr,size,true), val, size);
    }

    void SetBytes(FlowPtr addr, const void *buf, size_t size) {
        if (unlikely(size == 0)) return;
        memcpy(VerifyAccess(addr,size,true), buf, size);
    }

    void GetBytes(FlowPtr addr, void *buf, size_t size) {
        if (unlikely(size == 0)) return;
        memcpy(buf, VerifyAccess(addr,size,false), size);
    }

    const StackSlot &GetStackSlot(FlowPtr addr) {
        return *(StackSlot*)VerifyAccess(addr, STACK_SLOT_SIZE, false);
    }

    void SetStackSlot(FlowPtr addr, const StackSlot &val) {
        *(StackSlot*)VerifyAccess(addr, STACK_SLOT_SIZE, true) = val;
    }
};

#endif
