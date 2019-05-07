#include "STLHelpers.h"

#include <stdio.h>

#ifdef QT_CORE_LIB
#include <QDebug>
#include <QFile>
#include <QString>
#include <QDir>
#include <QTemporaryFile>
#endif

#include <sstream>
#include <cstring>

#ifdef IOS
#import <UIKit/UIKit.h>
#endif

/* Character encoding */

static inline int encode(uint8_t *out, uint16_t c) {
    if (c <= 0x7F)
    {
        out[0] = c;
        return 1;
    }
    else if (c <= 0x7FF)
    {
        out[0] = (0xC0 | (c >> 6));
        out[1] = (0x80 | (c & 0x3F));
        return 2;
    }
    else /*if (c <= 0xFFFF)*/
    {
        out[0] = (0xE0 | (c >> 12));
        out[1] = (0x80 | ((c >> 6) & 0x3F));
        out[2] = (0x80 | (c & 0x3F));
        return 3;
    }
}

/* String processing */

template<class C>
struct Utf8Parser
{
    uint32_t w;
    int bytes;

    unicode_string parse(const C &str, unsigned size);
    void parse_range(unicode_string &out, const C &str, unsigned size);
};

template<class C>
unicode_string Utf8Parser<C>::parse(const C &str, unsigned size)
{
    unicode_string out;
    w = 0;
    bytes = 0;
    uint32_t err = L'?';
    parse_range(out, str, size);
    if (bytes)
        out.push_back(err);
    return out;
}

template<class C>
void Utf8Parser<C>::parse_range(unicode_string &out, const C &str, unsigned size)
{
    uint32_t w = 0;
    int bytes = 0;
    for (size_t i = 0; i < size; i++){
        unsigned char c = (unsigned char) str[i];
        if (c <= 0x7f) { //first byte
            bytes = 0;
            out.push_back((uint32_t) c);
        } else if (c <= 0xbf){//second/third/etc byte
            if (bytes) {
                w = ((w << 6)|(c & 0x3f));
                bytes--;
                if (bytes == 0) {
                    out.push_back(w);
                }
            } else {
                bytes = 0;
            }
        }
        else if (c <= 0xdf){//2byte sequence start
            bytes = 1;
            w = c & 0x1f;
        }
        else if (c <= 0xef){//3byte sequence start
            bytes = 2;
            w = c & 0x0f;
        }
        else if (c <= 0xf7){//3byte sequence start
            bytes = 3;
            w = c & 0x07;
        } else {
            bytes = 0;
        }
    }
}

void IncrementalUtf8Parser::parse(unicode_string &out, const char *data, unsigned size)
{
    Utf8Parser<const char*> worker;
    worker.w = w;
    worker.bytes = bytes;
    worker.parse_range(out, data, size);
    w = worker.w;
    bytes = worker.bytes;
}

unicode_string parseUtf8(const std::string &str) {
    return Utf8Parser<const char*>().parse(str.data(), str.size());
}

unicode_string parseUtf8(const char *str, unsigned size) {
    return Utf8Parser<const char*>().parse(str, size);
}

unicode_string parseUtf8u(const unicode_string &str) {
    return Utf8Parser<const unicode_char*>().parse(str.data(), str.size());
}

template<class C, class I>
inline C doEncodeUtf8(I str, unsigned size)
{
    C out;
    out.reserve(size*3);

    uint8_t buf[4];
    for (unsigned i = 0; i < size; i++) {
        int cnt = encode(buf, str[i]);
        out.append(&buf[0], &buf[cnt]);
    }

    return out;
}

std::string encodeUtf8(const unicode_string &str)
{
    return doEncodeUtf8<std::string, const unicode_char*>(str.data(), str.size());
}

std::string encodeUtf8(const unicode_char *str, unsigned size)
{
    return doEncodeUtf8<std::string, const unicode_char*>(str, size);
}

unicode_string encodeUtf8u(const unicode_string &str)
{
    return doEncodeUtf8<unicode_string, const unicode_char*>(str.data(), str.size());
}

/* Random utilities from STLHelpers.h not specific to Flow runner */

unicode_string readFileAsUnicodeString(std::string filename, bool *ok)
{
    if (ok) *ok = false;

    FILE *file = fopen(filename.c_str(), "rb");
    if (file) {
        fseek(file, 0, SEEK_END);
        size_t size = ftell(file);
        rewind(file);

        // Initialize a pointer for reading file data
        void* data = malloc(size);

        // Pick first 2 bytes to check whether it starts from BOM bytes
        static const uint8_t bom_bytes[] = { 0xFF, 0xFE };
        uint8_t leading_buffer[] = { '\0', '\0' };
        size_t delta = fread(&leading_buffer, 1, 2, file);

        // If so it means that is an UTF-16 string
        bool isUtf16String = delta == 2 && memcmp(bom_bytes, leading_buffer, 2) == 0;

        if (!isUtf16String)
            rewind(file);

        // Read file content
        size_t pos = 0;
        while (pos < size) {
            size_t delta = fread(data, 1, size-pos, file);
            if (!delta) {
                break;
            } else {
                pos += delta;
            }
        }

        fclose(file);
        if (ok) *ok = true;

        // Interpret a file content as UTF-16 or UTF-8
        if (isUtf16String) {
            return unicode_string((uint16_t*)data, pos / 2);
        } else {
            return parseUtf8(std::string((char*)data, pos));
        }
    }

    return unicode_string();
}

bool readFileToVector(std::vector<uint8_t> *buffer, std::string name, bool auto_size)
{
    FILE *file = fopen(name.c_str(), "rb");

    if (file) {
        size_t size = buffer->size();

        if (auto_size) {
            fseek(file, 0, SEEK_END);
            size = ftell(file);
            rewind(file);

            buffer->resize(size);
        }

        for (size_t pos = 0; pos < size; ) {
            size_t delta = fread(&(*buffer)[pos], 1, size-pos, file);
            if (!delta) {
                if (auto_size)
                    buffer->resize(pos);
                else
                    memset(&(*buffer)[pos], 0, size-pos);
                break;
            } else {
                pos += delta;
            }
        }

        fclose(file);
        return true;
    }

    return false;
}

#ifdef QT_CORE_LIB
std::string temp_file_path = encodeUtf8(qt2unicode(QDir::tempPath()));
#elif defined(IOS)
std::string temp_file_path = std::string([NSTemporaryDirectory() UTF8String]);
#else
std::string temp_file_path = P_tmpdir;
#endif

FILE *MakeTemporaryFile(std::string *pname)
{
    std::string path = temp_file_path;
    if (!path.empty() && path[path.size()-1] != '/' && path[path.size()-1] != '\\')
        path += "/";
    path += "flowtmpXXXXXX";

#ifdef QT_CORE_LIB
    QString pattern = unicode2qt(parseUtf8(path));

    QTemporaryFile file(pattern);
    if (!file.open())
        return NULL;

    std::string name = encodeUtf8(qt2unicode(file.fileName()));
    if (pname)
        *pname = name;

    if (FILE *fobj = fopen(name.c_str(), "w+b"))
    {
        file.setAutoRemove(false);
        return fobj;
    }

    file.remove();
    return NULL;
#else
    path.push_back(0);

    int fd = mkstemp(&path[0]);
    if (fd == -1)
        return NULL;

    if (pname)
        *pname = path.substr(0, path.size()-1);

    return fdopen(fd, "w+b");
#endif
}

std::string stl_sprintf(const char *fmt, ...) {
    va_list lst;
    va_start(lst, fmt);
    std::string rv = stl_vsprintf(fmt, lst);
    va_end(lst);
    return rv;
}

std::string stl_vsprintf(const char *fmt, va_list args) {
    std::vector<char> buf;
    buf.resize(4096);
    for (;;) {
        int rsz = vsnprintf(&buf[0], buf.size(), fmt, args);

        if (rsz < 0)
            buf.resize(buf.size()*2);
        else if (unsigned(rsz) > buf.size())
            buf.resize(rsz+1);
        else
            return std::string(&buf[0], rsz);
    }
}

void printQuotedString(std::ostream &out, const std::string &sv)
{
    out << "\"";

    unsigned start = 0;
    for (unsigned i = 0; i < sv.length(); i++) {
        char code = sv[i];
        switch (code) {
        case '\\':
        case '"':
            break;
        case '\n':
            code = 'n'; break;
        case '\r': {
            out << sv.substr(start, i-start) << "\\u000d";
            start = i + 1;
            goto next;
        }
        case '\t':
            code = 't'; break;
        default:
            goto next;
        }

        out << sv.substr(start, i-start) << "\\" << code;
        start = i+1;
    next:;
    }

    out << sv.substr(start) << "\"";
}

void printQuotedString2(std::ostream &out, const std::string &sv) {
    out << "\"";
    unicode_string str = parseUtf8(sv);
    for (unsigned i = 0; i < str.size(); ++i) {
        unicode_char uc = str[i];
        switch(uc) {
            case '\n': out << "\\n"; break;
            case '\'': out << "\\'"; break;
            case '\"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\a': out << "\\a"; break;
            case '\b': out << "\\b"; break;
            case '\f': out << "\\f"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            case '\v': out << "\\v"; break;
            default:
                if(uc < 0x80) {
                    out << (char)uc;
                } else {
                    static char ucode[7];
                    sprintf(ucode, "\\u%04x", uc);
                    out << ucode;
                }
        }
    }

    out << "\"";
}

bool split_string(std::vector<std::string> *out,
                  const std::string &str, const std::string &separator, bool squash_empty)
{
    out->clear();

    size_t start = 0, pos;

    if (!separator.empty())
    {
        while ((pos = str.find(separator,start)) != std::string::npos)
        {
            if (pos > start || !squash_empty)
                out->push_back(str.substr(start, pos-start));
            start = pos + separator.size();
        }
    }

    if (start < str.size() || !squash_empty)
        out->push_back(str.substr(start));

    return out->size() > 1;
}

std::string join_strings(const std::string &separator, const std::vector<std::string> &items)
{
    std::stringstream ss;

    for (size_t i = 0; i < items.size(); i++)
    {
        if (i)
            ss << separator;
        ss << items[i];
    }

    return ss.str();
}

void tokenize_string(std::vector<std::string> *output, const std::string &input)
{
    std::string *cur = NULL;

    for (size_t i = 0; i < input.size(); i++) {
        unsigned char c = input[i];
        if (isspace(c)) {
            cur = NULL;
        } else {
            if (!cur) {
                output->push_back("");
                cur = &output->back();
            }

            if (c == '"') {
                for (i++; i < input.size(); i++) {
                    c = input[i];
                    if (c == '"')
                        break;
                    else if (c == '\\') {
                        if (++i < input.size())
                        {
                            char c = input[i];

                            switch (c) {
                            case 'n': c = '\n'; break;
                            case 'r': c = '\r'; break;
                            case 't': c = '\t'; break;
                            }

                            cur->push_back(c);
                        }
                    }
                    else
                        cur->push_back(c);
                }
            } else {
                cur->push_back(c);
            }
        }
    }
}
