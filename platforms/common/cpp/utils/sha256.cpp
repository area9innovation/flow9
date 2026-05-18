/*
 * SHA-256 and HMAC-SHA-256 implementation
 * Based on FIPS PUB 180-4
 * Public domain
 */

#include "sha256.h"
#include <cstring>
#include <sstream>
#include <iomanip>

static const uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static inline uint32_t rotr32(uint32_t x, uint32_t n) {
    return (x >> n) | (x << (32 - n));
}

#define CH(x, y, z)  (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (rotr32(x,  2) ^ rotr32(x, 13) ^ rotr32(x, 22))
#define EP1(x) (rotr32(x,  6) ^ rotr32(x, 11) ^ rotr32(x, 25))
#define SIG0(x) (rotr32(x,  7) ^ rotr32(x, 18) ^ ((x) >>  3))
#define SIG1(x) (rotr32(x, 17) ^ rotr32(x, 19) ^ ((x) >> 10))

SHA256::SHA256() : msglen(0), buflen(0), finalized(false) {
    state[0] = 0x6a09e667;
    state[1] = 0xbb67ae85;
    state[2] = 0x3c6ef372;
    state[3] = 0xa54ff53a;
    state[4] = 0x510e527f;
    state[5] = 0x9b05688c;
    state[6] = 0x1f83d9ab;
    state[7] = 0x5be0cd19;
    memset(buffer, 0, sizeof(buffer));
    memset(digest, 0, sizeof(digest));
}

void SHA256::transform(const uint8_t* block) {
    uint32_t w[64];
    for (int i = 0; i < 16; ++i) {
        w[i] = ((uint32_t)block[i * 4    ] << 24) |
               ((uint32_t)block[i * 4 + 1] << 16) |
               ((uint32_t)block[i * 4 + 2] <<  8) |
               ((uint32_t)block[i * 4 + 3]);
    }
    for (int i = 16; i < 64; ++i) {
        w[i] = SIG1(w[i - 2]) + w[i - 7] + SIG0(w[i - 15]) + w[i - 16];
    }

    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];

    for (int i = 0; i < 64; ++i) {
        uint32_t t1 = h + EP1(e) + CH(e, f, g) + K[i] + w[i];
        uint32_t t2 = EP0(a) + MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

void SHA256::update(const uint8_t* data, size_t length) {
    for (size_t i = 0; i < length; ++i) {
        buffer[buflen++] = data[i];
        if (buflen == 64) {
            transform(buffer);
            buflen = 0;
            msglen += 512;
        }
    }
}

void SHA256::update(const std::string& data) {
    update(reinterpret_cast<const uint8_t*>(data.data()), data.size());
}

void SHA256::finalize() {
    if (finalized) return;
    finalized = true;

    uint64_t totalBits = msglen + buflen * 8;

    buffer[buflen++] = 0x80;
    if (buflen > 56) {
        while (buflen < 64) buffer[buflen++] = 0x00;
        transform(buffer);
        buflen = 0;
    }
    while (buflen < 56) buffer[buflen++] = 0x00;

    // Append total bit length as 64-bit big-endian
    for (int i = 7; i >= 0; --i) {
        buffer[56 + (7 - i)] = (uint8_t)(totalBits >> (i * 8));
    }
    transform(buffer);

    for (int i = 0; i < 8; ++i) {
        digest[i * 4    ] = (uint8_t)(state[i] >> 24);
        digest[i * 4 + 1] = (uint8_t)(state[i] >> 16);
        digest[i * 4 + 2] = (uint8_t)(state[i] >>  8);
        digest[i * 4 + 3] = (uint8_t)(state[i]);
    }
}

std::string SHA256::hexdigest() {
    finalize();
    std::ostringstream oss;
    oss << std::hex << std::setfill('0');
    for (int i = 0; i < 32; ++i) {
        oss << std::setw(2) << (unsigned int)digest[i];
    }
    return oss.str();
}

std::string SHA256::hash(const std::string& input) {
    SHA256 ctx;
    ctx.update(input);
    return ctx.hexdigest();
}

std::string sha256(const std::string& input) {
    return SHA256::hash(input);
}

std::string hmacSha256(const std::string& input, const std::string& key) {
    const size_t BLOCK_SIZE = 64;

    // If key is longer than block size, hash it first into raw bytes
    std::string k;
    if (key.size() > BLOCK_SIZE) {
        std::string hex = sha256(key);
        k.reserve(32);
        for (size_t i = 0; i < hex.size(); i += 2) {
            k += (char)(uint8_t)strtol(hex.substr(i, 2).c_str(), nullptr, 16);
        }
    } else {
        k = key;
    }
    k.resize(BLOCK_SIZE, '\0');

    // Build inner and outer padded keys
    std::string ipad(BLOCK_SIZE, '\x36');
    std::string opad(BLOCK_SIZE, '\x5c');
    for (size_t i = 0; i < BLOCK_SIZE; ++i) {
        ipad[i] ^= k[i];
        opad[i] ^= k[i];
    }

    // Inner hash: H(ipad || input)
    SHA256 inner;
    inner.update(ipad);
    inner.update(input);
    std::string innerHex = inner.hexdigest();

    // Convert inner hex digest to raw bytes
    std::string innerRaw;
    innerRaw.reserve(32);
    for (size_t i = 0; i < innerHex.size(); i += 2) {
        innerRaw += (char)(uint8_t)strtol(innerHex.substr(i, 2).c_str(), nullptr, 16);
    }

    // Outer hash: H(opad || innerRaw)
    SHA256 outer;
    outer.update(opad);
    outer.update(innerRaw);
    return outer.hexdigest();
}
