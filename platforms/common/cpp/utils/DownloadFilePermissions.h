#ifndef FLOW_DOWNLOAD_FILE_PERMISSIONS_H
#define FLOW_DOWNLOAD_FILE_PERMISSIONS_H

#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#if defined(__linux__)
#include <sys/vfs.h>
#include <sys/ioctl.h>
#include <linux/fs.h>
#include <linux/magic.h>
#include <sys/xattr.h>
#include <cstring>
#include <vector>

// Unknown and network filesystems can have server-side ACLs that are not
// represented by the POSIX mode or xattrs. Update their existing object.
static bool canStageDownload(int fd)
{
    struct statfs fs;
    if (fstatfs(fd, &fs) != 0) return false;
    return fs.f_type == EXT4_SUPER_MAGIC || fs.f_type == TMPFS_MAGIC;
}

// Inode flags (e.g. nodump) and project IDs are not xattrs. Do not
// replace a file with an ordinary stage if it would change those settings.
static bool matchingInodeSettings(int source, int stage)
{
    int src = 0, dst = 0;
    if (ioctl(source, FS_IOC_GETFLAGS, &src) == 0) {
        if (ioctl(stage, FS_IOC_GETFLAGS, &dst) || src != dst) return false;
    } else if (errno != ENOTTY && errno != ENOTSUP) return false;
#ifdef FS_IOC_FSGETXATTR
    struct fsxattr a = {}, b = {};
    if (ioctl(source, FS_IOC_FSGETXATTR, &a) == 0) {
        if (ioctl(stage, FS_IOC_FSGETXATTR, &b) || a.fsx_projid != b.fsx_projid ||
            a.fsx_xflags != b.fsx_xflags || a.fsx_extsize != b.fsx_extsize) return false;
    } else if (errno != ENOTTY && errno != ENOTSUP) return false;
#endif
    return true;
}

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

// The stage is still empty. A mismatch selects an ordinary in-place write.
static bool prepareDownloadFile(int source, int stage, const struct stat &expected)
{
    struct stat src, dst;
    if (fstat(source, &src) || fstat(stage, &dst) || !S_ISREG(src.st_mode) || src.st_nlink != 1 ||
        src.st_dev != expected.st_dev || src.st_ino != expected.st_ino ||
        src.st_uid != dst.st_uid || src.st_gid != dst.st_gid || (src.st_mode & 07000) ||
        fchmod(stage, src.st_mode & 0777)) return false;
    if (!matchingInodeSettings(source, stage) || !knownDownloadAttrs(source) || !knownDownloadAttrs(stage)) return false;
    std::vector<char> label, newLabel, acl, newAcl;
    const char *security = "security.selinux", *access = "system.posix_acl_access";
    if (!readDownloadAttr(source, security, label) || !readDownloadAttr(stage, security, newLabel) ||
        label != newLabel || !readDownloadAttr(source, access, acl) || !readDownloadAttr(stage, access, newAcl)) return false;
    if (acl != newAcl) {
        if (acl.empty() ? fremovexattr(stage, access) != 0 : fsetxattr(stage, access, acl.data(), acl.size(), 0) != 0)
            return false;
    }
    return fstat(stage, &dst) == 0 && (dst.st_mode & 07777) == (src.st_mode & 07777);
}
#endif // __linux__

#endif
