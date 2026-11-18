#include "STLHelpers.h"

// Encoding ‘flat’ UTF-32 char to UTF-16, which is not flat since 1996.
// Maximum output length is 2, so that's minimum safe allocated output buffer size.
size_t encodeCharUtf32toUtf16(uint32_t c, uint16_t *out) {
    if (c >= 0x10000 && c < 0x110000) {
        c -= 0x10000; //Regarding UTF-16 spec.
        out[0] = 0xD800 + (c >> 10);
        out[1] = 0xDC00 + (c & 0x3FF);
        return 2;
    } else if (c < 0xD800 || (c >= 0xE000 && c < 0x10000)) {
        out[0] = c;
        return 1;
    }
    else {
        return 0; // Out of range.
    }
}

// Encoding UTF-32 characters to UTF-16.
// Function returns input position with error encountered or given length when ok.
// Output_size indicates number of successfully output words.
size_t encodeCharsUtf32toUtf16(const uint32_t *input, size_t input_size, uint16_t *output, size_t *output_size) {
    *output_size = 0;
    for (size_t inpos = 0; inpos < input_size; ++inpos) {
        size_t len = encodeCharUtf32toUtf16(input[inpos], &output[*output_size]);
        if (!len) return inpos;
        (*output_size) += len;
    }
    return input_size;
}

// Decoding non-flat UTF-16 characters to flat UTF-32.
// Function returns input position with error encountered or given length when ok.
// Output_size indicates number of successfully output dwords.
size_t decodeCharsUtf16toUtf32(const uint16_t *input, size_t input_size, uint32_t *output, size_t *output_size) {
    *output_size = 0;

    // 0 for new conversion pending,
    // 1 for 0xD800+ (first of sequence of two) encountered and expecting 0xDC00+.
    uint8_t bytes_expecting=0;
    uint32_t c, acc;
    size_t inpos = 0;
    for (; inpos < input_size; ++inpos) {
        c = input[inpos];
        if (bytes_expecting) {
            if (c < 0xDC00 || c >= 0xE000) {
                return inpos-1;  // Expected 0xDC00+, previous word is incompleted prefix.
            } else {
                output[(*output_size)++] = 0x10000L + (((acc & 0x3FFL) << 10) | (c & 0x3FFL));
                bytes_expecting = 0;
            }
        } else {
            if (c > 0x110000L || (c >= 0xDC00L && c < 0xE000L)) {
                return inpos;  // Out of range or unexpected continuation word.
            } else if (c >= 0xD800L && c < 0xDC00L) {  // Prefix.
                acc = c;
                bytes_expecting = 1;
            } else {
                output[(*output_size)++] = c;  // 1-to-1 conversion.
            }
        }
    }
    if (bytes_expecting) {
        return inpos-1;  // Expected 0xDC00+, but string ends. Last word is incompleted prefix.
    }
    return inpos;
}


// Inserts 0xFFFE (invalid character) when something's failed, and goes on.
unicode_string encodeUtf32toUtf16(const uint32_t *str, size_t size) {
    unicode_string out;
    out.reserve(size*5/4);  // Just a guess. Better 1 or more for usual cases and 2 or less for Chinese, Japan, Arabic, Hebrew, Yiddish, maybe some else.
    uint16_t outbuf[2];
    size_t outlen;
    for (size_t pos = 0; pos < size; ++pos) {
        outlen = encodeCharUtf32toUtf16(str[pos], outbuf);
        if (!outlen) {
            // instead of throwing DecodeError
            outbuf[0] = 0xFFFE;
            outlen = 1;
        }
        out.append(outbuf, outlen);
    }
    return out;
}

unicode_string encodeUtf32toUtf16(const utf32_string &str) {
    return encodeUtf32toUtf16(str.data(), str.size());
}

static bool startsSurrogatePair(const unicode_char *str, size_t size) {
    return size >= 2 && str[0] >= 0xD800 && str[0] < 0xDC00 &&
                        str[1] >= 0xDC00 && str[1] < 0xE000;
}

// len is one code unit or one confirmed pair.
static ucs4_char decodeUtf16Char(const unicode_char *str, size_t len) {
    ucs4_char value;
    size_t outlen;
    if (decodeCharsUtf16toUtf32(str, len, &value, &outlen) != len || outlen != 1)
        return 0xFFFE;
    return value;
}

// Inserts 0xFFFE (invalid character) when something's failed, and goes on.
utf32_string decodeUtf16toUtf32(const unicode_char *str, size_t size) {
    utf32_string out;
    out.reserve(size*4/5);  // Just a guess. Better 1 or less for usual cases and ½ or more for Chinese, Japan, Arabic, Hebrew, Yiddish, maybe some else.
    for (size_t pos = 0; pos < size;) {
        const size_t len = startsSurrogatePair(str + pos, size - pos) ? 2 : 1;
        out.push_back(decodeUtf16Char(str + pos, len));
        pos += len;
    }
    return out;
}

utf32_string decodeUtf16toUtf32(const unicode_string &str) {
    return decodeUtf16toUtf32(str.data(), str.size());
}


void Utf32InputIterator::seekBegin() {
    seekEnd();
    ++*this;
}

DecodeUtf16toUtf32::DecodeUtf16toUtf32(DecodeUtf16toUtf32 &org) {
    this->org = org.org;
    this->size = org.size;
}

DecodeUtf16toUtf32::DecodeUtf16toUtf32(unicode_char *org, size_t size) {
    this->org = org;
    this->size = size;
}

DecodeUtf16toUtf32::DecodeUtf16toUtf32(unicode_string &org) {
    this->org = const_cast<unicode_char *>(org.data());
    this->size = org.size();
}

DecodeUtf16toUtf32::Iterator::Iterator(DecodeUtf16toUtf32 *parent, size_t pos)
    : parent(parent), pos(pos) {}

size_t DecodeUtf16toUtf32::Iterator::charNativeLen() const {
    return pos < parent->size && startsSurrogatePair(parent->org + pos, parent->size - pos) ? 2 : 1;
}

Utf32InputIterator &DecodeUtf16toUtf32::Iterator::forward() {
    if (pos < parent->size) pos += charNativeLen(); else pos = 0;
    return *this;
}

Utf32InputIterator &DecodeUtf16toUtf32::Iterator::backward() {
    if (pos >= 2 && startsSurrogatePair(parent->org + (pos - 2), 2)) pos -= 2;
    else if (pos > 0) --pos;
    else pos = parent->size;
    return *this;
}

ucs4_char DecodeUtf16toUtf32::Iterator::operator *(){
    if (pos >= parent->size) return 0; // The iterator's end sentinel.
    return decodeUtf16Char(parent->org + pos, charNativeLen());
}
ucs4_char_tracer DecodeUtf16toUtf32::Iterator::traceCurrent() {
    return ucs4_char_tracer(pos, pos + charNativeLen(), **this);
}

bool DecodeUtf16toUtf32::Iterator::operator ==(DecodeUtf16toUtf32::Iterator &other){
    return Utf32InputIterator::operator ==(other);
}

shared_ptr<Utf32InputIterator> DecodeUtf16toUtf32::DirectIterator::clone() {
    shared_ptr<Utf32InputIterator> r(new DirectIterator(this->parent, this->pos));
    return r;
}

shared_ptr<Utf32InputIterator> DecodeUtf16toUtf32::ReversedIterator::clone() {
    shared_ptr<Utf32InputIterator> r(new ReversedIterator(this->parent, this->pos));
    return r;
}

shared_ptr<Utf32InputIterator> DecodeUtf16toUtf32::DirectIterator::cloneReversed() {
    shared_ptr<Utf32InputIterator> r(new ReversedIterator(this->parent, this->pos));
    return r;
}

shared_ptr<Utf32InputIterator> DecodeUtf16toUtf32::ReversedIterator::cloneReversed() {
    shared_ptr<Utf32InputIterator> r(new DirectIterator(this->parent, this->pos));
    return r;
}

DecodeUtf16toUtf32::DirectIterator DecodeUtf16toUtf32::begin() {
    DecodeUtf16toUtf32::DirectIterator r(this, 0);
    return r;
}
DecodeUtf16toUtf32::DirectIterator DecodeUtf16toUtf32::end() {
    DecodeUtf16toUtf32::DirectIterator r(this, size);
    return r;
}
DecodeUtf16toUtf32::ReversedIterator DecodeUtf16toUtf32::rbegin() {
    auto r = rend();
    ++r;
    return r;
}
DecodeUtf16toUtf32::ReversedIterator DecodeUtf16toUtf32::rend() {
    DecodeUtf16toUtf32::ReversedIterator r(this, size);
    return r;
}
