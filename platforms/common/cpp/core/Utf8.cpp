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
#include <new>

#ifdef IOS
#import <UIKit/UIKit.h>
#endif

// We store here compiler flag about which logic of utf8 decode we should use:
//  false - old UTF8 format with coding UTF16 surrogate pairs independently (WTF-8 (Wobbly Transformation Format − 8-bit) https://simonsapin.github.io/wtf-8/):
//    It produces 6 bytes (a pair of 3 byte UTF8 characters) for the UTF16 surrogate pair.
//    From https://en.wikipedia.org/wiki/UTF-8:
//      Since RFC 3629 (November 2003), the high and low surrogates used by UTF-16 (U+D800 through U+DFFF) are not legal Unicode values,
//      and their UTF-8 encodings must be treated as an invalid byte sequence.
//  true - Recent UTF8 format:
//    It produces 4 byte UTF8 character from a UTF16 surrogate pair.
// This flag is used for backward compatibility only and should be removed in the future.
bool utf8_style_global_flag = true;

void setUtf8StyleGlobalFlag(const bool flag)
{
    utf8_style_global_flag = flag;
}

/*  Character encoding from internal format (UTF16) to UTF8/WTF8 bytes
 *  In WTF8 each UTF16 charecter is one WTF8 character (from 1 to 3 bytes) even if the UTF16 charecter if a part of a surrogate pair.
 *  In UTF8 each UTF16 charecter is one UTF8 character (from 1 to 3 bytes) exept to surrogate pair when 2 UTF16 charecters produces 1 UTF8 charecter (4 bytes).
 */
static unsigned encode(uint16_t c, uint16_t next_c, uint8_t *out, int &cnt)
{
    // How much symbols (chars) used to decode original symbol
    unsigned usedSymbolsCount = 1;
    uint16_t encode_error = (uint16_t)0xFFFD;
    // Some of utf8 codes are 4 bytes length
    uint32_t code = c;

    if (::utf8_style_global_flag)
    {
        // `code` is the highest part of the surrogate pair
        if (0xD800 <= code && code <= 0xDBFF)
        {
            // We have second symbol of surrogate pair and we can decode original symbol
            if (0xDC00 <= next_c && next_c <= 0xDFFF)
            {
                uint16_t hi = code;
                uint16_t low = next_c;
                code = ((hi & 0x3FF) << 10) + (low & 0x3FF) + 0x10000;
                usedSymbolsCount = 2;
            }
            else
            {
                code = encode_error;
                usedSymbolsCount = 1;
            }
        }
        // `code` is the lowest part of the surrogate pair
        // If we meet it - something went wrong.
        else if (0xDC00 <= code && code <= 0xDFFF)
        {
            code = encode_error;
            usedSymbolsCount = 1;
        }
        // Otherwise we do nothing - we have utf8 code.
        // Will process it below.
    }

    // Let's check on errors: UTF-8 accept only max 4 bytes
    if (code > 0x1FFFFF) // 5 (or more) bytes sequence, 0x1FFFFF = 0001 1111 1111 1111 1111 1111
    {
        code = encode_error;
        usedSymbolsCount = 1;
    }

    if (code <= 0x7F) // 1 byte sequence, 0x7F = 0111 1111
    {
        out[0] = code;
        cnt = 1;
    }
    else if (code <= 0x7FF) //2 bytes sequence, 0x7FF = 0111 1111 1111
    {
        out[0] = (0xC0 | (code >> 6));   // 110x xxxx + first 5 bits
        out[1] = (0x80 | (code & 0x3F)); // 10xx xxxx + last 6 bits
        cnt =  2;
    }
    else if (code <= 0xFFFF) // 3 bytes sequence, 0xFFFF = 1111 1111 1111 1111
    {
        out[0] = (0xE0 | (code >> 12));         // 1110 xxxx + first 4 bits
        out[1] = (0x80 | ((code >> 6) & 0x3F)); // 10xx xxxx + next 6 bits
        out[2] = (0x80 | (code & 0x3F));        // 10xx xxxx + last 6 bits
        cnt = 3;
    }
    else if (code <= 0x1FFFFF) // 4 bytes sequence, 0x1FFFFF = 0001 1111 1111 1111 1111 1111
    {
        out[0] = (0xF0 | (code >> 18));         // 1111 0xxx + first 3 bits
        out[1] = (0x80 | ((code >> 12) & 0x3F));// 10xx xxxx + next 6 bits
        out[2] = (0x80 | ((code >> 6) & 0x3F)); // 10xx xxxx + next 6 bits
        out[3] = (0x80 | (code & 0x3F));        // 10xx xxxx + last 6 bits
        cnt = 4;
    }
    //else //error, UTF-8 accept only max 4 bytes
    // but we already checked for error above.

    return usedSymbolsCount;
}

static void appendUtf16(unicode_string &out, uint32_t w)
{
    if (w < 0x10000) {
        out.push_back((unicode_char) w);
    } else {
        w -= 0x10000;
        out.push_back((unicode_char) ((w >> 10) + 0xD800));
        out.push_back((unicode_char) ((w & 0x3FF) + 0xDC00));
    }
}

/* Decodes UTF-8 into UTF-16 and returns how many bytes it used. Each malformed part
 * becomes one U+FFFD (Unicode "maximal subpart"); surrogates still decode, to read WTF-8.
 * With final == false it stops before a sequence that the next chunk can complete. */
template<class C>
static size_t decodeUtf8(unicode_string &out, const C &str, size_t size, bool final)
{
    static const unicode_char decode_error = 0xFFFD;
    size_t i = 0;
    while (i < size) {
        unsigned char c = (unsigned char) str[i];
        if (c <= 0x7F) {
            out.push_back(c);
            i++;
            continue;
        }

        // Lead bytes C0, C1 and F5-FF only start overlong or out-of-range code points;
        // E0, F0 and F4 narrow the second byte for the same reason.
        size_t length;
        uint32_t w;
        unsigned char low = 0x80, high = 0xBF;
        if (c >= 0xC2 && c <= 0xDF) {
            length = 2; w = c & 0x1F;
        } else if (c >= 0xE0 && c <= 0xEF) {
            length = 3; w = c & 0x0F;
            if (c == 0xE0) low = 0xA0;
        } else if (c >= 0xF0 && c <= 0xF4) {
            length = 4; w = c & 0x07;
            if (c == 0xF0) low = 0x90;
            if (c == 0xF4) high = 0x8F;
        } else {
            out.push_back(decode_error);
            i++;
            continue;
        }

        size_t j = 1;
        for (; j < length && i + j < size; j++) {
            unsigned char next = (unsigned char) str[i + j];
            if (next < low || next > high)
                break;
            w = (w << 6) | (next & 0x3F);
            low = 0x80;
            high = 0xBF;
        }

        if (j == length)
            appendUtf16(out, w);
        else if (i + j == size && !final)
            break;
        else
            out.push_back(decode_error);
        i += j;
    }
    return i;
}

void IncrementalUtf8Parser::parse(unicode_string &out, const char *data, unsigned size)
{
    size_t from = 0;
    if (!pending.empty()) {
        // A sequence is at most 4 bytes, so this many settle the one the last chunk cut.
        std::string head = pending + std::string(data, std::min<size_t>(size, 4 - pending.size()));
        size_t used = decodeUtf8(out, head.data(), head.size(), false);
        if (used < pending.size()) {
            pending = head.substr(used);
            return;
        }
        from = used - pending.size();
    }
    size_t used = decodeUtf8(out, data + from, size - from, false);
    pending.assign(data + from + used, size - from - used);
}

void IncrementalUtf8Parser::finish(unicode_string &out)
{
    decodeUtf8(out, pending.data(), pending.size(), true);
    pending.clear();
}

unicode_string parseUtf8(const std::string &str) {
    return parseUtf8(str.data(), str.size());
}

unicode_string parseUtf8(const char *str, unsigned size) {
    unicode_string out;
    decodeUtf8(out, str, size, true);
    return out;
}

unicode_string parseUtf8u(const unicode_string &str) {
    unicode_string out;
    decodeUtf8(out, str.data(), str.size(), true);
    return out;
}

template<class C, class I>
inline C doEncodeUtf8(I str, unsigned size)
{
    C out;
    // Max length of the one coded symbol is 4 bytes.
    out.reserve(size*4);

    uint8_t buf[4];
    int cnt = 0;
    for (unsigned i = 0; i < size; i++)
    {
        bool is_last = size - i == 1;
        uint16_t next_c = 0;
        if (!is_last) next_c = str[i + 1];
        i += encode(str[i], next_c, buf, cnt) - 1;
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

// The file's size, or -1 when it cannot be read whole: ftell gives -1 for a pipe, and
// a directory opens on Linux (ftell may say LONG_MAX) but fails its first read.
static long readableFileSize(FILE *file)
{
    if (fseek(file, 0, SEEK_END) != 0)
        return -1;
    long size = ftell(file);
    rewind(file);
    char probe;
    if (size < 0 || (fread(&probe, 1, 1, file) == 0 && ferror(file)))
        return -1;
    rewind(file);
    return size;
}

// Reads up to size bytes and returns how many it got.
static size_t readUpTo(FILE *file, void *dest, size_t size)
{
    size_t pos = 0;
    while (pos < size) {
        size_t delta = fread((char*)dest + pos, 1, size - pos, file);
        if (!delta)
            break;
        pos += delta;
    }
    return pos;
}

unicode_string readFileAsUnicodeString(std::string filename, bool *ok)
{
    if (ok) *ok = false;

    FILE *file = fopen(filename.c_str(), "rb");
    if (!file)
        return unicode_string();

    long size = readableFileSize(file);
    std::unique_ptr<char[]> data(size < 0 ? nullptr : new (std::nothrow) char[size]);
    if (!data) {
        fclose(file);
        return unicode_string();
    }
    size_t pos = readUpTo(file, data.get(), size);
    fclose(file);
    if (ok) *ok = true;

    // A file that starts with the bytes FF FE (BOM) is UTF-16, otherwise it is UTF-8
    if (pos >= 2 && (uint8_t)data[0] == 0xFF && (uint8_t)data[1] == 0xFE) {
        return unicode_string((uint16_t*)(data.get() + 2), (pos - 2) / 2);
    } else {
        return parseUtf8(data.get(), pos);
    }
}

bool readFileToVector(std::vector<uint8_t> *buffer, std::string name, bool auto_size)
{
    FILE *file = fopen(name.c_str(), "rb");
    if (!file)
        return false;

    if (auto_size) {
        long size = readableFileSize(file);
        if (size < 0) {
            fclose(file);
            return false;
        }
        buffer->resize(size);
    }

    size_t pos = readUpTo(file, buffer->data(), buffer->size());
    if (auto_size)
        buffer->resize(pos);
    else
        memset(buffer->data() + pos, 0, buffer->size() - pos);

    fclose(file);
    return true;
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

// A pre-C99 vsnprintf returns -1 when the buffer is too small, a C99 one when the
// output cannot be encoded; growing the buffer stops here so the second never loops.
static const size_t STL_VSPRINTF_MAX_BUFFER = 64 * 1024 * 1024;

std::string stl_vsprintf(const char *fmt, va_list args) {
    std::vector<char> buf;
    buf.resize(4096);
    for (;;) {
        // vsnprintf consumes the list it is given, so every attempt gets its own copy.
        va_list attempt;
        va_copy(attempt, args);
        int rsz = vsnprintf(&buf[0], buf.size(), fmt, attempt);
        va_end(attempt);

        if (rsz < 0 && buf.size() >= STL_VSPRINTF_MAX_BUFFER)
            return std::string();
        else if (rsz < 0)
            buf.resize(buf.size()*2);
        else if (unsigned(rsz) >= buf.size())
            buf.resize(rsz+1);
        else
            return std::string(&buf[0], rsz);
    }
}

void printQuotedString(std::ostream &out, const std::string &sv, bool print_non_printable)
{
	auto output = [print_non_printable, &out](const std::string& s){
		for (char code : s) {
			if (print_non_printable || isprint(code)) {
				out << code;
			} else {
				out << std::hex << "\\x" << (int)code << std::dec;
			}
		}
	};
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
            output(sv.substr(start, i-start));
            out << "\\u000d";
            start = i + 1;
            goto next;
        }
        case '\t':
            code = 't'; break;
        default:
            goto next;
        }

        output(sv.substr(start, i-start));
        out << "\\" << code;
        start = i+1;
    next:;
    }

    output(sv.substr(start)); out << "\"";
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
