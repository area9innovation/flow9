/*
 * SHA-256 and HMAC-SHA-256 implementation
 * Based on FIPS PUB 180-4
 * Public domain
 */

#ifndef SHA256_H
#define SHA256_H

#include <cstdint>
#include <string>

class SHA256 {
public:
    SHA256();
    void update(const uint8_t* data, size_t length);
    void update(const std::string& data);
    std::string hexdigest();

    static std::string hash(const std::string& input);

private:
    void transform(const uint8_t* block);
    void finalize();

    uint32_t state[8];
    uint64_t msglen;   // total message length in bits (before current buffer)
    size_t   buflen;   // bytes currently in buffer
    uint8_t  buffer[64];
    uint8_t  digest[32];
    bool     finalized;
};

std::string sha256(const std::string& input);
std::string hmacSha256(const std::string& input, const std::string& key);

#endif // SHA256_H
