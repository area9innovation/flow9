#include <ostream>
#include <istream>
#include "__flow_runtime_string.hpp"

namespace flow {

IntStats string_leng_stats;

inline uint32_t getCodePoint(const string& str, std::size_t& i) {
	char16_t ch = str.at(i);
	uint32_t x = ch;
	if (UNI_SUR_HIGH_START <= ch && ch <= UNI_SUR_HIGH_END && i + 1 < str.size()) {
		char16_t ch1 = str.at(i + 1);
		if (UNI_SUR_LOW_START <= ch1 && ch1 <= UNI_SUR_LOW_END) {
			// surrogate pair detected
			i += 1;
			x = ((ch & UNI_HALF_MASK) << UNI_HALF_SHIFT) + (ch1 & UNI_HALF_MASK) + UNI_HALF_BASE;
		}
	}
	return x;
}

void copyString2std(const string& str, std::string& ret) {
	std::size_t len = 0;
	for (std::size_t i = 0; i < str.size(); ++i) {
		uint32_t x = getCodePoint(str, i);
		if (x < 0x30) len += 1; else
		if (x < 0x800) len += 2; else
		if (x < 0x10000) len += 3; else
		if (x < 0x10FFFF) len += 4; else len += 5;
	}
	ret.reserve(len);
	for (std::size_t i = 0; i < str.size(); ++i) {
		uint32_t x = getCodePoint(str, i);
		if (x < 0x80) {
			ret += x;
		} else if (x < 0x800) {
			ret += (0xC0 | ((x >> 6) & 0x3F));
			ret += (0x80 | (x & 0x3F));
		} else if (x < 0x10000) {
			ret += (0xE0 | ((x >> 12) & 0x3F));
			ret += (0x80 | ((x >> 6)  & 0x3F));
			ret += (0x80 | (x & 0x3F));
		} else if (x < 0x10FFFF) {
			ret += (0xF0 | ((x >> 18) & 0x3F));
			ret += (0x80 | ((x >> 12) & 0x3F));
			ret += (0x80 | ((x >> 6)  & 0x3F));
			ret += (0x80 | (x & 0x3F));
		} else {
			ret += (0xF8 | ((x >> 24) & 0x3F));
			ret += (0x80 | ((x >> 18) & 0x3F));
			ret += (0x80 | ((x >> 12) & 0x3F));
			ret += (0x80 | ((x >> 6)  & 0x3F));
			ret += (0x80 | (x & 0x3F));
		}
	}
}

void string2ostream(const string& str, std::ostream& os) {
	for (std::size_t i = 0; i < str.size(); ++i) {
		uint32_t x = getCodePoint(str, i);
		if (x < 0x80) {
			os << static_cast<char>(x);
		} else if (x < 0x800) {
			os << static_cast<char>(0xC0 | ((x >> 6) & 0x3F));
			os << static_cast<char>(0x80 | (x & 0x3F));
		} else if (x < 0x10000) {
			os << static_cast<char>(0xE0 | ((x >> 12) & 0x3F));
			os << static_cast<char>(0x80 | ((x >> 6)  & 0x3F));
			os << static_cast<char>(0x80 | (x & 0x3F));
		} else if (x < 0x10FFFF) {
			os << static_cast<char>(0xF0 | ((x >> 18) & 0x3F));
			os << static_cast<char>(0x80 | ((x >> 12) & 0x3F));
			os << static_cast<char>(0x80 | ((x >> 6)  & 0x3F));
			os << static_cast<char>(0x80 | (x & 0x3F));
		} else {
			os << static_cast<char>(0xF8 | ((x >> 24) & 0x3F));
			os << static_cast<char>(0x80 | ((x >> 18) & 0x3F));
			os << static_cast<char>(0x80 | ((x >> 12) & 0x3F));
			os << static_cast<char>(0x80 | ((x >> 6)  & 0x3F));
			os << static_cast<char>(0x80 | (x & 0x3F));
		}
	}
}

void copyStd2string(const std::string& s, string& str) {
	std::size_t len = 0;
	for (std::size_t i = 0; i < s.length(); ++i) {
		uint8_t ch = s.at(i);
		if ((ch & 0xFC) == 0xF8 && i < len - 4) {
			i += 4; len += 2;
		} else if ((ch & 0xF8) == 0xF0 && i < len - 3) {
			i += 3; len +=2;
		} else if ((ch & 0xF0) == 0xE0 && i < len - 2) {
			i += 2; len += 1;
		} else if ((ch & 0xE0) == 0xC0 && i < len - 1) {
			i += 1; len += 1;
		} else { 
			len += 1;
		}
	}
	str.reserve(len);
	for (std::size_t i = 0; i < s.length(); ++i) {
		uint8_t b1 = s.at(i);

		if ((b1 & 0xFC) == 0xF8 && i < s.length() - 4) {
			uint8_t b2 = s.at(i + 1);
			uint8_t b3 = s.at(i + 2);
			uint8_t b4 = s.at(i + 3);
			uint8_t b5 = s.at(i + 4);
			i += 4;

			uint32_t h1 = (b1 & 0x3)  << 24;
			uint32_t h2 = (b2 & 0x3F) << 18;
			uint32_t h3 = (b3 & 0x3F) << 12;
			uint32_t h4 = (b4 & 0x3F) << 6;
			uint32_t h5 = 0x3F & b5;

			uint32_t h = h1 | h2 | h3 | h4 | h5;

			// Surrogate pair
			h = h - UNI_HALF_BASE;
			str.push_back((char16_t) ((h >> UNI_HALF_SHIFT)   + UNI_SUR_HIGH_START));
			str.push_back((char16_t) ((h & UNI_HALF_MASK) + UNI_SUR_LOW_START));
		} else if ((b1 & 0xF8) == 0xF0 && i < s.length() - 3) {
			uint8_t b2 = s.at(i + 1);
			uint8_t b3 = s.at(i + 2);
			uint8_t b4 = s.at(i + 3);
			i += 3;

			uint32_t h1 = (b1 & 0x7)  << 18;
			uint32_t h2 = (b2 & 0x3F) << 12;
			uint32_t h3 = (b3 & 0x3F) << 6;
			uint32_t h4 = 0x3F & b4;

			uint32_t h = h1 | h2 | h3 | h4;

			// Surrogate pair
			h = h - UNI_HALF_BASE;
			str.push_back((char16_t) ((h >> UNI_HALF_SHIFT)   + UNI_SUR_HIGH_START));
			str.push_back((char16_t) ((h & UNI_HALF_MASK) + UNI_SUR_LOW_START));
		} else if ((b1 & 0xF0) == 0xE0 && i < s.length() - 2) {
			uint8_t b2 = s.at(i + 1);
			uint8_t b3 = s.at(i + 2);
			i += 2;

			char16_t h1 = (b1 & 0xF)  << 12;
			char16_t h2 = (b2 & 0x3F) << 6;
			char16_t h3 = 0x3F & b3;

			char16_t h = h1 | h2 | h3;

			str.push_back(h);
		} else if ((b1 & 0xE0) == 0xC0 && i < s.length() - 1) {
			uint8_t b2 = s.at(i + 1);
			i += 1;

			char16_t h1 = (b1 & 0x1F) << 6;
			char16_t h2 = 0x3F & b2;
			char16_t h = h1 | h2;

			str.push_back(h);
		} else {
			char16_t h = b1 & 0xff;
			str.push_back(h);
		}
	}
}

void istream2string(std::istream& is, string& str) {
	std::size_t len = is.tellg();
	is.seekg(0);
	str.reserve(str.length() + len);
	for (std::size_t i = 0; i < len; ++ i) {
		uint8_t b1 = is.get();

		if ((b1 & 0xFC) == 0xF8 && i < len - 4) {
			uint8_t b2 = is.get();
			uint8_t b3 = is.get();
			uint8_t b4 = is.get();
			uint8_t b5 = is.get();
			i += 4;

			uint32_t h1 = (b1 & 0x3)  << 24;
			uint32_t h2 = (b2 & 0x3F) << 18;
			uint32_t h3 = (b3 & 0x3F) << 12;
			uint32_t h4 = (b4 & 0x3F) << 6;
			uint32_t h5 = 0x3F & b5;

			uint32_t h = h1 | h2 | h3 | h4 | h5;

			// Surrogate pair
			h = h - UNI_HALF_BASE;
			str.push_back((char16_t) ((h >> UNI_HALF_SHIFT)   + UNI_SUR_HIGH_START));
			str.push_back((char16_t) ((h & UNI_HALF_MASK) + UNI_SUR_LOW_START));
		} else if ((b1 & 0xF8) == 0xF0 && i < len - 3) {
			uint8_t b2 = is.get();
			uint8_t b3 = is.get();
			uint8_t b4 = is.get();
			i += 3;

			uint32_t h1 = (b1 & 0x7)  << 18;
			uint32_t h2 = (b2 & 0x3F) << 12;
			uint32_t h3 = (b3 & 0x3F) << 6;
			uint32_t h4 = 0x3F & b4;

			uint32_t h = h1 | h2 | h3 | h4;

			// Surrogate pair
			h = h - UNI_HALF_BASE;
			str.push_back((char16_t) ((h >> UNI_HALF_SHIFT)   + UNI_SUR_HIGH_START));
			str.push_back((char16_t) ((h & UNI_HALF_MASK) + UNI_SUR_LOW_START));
		} else if ((b1 & 0xF0) == 0xE0 && i < len - 2) {
			uint8_t b2 = is.get();
			uint8_t b3 = is.get();
			i += 2;

			char16_t h1 = (b1 & 0xF)  << 12;
			char16_t h2 = (b2 & 0x3F) << 6;
			char16_t h3 = 0x3F & b3;

			char16_t h = h1 | h2 | h3;

			str.push_back(h);
		} else if ((b1 & 0xE0) == 0xC0 && i < len - 1) {
			uint8_t b2 = is.get();
			i += 1;

			char16_t h1 = (b1 & 0x1F) << 6;
			char16_t h2 = 0x3F & b2;
			char16_t h = h1 | h2;

			str.push_back(h);
		} else {
			char16_t h = b1 & 0xff;
			str.push_back(h);
		}
	}
}

String* String::concatRc(String* s1, String* s2) {
	if (s2->str_.size() == 0) {
		decRc(s2);
		return s1;
	} else if (s1->str_.size() == 0) {
		decRc(s1);
		return s2;
	} else if (isUnitRc(s1)) {
		s1->strRef().reserve(s1->str_.size() + s2->str_.size());
		s1->str_ += s2->str_;
		decRc(s2);
		return s1;
	} else {
		string ret;
		ret.reserve(s1->str_.size() + s2->str_.size());
		ret += s1->str_;
		ret += s2->str_;
		decRc(s1); decRc(s2);
		return String::make(std::move(ret));
	}
}

}
