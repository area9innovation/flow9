#include "AbstractHttpSupport.h"

#include "core/RunnerMacros.h"

#include <stdlib.h>
#include <fstream>
#include <sstream>
#ifndef _WIN32
#include "core/ReplaceFile.h"
#include "DownloadFilePermissions.h"
#else
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <atomic>
#endif

// 
ResponseEncoding defaultResponseEncoding = ResponseEncodingAuto;

AbstractHttpSupport::AbstractHttpSupport(ByteCodeRunner *owner) : NativeMethodHost(owner)
{
    next_http_request = 1;
}

HttpRequest *AbstractHttpSupport::getRequestById(int id)
{
    T_active_requests::iterator it = active_requests.find(id);
    return (it != active_requests.end() ? &it->second : NULL);
}

void AbstractHttpSupport::cancelRequest(int id)
{
    HttpRequest *rq = getRequestById(id);
    if (rq) {
        doCancelRequest(*rq);
        active_requests.erase(id);
    }
}

unicode_string AbstractHttpSupport::parseDataBytes(const void * buffer, size_t count)
{
    const unsigned char *pdata = (const unsigned char*)buffer;

    if (count >= 2 && pdata[0] == 0xFF && pdata[1] == 0xFE) // UTF-16 BOM
        return unicode_string((unicode_char*)(pdata+2), (count-2)/FLOW_CHAR_SIZE);
    else
        return parseUtf8((const char*)buffer, count);
}

void AbstractHttpSupport::deliverDataBytes(int id, const void *buffer, unsigned count)
{
    HttpRequest *rq = getRequestById(id);

    if (!rq) return;
    if (rq->response_enc != ResponseEncodingByte)
        deliverData(id, parseDataBytes(buffer, count));
    else
        deliverData(id, unicode_string((unicode_char*)buffer, count/FLOW_CHAR_SIZE));
}

void AbstractHttpSupport::deliverData(int id, const unicode_char *data, unsigned count)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->data_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlots1(msg);

        msg = RUNNER->AllocateString(data, count);
        RUNNER->EvalFunction(rq->data_cb, 1, msg);
    }
}

void AbstractHttpSupport::deliverPartialData(int id, const void *buffer, unsigned count, bool last)
{
    HttpRequest *rq = getRequestById(id);
    if (!rq) return;

    if (rq->is_media_preload)
    {
        if (last)
            deliverData(id, (unicode_char*)NULL, 0);
        return;
    }

    if (!rq->tmp_file)
    {
        size_t pos = rq->tmp_buffer.size();
        rq->tmp_buffer.resize(pos+count);
        if (count) memcpy(rq->tmp_buffer.data()+pos, buffer, count);

        if (rq->tmp_buffer.size() >= MIN_MMAP_SIZE)
        {
            rq->tmp_file = MakeTemporaryFile(&rq->tmp_filename);

            if (!rq->tmp_file)
            {
                const char message[] = "Could not open temporary file";
                deliverError(id, message, sizeof(message) - 1);
                return;
            }

            rq->is_utf = !(rq->tmp_buffer[0] == char(0xFF) && rq->tmp_buffer[1] == char(0xFE));
            int skip = (rq->is_utf || rq->save_to_file ? 0 : 2);
            buffer = rq->tmp_buffer.data()+skip;
            count = rq->tmp_buffer.size()-skip;
        }
    }

    if (rq->save_to_file) {
        // Binary downloads keep the spool open until deliverResponse. No text
        // conversion or close/reopen by pathname is needed for this callback.
        if (rq->tmp_file) {
            if (count && fwrite(buffer, 1, count, rq->tmp_file) != count) {
                const char message[] = "Could not write temporary download file";
                deliverError(id, message, sizeof(message) - 1);
                return;
            }
            rq->tmp_buffer.clear();
        }
        return;
    }

    if (rq->tmp_file)
    {
        if (rq->is_utf && rq->response_enc != ResponseEncodingByte)
        {
            unicode_string tmp;
            rq->tmp_parser.parse(tmp, (const char*)buffer, count);
            fwrite(tmp.data(), sizeof(unicode_char), tmp.size(), rq->tmp_file);
        }
        else
            fwrite(buffer, 1, count, rq->tmp_file);

        rq->tmp_buffer.clear();
    }

    if (last)
    {
        if (!rq->tmp_file)
        {
            deliverDataBytes(id, rq->tmp_buffer.data(), rq->tmp_buffer.size());
            return;
        }

        if (rq->is_utf && rq->response_enc != ResponseEncodingByte)
        {
            unicode_string tail;
            rq->tmp_parser.finish(tail);
            fwrite(tail.data(), sizeof(unicode_char), tail.size(), rq->tmp_file);
        }

        fclose(rq->tmp_file);
        rq->tmp_file = NULL;

        if (!rq->data_cb.IsVoid()) {
            WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

            RUNNER_VAR = getFlowRunner();
            RUNNER_DefSlots1(msg);

            msg = RUNNER->LoadFileAsString(rq->tmp_filename, true);

            RUNNER->EvalFunction(rq->data_cb, 1, msg);

            active_requests.erase(id);
            getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
        }
    }
}

void AbstractHttpSupport::deliverError(int id, const void * buffer, size_t count)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (!rq) return;
    if (rq->save_to_file) {
        finishDownload(*rq, true, buffer, count);
    } else if (!rq->error_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlots1(msg);

        msg = RUNNER->AllocateString(parseDataBytes(buffer, count));
        RUNNER->EvalFunction(rq->error_cb, 1, msg);

        active_requests.erase(id);
        getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
    } else {
        rq->tmp_buffer.resize(count);
        memcpy(rq->tmp_buffer.data(), buffer, count);
    }
}

void AbstractHttpSupport::deliverStatus(int id, int status)
{
    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);
    
    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->status_cb.IsVoid()) {
        RUNNER->EvalFunction(rq->status_cb, 1, StackSlot::MakeInt(status));
    }

    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

// Called under the deferred runner lock. The callback may reenter the host, or
// quit without unwinding it. Keep only Flow roots across that call.
void AbstractHttpSupport::finishDownload(HttpRequest &rq, bool failed, const void *message, size_t length)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlots2(cb, arg);
    cb = failed ? rq.error_cb : rq.done_cb;
    if (failed && !cb.IsVoid())
        arg = RUNNER->AllocateString(parseDataBytes(message, length));
    const int id = rq.req_id;
    active_requests.erase(id); // closes and removes the named spool
    if (!cb.IsVoid() && !RUNNER->IsErrorReported()) {
        if (failed) RUNNER->EvalFunction(cb, 1, arg);
        else RUNNER->EvalFunction(cb, 0);
    }
    RUNNER->NotifyHostEvent(HostEventNetworkIO);
}

static bool writeDownload(const HttpRequest &rq, FILE *dest)
{
    FILE *source = rq.tmp_file;
    if (source) {
        if (fflush(source) != 0 || fseek(source, 0, SEEK_SET) != 0) return false;
        char block[16384];
        size_t n;
        while ((n = fread(block, 1, sizeof(block), source)) != 0)
            if (fwrite(block, 1, n, dest) != n) return false;
        return !ferror(source);
    }
    return rq.tmp_buffer.empty() || fwrite(rq.tmp_buffer.data(), 1, rq.tmp_buffer.size(), dest) == rq.tmp_buffer.size();
}

static bool writeAndCloseDownload(const HttpRequest &rq, FILE *out, bool overwrite = false)
{
    bool ok = writeDownload(rq, out) && !ferror(out);
    // The checked handle starts at offset zero, without O_TRUNC. Drop an old
    // tail only after the response was copied and the last write succeeded.
    if (ok && overwrite) {
        ok = fflush(out) == 0;
#ifdef _WIN32
        if (ok) ok = SetEndOfFile(reinterpret_cast<HANDLE>(_get_osfhandle(_fileno(out)))) != 0;
#else
        off_t end = ok ? ftello(out) : -1;
        ok = end >= 0 && ftruncate(fileno(out), end) == 0;
#endif
    }
    return fclose(out) == 0 && ok;
}

#ifndef _WIN32
static int openSearchDirectory(int base, const char *path)
{
#if defined(O_PATH) && !defined(FLOW_TEST_NO_SEARCH_HANDLE)
    const int access = O_PATH;
#elif defined(O_SEARCH) && !defined(FLOW_TEST_NO_SEARCH_HANDLE)
    const int access = O_SEARCH;
#else
    const int access = O_RDONLY;
#endif
    const int flags = O_DIRECTORY | O_CLOEXEC;
    int fd = openat(base, path, access | flags);
    if (fd < 0 && access != O_RDONLY && (errno == EINVAL || errno == ENOTSUP))
        return openat(base, path, O_RDONLY | flags); // newer SDK, older kernel
    return fd;
}

static bool anchorDownloadPath(ScopedFd &anchor, std::string &path)
{
    int fd = openSearchDirectory(AT_FDCWD, ".");
    if (fd < 0) {
        if (errno != EACCES) return false;
        // A relative destination can have an openable parent even when '.'
        // itself cannot be opened for reading. Pin it while the name is short.
        size_t leaf = path.find_last_of('/') + 1;
        if (leaf && leaf < path.size()) {
            fd = openSearchDirectory(AT_FDCWD, path.substr(0, leaf).c_str());
            if (fd >= 0) {
                anchor.reset(fd);
                path.erase(0, leaf);
                return true;
            }
        }
        // Older kernels/SDKs may not provide search-only handles. Keep the
        // unlistable components relative to the nearest openable ancestor.
        std::vector<char> buf(256);
        while (!getcwd(buf.data(), buf.size())) {
            if (errno != ERANGE) return false;
            buf.resize(buf.size() * 2);
        }
        std::string cwd = buf.data();
        if (cwd.empty() || cwd[0] != '/') return false;
        while (cwd.size() > 1) {
            size_t slash = cwd.rfind('/');
            path.insert(0, cwd.substr(slash + 1) + '/');
            cwd.resize(slash ? slash : 1);
            fd = openSearchDirectory(AT_FDCWD, cwd.c_str());
            if (fd >= 0) break;
            if (errno != EACCES && errno != ENAMETOOLONG) return false;
        }
        if (fd < 0) { path.insert(0, "/"); return true; } // even '/' is search-only
    }
    anchor.reset(fd);
    return true;
}

// When a directory can be searched but not opened, the fallback retains an
// ancestor. The kernel may accept each half of a pathname but not the joined
// syscall argument. Use a private, short-lived symlink for the first half.
// Its target starts at the *held fd*, not a mutable absolute name or cwd.
// No helper is left on disk while the HTTP request is pending.
template<class Use>
static bool withDownloadPath(const HttpRequest &rq, Use use)
{
    const int base = rq.result_dir.get();
    const std::string &path = rq.result_filename;
    if (rq.result_split == path.npos) return use(base, path);
#ifdef __linux__
    const std::string root = "/proc/self/fd/" + std::to_string(base);
    struct stat held, via_proc;
    if (fstat(base, &held) || stat(root.c_str(), &via_proc) ||
        held.st_dev != via_proc.st_dev || held.st_ino != via_proc.st_ino) return false;

    if (temp_file_path.empty() || temp_file_path[0] != '/') return false;
    // As with /tmp, only the owner should be able to rename a private entry.
    // stat and mkdtemp need search/write access here, not directory listing.
    struct stat tmp;
    if (stat(temp_file_path.c_str(), &tmp) || !S_ISDIR(tmp.st_mode) ||
        (tmp.st_uid != 0 && tmp.st_uid != geteuid()) ||
        ((tmp.st_mode & 0022) && !(tmp.st_mode & S_ISVTX))) return false;

    std::string dir = temp_file_path + "/flowtmp-path-XXXXXX";
    const std::string target = root + "/" + path.substr(0, rq.result_split);
    const std::string name = "p" + path.substr(rq.result_split);
    if (!mkdtemp(&dir[0])) return false;
    struct RemoveAt {
        int base; const char *name; int flags;
        ~RemoveAt() { unlinkat(base, name, flags); }
    } remove_dir{AT_FDCWD, dir.c_str(), AT_REMOVEDIR};
    ScopedFd scratch;
    struct stat private_dir;
    if (!openStageDirectory(AT_FDCWD, dir, scratch) || fstat(scratch.get(), &private_dir) ||
        private_dir.st_uid != geteuid() || symlinkat(target.c_str(), scratch.get(), "p")) return false;
    RemoveAt remove_link{scratch.get(), "p", 0};
    return use(scratch.get(), name);
#else
    return false;
#endif
}
#endif

static void setDownloadDestination(HttpRequest &rq, const unicode_string &name)
{
    rq.save_to_file = true;
    if (name.empty() || name.find(unicode_char(0)) != name.npos) return;
#ifndef _WIN32
    std::string path = encodeUtf8(name);
    const size_t original = path.size();
    if (name[0] != '/' && !anchorDownloadPath(rq.result_dir, path)) return;
    rq.result_filename.swap(path);
    struct stat st;
    auto inspect = [&](int base, const std::string &p) {
        rq.create_only = fstatat(base, p.c_str(), &st, AT_SYMLINK_NOFOLLOW) != 0;
        return !rq.create_only || errno == ENOENT;
    };
    if (!inspect(rq.result_dir.get(), rq.result_filename)) {
        // Only shorten the expanded fallback, never reinterpret a caller's
        // already-invalid overlong spelling. Split inside the captured prefix.
        const size_t size = rq.result_filename.size();
        if (errno == ENAMETOOLONG && rq.result_dir.get() >= 0 && size > original) {
            rq.result_split = rq.result_filename.rfind('/', std::min(size / 2, size - original - 1));
            if (rq.result_split != std::string::npos && withDownloadPath(rq, inspect)) return;
        }
        rq.result_filename.clear(); // unknown is not the same as initially absent
    }
#else
    // Let Win32 resolve drive-relative and rooted names against the current
    // drive/directory. Retain the native spelling through publication.
    std::wstring input(name.begin(), name.end());
    // Allow an extended-length path without a second lookup against a mutable cwd.
    std::vector<wchar_t> buffer(32768);
    wchar_t *leaf = NULL;
    DWORD n = GetFullPathNameW(input.c_str(), DWORD(buffer.size()), buffer.data(), &leaf);
    if (!n || n >= buffer.size() || !leaf || wcschr(leaf, L':')) return;
    rq.result_filename.assign(buffer.data(), n);
    rq.create_only = GetFileAttributesW(rq.result_filename.c_str()) == INVALID_FILE_ATTRIBUTES;
#endif
}

#ifndef _WIN32
static bool saveDownloadAt(const HttpRequest &rq, int start, const std::string &original)
{
    std::string path = original;
    int base = start;
    ScopedFd parent;
    struct stat st;
    bool existing;
    // Only the final link needs resolving for renameat; the kernel handles
    // intermediate links and '..'. A dangling link is never a new file.
    for (unsigned hops = 0; ; ++hops) {
        size_t prefix = path.find_last_of('/') + 1;
        if (prefix) {
            if (prefix == path.size()) return false;
            int next = openSearchDirectory(base, path.substr(0, prefix).c_str());
            if (next >= 0) {
                parent.reset(next);
                base = next;
                path.erase(0, prefix);
                prefix = 0;
            } else if (errno != EACCES) return false;
        }
        existing = fstatat(base, path.c_str(), &st, AT_SYMLINK_NOFOLLOW) == 0;
        if (!existing) {
            if (hops || errno != ENOENT) return false;
            break;
        }
        if (rq.create_only) return false;
        if (!S_ISLNK(st.st_mode)) break;
        // Check the original spelling against the filesystem's own link limit,
        // including links in parent components, before walking the leaf links.
        if (!hops && fstatat(start, original.c_str(), &st, 0) != 0) return false;
        if (hops == 40) return false;
        std::vector<char> target(256);
        ssize_t n;
        while ((n = readlinkat(base, path.c_str(), target.data(), target.size())) == ssize_t(target.size()))
            target.resize(target.size() * 2);
        if (n <= 0) return false;
        path.replace(target[0] == '/' ? 0 : prefix, path.npos, target.data(), size_t(n));
    }
    if (existing && !S_ISREG(st.st_mode)) {
        if (!S_ISCHR(st.st_mode) && !S_ISFIFO(st.st_mode)) return false;
        int fd = openat(base, path.c_str(), O_WRONLY | O_NOFOLLOW | O_CLOEXEC);
        if (fd == -1) return false;
        if (fstat(fd, &st) == 0 && (S_ISCHR(st.st_mode) || S_ISFIFO(st.st_mode))) {
            if (FILE *out = fdopen(fd, "wb")) return writeAndCloseDownload(rq, out);
        }
        close(fd);
        return false;
    }
    auto write = [&](FILE *out) { return writeDownload(rq, out); };
    if (!existing) {
        return replaceRegularFile(base, path, NULL, write,
            [](int, const struct stat &) { return false; }) == StageResult::Published;
    }

    ScopedFd source(openat(base, path.c_str(), O_WRONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC));
    struct stat opened;
    if (source.get() < 0 || fstat(source.get(), &opened) || !S_ISREG(opened.st_mode) ||
        st.st_dev != opened.st_dev || st.st_ino != opened.st_ino) return false;
#ifdef __linux__
    if (opened.st_nlink == 1 && canStageDownload(source.get())) {
        auto result = replaceRegularFile(base, path, &opened, write,
            [&](int stage, const struct stat &expected) { return prepareDownloadFile(source.get(), stage, expected); });
        if (result != StageResult::Unavailable) return result == StageResult::Published;
    }
#endif
    // Metadata, hard links or directory permissions can preclude replacing
    // the entry without precluding an ordinary write to the file itself.
    if (fstatat(base, path.c_str(), &st, AT_SYMLINK_NOFOLLOW) ||
        st.st_dev != opened.st_dev || st.st_ino != opened.st_ino) return false;
    FILE *out = fdopen(source.get(), "wb"); // fdopen does not truncate
    if (!out) return false;
    source.release();
    return writeAndCloseDownload(rq, out, true);
}

static bool saveDownload(const HttpRequest &rq)
{
    return !rq.result_filename.empty() && withDownloadPath(rq, [&](int base, const std::string &path) {
        return saveDownloadAt(rq, base, path);
    });
}
#else
static bool writeDownloadHandle(const HttpRequest &rq, HANDLE h, bool overwrite = false)
{
    int fd = _open_osfhandle(reinterpret_cast<intptr_t>(h), _O_WRONLY | _O_BINARY);
    if (fd == -1) { CloseHandle(h); return false; }
    if (FILE *out = _fdopen(fd, "wb")) return writeAndCloseDownload(rq, out, overwrite);
    _close(fd);
    return false;
}

static bool saveDownload(const HttpRequest &rq)
{
    const std::wstring &path = rq.result_filename;
    if (path.empty()) return false;

    // Check the existing target without truncating it. A device/pipe is a
    // stream; a reparse point must not be replaced with a new directory entry.
    HANDLE h = CreateFileW(path.c_str(), GENERIC_WRITE | FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (h != INVALID_HANDLE_VALUE) {
        if (rq.create_only) { CloseHandle(h); return false; }
        DWORD type = GetFileType(h);
        if (type == FILE_TYPE_CHAR || type == FILE_TYPE_PIPE) return writeDownloadHandle(rq, h);
        BY_HANDLE_FILE_INFORMATION info;
        const DWORD refused = FILE_ATTRIBUTE_ENCRYPTED | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY |
                              FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_READONLY | FILE_ATTRIBUTE_SYSTEM;
        if (type == FILE_TYPE_DISK && GetFileInformationByHandle(h, &info) && !(info.dwFileAttributes & refused))
            return writeDownloadHandle(rq, h, true); // only the unnamed data stream; preserve the file object
        CloseHandle(h);
        return false;
    }
    if (GetLastError() != ERROR_FILE_NOT_FOUND) return false;

    static std::atomic<unsigned> sequence(0);
    size_t slash = path.find_last_of(L'\\');
    if (slash == path.npos) return false;
    const std::wstring dir = path.substr(0, slash + 1);
    std::wstring stage;
    for (unsigned i = 0; i < 128; ++i) {
        stage = dir + L".flow-download-" + std::to_wstring(GetCurrentProcessId()) + L"-" + std::to_wstring(++sequence);
        if (_wcsicmp(path.c_str(), stage.c_str()) == 0) continue;
        h = CreateFileW(stage.c_str(), GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (h == INVALID_HANDLE_VALUE) {
            if (GetLastError() == ERROR_FILE_EXISTS) continue;
            return false;
        }
        if (writeDownloadHandle(rq, h) && MoveFileExW(stage.c_str(), path.c_str(), 0)) {
            return true;
        }
        DeleteFileW(stage.c_str());
        return false;
    }
    return false;
}
#endif

void AbstractHttpSupport::deliverResponse(int id, int status, HeadersMap headers)
{
    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);
    
    HttpRequest *rq = getRequestById(id);

    if (rq && rq->save_to_file) {
        if (saveDownload(*rq)) {
#ifdef FLOW_MMAP_HEAP
            // This erases a spelling, not a file lookup against the current cwd.
            // Both packed readers revalidate other spellings by open-file identity.
            RUNNER->InvalidateFileCache(rq->result_filename);
#endif
            finishDownload(*rq, false, NULL, 0);
        } else {
            const char message[] = "Could not save downloaded file";
            finishDownload(*rq, true, message, sizeof(message) - 1);
        }
        return;
    }

    if (rq && !rq->response_cb.IsVoid()) {
        RUNNER_DefSlots1(data);

        if (rq->tmp_filename != "") {
            data = RUNNER->LoadFileAsString(rq->tmp_filename, true);
        } else {
            const unsigned char* pdata = (const unsigned char*)rq->tmp_buffer.data();
            size_t count = rq->tmp_buffer.size();

            if (count >= 2 && pdata[0] == 0xFF && pdata[1] == 0xFE) { // UTF-16 BOM
                data = RUNNER->AllocateString((unicode_char*)(pdata+2), (count-2)/FLOW_CHAR_SIZE);
            } else {
                switch (rq->response_enc)
                {
                    case ResponseEncodingUTF8:
                    case ResponseEncodingWTF8:
                        data = RUNNER->AllocateString(parseUtf8((const char*)pdata, count));
                        break;
                    case ResponseEncodingByte:
                        data = RUNNER->AllocateString((unicode_char*)pdata, count/FLOW_CHAR_SIZE+count%FLOW_CHAR_SIZE);
                        break;
                    default: /* ResponseEncodingAuto */
                        data = RUNNER->AllocateString(parseUtf8((const char*)pdata, count));
                }
            }
        }

        int i = 0;
        RUNNER_DefSlots2(headersArray, headerPair);
        headersArray = RUNNER->AllocateArray(headers.size());
        for (std::map<unicode_string, unicode_string>::iterator it = headers.begin(); it != headers.end(); ++it) {
            if (RUNNER->IsErrorReported()) break;
            headerPair = RUNNER->AllocateArray(2);
            if (RUNNER->IsErrorReported()) break;

            RUNNER->SetArraySlot(headerPair, 0, RUNNER->AllocateString(it->first));
            RUNNER->SetArraySlot(headerPair, 1, RUNNER->AllocateString(it->second));

            RUNNER->SetArraySlot(headersArray, i++, headerPair);
        }

        if (!RUNNER->IsErrorReported())
            RUNNER->EvalFunction(rq->response_cb, 3, StackSlot::MakeInt(status), data, headersArray);
    }

    if (rq && !rq->done_cb.IsVoid()) {
        getFlowRunner()->EvalFunction(rq->done_cb, 0);

        active_requests.erase(id);
        getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
    }
}

void AbstractHttpSupport::deliverTransferStarted(int id)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->open_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(rq->open_cb, 0);
    }

    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

void AbstractHttpSupport::deliverProgress(int id, FlowDouble pos, FlowDouble total)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->progress_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(rq->progress_cb, 2, StackSlot::MakeDouble(pos), StackSlot::MakeDouble(total));
    }

    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

void AbstractHttpSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    active_requests.clear();
}

void AbstractHttpSupport::flowGCObject(GarbageCollectorFn ref)
{
    ref << active_requests;
}

NativeFunction *AbstractHttpSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "HttpSupport."

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, httpRequest, 7);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, preloadMediaUrl, 3);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, uploadNativeFile, 8);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, downloadFile, 4);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, downloadFileBinary, 4);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, downloadFileBinaryWithHeaders, 5);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, removeUrlFromCache, 1);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, clearUrlCache, 0);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, getAvailableCacheSpaceMb, 0);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, systemDownloadFile, 1);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, sendHttpRequestWithAttachments, 6);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, httpCustomRequestNative, 8);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, deleteAppCookies, 0);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, setDefaultResponseEncoding, 1);

    return NULL;
}

void AbstractHttpSupport::decodeMap(RUNNER_VAR, HttpRequest::T_SMap *pmap, const StackSlot &smap)
{
    for (unsigned int i = 0; i < RUNNER->GetArraySize(smap); i++) {
        const StackSlot &map_item = RUNNER->GetArraySlot(smap,i);
        RUNNER_CheckTagVoid(TArray, map_item);

        unicode_string key = RUNNER->GetString(RUNNER->GetArraySlot(map_item,0));
        unicode_string value = RUNNER->GetString(RUNNER->GetArraySlot(map_item,1));
        (*pmap)[key] = value;
    }
}

void AbstractHttpSupport::processAttachmentsAsMultipart(HttpRequest& rq) {
    std::ostringstream body;

    // based on this code: https://gist.github.com/mombrea/8467128
    std::string boundary("*****");
    std::string boundaryDataLine = "--" + boundary + "\r\n";

    rq.headers[parseUtf8("Content-Type")] = parseUtf8("multipart/form-data; boundary=" + boundary);
    rq.headers[parseUtf8("Connection")] = parseUtf8("Keep-Alive");

    // loop for params
    for (HttpRequest::T_SMap::iterator it = rq.params.begin(); it != rq.params.end(); ++it)
    {
        body << boundaryDataLine;
        body << "Content-Disposition: form-data; name=\"" << encodeUtf8(it->first)
             << "\"\r\n\r\n" << encodeUtf8(it->second) << "\r\n";
    }

    // loop for attachments
    for (HttpRequest::T_FileMap::iterator it = rq.attachments.begin(); it != rq.attachments.end(); ++it)
    {
        FlowFile *flowFile = it->second;
        if(!flowFile->open())
            continue;
        std::vector<uint8_t> fileContent = flowFile->readBytes();
        flowFile->close();

        body << boundaryDataLine;
        body << "Content-Disposition: form-data; name=\"" << encodeUtf8(it->first) << "\";filename=\"" << flowFile->getFilepath() << "\"\r\n\r\n";
        body << std::string(fileContent.begin(), fileContent.end()) << "\r\n";
    }

    body << "--" + boundary + "--\r\n";

    std::string body_str = body.str();
    rq.payload = std::vector<uint8_t>(body_str.begin(), body_str.end());
}

unicode_string AbstractHttpSupport::urlencode(const unicode_string &url)
{
    static const char lookup[]= "0123456789ABCDEF";
    std::stringstream e;
    const std::string &s = encodeUtf8(url);
    for(size_t i = 0, ix = s.length(); i < ix; i++)
    {
        const char& c = s[i];

        if ( (48 <= c && c <= 57) ||//0-9
             (65 <= c && c <= 90) ||//abc...xyz
             (97 <= c && c <= 122) || //ABC...XYZ
             (c=='-' || c=='_' || c=='.' || c=='~')
        ) {
            e << c;
        } else {
            e << '%';
            e << lookup[ (c&0xF0)>>4 ];
            e << lookup[ (c&0x0F) ];
        }
    }
    return parseUtf8(e.str());
}

void AbstractHttpSupport::processRequest(HttpRequest &rq) {
    std::map<unicode_string,unicode_string>::iterator found = rq.headers.find(parseUtf8("Content-Type"));
    bool useMultipart = found != rq.headers.end() && encodeUtf8(found->second).find("multipart/form-data") == 0;
    if ((!rq.attachments.empty() || useMultipart) && rq.payload.empty()) {
        processAttachmentsAsMultipart(rq);
    } else {
        std::string url = encodeUtf8(rq.url);

        HttpRequest::T_SMap paramsEncoded;
        for (HttpRequest::T_SMap::iterator it = rq.params.begin(); it != rq.params.end(); ++it) {
            paramsEncoded[urlencode(it->first)] = urlencode(it->second);
        }

        // Map url query parameters to rq.params
        size_t queryPos = url.find_first_of('?');
        size_t dashPos = url.find_first_of('#');

        if (queryPos != std::string::npos) {
            size_t querySize = dashPos == std::string::npos ? dashPos : dashPos - queryPos - 1;

            std::string query = url.substr(queryPos + 1, querySize);

            size_t pos = 0;
            while(pos < querySize) {
                size_t equalPos = query.find_first_of('=', pos);
                size_t ampPos = query.find_first_of('&', pos);

                unicode_string key = parseUtf8(query.substr(pos, equalPos - pos));
                unicode_string value = parseUtf8(query.substr(equalPos + 1, ampPos - equalPos - 1));
                paramsEncoded[key] = value;

                pos = ampPos != std::string::npos ? ampPos + 1 : querySize;
            }
        }

        unicode_string params;
        for (HttpRequest::T_SMap::iterator it = paramsEncoded.begin(); it != paramsEncoded.end(); ++it) {
            if (it != paramsEncoded.begin())
                params += unicode_string(1, '&');

            params += it->first + unicode_string(1, '=') + it->second;
        }

        if (encodeUtf8(rq.method) == "GET") {
			if (params.empty()) {
				// Avoid adding the ? on requests without parameters
				rq.url = parseUtf8(url);
			} else {
				std::string dash = dashPos != std::string::npos ? url.substr(dashPos, url.size() - dashPos) : "";
				rq.url = parseUtf8(url.substr(0, queryPos)) + unicode_char('?') + params + parseUtf8(dash);
			}
        } else if (rq.payload.empty()) {
            std::string params_str = encodeUtf8(params);
            rq.payload = std::vector<uint8_t>(params_str.begin(), params_str.end());
            rq.headers[parseUtf8("Content-Type")] = parseUtf8("application/x-www-form-urlencoded");
        }
    }

    if (!rq.payload.empty()) {
        std::ostringstream contentlength;
        contentlength << rq.payload.size();
        rq.headers[parseUtf8("Content-Length")] = parseUtf8(contentlength.str());
    }
}

StackSlot AbstractHttpSupport::httpRequest(RUNNER_ARGS)
{
    RUNNER_PopArgs7(url, postMethod, headers, params, onData, onError, onStatus);
    RUNNER_CheckTag1(TString, url);
    RUNNER_CheckTag1(TBool, postMethod);
    RUNNER_CheckTag2(TArray, headers, params);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);

    if (postMethod.GetBool()) {
        rq.method = parseUtf8("POST");
    } else {
        rq.method = parseUtf8("GET");
    }

    rq.data_cb = onData;
    rq.error_cb = onError;
    rq.status_cb = onStatus;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::httpCustomRequestNative(RUNNER_ARGS)
{
    RUNNER_PopArgs8(url, method, headers, params, data, responseEncoding, onResponse, async);
    RUNNER_CheckTag4(TString, url, method, data, responseEncoding);
    RUNNER_CheckTag2(TArray, headers, params);
    RUNNER_CheckTag1(TBool, async);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = RUNNER->GetString(method);
    rq.response_enc = GetResponseEncodingFromString(encodeUtf8(RUNNER->GetString(responseEncoding)));
    rq.response_enc = (rq.response_enc == ResponseEncodingAuto ? defaultResponseEncoding : rq.response_enc);
    std::string payload_string = encodeUtf8(RUNNER->GetString(data));
    rq.payload = std::vector<uint8_t>(payload_string.begin(), payload_string.end());
    rq.response_cb = onResponse;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::preloadMediaUrl(RUNNER_ARGS)
{
    RUNNER_PopArgs3(url, onDone, onError);
    RUNNER_CheckTag1(TString, url);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = parseUtf8("GET");
    rq.is_media_preload = true;
    rq.done_cb = onDone;
    rq.error_cb = onError;

    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::downloadFile(RUNNER_ARGS)
{
    RUNNER_PopArgs4(url, onData, onError, onProgress);
    RUNNER_CheckTag1(TString, url);
	
    int id = next_http_request++;
	
    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.method = parseUtf8("GET");
    rq.url = RUNNER->GetString(url);
    rq.data_cb = onData;
    rq.error_cb = onError;
    rq.progress_cb = onProgress;

    processRequest(rq);
    doRequest(rq);
	
    RETVOID;
}



StackSlot AbstractHttpSupport::downloadFileBinary(RUNNER_ARGS)
{
    RUNNER_PopArgs4(url, pathToSave, onDone, onError);
    RUNNER_CheckTag2(TString, url, pathToSave);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.method = parseUtf8("GET");
    rq.response_enc = ResponseEncodingByte;
    rq.url = RUNNER->GetString(url);
    setDownloadDestination(rq, RUNNER->GetString(pathToSave));
    rq.done_cb = onDone;
    rq.error_cb = onError;

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}



StackSlot AbstractHttpSupport::downloadFileBinaryWithHeaders(RUNNER_ARGS)
{
    RUNNER_PopArgs5(url, headers, pathToSave, onDone, onError);
    RUNNER_CheckTag2(TString, url, pathToSave);
	RUNNER_CheckTag(TArray, headers);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.method = parseUtf8("GET");
    rq.response_enc = ResponseEncodingByte;
    rq.url = RUNNER->GetString(url);
    setDownloadDestination(rq, RUNNER->GetString(pathToSave));
    rq.done_cb = onDone;
    rq.error_cb = onError;
	
    decodeMap(RUNNER, &rq.headers, headers);

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::uploadNativeFile(RUNNER_ARGS)
{
    RUNNER_PopArgs8(file, url, params, headers, onOpen, onDataFn, onErrorFn, onProgressFn);
    RUNNER_CheckTag(TNative, file);
    RUNNER_CheckTag(TString, url);
    RUNNER_CheckTag2(TArray, headers, params);

    FlowFile *flowFile = RUNNER->GetNative<FlowFile*>(file);
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = parseUtf8("POST");

    rq.open_cb = onOpen;
    rq.data_cb = onDataFn;
    rq.error_cb = onErrorFn;
    rq.progress_cb = onProgressFn;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    unicode_string filename = parseUtf8(flowFile->getFilename());

    HttpRequest::T_SMap::iterator customNameField = rq.params.find(parseUtf8("uploadDataFieldName"));
    if(customNameField != rq.params.end()) {
        filename = customNameField->second;
        rq.params.erase(customNameField);
    }

    rq.attachments[filename] = flowFile;

    processRequest(rq);
    doRequest(rq);

    return RUNNER->AllocateNativeClosure(cbCancel, "uploadNativeFile$cancel", 0, this, 1, StackSlot::MakeInt(id));
}

StackSlot AbstractHttpSupport::cbCancel(RUNNER_ARGS, void *ptr) {
    AbstractHttpSupport *self = static_cast<AbstractHttpSupport*>(ptr);
    self->cancelRequest(RUNNER->GetClosureSlot(RUNNER_CLOSURE,0).GetInt());
    RETVOID;
}

StackSlot AbstractHttpSupport::removeUrlFromCache(RUNNER_ARGS) {
    RUNNER_PopArgs1(url);
    RUNNER_CheckTag1(TString, url);
    doRemoveUrlFromCache(RUNNER->GetString(url));
    RETVOID;
}

StackSlot AbstractHttpSupport::clearUrlCache(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    doClearUrlCache();
    RETVOID;
}

StackSlot AbstractHttpSupport::getAvailableCacheSpaceMb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeInt(doGetAvailableCacheSpaceMb());
}

StackSlot AbstractHttpSupport::systemDownloadFile(RUNNER_ARGS) {
    RUNNER_PopArgs1(url);
    RUNNER_CheckTag1(TString, url);
    doSystemDownloadFile(RUNNER->GetString(url));
    RETVOID;
}

StackSlot AbstractHttpSupport::sendHttpRequestWithAttachments(RUNNER_ARGS) {
    RUNNER_PopArgs6(url, headers, params, attachments, onData, onError);
    RUNNER_CheckTag1(TString, url);
    RUNNER_CheckTag3(TArray, headers, params, attachments);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = parseUtf8("POST");
    rq.data_cb = onData;
    rq.error_cb = onError;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    HttpRequest::T_SMap attachments_buffer;
    decodeMap(RUNNER, &attachments_buffer, attachments);
    for (HttpRequest::T_SMap::iterator it = attachments_buffer.begin(); it != attachments_buffer.end(); ++it)
    {
        rq.attachments[it->first] = new FlowFile(RUNNER, encodeUtf8(it->second));
    }

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::deleteAppCookies(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    doDeleteAppCookies();

    RETVOID;
}

ResponseEncoding AbstractHttpSupport::GetResponseEncodingFromString(std::string str)
{
    if (str == "utf8")
        return ResponseEncodingUTF8;
    else if (str == "wtf8") {
        return ResponseEncodingWTF8;
    } else if (str == "byte")
        return ResponseEncodingByte;
    else if (str == "auto")
        return ResponseEncodingAuto;
    else {
        cout << "Invalid encoding '" << str << "'. Switched to 'auto'." << endl;
        return ResponseEncodingAuto;
    }
}

StackSlot AbstractHttpSupport::setDefaultResponseEncoding(RUNNER_ARGS)
{
    RUNNER_PopArgs1(tmp_value);
    RUNNER_CheckTag1(TString, tmp_value);

    defaultResponseEncoding = GetResponseEncodingFromString(encodeUtf8(RUNNER->GetString(tmp_value)));

    static const char lookup[] = "Default response encoding switched to ";

    switch (defaultResponseEncoding) {
        case ResponseEncodingUTF8:
            setUtf8StyleGlobalFlag(true);
            cout << lookup << "'UTF8'." << endl;
            break;
        case ResponseEncodingWTF8:
            setUtf8StyleGlobalFlag(false);
            cout << lookup << "'WTF8'." << endl;
            break;
        case ResponseEncodingByte:
            setUtf8StyleGlobalFlag(false);
            cout << lookup << "'raw byte'." << endl;
            break;
        case ResponseEncodingAuto:
            setUtf8StyleGlobalFlag(true);
            cout << lookup << "'auto'." << endl;
            break;
        default:
            setUtf8StyleGlobalFlag(true);
            cout << "Invalid encoding '" << encodeUtf8(RUNNER->GetString(tmp_value)) << "'. Switched to 'auto'." << endl;
    }

    RETVOID;  
}
