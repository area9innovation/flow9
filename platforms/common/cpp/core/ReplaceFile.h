#ifndef FLOW_REPLACE_FILE_H
#define FLOW_REPLACE_FILE_H

#include "ScopedFd.h"
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <random>
#include <stdexcept>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef __linux__
#include <sys/syscall.h>
#endif
#ifdef __APPLE__
#include <sys/acl.h>
#endif

// Publish a closed stage without overwriting a directory entry. Prefer rename
// when available (some filesystems do not support hard links).
static bool publishNewFile(int from, const char *stage, int to, const char *dest)
{
#if defined(SYS_renameat2)
    const unsigned noReplace = 1; // Linux RENAME_NOREPLACE, including older libc headers
    if (syscall(SYS_renameat2, from, stage, to, dest, noReplace) == 0) return true;
    if (errno != ENOSYS && errno != EINVAL && errno != ENOTSUP) return false;
#elif defined(__APPLE__) && defined(RENAME_EXCL)
    if (__builtin_available(macOS 10.12, iOS 10.0, *)) {
        if (renameatx_np(from, stage, to, dest, RENAME_EXCL) == 0) return true;
        if (errno != ENOTSUP && errno != EINVAL) return false;
    }
#endif
    if (linkat(from, stage, to, dest, 0) != 0) return false;
    unlinkat(from, stage, 0);
    return true;
}

// There is no POSIX mkdtempat. Always create exclusively with mode 0700;
// collisions never authorize opening or removing an existing directory.
static bool makeStageDirectory(int base, std::string &dir)
{
    if (base == AT_FDCWD) {
        dir += ".flowcopyXXXXXX";
        return mkdtemp(&dir[0]) != NULL;
    }
    const std::string prefix = dir + ".flowcopy";
    try {
        std::random_device random;
        for (int i = 0; i < 128; ++i) {
            dir = prefix + std::to_string(random());
            if (mkdirat(base, dir.c_str(), 0700) == 0) return true;
            if (errno != EEXIST) break;
        }
    } catch (const std::runtime_error &) { /* no random source */ }
    return false;
}

// Open a newly created private directory, including under an
// owner-restrictive umask. Only use the opened fd for entries inside it.
static bool openStageDirectory(int base, const std::string &dir, ScopedFd &directory)
{
    struct stat stage;
    bool ready = fstatat(base, dir.c_str(), &stage, AT_SYMLINK_NOFOLLOW) == 0 && S_ISDIR(stage.st_mode);
    if (ready) {
        // Keep setgid inheritance from a shared parent, including when umask
        // removes owner permissions. Refuse if chmod silently clears setgid.
        mode_t mode = 0700 | (stage.st_mode & S_ISGID);
        ready = (stage.st_mode & 07777) == mode ||
            fchmodat(base, dir.c_str(), mode, AT_SYMLINK_NOFOLLOW) == 0;
    }
    directory.reset(ready ? openat(base, dir.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) : -1);
    struct stat opened;
    ready = directory.get() >= 0 && fstat(directory.get(), &opened) == 0 &&
        opened.st_dev == stage.st_dev && opened.st_ino == stage.st_ino &&
        (opened.st_mode & 07777) == (0700 | (stage.st_mode & S_ISGID));
#ifdef __APPLE__
    // Darwin's inherited allow ACEs need not be masked by mode 0700. Refuse
    // such a stage; stripping its ACL could also discard child inheritance.
    if (ready) {
        acl_t acl = acl_get_fd_np(directory.get(), ACL_TYPE_EXTENDED);
        if (acl) {
            acl_entry_t entry;
            ready = acl_get_entry(acl, ACL_FIRST_ENTRY, &entry) < 0 && errno == EINVAL;
            acl_free(acl);
        } else ready = errno == ENOENT;
    }
#endif
    return ready;
}

enum class StageResult { Published, Unavailable, Failed };

// Unavailable: staging or metadata preservation was not possible. A payload
// write/flush/close failure is terminal; never retry it against the original.
template<class Write, class Prepare>
static StageResult replaceRegularFile(int base, const std::string &dest, const struct stat *existing, Write write, Prepare prepare)
{
    // Let open apply the ordinary creation mode and umask inside a private stage.
    std::string dir = dest.substr(0, dest.find_last_of('/') + 1);
    if (!makeStageDirectory(base, dir)) return StageResult::Unavailable;
    ScopedFd directory;
    bool ready = openStageDirectory(base, dir, directory);
    int fd = ready ? openat(directory.get(), "data", O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, existing ? 0600 : 0666) : -1;
    StageResult result = StageResult::Unavailable;
    if (fd >= 0) {
        if (FILE *out = fdopen(fd, "wb")) {
            bool prepared = !existing || prepare(fd, *existing);
            bool written = prepared && write(out) && !ferror(out) && fflush(out) == 0;
            if (fclose(out) != 0) written = false;
            if (prepared) result = StageResult::Failed;
            if (written) {
                if (!existing) {
                    if (publishNewFile(directory.get(), "data", base, dest.c_str())) result = StageResult::Published;
                } else if (renameat(directory.get(), "data", base, dest.c_str()) == 0) {
                    result = StageResult::Published;
                } else if (errno == EACCES || errno == EPERM || errno == EBUSY || errno == ENOTSUP) {
                    result = StageResult::Unavailable;
                }
            }
        } else {
            close(fd);
        }
        if (result != StageResult::Published) unlinkat(directory.get(), "data", 0);
    }
    unlinkat(base, dir.c_str(), AT_REMOVEDIR);
    return result;
}

#endif
