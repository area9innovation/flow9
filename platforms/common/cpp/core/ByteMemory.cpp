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

ByteMemory::ByteMemory(size_t size)
{
    if (!reserve(MAX_MEMORY_SIZE + 2*START_SHIFT))
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
    size = align_up(size, page_size());
    if (size > BufferSize)
        CommitRange(MakeFlowPtr(BufferSize), MakeFlowPtr(size));
    else
        DecommitRange(MakeFlowPtr(size), MakeFlowPtr(BufferSize));
    BufferSize = size;
}

void ByteMemory::CommitRange(FlowPtr start, FlowPtr end)
{
    size_t soff = align_down(FlowPtrToInt(start), page_size());
    size_t eoff = align_up(FlowPtrToInt(end), page_size());

    if (eoff > MAX_MEMORY_SIZE)
    {
        cerr << "Trying to commit heap beyond hard limit: " << eoff << endl;
        abort();
    }

#ifdef DEBUG_FLOW
    cerr << "Commit(" << std::hex << soff << ".." << eoff << std::dec << ")" << endl;
#endif
    
    commit(soff + START_SHIFT, eoff + START_SHIFT);
}

void ByteMemory::DecommitRange(FlowPtr start, FlowPtr end)
{
    size_t soff = align_up(FlowPtrToInt(start), page_size());
    size_t eoff = align_down(FlowPtrToInt(end), page_size());

    if (eoff > MAX_MEMORY_SIZE)
        eoff = MAX_MEMORY_SIZE;

#ifdef DEBUG_FLOW
    cerr << "Decommit(" << std::hex << soff << ".." << eoff << std::dec << ")" << endl;
#endif

    decommit(soff + START_SHIFT, eoff + START_SHIFT);
}

bool ByteMemory::MapFile(FlowPtr start, size_t length, std::string filename, size_t offset, bool writable)
{
    size_t pos = FlowPtrToInt(start);
    if (align_down(pos, alloc_step_size()) != pos)
    {
        cerr << "Could not map file at non-page address: " << pos << endl;
        return false;
    }
    if (align_up(pos+length, page_size()) > MAX_MEMORY_SIZE)
    {
        cerr << "Could not map file at too high address: (" << pos << ".." << (pos+length) << ")" << endl;
        return false;
    }

    return map_file(pos + START_SHIFT, length, filename, offset, writable);
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
