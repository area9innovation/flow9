#include "MemoryArea.h"

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <limits>
#include <sys/types.h>

using std::min;
#ifdef _WIN32
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
#ifdef _WIN32
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
#ifdef _WIN32
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
#ifdef _WIN32
#define MAP_FAILURE_RETVAL NULL
#else
#define MAP_FAILURE_RETVAL MAP_FAILED
#endif

/* Reserve address space without allocating memory if possible */
static void *ReserveVirtualMemory(size_t size)
{
#ifdef _WIN32
    return VirtualAlloc(NULL, size, MEM_RESERVE, PAGE_NOACCESS);
#else
    return mmap(NULL, size, PROT_NONE, MAP_ANON | MAP_PRIVATE, 0, 0);
#endif
}

/* Free a mapping produced by ReserveVirtualMemory */
static void UnmapMemory(void *ptr, size_t size)
{
#ifdef _WIN32
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

#ifdef _WIN32
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

#ifdef _WIN32
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

#ifdef _WIN32
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

#ifdef _WIN32
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
#ifdef _WIN32
    UnmapViewOfFile(ptr);
#else
    UnmapMemory(ptr, size);
#endif
}

/* Map file to memory */
static void *MapFileToMemory(FILE *file, size_t size, bool writable)
{
    if (!file || !size)
        return MAP_FAILURE_RETVAL;
    int fd = fileno(file);
    if (fd < 0)
        return MAP_FAILURE_RETVAL;

#ifdef _WIN32
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

    struct stat info;
    if (fstat(fd, &info) != 0 || !S_ISREG(info.st_mode) || info.st_size < 0 ||
        uintmax_t(size) > uintmax_t(info.st_size))
        return MAP_FAILURE_RETVAL;

    return mmap(NULL, size, perms, MAP_SHARED, fd, 0);
#endif
}

/* Map at a specific address */
static bool MapFileToMemory(void *where, size_t length, FILE *file, size_t offset, bool writable)
{
#ifdef _WIN32
    // can't be done
    return false;
#else
    if (!file || uintmax_t(offset) > uintmax_t(std::numeric_limits<off_t>::max()))
        return false;
    int fd = fileno(file);
    if (fd < 0)
        return false;

    struct stat info;
    if (fstat(fd, &info) != 0 || !S_ISREG(info.st_mode) || info.st_size < 0 ||
        uintmax_t(offset) > uintmax_t(info.st_size) ||
        uintmax_t(length) > uintmax_t(info.st_size) - offset)
        return false;

    int perms = writable ? (PROT_READ | PROT_WRITE) : PROT_READ;
    int mode = writable ? MAP_PRIVATE : MAP_SHARED;

    void *rv = mmap(where, length, perms, mode | MAP_FIXED, fd, static_cast<off_t>(offset));

    if (rv != where)
    {
        cerr << "Could not map file (" << std::hex << uintptr_t(where) << ".." << (uintptr_t(where)+length) << std::dec << "): error " << errno << endl;
        return false;
    }
#ifdef DEBUG_FLOW
    cerr << "MapFile(" << std::hex << where << "," << length << std::dec << ")" << endl;
#endif
    return true;
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

    const size_t step = AllocStepSize();
    if (!newsz || newsz > align_down(SIZE_MAX, step))
        return false;

    newsz = align_up(newsz, step);
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
    length = 0;
}

void MemoryArea::check_range(size_t soff, size_t eoff) const
{
    if (!buf || soff > eoff || eoff > length) {
        cerr << "Invalid MemoryArea range: " << soff << ".." << eoff << endl;
        abort();
    }
}

void MemoryArea::commit(size_t soff, size_t eoff)
{
    check_range(soff, eoff);
    if (soff != eoff)
        CommitMemory(buf + soff, buf + eoff);
}

void MemoryArea::decommit(size_t soff, size_t eoff)
{
    check_range(soff, eoff);
    if (soff != eoff)
        DecommitMemory(buf + soff, buf + eoff);
}

void MemoryArea::executable(size_t soff, size_t eoff, bool enable)
{
    check_range(soff, eoff);
    if (soff != eoff)
        MakeExecutable(buf + soff, buf + eoff, enable);
}

void MemoryArea::readonly(size_t soff, size_t eoff, bool enable)
{
    check_range(soff, eoff);
    if (soff != eoff)
        MakeReadonly(buf + soff, buf + eoff, enable);
}

bool MemoryArea::map_file(size_t off, size_t len, std::string filename, size_t offset, bool writable)
{
    FILE *file = fopen(filename.c_str(), "rb");
    if (!file)
        return false;

    bool ok = map_file(off, len, file, offset, writable);
    fclose(file);
    return ok;
}

bool MemoryArea::map_file(size_t off, size_t len, FILE *file, size_t offset, bool writable)
{
    // length is page-aligned, so rounding a valid end up stays in the reservation.
    if (!buf || !len || off > length || len > length - off ||
        off % PageSize() || offset % PageSize())
        return false;
    return MapFileToMemory(buf + off, len, file, offset, writable);
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
        long pos = fseek(file, 0, SEEK_END) == 0 ? ftell(file) : -1;

        if (pos < 0 || fseek(file, 0, SEEK_SET) != 0) {
            fclose(file);
            return false;
        }

        size = pos;
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
        if (!ptr && size) {
            fclose(file);
            return false;
        }

        for (size_t pos = 0; pos < size; ) {
            size_t delta = fread(ptr+pos, 1, size-pos, file);
            if (!delta) {
                if (auto_size || ferror(file))
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
                ok = fflush(file) == 0 && map_file(file, size, true);
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

    uint8_t *mem = (uint8_t*)malloc(size);
    if (!mem && size > 0)
        return false;

    p = shared_ptr<Data>(new Data(mem, size, false));

#ifdef DEBUG_FLOW
    cerr << "StaticBuffer alloc; total " << total_mem << " heap, " << total_maps << " mmap." << endl;
#endif

    return true;
}
