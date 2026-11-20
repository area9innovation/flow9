#pragma once

#include <cerrno>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <random>
#include <stdexcept>
#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#else
#include <cstdlib>
#include <sys/stat.h>
#include <unistd.h>
#endif

namespace flow {

#ifdef _WIN32
inline std::FILE* openCopyStage(const std::filesystem::path& path) {
    int fd = _wopen(path.c_str(), _O_CREAT | _O_EXCL | _O_WRONLY | _O_BINARY, _S_IREAD | _S_IWRITE);
    if (fd < 0) return nullptr;
    auto out = _fdopen(fd, "wb");
    if (!out) { _close(fd); _wunlink(path.c_str()); }
    return out;
}
#endif

inline bool stagedCopy(const std::filesystem::path& src, const std::filesystem::path& dst) {
    namespace fs = std::filesystem;
    std::error_code ec;
    if (dst.filename().empty() || !fs::is_regular_file(src, ec)) return false;
    auto status = fs::status(dst, ec);
    if (ec && ec != std::errc::no_such_file_or_directory) return false;
    bool existing = fs::exists(status);
    if (existing && (!fs::is_regular_file(status) || fs::equivalent(src, dst, ec) || ec)) return false;
    std::ifstream in(src, std::ios::binary);
    if (!in) return false;

    fs::path tmp;
    std::FILE* out = nullptr;
    // Even an absent destination must never be chosen as its own stage.
    const char* prefix = dst.filename().native().front() == '.' ? "_flowcopy-" : ".flowcopy-";
#ifdef _WIN32
    try {
        std::random_device random;
        for (int i = 0; i < 16 && !out; ++i) {
            tmp = dst.parent_path() / (prefix + std::to_string(random()));
            out = openCopyStage(tmp);
            if (!out && errno != EEXIST) return false;
        }
    } catch (const std::runtime_error&) { return false; }
#else
    auto dir = (dst.parent_path() / (std::string(prefix) + "XXXXXX")).string();
    if (!::mkdtemp(dir.data())) return false;
    struct RemoveStage {
        const std::string& name;
        const fs::path& file;
        ~RemoveStage() {
            if (!file.empty()) ::unlink(file.c_str());
            ::rmdir(name.c_str());
        }
    } cleanup{dir, tmp};
    struct stat st;
    if (::chmod(dir.c_str(), 0700) != 0 || ::stat(dir.c_str(), &st) != 0 ||
        (st.st_mode & 07777) != 0700) return false;
    tmp = fs::path(dir) / "data";
    out = std::fopen(tmp.c_str(), "wb"); // creation mode is filtered by the caller's umask
#endif
    if (!out) return false;
    char buf[16384];
    bool ok = true;
    while (ok && in) {
        in.read(buf, sizeof(buf));
        auto n = static_cast<size_t>(in.gcount());
        ok = std::fwrite(buf, 1, n, out) == n;
    }
    ok = ok && in.eof() && !in.bad() && !std::ferror(out) && std::fflush(out) == 0;
    in.clear();
    in.close();
    if (std::fclose(out) != 0 || in.fail()) ok = false;
#ifndef _WIN32
    if (ok && existing) {
        fs::permissions(tmp, status.permissions() & fs::perms::all, ec);
        ok = !ec;
    }
#endif
    if (ok) {
        fs::rename(tmp, dst, ec);
        if (!ec) return true;
    }
#ifdef _WIN32
    fs::remove(tmp, ec);
#endif
    return false;
}

} // namespace flow
