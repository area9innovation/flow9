#ifndef _MEMORY_AREA_H_
#define _MEMORY_AREA_H_

#include <memory.h>
#include <stdint.h>
#include "CommonTypes.h"

#ifdef _MSC_VER
    #define _INLINE_WRAP(content) __forceinline content
#else
    #define _INLINE_WRAP(content) content __attribute__((always_inline))
#endif

inline size_t align_up(size_t size, size_t page) {
    return ((size+page-1) & ~(page-1));
}
inline size_t align_down(size_t size, size_t page) {
    return (size & ~(page-1));
}

class MemoryArea {
protected:
    uint8_t *buf;
    size_t length;

    friend class FlowJitProgram;

public:
    MemoryArea();
    ~MemoryArea();

    uint8_t *data() { return buf; }
    size_t size() { return length; }

    bool reserve(size_t length);
    void unmap();

    void commit(size_t start, size_t end);
    void decommit(size_t start, size_t end);

    void executable(size_t start, size_t end, bool enable = true);
    void readonly(size_t start, size_t end, bool enable = true);

    bool map_file(size_t off, size_t length, std::string filename, size_t offset, bool writable);

    static size_t page_size();
    static size_t alloc_step_size();
};

template<class T>
class FlowVMemStack : protected MemoryArea
{
    T *pos, *limit;

    friend class FlowJitProgram;

    void grow(T *new_pos) {
        while (new_pos > limit)
            limit += (limit - data());

        commit(0, ((uint8_t*)limit) - buf);
    }

public:
    FlowVMemStack() { pos = limit = NULL; }

    T *data() { return (T*)buf; }
    const T *data() const { return (const T*)buf; }

    void allocate(unsigned size) {
        MemoryArea::reserve(size * sizeof(T));
        unsigned cnt = (unsigned) page_size() / sizeof(T);
        pos = data();
        limit = pos+cnt;
        commit(0, cnt * sizeof(T));
    }

    void readonly(unsigned size, bool enable) {
        MemoryArea::readonly(0, size*sizeof(StackSlot), enable);
    }

    void swap(FlowVMemStack<T> &other) {
        std::swap(buf, other.buf);
        std::swap(length, other.length);
        std::swap(pos, other.pos);
        std::swap(limit, other.limit);
    }

    void clear() {
        pos = data();
    }

    void resize(unsigned size) {
        pos = data()+size;
        if (pos > limit) grow(pos);
    }
    void reserve(unsigned size) {
        if (pos+size > limit) grow(pos+size);
    }

    bool empty() const { return pos == data(); }
    unsigned size() const { return pos-data(); }
    unsigned capacity() const { return limit-data(); }

    T &operator[] (unsigned i) { return data()[i]; }
    T &top(unsigned off = 0) { return pos[-1-intptr_t(off)]; }
    const T &operator[] (unsigned i) const { return data()[i]; }
    const T &top(unsigned off = 0) const { return pos[-1-intptr_t(off)]; }

    _INLINE_WRAP(T *push_ptr(unsigned sz = 1)) {
        T *rv = pos;
        pos += sz;
        if (pos > limit) grow(pos);
        return rv;
    }

    _INLINE_WRAP(T *pop_ptr(unsigned sz = 1)) {
        pos -= sz;
        return pos;
    }

    _INLINE_WRAP(void push_back(const T &v)) { *push_ptr() = v; }
    _INLINE_WRAP(T &pop()) { return *pop_ptr(); }
};

class StaticBuffer {
    static size_t total_mem, total_maps;

    struct Data {
        uint8_t *ptr;
        size_t size;
        bool mapped;

        Data(uint8_t *ptr, size_t size, bool mapped);
        ~Data();
    };
    shared_ptr<Data> p;

    bool map_file(FILE *f, size_t size, bool writable);

public:
    bool isNull() { return !p; }

    void reset() { p.reset(); }

    static size_t total_memory() { return total_mem; }
    static size_t total_mapped() { return total_maps; }

    const uint8_t *data() { return p ? p->ptr : NULL; }
    size_t size() { return p ? p->size : 0; }

    uint8_t *writable_data() { return p ? p->ptr : NULL; }

    static const size_t AUTO_SIZE = size_t(-1);

    bool load_file(const std::string &fname, size_t size = AUTO_SIZE);
    bool allocate(size_t size, bool use_tmpfile = false);
};


#endif
