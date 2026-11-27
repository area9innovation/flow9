#ifndef FLOW_SCOPED_FD_H
#define FLOW_SCOPED_FD_H

#include <unistd.h>

class ScopedFd {
    int fd;
public:
    explicit ScopedFd(int fd = -1) : fd(fd) {}
    ScopedFd(const ScopedFd &) = delete;
    ScopedFd &operator=(const ScopedFd &) = delete;
    ~ScopedFd() { reset(); }
    int get() const { return fd; }
    int release() { int old = fd; fd = -1; return old; }
    void reset(int next = -1) { if (fd >= 0) close(fd); fd = next; }
};

#endif
