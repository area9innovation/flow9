#include "ByteMemory.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#ifdef FLOW_EMBEDDED
unsigned int MIN_HEAP_SIZE = (256 * 1048576);
#else
unsigned int MIN_HEAP_SIZE = (256 * 1048576);
#endif


#ifdef FLOW_EMBEDDED
unsigned int MAX_HEAP_SIZE = (1024 * 1048576);
#else
unsigned int MAX_HEAP_SIZE = (1024 * 1048576);
#endif

#define START_SHIFT alloc_step_size()

ByteMemory::ByteMemory(size_t size) : RangeLimit(align_down(MAX_MEMORY_SIZE, page_size()))
{
    const size_t limit = MAX_MEMORY_SIZE;
    if (limit > SIZE_MAX - 2*START_SHIFT || !reserve(limit + 2*START_SHIFT))
    {
        cerr << "Could not allocate heap address space. Error: " << errno << endl;
        abort();
    }

    Buffer = (char*)data() + START_SHIFT;
    BufferSize = 0;

    SetSize(size);
}

void ByteMemory::SetSize(size_t size)
{
    if (size > RangeLimit)
        ReportFailure(MakeFlowPtr(0), size, true);
    size = align_up(size, page_size());
    if (size > BufferSize)
        CommitRange(MakeFlowPtr(BufferSize), MakeFlowPtr(size));
    else
        DecommitRange(MakeFlowPtr(size), MakeFlowPtr(BufferSize));
    BufferSize = size;
}

void ByteMemory::CommitRange(FlowPtr start, FlowPtr end)
{
    const size_t page = page_size();
    if (start > end || FlowPtrToInt(end) > RangeLimit)
        ReportFailure(start, 0, true);
    if (start == end)
        return;

    size_t soff = align_down(FlowPtrToInt(start), page);
    size_t eoff = align_up(FlowPtrToInt(end), page);

#ifdef DEBUG_FLOW
    cerr << "Commit(" << std::hex << soff << ".." << eoff << std::dec << ")" << endl;
#endif
    
    commit(soff + START_SHIFT, eoff + START_SHIFT);
}

void ByteMemory::DecommitRange(FlowPtr start, FlowPtr end)
{
    const size_t page = page_size();
    if (start > end || FlowPtrToInt(end) > MAX_MEMORY_SIZE)
        ReportFailure(start, 0, true);
    size_t eoff = align_down(FlowPtrToInt(end), page);
    if (FlowPtrToInt(start) >= eoff)
        return;
    size_t soff = align_up(FlowPtrToInt(start), page);

#ifdef DEBUG_FLOW
    cerr << "Decommit(" << std::hex << soff << ".." << eoff << std::dec << ")" << endl;
#endif

    decommit(soff + START_SHIFT, eoff + START_SHIFT);
}

bool ByteMemory::MapFile(FlowPtr start, size_t length, FILE *file, size_t offset, bool writable)
{
    const size_t pos = FlowPtrToInt(start);
    if (pos % alloc_step_size() || pos > RangeLimit || !length || length > RangeLimit - pos)
        return false;
    return map_file(pos + START_SHIFT, length, file, offset, writable);
}

ByteMemory::~ByteMemory()
{
}

void ByteMemory::Clear() {
    DecommitRange(MakeFlowPtr(0), MakeFlowPtr(BufferSize));
    CommitRange(MakeFlowPtr(0), MakeFlowPtr(BufferSize));
}

void ByteMemory::ReportFailure(FlowPtr ptr, size_t size, bool write) {
    cerr << "Invalid ByteMemory access: " << (write ? "write to" : "read from")
         << " " << FlowPtrToInt(ptr) << ", " << size << " bytes." << endl;
    abort();
}
