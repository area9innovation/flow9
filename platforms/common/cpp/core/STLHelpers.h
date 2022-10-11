#ifndef STLHELPERS_H
#define STLHELPERS_H

/* Stupid isnan macro workaround */

#if defined(ANDROID) && !defined(_GLIBCXX_USE_C99_MATH)
#ifdef isnan
#error isnan already defined
#endif
#define _GLIBCXX_USE_C99_MATH 1
#define _GLIBCXX_USE_C99_FP_MACROS_DYNAMIC 0
#include <cmath>
#undef _GLIBCXX_USE_C99_MATH
#undef _GLIBCXX_USE_C99_FP_MACROS_DYNAMIC
#ifdef isnan
#error isnan defined by cmath
#endif
#endif

#ifdef IOS
#undef check
#endif

/* ints */

#include <stdint.h>

#include <stdarg.h>

/* STL headers */

#include <iostream>
#include <ctype.h>

using std::istream;
using std::ostream;
using std::cout;
using std::cerr;
using std::hex;
using std::dec;
using std::endl;
using std::flush;

#include <string>
#include <vector>
#include <map>
#include <set>
#include <list>
#include <algorithm>

#ifdef QT_CORE_LIB
#include <QString>
#endif

#if defined(_LIBCPP_VERSION) && defined(__GXX_EXPERIMENTAL_CXX0X__)
# define IOSCPP11 1
#else
# define IOSCPP11 0
#endif

#if defined(__cplusplus) || defined(_MSC_VER)
# define C11 1
#else
# define C11 0
#endif

#if C11
#include <memory>
#include <unordered_set>
#include <unordered_map>
#else
#include <tr1/memory>
#include <tr1/unordered_set>
#include <tr1/unordered_map>
#endif

#include <assert.h>

#if !defined(__GNUC__) || (__GNUC__ < 3)
#define likely(form) (form)
#define unlikely(form) (form)
#else
#define likely(form) __builtin_expect(form,1)
#define unlikely(form) __builtin_expect(form,0)
#endif

/*
#define _GLIBCXX_PERMIT_BACKWARD_HASH
#include <ext/hash_map>
#include <ext/hash_set>
*/

#if C11
using std::shared_ptr;
using std::weak_ptr;
using std::static_pointer_cast;
#define STL_HASH_NAMESPACE std
#else
using std::tr1::shared_ptr;
using std::tr1::weak_ptr;
using std::tr1::static_pointer_cast;
#define STL_HASH_NAMESPACE std::tr1
#endif

#define STL_HASH STL_HASH_NAMESPACE::hash
#define STL_HASH_MAP STL_HASH_NAMESPACE::unordered_map
#define STL_HASH_SET STL_HASH_NAMESPACE::unordered_set

#if C11
#  define BEGIN_STL_HASH_NAMESPACE namespace std {
#  define END_STL_HASH_NAMESPACE }

#elif _MSC_VER
// Compatibility
#  define __attribute__(x)
#  define snprintf _snprintf

#else
#  define BEGIN_STL_HASH_NAMESPACE namespace std { namespace tr1 {
#  define END_STL_HASH_NAMESPACE }}
#endif

template<class T>
inline size_t hash_char_array(const T* arr, unsigned size)
{
  unsigned long h = 0;
  for (; size != 0; --size, ++arr)
    h = 5 * h + *arr;
  return size_t(h);
}

/*
BEGIN_STL_HASH_NAMESPACE
    template <> struct hash<std::string> {
        size_t operator() (const std::string& x) const {
            return hash_char_array(x.data(), x.size());
        }
    };
END_STL_HASH_NAMESPACE
}*/

struct ptr_hash {
    size_t operator() (void *p) const {
        return STL_HASH<unsigned long>()((unsigned long)p);
    }
};

template<class T>
T safeVectorAt(const std::vector<T> &v, int i, T defval = T()) {
    return (unsigned(i) < v.size()) ? v[i] : defval;
}

template<class M>
typename M::mapped_type safeMapAt(const M &v, const typename M::key_type &k,
                                  typename M::mapped_type defval = typename M::mapped_type())
{
    typename M::const_iterator it = v.find(k);
    return it == v.end() ? defval : it->second;
}

template<class M>
typename M::iterator mapFindLE(M &m, const typename M::key_type &k)
{
    typename M::iterator it = m.upper_bound(k);
    if (it == m.begin())
        return m.end();
    else
        return --it;
}

template<class M>
typename M::const_iterator mapFindLE(const M &m, const typename M::key_type &k)
{
    typename M::const_iterator it = m.upper_bound(k);
    if (it == m.begin())
        return m.end();
    else
        return --it;
}

template<class T>
inline T* safeVectorPtrAt(std::vector<T> &v, int i) {
    return (unsigned(i) < v.size()) ? &v[i] : NULL;
}

template<class T, class V>
void eraseItem(T &container, const V &value) {
    container.erase(std::remove(container.begin(), container.end(), value), container.end());
}

#define FLOW_CHAR_SIZE 2
typedef uint16_t unicode_char;
typedef uint32_t ucs4_char;
typedef std::basic_string<unicode_char> unicode_string;
typedef std::basic_string<ucs4_char> utf32_string;
typedef std::tuple<size_t, size_t, ucs4_char> ucs4_char_tracer;

#if !defined(_MSC_VER)
BEGIN_STL_HASH_NAMESPACE
    template <> struct hash<unicode_string> {
        size_t operator() (const unicode_string& x) const {
            return hash_char_array(x.data(), x.size());
        }
    };
END_STL_HASH_NAMESPACE
#endif

inline bool isualpha(unicode_char c) { return (c < 256 && isalpha(c)); }
inline bool isuspace(unicode_char c) { return (c < 256 && isspace(c)); }

class IncrementalUtf8Parser
{
    uint32_t w;
    int bytes;
public:
    IncrementalUtf8Parser() : w(0), bytes(0) {}
    void parse(unicode_string &out, const char *data, unsigned size);
    bool is_complete() { return bytes == 0; }
};

// We store here compiler flag about which logic of utf8 decode we should use:
//  false - usual way with loss real code for 3 bytes codes,
//  true - with decoding 3 bytes codes into UTF-16 codes (pairs of 2 bytes codes).
void setUtf8JsStyleGlobalFlag(const bool flag);

unicode_string parseUtf8(const std::string &str);
unicode_string parseUtf8(const char *str, unsigned size);
unicode_string parseUtf8Base(const char *str, unsigned size, bool js_style);

unicode_string parseUtf8u(const unicode_string &str);

std::string encodeUtf8(const unicode_string &str);
std::string encodeUtf8(const unicode_char *str, unsigned size);

unicode_string encodeUtf8u(const unicode_string &str);

size_t encodeCharUtf32toUtf16(uint32_t c, uint16_t *out);
size_t decodeCharsUtf16toUtf32(const uint16_t *input, size_t input_size, uint32_t *output, size_t *output_size);
size_t encodeCharsUtf32toUtf16(const uint32_t *input, size_t input_size, uint16_t *output, size_t *output_size);

class Utf32InputIterator: public std::iterator<std::input_iterator_tag, ucs4_char> {
public:
    virtual void *data() =0;

    // In any units source declares, not guaranteed in chars. So, if data is the same,
    // source is the same too, thus, the units are same and we can compare positions.
    virtual size_t position() =0;

    bool operator ==(Utf32InputIterator &other) {return data() == other.data() && position() == other.position();}
    bool operator !=(Utf32InputIterator &other) {return !(*this == other);}
    virtual ucs4_char operator *() =0;
    virtual ucs4_char_tracer traceCurrent() =0;

    // Cycle through all characters and one extra «ending» position.
    virtual Utf32InputIterator &operator ++() =0;
    virtual Utf32InputIterator &operator ++(int _) =0;

    virtual shared_ptr<Utf32InputIterator> clone() =0;
    virtual shared_ptr<Utf32InputIterator> cloneReversed() =0;

    virtual void seekBegin();
    virtual void seekEnd() = 0;
};


class DecodeUtf16toUtf32 {
protected:
    unicode_char* org;
    size_t size;

public:
    DecodeUtf16toUtf32(DecodeUtf16toUtf32 &org);
    DecodeUtf16toUtf32(unicode_char *org, size_t size);
    DecodeUtf16toUtf32(unicode_string& org);

    class Iterator: public Utf32InputIterator {
    protected:
        DecodeUtf16toUtf32 *parent;
        size_t pos;
        ucs4_char outbuf;
        char currentCharLen;

        Iterator(DecodeUtf16toUtf32 *parent, size_t pos);
        void refreshState();
        void decodeChar();
        char charNativeLen();
        Utf32InputIterator &forward();
        Utf32InputIterator &backward();
    public:
        virtual void *data() {return parent->org;}
        virtual size_t position() {return pos;}
        virtual ucs4_char operator *();
        virtual ucs4_char_tracer traceCurrent();
        virtual bool operator ==(Iterator &other);
        virtual void seekEnd() { pos = parent->size; }
    };
    class DirectIterator: public Iterator {
        friend class DecodeUtf16toUtf32;
    protected:
        DirectIterator(DecodeUtf16toUtf32 *parent, size_t pos): Iterator(parent, pos) {}
    public:
        // Cycle through all characters and one extra «ending» position.
        virtual Utf32InputIterator &operator ++() {return forward();}
        virtual Utf32InputIterator &operator ++(int) {return forward();}
        virtual void seekBegin() { pos = 0; };

        virtual shared_ptr<Utf32InputIterator> clone();
        virtual shared_ptr<Utf32InputIterator> cloneReversed();
    };
    class ReversedIterator: public Iterator {
        friend class DecodeUtf16toUtf32;
    protected:
        ReversedIterator(DecodeUtf16toUtf32 *parent, size_t pos): Iterator(parent, pos) {}
    public:
        // Cycle through all characters and one extra «ending» position.
        virtual Utf32InputIterator &operator ++() {return backward();}
        virtual Utf32InputIterator &operator ++(int)  {return backward();}
        virtual void seekBegin() { pos = parent->size? parent->size-1 : 0; };

        virtual shared_ptr<Utf32InputIterator> clone();
        virtual shared_ptr<Utf32InputIterator> cloneReversed();
    };

    DirectIterator begin();
    DirectIterator end();
    ReversedIterator rbegin();
    ReversedIterator rend();
};

unicode_string readFileAsUnicodeString(std::string filename, bool *ok = NULL);
bool readFileToVector(std::vector<uint8_t> *buffer, std::string name, bool auto_size = true);

extern std::string temp_file_path;

FILE *MakeTemporaryFile(std::string *pname = NULL);

double GetCurrentTime();

std::string stl_sprintf(const char *fmt, ...);
std::string stl_vsprintf(const char *fmt, va_list args);

void printQuotedString(std::ostream &out, const std::string &sv, bool print_non_printable = true);
void printQuotedString2(std::ostream &out, const std::string &sv);

bool split_string(std::vector<std::string> *out,
                  const std::string &str, const std::string &separator, bool squash_empty);
std::string join_strings(const std::string &separator, const std::vector<std::string> &items);
void tokenize_string(std::vector<std::string> *output, const std::string &input);

#ifdef QT_CORE_LIB
inline unicode_string qt2unicode(QString str) {
    return unicode_string(str.utf16(), str.length());
}
inline QString unicode2qt(const unicode_string &str) {
    return QString::fromUtf16(str.data(), (int) str.size());
}
inline QString unicode2qt(const utf32_string &str) {
    return QString::fromUcs4(str.data(), (int) str.size());
}
#endif

//#include <unordered_map>
//#define STL_HASH_MAP std::unordered_map

/* Very trivial template metaprogramming tools */

namespace TemplateUtils {
    // From boost
    typedef char (&yes)[1];
    typedef char (&no)[2];

    template <typename B, typename D>
    struct Host
    {
      operator B*() const;
      operator D*();
    };

    template <typename B, typename D>
    struct flow_is_base_of
    {
      template <typename T>
      static yes check(D*, T);
      static no check(B*, int);

      static const bool value = sizeof(check(Host<B,D>(), int())) == sizeof(yes);
    };

    template <bool B, class T = void>
    struct enable_if_c {
      typedef T type;
    };

    template <class T>
    struct enable_if_c<false, T> {};

    template <class Cond, class T = void>
    struct enable_if : public enable_if_c<Cond::value, T> {};

    template <class Cond, class T = void>
    struct disable_if : public enable_if_c<!Cond::value, T> {};

    // based on wiki
    template <typename T>
    struct has_typedef_iterator
    {
        template <typename C>
        static yes test(typename C::iterator*);
        template <typename C>
        static no test(...);

        static const bool value = sizeof(test<T>(0)) == sizeof(yes);
    };

    //
    template <class T>
    struct pointer_base_of { typedef void type; };
    template <class T>
    struct pointer_base_of<T*> { typedef T type; };
    template <class T>
    struct pointer_base_of<T*const> { typedef T type; };
}

using TemplateUtils::flow_is_base_of;
using TemplateUtils::enable_if;
using TemplateUtils::disable_if;
using TemplateUtils::pointer_base_of;
using TemplateUtils::has_typedef_iterator;

#endif // STLHELPERS_H
