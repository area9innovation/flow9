#ifndef CHAR_TRAITS_FIX_H
#define CHAR_TRAITS_FIX_H

#include <string>

// Template for creating char_traits specializations
#define DEFINE_CHAR_TRAITS_FOR_TYPE(TYPE) \
namespace std { \
    template<> \
    struct char_traits<TYPE> { \
        typedef TYPE char_type; \
        typedef int int_type; \
        typedef streamoff off_type; \
        typedef streampos pos_type; \
        typedef mbstate_t state_type; \
 \
        static void assign(char_type& c1, const char_type& c2) noexcept { c1 = c2; } \
        static bool eq(const char_type& c1, const char_type& c2) noexcept { return c1 == c2; } \
        static bool lt(const char_type& c1, const char_type& c2) noexcept { return c1 < c2; } \
 \
        static int compare(const char_type* s1, const char_type* s2, size_t n) { \
            for (size_t i = 0; i < n; ++i) { \
                if (lt(s1[i], s2[i])) return -1; \
                if (lt(s2[i], s1[i])) return 1; \
            } \
            return 0; \
        } \
 \
        static size_t length(const char_type* s) { \
            size_t len = 0; \
            while (!eq(s[len], char_type(0))) ++len; \
            return len; \
        } \
 \
        static const char_type* find(const char_type* s, size_t n, const char_type& a) { \
            for (size_t i = 0; i < n; ++i) { \
                if (eq(s[i], a)) return s + i; \
            } \
            return nullptr; \
        } \
 \
        static char_type* move(char_type* s1, const char_type* s2, size_t n) { \
            if (n == 0) return s1; \
            return static_cast<char_type*>(memmove(s1, s2, n * sizeof(char_type))); \
        } \
 \
        static char_type* copy(char_type* s1, const char_type* s2, size_t n) { \
            if (n == 0) return s1; \
            return static_cast<char_type*>(memcpy(s1, s2, n * sizeof(char_type))); \
        } \
 \
        static char_type* assign(char_type* s, size_t n, char_type a) { \
            for (size_t i = 0; i < n; ++i) { \
                s[i] = a; \
            } \
            return s; \
        } \
 \
        static int_type not_eof(const int_type& c) noexcept { \
            return (c == eof()) ? 0 : c; \
        } \
 \
        static char_type to_char_type(const int_type& c) noexcept { \
            return static_cast<char_type>(c); \
        } \
 \
        static int_type to_int_type(const char_type& c) noexcept { \
            return static_cast<int_type>(c); \
        } \
 \
        static bool eq_int_type(const int_type& c1, const int_type& c2) noexcept { \
            return c1 == c2; \
        } \
 \
        static int_type eof() noexcept { \
            return static_cast<int_type>(-1); \
        } \
    }; \
}

// Define specializations for both uint16_t and uint32_t (unsigned int)
DEFINE_CHAR_TRAITS_FOR_TYPE(uint16_t)
DEFINE_CHAR_TRAITS_FOR_TYPE(uint32_t)

#endif // CHAR_TRAITS_FIX_H
