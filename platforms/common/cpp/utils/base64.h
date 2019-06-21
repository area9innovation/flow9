#ifndef BASE64_H
#define BASE64_H

#include <cstring>
#include <cstdlib>

class Base64
{
public:
    static unsigned char * encode(const unsigned char *src, size_t len,
                      size_t *out_len);
    static unsigned char * decode(const unsigned char *src, size_t len,
                      size_t *out_len);
};

#endif // BASE64_H
