// Tests of the runner's Unicode decoders, file reads, stl_sprintf and font-name parsing.
// Run with run_tests.sh, which builds it with the sanitizers in a temporary folder.

#include <cstring>
#include "core/STLHelpers.h"
#include "font/TextFont.h"

#include <algorithm>
#include <cstdio>
#ifndef _WIN32
#include <cstdlib>
#include <fcntl.h>
#include <sys/stat.h>
#endif
#include <string>
#include <vector>

static int failures = 0;
static const unicode_char R = 0xFFFD;

static std::string hex(const unicode_string &s) {
    std::string out;
    char digits[8];
    for (unicode_char c : s) {
        snprintf(digits, sizeof digits, "%04X ", c);
        out += digits;
    }
    return out;
}

static void fail(const std::string &message) {
    failures++;
    printf("FAIL: %s\n", message.c_str());
}

static void check(const char *name, const unicode_string &actual, const std::vector<unicode_char> &expected) {
    unicode_string want(expected.begin(), expected.end());
    if (actual != want)
        fail(std::string(name) + ": got " + hex(actual) + "expected " + hex(want));
}

static unicode_string decodeInChunks(const std::string &bytes, size_t step) {
    IncrementalUtf8Parser parser;
    unicode_string out;
    for (size_t i = 0; i < bytes.size(); i += step)
        parser.parse(out, bytes.data() + i, std::min(step, bytes.size() - i));
    parser.finish(out);
    return out;
}

static void writeFile(const char *name, const std::string &bytes) {
    FILE *file = fopen(name, "wb");
    fwrite(bytes.data(), 1, bytes.size(), file);
    fclose(file);
}

static void testDecoder() {
    check("valid text", parseUtf8(std::string("A\xC3\xA9\xE2\x82\xAC")), {'A', 0xE9, 0x20AC});
    check("U+1F600", parseUtf8(std::string("\xF0\x9F\x98\x80")), {0xD83D, 0xDE00});
    check("U+10FFFF", parseUtf8(std::string("\xF4\x8F\xBF\xBF")), {0xDBFF, 0xDFFF});
    check("WTF-8 lone surrogate", parseUtf8(std::string("\xED\xA0\x80")), {0xD800});
    check("stray continuation byte", parseUtf8(std::string("\x80" "AB")), {R, 'A', 'B'});
    check("lead byte without continuation", parseUtf8(std::string("\xE2" "ABC")), {R, 'A', 'B', 'C'});
    check("cut 3-byte sequence", parseUtf8(std::string("\xE2\x82" "A")), {R, 'A'});
    check("lead byte F7", parseUtf8(std::string("\xF7\xBF\xBF\xBF")), {R, R, R, R});
    check("above U+10FFFF", parseUtf8(std::string("\xF4\x90\x80\x80")), {R, R, R, R});
    check("overlong '/'", parseUtf8(std::string("\xC0\xAF")), {R, R});
    check("NUL in Java's modified UTF-8", parseUtf8(std::string("A\xC0\x80" "B")), {'A', 0, 'B'});
    check("overlong 3 bytes", parseUtf8(std::string("\xE0\x80\xAF")), {R, R, R});
    check("overlong 4 bytes", parseUtf8(std::string("\xF0\x80\x80\xAF")), {R, R, R, R});
    check("truncated at the end", parseUtf8(std::string("A\xF0\x9F\x98")), {'A', R});

    unicode_string pair = {0xD83D, 0xDE00, 'x'};
    check("UTF-8 round trip", parseUtf8(encodeUtf8(pair)), {0xD83D, 0xDE00, 'x'});
    setUtf8StyleGlobalFlag(false);
    check("WTF-8 round trip", parseUtf8(encodeUtf8(pair)), {0xD83D, 0xDE00, 'x'});
    setUtf8StyleGlobalFlag(true);
}

static void testChunkedDecoder() {
    const std::vector<std::string> samples = {
        "A\xC3\xA9\xE2\x82\xAC\xF0\x9F\x98\x80" "z",
        "\x80" "AB\xE2" "ABC\xF7\xBF\xBF\xBF\xE0\x80\xAF" "q",
        "cut at the end \xE2\x82",
        "\xF0\x9F\x98",
        "\xE2\xE2\x82\xAC\xC3",
        "nul \xC0\x80 and overlong \xC0\xAF end \xC0",
    };
    for (const std::string &sample : samples) {
        for (size_t step = 1; step <= sample.size(); step++) {
            if (decodeInChunks(sample, step) != parseUtf8(sample))
                fail("chunks of " + std::to_string(step) + " decode \"" + sample + "\" differently from parseUtf8");
        }
    }
}

static void testUtf16Validator() {
    const uint16_t input[] = {'A', 0xD83D};
    uint32_t output[2] = {};
    size_t outputSize;
    const size_t consumed = decodeCharsUtf16toUtf32(input, sizeof input / sizeof input[0], output, &outputSize);
    if (consumed != 1 || outputSize != 1 || output[0] != 'A')
        fail("UTF-16 validator should report the incomplete character and preserve the decoded prefix");
}

static void testUtf16Conversion() {
    const unicode_string text = {'A', 0xD800, 'B', 0xDC00, 0, 0xD83D, 0xDE00};
    if (decodeUtf16toUtf32(text) != utf32_string{'A', 0xFFFE, 'B', 0xFFFE, 0, 0x1F600})
        fail("UTF-16 string conversion should preserve text around unpaired surrogates");
    if (decodeUtf16toUtf32(text.data() + 4, 2) != utf32_string{0, 0xFFFE})
        fail("UTF-16 substring conversion should use only the supplied code units");
    if (!decodeUtf16toUtf32(unicode_string()).empty() || !decodeUtf16toUtf32(text.data(), 0).empty())
        fail("UTF-16 conversion of an empty string or range should be empty");
}

static void checkTraversal(const std::string &name, Utf32InputIterator &it, Utf32InputIterator &end,
                           size_t size, const std::vector<ucs4_char_tracer> &path) {
    auto unread = it.clone();
    for (const auto &ch : path) {
        const size_t pos = std::get<0>(ch);
        if (unread->position() != pos)
            fail(name + ": increment without dereference missed position " + std::to_string(pos));
        if (it.position() != pos || *it != std::get<2>(ch) || it.traceCurrent() != ch)
            fail(name + ": unexpected character or span at position " + std::to_string(pos));
        ++*unread;
        ++it;
    }
    if (end.position() != size || it != end || *unread != end || *it != 0 || *end != 0)
        fail(name + ": traversal should finish at the zero-valued end sentinel");

    const size_t first = path.empty() ? size : std::get<0>(path.front());
    ++it;
    if (it.position() != first)
        fail(name + ": incrementing end should cycle back to the beginning");
    it.seekEnd();
    if (it != end || *it != 0)
        fail(name + ": seekEnd should select the end sentinel");
    it.seekBegin();
    if (it.position() != first || (!path.empty() && it.traceCurrent() != path.front()))
        fail(name + ": seekBegin should restore the first character and its span");
}

static void checkUtf16Iterators(DecodeUtf16toUtf32 &decoder, size_t size,
                                const std::vector<ucs4_char_tracer> &path) {
    auto forward = decoder.begin(), end = decoder.end();
    auto reverse = decoder.rbegin(), rend = decoder.rend();
    checkTraversal("forward UTF-16", forward, end, size, path);
    checkTraversal("reverse UTF-16", reverse, rend, size, {path.rbegin(), path.rend()});
}

static void testUtf16Iteration() {
    unicode_string text = {0xD83D, 0xDE00, 0xD800, 'A', 0xDC00, 0, 0xE000, 0xDBFF, 0xDFFF};
    DecodeUtf16toUtf32 decoder(text);
    checkUtf16Iterators(decoder, text.size(), {
        {0, 2, 0x1F600}, {2, 3, 0xFFFE}, {3, 4, 'A'}, {4, 5, 0xFFFE},
        {5, 6, 0}, {6, 7, 0xE000}, {7, 9, 0x10FFFF}
    });

    DecodeUtf16toUtf32 prefix(&text[0], 1);
    checkUtf16Iterators(prefix, 1, {{0, 1, 0xFFFE}});
    unicode_string empty;
    DecodeUtf16toUtf32 emptyString(empty), emptyRange(&text[0], 0);
    checkUtf16Iterators(emptyString, 0, {});
    checkUtf16Iterators(emptyRange, 0, {});
}

static void testFileReads() {
    bool ok = true;
    if (!readFileAsUnicodeString(".", &ok).empty() || ok)
        fail("readFileAsUnicodeString on a directory should fail with an empty string");
    std::vector<uint8_t> buffer;
    if (readFileToVector(&buffer, ".", true))
        fail("readFileToVector on a directory should fail");

    writeFile("utf16.txt", std::string("\xFF\xFE" "A\0\xAC\x20", 6));
    check("UTF-16 file with BOM", readFileAsUnicodeString("utf16.txt", &ok), {'A', 0x20AC});
    writeFile("utf8.txt", "hi \xE2\x82\xAC");
    check("UTF-8 file", readFileAsUnicodeString("utf8.txt", &ok), {'h', 'i', ' ', 0x20AC});
    if (!readFileToVector(&buffer, "utf8.txt", true) || buffer.size() != 6)
        fail("readFileToVector should read all 6 bytes");
}

static void testSprintf() {
    if (stl_sprintf("%s-%d", std::string(5000, 'x').c_str(), 7).size() != 5002)
        fail("stl_sprintf should grow its buffer for a long result");
    if (stl_sprintf("%s", std::string(4096, 'x').c_str()).size() != 4096)
        fail("stl_sprintf should keep a result of exactly 4096 characters");
    // An encoding error must return, not grow the buffer forever
    wchar_t unencodable[] = { 0xD800, 0 };
    stl_sprintf("%ls", unencodable);
}

#ifndef _WIN32
static void testTemporaryFile() {
    const char *dir = getenv("TMPDIR"); // run_tests.sh supplies a private Unicode directory
    if (!dir) {
        fail("temporary file test needs TMPDIR");
        return;
    }
#ifndef QT_CORE_LIB
    temp_file_path = dir; // Qt already gets TMPDIR from QDir::tempPath().
#endif
    std::string name;
    FILE *file = MakeTemporaryFile(&name);
    if (!file) {
        fail("could not create named temporary file");
        return;
    }
    if (name.substr(0, name.rfind('/')) != dir)
        fail("temporary file is outside TMPDIR");
    int flags = fcntl(fileno(file), F_GETFD);
    if (flags == -1 || !(flags & FD_CLOEXEC))
        fail("temporary stream should be close-on-exec");

    const std::vector<uint8_t> bytes = {0, 0xff, '\n', 'x'};
    if (fwrite(bytes.data(), 1, bytes.size(), file) != bytes.size())
        fail("could not write to returned temporary stream");
    if (fclose(file) != 0)
        fail("could not close temporary stream");
    std::vector<uint8_t> actual;
    if (!readFileToVector(&actual, name) || actual != bytes)
        fail("could not read back temporary data by name after close");
    if (remove(name.c_str()) != 0)
        fail("could not remove temporary file by name");

    file = MakeTemporaryFile();
    if (!file) {
        fail("could not create unnamed temporary stream");
        return;
    }
    struct stat st;
    if (fstat(fileno(file), &st) != 0)
        fail("could not stat unnamed temporary stream");
    else if (st.st_nlink != 0)
        fail("unnamed temporary file should already be unlinked on return");

    if (fwrite(bytes.data(), 1, bytes.size(), file) != bytes.size())
        fail("could not write to unnamed temporary stream");
    rewind(file);
    std::vector<uint8_t> readback(bytes.size());
    if (fread(readback.data(), 1, readback.size(), file) != readback.size() || readback != bytes)
        fail("could not read back data from unnamed temporary stream");
    if (fclose(file) != 0)
        fail("could not close unnamed temporary stream");
}
#endif

static void testFontNames() {
    struct { const char *name; TextWeight weight; const char *family; TextStyle style; } cases[] = {
        { "Roboto", TextWeight::Regular, "Roboto", Normal },
        { "RobotoBold", TextWeight::Bold, "Roboto", Normal },
        { "RobotoExtraBold", TextWeight::ExtraBold, "Roboto", Normal },
        { "RobotoBoldItalic", TextWeight::Bold, "Roboto", Italic },
        { "RobotoUltraLight", TextWeight::UltraLight, "Roboto", Normal },
        { "RobotoSemiBold", TextWeight::SemiBold, "Roboto", Normal },
    };
    for (const auto &c : cases) {
        TextFont font = TextFont::makeWithParameters(c.name, TextWeight::Regular, "");
        if (font.family != c.family || font.weight != c.weight || font.style != c.style)
            fail(std::string("font name ") + c.name + " parsed as " + font.family + " " +
                 std::to_string(font.weight) + " " + std::to_string(font.style));
    }

    // family + suffix() is the asset path and the font key, so every name must come back whole
    const char *names[] = {
        "RobotoBold", "RobotoExtraBold", "RobotoBoldItalic", "SourceSansProExtraLight",
        "FooSemiLight", "FooLight", "FooDemiBold", "FooUltraBold", "FooExtraBlack", "FooBlack",
    };
    for (const char *name : names) {
        TextFont font = TextFont::makeWithParameters(name, TextWeight::Regular, "");
        if (font.family + font.suffix() != name)
            fail(std::string("font name ") + name + " comes back as " + font.family + font.suffix());
    }
}

int main() {
    testDecoder();
    testChunkedDecoder();
    testUtf16Validator();
    testUtf16Conversion();
    testUtf16Iteration();
    testFileReads();
#ifndef _WIN32
    testTemporaryFile();
#endif
    testSprintf();
    testFontNames();
    printf(failures ? "%d tests FAILED\n" : "All tests passed\n", failures);
    return failures != 0;
}
