// Tests of the runner's UTF-8 decoder, file reads, stl_sprintf and font-name parsing.
// Run with run_tests.sh, which builds it with the sanitizers in a temporary folder.

#include <cstring>
#include "core/STLHelpers.h"
#include "font/TextFont.h"

#include <algorithm>
#include <cstdio>
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
    };
    for (const std::string &sample : samples) {
        for (size_t step = 1; step <= sample.size(); step++) {
            if (decodeInChunks(sample, step) != parseUtf8(sample))
                fail("chunks of " + std::to_string(step) + " decode \"" + sample + "\" differently from parseUtf8");
        }
    }
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

static void testFontNames() {
    struct { const char *name; TextWeight weight; const char *family; TextStyle style; } cases[] = {
        { "Roboto", TextWeight::Regular, "Roboto", Normal },
        { "RobotoBold", TextWeight::Bold, "Roboto", Normal },
        { "RobotoExtraBold", TextWeight::ExtraBold, "Roboto", Normal },
        { "RobotoBoldItalic", TextWeight::Bold, "Roboto", Italic },
        { "SourceSansProExtraLight", TextWeight::UltraLight, "SourceSansPro", Normal },
        { "FooSemiLight", TextWeight::Light, "Foo", Normal },
        { "FooDemiBold", TextWeight::SemiBold, "Foo", Normal },
        { "FooUltraBold", TextWeight::ExtraBold, "Foo", Normal },
        { "FooExtraBlack", TextWeight::Black, "Foo", Normal },
    };
    for (const auto &c : cases) {
        TextFont font = TextFont::makeWithParameters(c.name, TextWeight::Regular, "");
        if (font.family != c.family || font.weight != c.weight || font.style != c.style)
            fail(std::string("font name ") + c.name + " parsed as " + font.family + " " +
                 std::to_string(font.weight) + " " + std::to_string(font.style));
    }
}

int main() {
    testDecoder();
    testChunkedDecoder();
    testFileReads();
    testSprintf();
    testFontNames();
    printf(failures ? "%d tests FAILED\n" : "All tests passed\n", failures);
    return failures != 0;
}
