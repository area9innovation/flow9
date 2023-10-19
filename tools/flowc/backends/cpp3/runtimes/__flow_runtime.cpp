#include "__flow_runtime.hpp"

// C++ runtime for flow

namespace flow {

const string RTTI::type_names[] = {
	u"unknown", u"void",   u"int",   u"bool", u"double", 
	u"string",  u"native", u"array", u"ref",  u"function"
};

std::unordered_map<string, int32_t> RTTI::struct_name_to_id;

string double2string(Double x, bool persistent_dot) {
	std::stringstream os;
	os << std::setprecision(15) << x;
	std::string str = os.str();
	os.str("");
	os.clear();
	std::size_t point_pos = str.find('.');
	if (point_pos != std::string::npos) {
		bool trailing_zeroes = true;
		for (std::size_t i = point_pos + 1; i < str.length() && trailing_zeroes; ++ i) {
			char ch = str.at(i);
			trailing_zeroes = !('1' <= ch && ch <= '9');
		}
		if (trailing_zeroes) {
			str = str.substr(0, point_pos);
		}
	}
	if (persistent_dot && str.find('.') == std::string::npos) {
		str.append(".0");
	}
	return std2string(str);
}

unsigned int2stringLen(unsigned __value, int __base = 10) noexcept {
	unsigned __n = 1;
	const unsigned __b2 = __base  * __base;
	const unsigned __b3 = __b2 * __base;
	const unsigned long __b4 = __b3 * __base;
	for (;;) {
		if (__value < (unsigned)__base) return __n;
		if (__value < __b2) return __n + 1;
		if (__value < __b3) return __n + 2;
		if (__value < __b4) return __n + 3;
		__value /= __b4;
		__n += 4;
	}
}

void int2stringImpl(char16_t* __first, unsigned __len, unsigned __val) noexcept {
    static constexpr char __digits[201] =
	"0001020304050607080910111213141516171819"
	"2021222324252627282930313233343536373839"
	"4041424344454647484950515253545556575859"
	"6061626364656667686970717273747576777879"
	"8081828384858687888990919293949596979899";
	unsigned __pos = __len - 1;
	while (__val >= 100) {
		auto const __num = (__val % 100) * 2;
		__val /= 100;
		__first[__pos] = __digits[__num + 1];
		__first[__pos - 1] = __digits[__num];
		__pos -= 2;
	}
	if (__val >= 10) {
		auto const __num = __val * 2;
		__first[1] = __digits[__num + 1];
		__first[0] = __digits[__num];
	} else {
		__first[0] = '0' + __val;
	}
}

string int2string(Int __val) noexcept {
	const bool __neg = __val < 0;
    const unsigned __uval = __neg ? (unsigned)~__val + 1u : __val;
    const auto __len = int2stringLen(__uval);
    string __str(__neg + __len, '-');
    int2stringImpl(&__str[__neg], __len, __uval);
    return __str;
}

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

void appendEscaped(string& str, const string& x) {
	for (char16_t c : x) {
		switch (c) {
			case '"':  str.append(u"\\\""); break;
			case '\\': str.append(u"\\\\"); break;
			case '\n': str.append(u"\\n");  break;
			case '\t': str.append(u"\\t");  break;
			case '\r': str.append(u"\\r");  break;
			default: str += c; break;
		}
	}
}

inline void flow2stringComponents(Flow* v, string& str, Int i) {
	if (i > 0) {
		str.append(u", ");
	}
	switch (v->componentTypeId(i)) {
		case TypeFx::INT:    str.append(int2string(v->getIntRc1(i))); break;
		case TypeFx::BOOL:   str.append(bool2string(v->getBoolRc1(i))); break;
		case TypeFx::DOUBLE: str.append(double2string(v->getDoubleRc1(i))); break;
		default:             flow2string(v->getFlow(i), str);
	}
}

void flow2string(Flow* v, string& str) {
	switch (v->typeId()) {
		case TypeFx::VOID:   str.append(u"{}"); break;
		case TypeFx::INT:    str.append(int2string(v->get<Int>())); break;
		case TypeFx::BOOL:   str.append(bool2string(v->get<Bool>())); break;
		case TypeFx::DOUBLE: str.append(double2string(v->get<Double>(), true)); break;
		case TypeFx::STRING: {
			str.append(u"\""); appendEscaped(str, v->get<String*>()->str()); str.append(u"\"");
			break;
		}
		case TypeFx::ARRAY: {
			str.append(u"[");
			Int size = v->componentSize();
			for (Int i = 0; i < size; ++i) {
				flow2stringComponents(v, str, i);
			}
			str.append(u"]");
			break;
		}
		case TypeFx::REF: {
			str.append(u"ref ");
			flow2stringComponents(v, str, 0);
			break;
		}
		case TypeFx::FUNC: {
			str.append(u"<function>");
			break;
		}
		case TypeFx::NATIVE: {
			str.append(u"<native>");
			break;
		}
		default: {
			str.append(RTTI::typeName(v->typeId()));
			str.append(u"(");
			Int size = v->componentSize();
			for (Int i = 0; i < size; ++ i) {
				flow2stringComponents(v, str, i);
			}
			str.append(u")");
			break;
		}
	}
}

inline Int flowCompareComponents(Flow* v1, Flow* v2, Int i) {
	TypeId type_id1 = v1->componentTypeId(i);
	TypeId type_id2 = v2->componentTypeId(i);
	if (type_id1 == type_id2) {
		switch (type_id1) {
			case TypeFx::INT:    return compare<Int>(v1->getIntRc1(i), v2->getIntRc1(i));
			case TypeFx::BOOL:   return compare<Bool>(v1->getBoolRc1(i), v2->getBoolRc1(i));
			case TypeFx::DOUBLE: return compare<Double>(v1->getDoubleRc1(i), v2->getDoubleRc1(i));
			default:             return flowCompare(v1->getFlow(i), v2->getFlow(i));
		}
	} else {
		if (type_id1 != TypeFx::FLOW && type_id2 != TypeFx::FLOW) {
			return compare<TypeId>(type_id1, type_id2);
		} else {
			return flowCompare(v1->getFlow(i), v2->getFlow(i));
		}
	}
}

Int flowCompare(Flow* v1, Flow* v2) {
	TypeId type_id1 = v1->typeId();
	TypeId type_id2 = v2->typeId();
	if (type_id1 != type_id2) {
		return compare<Int>(type_id1, type_id2);
	} else {
		switch (type_id1) {
			case TypeFx::VOID:   return 0;
			case TypeFx::INT:    return compare<Int>(v1->get<Int>(), v2->get<Int>());
			case TypeFx::BOOL:   return compare<Bool>(v1->get<Bool>(), v2->get<Bool>());
			case TypeFx::DOUBLE: return compare<Double>(v1->get<Double>(), v2->get<Double>());
			case TypeFx::STRING: return compare<String*>(v1->get<String*>(), v2->get<String*>());
			case TypeFx::ARRAY: {
				Int c1 = compare<Int>(v1->componentSize(), v2->componentSize());
				if (c1 != 0) {
					return c1;
				} else {
					Int size = v1->componentSize();
					for (Int i = 0; i < size; ++ i) {
						Int c2 = flowCompareComponents(v1, v2, i);
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case TypeFx::REF: {
				return flowCompareComponents(v1, v2, 0);
			}
			case TypeFx::FUNC: {
				return compare<void*>(v1, v2);
			}
			case TypeFx::NATIVE: {
				return compare<void*>(v1, v2);
			}
			default: {
				Int size = v1->componentSize();
				for (Int i = 0; i < size; ++ i) {
					Int c = flowCompareComponents(v1, v2, i);
					if (c != 0) {
						return c;
					}
				}
				return 0;
			}
		}
	}
}

}
