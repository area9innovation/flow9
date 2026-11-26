#ifndef FLOW_REPLACE_FILE_H
#define FLOW_REPLACE_FILE_H

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef __APPLE__
#include <sys/acl.h>
#endif

// POSIX: publish a regular file only after its writer, flush and close succeed.
template<class Write, class Prepare>
static bool replaceRegularFile(const std::string &dest, Write write, Prepare prepare)
{
    struct stat st;
    bool existing = stat(dest.c_str(), &st) == 0;
    if (existing ? !S_ISREG(st.st_mode) : errno != ENOENT) return false;

    // A private staging directory lets open apply the ordinary creation mode and
    // the caller's umask without exposing intermediate data or changing the umask.
    std::string dir = dest.substr(0, dest.find_last_of('/') + 1) + ".flowcopyXXXXXX";
    if (!mkdtemp(&dir[0])) return false;
    std::string tmp = dir + "/data";
    struct stat stage;
    bool ready = chmod(dir.c_str(), 0700) == 0 && stat(dir.c_str(), &stage) == 0 &&
                 (stage.st_mode & 07777) == 0700;
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
            ok = (!existing || prepare(fd, st)) && write(out) && !ferror(out) && fflush(out) == 0;
            if (fclose(out) != 0) ok = false;
        } else {
            close(fd);
        }
        if (ok) ok = rename(tmp.c_str(), dest.c_str()) == 0;
    }
    if (!ok && ready) unlink(tmp.c_str());
    rmdir(dir.c_str());
    return ok;
}

template<class Write>
static bool replaceRegularFile(const std::string &dest, Write write)
{
    return replaceRegularFile(dest, write, [](int fd, const struct stat &st) {
        return fchmod(fd, st.st_mode & 0777) == 0;
    });
}

#endif
