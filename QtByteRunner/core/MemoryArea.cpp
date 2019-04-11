#include "MemoryArea.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/types.h>

using std::min;
#ifdef _MSC_VER
#include <windows.h>
#include <io.h>
#else
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#endif

static size_t PageSize()
{
#ifdef _MSC_VER
    SYSTEM_INFO info;
    GetSystemInfo(&info);

    return info.dwPageSize;
#else
#ifdef PAGE_SIZE
    return PAGE_SIZE;
#else
    return getpagesize();
#endif
#endif
}

static size_t AllocStepSize()
{
#ifdef _MSC_VER
    SYSTEM_INFO info;
    GetSystemInfo(&info);

    return info.dwAllocationGranularity;
#else
#ifdef PAGE_SIZE
    return PAGE_SIZE;
#else
    return getpagesize();
#endif
#endif
}
#ifdef _MSC_VER
#define MAP_FAILURE_RETVAL NULL
#else
#define MAP_FAILURE_RETVAL MAP_FAILED
#endif

/* Reserve address space without allocating memory if possible */
static void *ReserveVirtualMemory(size_t size)
{
#ifdef _MSC_VER
    return VirtualAlloc(NULL, size, MEM_RESERVE, PAGE_NOACCESS);
#else
    return mmap(NULL, size, PROT_NONE, MAP_ANON | MAP_PRIVATE, 0, 0);
#endif
}

/* Free a mapping produced by ReserveVirtualMemory */
static void UnmapMemory(void *ptr, size_t size)
{
#ifdef _MSC_VER
    VirtualFree(ptr, 0, MEM_RELEASE);
#else
    munmap(ptr, size);
#endif
}

/* Allocate actual memory within a range produced by ReserveVirtualMemory */
static void CommitMemory(void *start, void *end)
{
    uintptr_t saddr = align_down(uintptr_t(start), PageSize());
    uintptr_t eaddr = align_up(uintptr_t(end), PageSize());

    if (saddr >= eaddr)
        return;

#ifdef _MSC_VER
    if (VirtualAlloc((void*)saddr, eaddr-saddr, MEM_COMMIT, PAGE_READWRITE) == NULL)
#else
    if (mprotect((void*)saddr, eaddr-saddr, PROT_READ | PROT_WRITE) != 0)
#endif
    {
        cerr << "Could not commit heap (" << std::hex << saddr << ".." << eaddr << "): error " << std::dec << errno << endl;
        abort();
    }
}

/* Free a previously committed range again */
static void DecommitMemory(void *start, void *end)
{
    uintptr_t saddr = align_up(uintptr_t(start), PageSize());
    uintptr_t eaddr = align_down(uintptr_t(end), PageSize());

    if (saddr >= eaddr)
        return;

#ifdef _MSC_VER
    if (!VirtualFree((void*)saddr, eaddr-saddr, MEM_DECOMMIT))
#else
    // Remap the area to purge all dirty pages
    void *rv = mmap((void*)saddr, eaddr-saddr, PROT_NONE, MAP_ANON | MAP_PRIVATE | MAP_FIXED, 0, 0);

    if (rv != (void*)saddr)
#endif
    {
        cerr << "Could not decommit heap (" << std::hex << saddr << ".." << eaddr << "): error " << std::dec << errno << endl;
        abort();
    }
}

/* Change between executable and writable */
static void MakeExecutable(void *start, void *end, bool enable)
{
    uintptr_t saddr = align_down(uintptr_t(start), PageSize());
    uintptr_t eaddr = align_up(uintptr_t(end), PageSize());

    if (saddr >= eaddr)
        return;

#ifdef _MSC_VER
    DWORD old;

    if (!VirtualProtect((void*)saddr, eaddr-saddr, enable ? PAGE_EXECUTE_READ : PAGE_READWRITE, &old))
#else
    if (mprotect((void*)saddr, eaddr-saddr, PROT_READ | (enable ? PROT_EXEC : PROT_WRITE)) != 0)
#endif
    {
        cerr << "Could not change executable status (" << std::hex << saddr << ".." << eaddr << "): error " << std::dec << errno << endl;
        abort();
    }
}

/* Change between readonly and writable */
static void MakeReadonly(void *start, void *end, bool enable)
{
    uintptr_t saddr = align_down(uintptr_t(start), PageSize());
    uintptr_t eaddr = align_up(uintptr_t(end), PageSize());

    if (saddr >= eaddr)
        return;

#ifdef _MSC_VER
    DWORD old;

    if (!VirtualProtect((void*)saddr, eaddr-saddr, enable ? PAGE_READONLY : PAGE_READWRITE, &old))
#else
    if (mprotect((void*)saddr, eaddr-saddr, PROT_READ | (enable ? 0 : PROT_WRITE)) != 0)
#endif
    {
        cerr << "Could not change readonly status (" << std::hex << saddr << ".." << eaddr << "): error " << std::dec << errno << endl;
        abort();
    }
}

/* Free a mapping produced by MapFileToMemory */
static void UnmapFile(void *ptr, size_t size)
{
#ifdef _MSC_VER
    UnmapViewOfFile(ptr);
#else
    UnmapMemory(ptr, size);
#endif
}

/* Map file to memory */
static void *MapFileToMemory(FILE *file, size_t size, bool writable)
{
    int fd = fileno(file);

#ifdef _MSC_VER
    HANDLE hMapFile = CreateFileMapping(writable ? INVALID_HANDLE_VALUE : (HANDLE)_get_osfhandle(fd),
                                        NULL,
                                        writable ? PAGE_READWRITE : PAGE_READONLY,
                                        0,
                                        size,
                                        NULL);

    if (hMapFile == NULL) {
        cerr << "Could not create file mapping object. Error: " << GetLastError() << endl;
        return NULL;
    }

    LPVOID pBuf = MapViewOfFile(hMapFile,
                                writable ? FILE_MAP_WRITE : FILE_MAP_READ,
                                0,
                                0,
                                size);

    if (pBuf == NULL) {
        cerr << "Could not map view of file. Error: " << GetLastError() << endl;
    }

    CloseHandle(hMapFile);

    return (void *)pBuf;
#else

    int perms = PROT_READ;
    if (writable) perms |= PROT_WRITE;

    return mmap(NULL, size, perms, MAP_SHARED, fd, 0);
#endif
}

/* Map at a specific address */
static bool MapFileToMemory(void *where, size_t length, std::string filename, size_t offset, bool writable)
{
#ifdef _MSC_VER
    // can't be done
    return false;
#else
    FILE *file = fopen(filename.c_str(), "rb");
    int fd = fileno(file);
    if (fd < 0)
        return false;

    int perms = writable ? (PROT_READ | PROT_WRITE) : PROT_READ;
    int mode = writable ? MAP_PRIVATE : MAP_SHARED;

    void *rv = mmap(where, length, perms, mode | MAP_FIXED, fd, offset);

    if (rv != where)
    {
        cerr << "Could not map file (" << std::hex << uintptr_t(where) << ".." << (uintptr_t(where)+length) << std::dec << "): error " << errno << endl;
        fclose(file);
        return false;
    }
    else
    {
#ifdef DEBUG_FLOW
        cerr << "MapFile(" << std::hex << where << "," << length << std::dec << ",\"" << filename << "\")" << endl;
#endif
        fclose(file);
        return true;
    }
#endif
}

MemoryArea::MemoryArea()
{
    buf = NULL;
    length = 0;
}

MemoryArea::~MemoryArea()
{
    if (buf)
        UnmapMemory(buf, length);
}

size_t MemoryArea::page_size()
{
    return PageSize();
}

size_t MemoryArea::alloc_step_size()
{
    return AllocStepSize();
}

bool MemoryArea::reserve(size_t newsz)
{
    if (buf)
        return newsz <= length;

    newsz = align_up(newsz, AllocStepSize());
    void *rv = ReserveVirtualMemory(newsz);

    if (rv == MAP_FAILURE_RETVAL || rv == NULL)
        return false;

    buf = (uint8_t*)rv;
    length = newsz;
    return true;
}

void MemoryArea::unmap()
{
    if (buf)
        UnmapMemory(buf, length);

    buf = NULL;
}

void MemoryArea::commit(size_t soff, size_t eoff)
{
    assert(buf && soff < length && eoff <= length);

    CommitMemory(buf + soff, buf + eoff);
}

void MemoryArea::decommit(size_t soff, size_t eoff)
{
    assert(buf && soff < length && eoff <= length);

    DecommitMemory(buf + soff, buf + eoff);
}

void MemoryArea::executable(size_t soff, size_t eoff, bool enable)
{
    assert(buf && soff < length && eoff <= length);

    MakeExecutable(buf + soff, buf + eoff, enable);
}

void MemoryArea::readonly(size_t soff, size_t eoff, bool enable)
{
    assert(buf && soff < length && eoff <= length);

    MakeReadonly(buf + soff, buf + eoff, enable);
}

bool MemoryArea::map_file(size_t off, size_t len, std::string filename, size_t offset, bool writable)
{
    assert(buf && off < length && off+len <= length);

    return MapFileToMemory(buf + off, len, filename, offset, writable);
}

size_t StaticBuffer::total_maps = 0;
size_t StaticBuffer::total_mem = 0;

StaticBuffer::Data::Data(uint8_t *ptr, size_t size, bool mapped)
    : ptr(ptr), size(size), mapped(mapped)
{
    if (mapped)
        total_maps += size;
    else
        total_mem += size;
}

StaticBuffer::Data::~Data()
{
    if (mapped)
        total_maps -= size;
    else
        total_mem -= size;

#ifdef DEBUG_FLOW
    cerr << "StaticBuffer " << (mapped?"unmap":"free")
         << "; total " << total_mem << " heap, " << total_maps << " mmap." << endl;
#endif

    if (mapped)
        UnmapFile(ptr, size);
    else
        free(ptr);
}

bool StaticBuffer::map_file(FILE *file, size_t size, bool writable)
{
    void *rv = MapFileToMemory(file, size, writable);

    if (rv == MAP_FAILURE_RETVAL)
        return false;

    p = shared_ptr<Data>(new Data((uint8_t*)rv, size, true));
    return true;
}


bool StaticBuffer::load_file(const std::string &fname, size_t size)
{
    FILE *file = fopen(fname.c_str(), "rb");
    if (!file)
        return false;

    bool auto_size = (size == AUTO_SIZE);

    if (auto_size)
    {
        fseek(file, 0, SEEK_END);
        long pos = ftell(file);

        if (pos < 0) {
            fclose(file);
            return false;
        }

        size = pos;
        rewind(file);
    }

    bool ok;
    if (size > 64*1024)
    {
        ok = map_file(file, size, false);
    }
    else
    {
        ok = true;
        uint8_t *ptr = (uint8_t*)malloc(size);

        for (size_t pos = 0; pos < size; ) {
            size_t delta = fread(ptr+pos, 1, size-pos, file);
            if (!delta) {
                if (auto_size)
                    ok = false;
                else
                    memset(ptr+pos, 0, size-pos);
                break;
            } else {
                pos += delta;
            }
        }

        if (ok)
            p = shared_ptr<Data>(new Data(ptr, size, false));
        else
            free(ptr);
    }

#ifdef DEBUG_FLOW
    if (ok)
        cerr << "StaticBuffer load; total " << total_mem << " heap, " << total_maps << " mmap." << endl;
#endif

    fclose(file);
    return ok;
}

bool StaticBuffer::allocate(size_t size, bool use_tmpfile)
{
    (void)&use_tmpfile;

    if (use_tmpfile && size > 0)
    {
        std::string fname;
        FILE *file = MakeTemporaryFile(&fname);

        if (file)
        {
            bool ok = true;

            // Fill the file
            char tmp[64*1024];
            memset(tmp, 0, sizeof(tmp));

            for (size_t pos = 0; pos < size && ok; ) {
                size_t delta = fwrite(tmp, 1, min(size-pos, (size_t)sizeof(tmp)), file);
                if (!delta)
                    ok = false;
                pos += delta;
            }

            // Map it
            if (ok)
            {
                fflush(file);
                ok = map_file(file, size, true);
            }

            // And delete it - assuming POSIX deletion semantics
            fclose(file);
            unlink(fname.c_str());

#ifdef DEBUG_FLOW
            cerr << "StaticBuffer tmpalloc; total " << total_mem << " heap, " << total_maps << " mmap." << endl;
#endif

            return ok;
        }
    }

    p = shared_ptr<Data>(new Data((uint8_t*)malloc(size), size, false));

#ifdef DEBUG_FLOW
    cerr << "StaticBuffer alloc; total " << total_mem << " heap, " << total_maps << " mmap." << endl;
#endif

    return true;
}
