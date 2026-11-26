#ifndef FLOW_DOWNLOAD_FILE_PERMISSIONS_H
#define FLOW_DOWNLOAD_FILE_PERMISSIONS_H

#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#if defined(__linux__)
#include <sys/xattr.h>
#include <cstring>
#include <vector>
#elif defined(__APPLE__)
#include <sys/acl.h>
#include <sys/xattr.h>
#include <TargetConditionals.h>
#endif

#if defined(__linux__)
// Use the kernel's access ACL representation; Android does not ship libacl.
// Reject unknown attributes visible to this caller (including filesystem-specific ACLs).
static bool knownDownloadAttrs(int fd)
{
    ssize_t n = flistxattr(fd, NULL, 0);
    if (n <= 0) return n == 0 || errno == ENOTSUP;
    std::vector<char> names(n);
    if (flistxattr(fd, names.data(), names.size()) != n) return false;
    for (const char *p = names.data(); p < names.data() + n; p += strlen(p) + 1) {
        if (strcmp(p, "system.posix_acl_access") && strcmp(p, "security.selinux")) return false;
    }
    return true;
}

static bool readDownloadAttr(int fd, const char *name, std::vector<char> &value)
{
    ssize_t n = fgetxattr(fd, name, NULL, 0);
    if (n < 0) return errno == ENODATA || errno == ENOTSUP;
    value.resize(n);
    return fgetxattr(fd, name, value.data(), value.size()) == n;
}
#endif

// The stage is still empty, inside a private directory. Refuse a replacement
// rather than change owners, drop an access rule, or write with a different label.
static bool prepareDownloadFile(int source, int stage, const struct stat &expected)
{
    struct stat src, dst;
    if (fstat(source, &src) || fstat(stage, &dst) || !S_ISREG(src.st_mode) ||
        src.st_dev != expected.st_dev || src.st_ino != expected.st_ino ||
        src.st_uid != dst.st_uid || src.st_gid != dst.st_gid || (src.st_mode & 07000) ||
        fchmod(stage, src.st_mode & 0777)) return false;
#if defined(__linux__)
    if (!knownDownloadAttrs(source) || !knownDownloadAttrs(stage)) return false;
    std::vector<char> label, newLabel, acl, newAcl;
    const char *security = "security.selinux", *access = "system.posix_acl_access";
    if (!readDownloadAttr(source, security, label) || !readDownloadAttr(stage, security, newLabel) ||
        label != newLabel || !readDownloadAttr(source, access, acl) || !readDownloadAttr(stage, access, newAcl)) return false;
    if (acl != newAcl) {
        if (acl.empty() ? fremovexattr(stage, access) != 0 : fsetxattr(stage, access, acl.data(), acl.size(), 0) != 0)
            return false;
    }
#elif defined(__APPLE__)
#if TARGET_OS_IPHONE
#if defined(F_GETPROTECTIONCLASS)
    int protection = fcntl(source, F_GETPROTECTIONCLASS);
    if (protection < 0 || protection != fcntl(stage, F_GETPROTECTIONCLASS)) return false;
#else
    return false;
#endif
#endif
    if (src.st_flags || flistxattr(source, NULL, 0, 0) != 0 || flistxattr(stage, NULL, 0, 0) != 0) return false;
    // Install the exact ACL, including inherited entries. A copy operation
    // that merges inheritance from the stage's parent is not equivalent.
    acl_t acl = acl_get_fd_np(source, ACL_TYPE_EXTENDED);
    if (acl) {
        bool ok = acl_set_fd_np(stage, acl, ACL_TYPE_EXTENDED) == 0;
        acl_free(acl);
        if (!ok) return false;
    } else {
        if (errno != ENOENT) return false;
        acl_t inherited = acl_get_fd_np(stage, ACL_TYPE_EXTENDED);
        if (inherited) { acl_free(inherited); return false; }
        if (errno != ENOENT) return false;
    }
#else
    return false; // No verified ACL implementation on this target.
#endif
    return fstat(stage, &dst) == 0 && (dst.st_mode & 07777) == (src.st_mode & 07777);
}

#endif
