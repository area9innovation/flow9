#ifndef FLOW_REPLACE_FILE_H
#define FLOW_REPLACE_FILE_H

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <string>
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
static bool publishNewFile(const char *stage, const char *dest)
{
#if defined(SYS_renameat2)
    const unsigned noReplace = 1; // Linux RENAME_NOREPLACE, including older libc headers
    if (syscall(SYS_renameat2, AT_FDCWD, stage, AT_FDCWD, dest, noReplace) == 0) return true;
    if (errno != ENOSYS && errno != EINVAL && errno != ENOTSUP) return false;
#elif defined(__APPLE__) && defined(RENAME_EXCL)
    if (__builtin_available(macOS 10.12, iOS 10.0, *)) {
        if (renamex_np(stage, dest, RENAME_EXCL) == 0) return true;
        if (errno != ENOTSUP && errno != EINVAL) return false;
    }
#endif
    if (link(stage, dest) != 0) return false;
    unlink(stage);
    return true;
}

// existing describes the regular file the caller inspected. A null pointer
// means create only, even if another writer publishes while the stage is open.
template<class Write, class Prepare>
static bool replaceRegularFile(const std::string &dest, const struct stat *existing, Write write, Prepare prepare)
{
    // A private staging directory lets open apply the ordinary creation mode and
    // the caller's umask without exposing intermediate data or changing the umask.
    std::string dir = dest.substr(0, dest.find_last_of('/') + 1) + ".flowcopyXXXXXX";
    if (!mkdtemp(&dir[0])) return false;
    std::string tmp = dir + "/data";
    struct stat stage;
    bool ready = stat(dir.c_str(), &stage) == 0;
    if (ready) {
        // Keep setgid inheritance from a shared parent, including when umask
        // removes owner permissions. Refuse if chmod silently clears setgid.
        mode_t mode = 0700 | (stage.st_mode & S_ISGID);
        ready = (stage.st_mode & 07777) == mode ||
            (chmod(dir.c_str(), mode) == 0 && stat(dir.c_str(), &stage) == 0 && (stage.st_mode & 07777) == mode);
    }
#ifdef __APPLE__
    // Darwin's inherited allow ACEs need not be masked by mode 0700. Refuse
    // such a stage; stripping its ACL could also discard child inheritance.
    if (ready) {
        acl_t acl = acl_get_file(dir.c_str(), ACL_TYPE_EXTENDED);
        if (acl) {
            acl_entry_t entry;
            ready = acl_get_entry(acl, ACL_FIRST_ENTRY, &entry) < 0 && errno == EINVAL;
            acl_free(acl);
        } else ready = errno == ENOENT;
    }
#endif
    int fd = ready ? open(tmp.c_str(), O_WRONLY | O_CREAT | O_EXCL, existing ? 0600 : 0666) : -1;
    bool ok = false;
    if (fd >= 0) {
        if (FILE *out = fdopen(fd, "wb")) {
            ok = (!existing || prepare(fd, *existing)) && write(out) && !ferror(out) && fflush(out) == 0;
            if (fclose(out) != 0) ok = false;
        } else {
            close(fd);
        }
        if (ok) ok = existing ? rename(tmp.c_str(), dest.c_str()) == 0 : publishNewFile(tmp.c_str(), dest.c_str());
    }
    if (!ok && ready) unlink(tmp.c_str());
    rmdir(dir.c_str());
    return ok;
}

template<class Write>
static bool replaceRegularFile(const std::string &dest, Write write)
{
    struct stat st;
    bool existing = stat(dest.c_str(), &st) == 0;
    if (existing ? !S_ISREG(st.st_mode) : errno != ENOENT) return false;
    return replaceRegularFile(dest, existing ? &st : NULL, write, [](int fd, const struct stat &st) {
        return fchmod(fd, st.st_mode & 0777) == 0;
    });
}

#endif
