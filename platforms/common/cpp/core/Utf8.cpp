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

/* String processing */
/* Parse UTF8 string to UTF16 (internal format) */
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

/*
 * | Symbol octets | Binary representation               | First octet max value | Second octet max value |
 * |------------------------------------------------------------------------------------------------------|
 * | 1 octet       | 0xxxxxxx                            | 0000007F              | --                     |
 * | 2 octets      | 110xxxxx 10xxxxxx                   | 000000DF              | 000000BF               |
 * | 3 octets      | 1110xxxx 10xxxxxx 10xxxxxx          | 000000EF              | 000000BF               |
 * | 4 octets      | 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx | 000000F7              | 000000BF               |
*/
template<class C>
void Utf8Parser<C>::parse_range(unicode_string &out, const C &str, unsigned size)
{
    int bytes = 0;
    uint16_t decode_error = (uint16_t)0xFFFD;

    auto to_utf16 = [&out](uint64_t w)
    {
        if (w < 0x10000 /* 2 bytes or less */)
        {
            out.push_back((uint32_t) w);
        }
        else
        {
            w = w - 0x10000;
            out.push_back((uint32_t) ((w >> 10) + 0xD800));
            out.push_back((uint32_t) ((w & 0x3FF) + 0xDC00));
        }
    };

    // Before decode the symbol from bytes chain we should check, does the chain is correct.
    // Each byte after the first should contains signature that it is a part of chain.
    //  second/third/fourth bytes should starts with 10xxxxxx
    auto is_sequence_correct = [str, size](size_t i, int bytes)
    {
        bool is_correct = true;
        if (size - i >= bytes)
        {
            unsigned char mask = 0xC0; // xx000000
            unsigned char next_octet_mask = 0x80; // 10xxxxxx

            for (size_t j = 1; j < bytes; j++)
            {
                unsigned char c = (unsigned char) str[i + j];
                is_correct = is_correct && ((c&mask) == next_octet_mask);
            }
        }
        else
        {
            is_correct = false;
        }

        return is_correct;
    };

    // Decode the chain of bytes into one symbol.
    auto push_sequence = [&out, str, decode_error, is_sequence_correct, to_utf16](unsigned char mask, unsigned char c, size_t i, int bytes)
    {
        if (is_sequence_correct(i, bytes))
        {
            uint64_t w = (c & mask);

            // second/third/fourth bytes
            for (size_t j = 1; j < bytes; j++)
            {
                c = (unsigned char) str[i + j];
                w = ((w << 6)|(c & 0x3F)); // 0x3F = 0011 1111
            }

            to_utf16(w);
        }
        else
        {
            out.push_back(decode_error);
        }

        return;
    };

    // Here we check signature of first byte - how much bytes in the chain (to read one utf8 symbol).
    // If one byte chain - we push it at the end of the our decoded string.
    // Otherwise (more that one byte) - we read the sequence and decode it into one symbol.
    for (size_t i = 0; i < size; i++)
    {
        unsigned char c = (unsigned char) str[i];

        if (c <= 0x7F)  // 1 byte sequence, 0x7F = 0111 1111
        {
            out.push_back((uint32_t) c);
        }
        else if (c <= 0xDF) //2 bytes sequence, 0xDF = 1101 1111
        {
            bytes = 2;
            push_sequence(0x1F, c, i, bytes); // 0x1F = 0001 1111
            i += bytes - 1;
        }
        else if (c <= 0xEF) // 3 bytes sequence, 0xEF = 1110 1111
        {
            bytes = 3;
            push_sequence(0x0F, c, i, bytes); // 0x0F = 0000 1111
            i += bytes - 1;
        }
        else if (c <= 0xF7) // 4 bytes sequence, 0xF7 = 1111 0111
        {
            bytes = 4;
            push_sequence(0x07, c, i, bytes); // 0x07 = 0000 0111
            i += bytes - 1;
        }
        else //error, UTF-8 accept only max 4 octets
        {
            out.push_back(decode_error);
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
