#include "__flow_runtime.hpp"

// C++ runtime for flow

namespace flow {

const string RTTI::type_names[] = {
	u"unknown", u"void",   u"int",   u"bool", u"double", 
	u"string",  u"native", u"array", u"ref",  u"function"
};

std::unordered_map<string, int32_t> RTTI::struct_name_to_id;

string double2string(Double x, bool persistent_dot) {
	static std::stringstream os;
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

std::string string2std(const string& str) {
	std::size_t len = 0;
	for (std::size_t i = 0; i < str.size(); ++i) {
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
		if (x < 0x30) len += 1; else
		if (x < 0x800) len += 2; else
		if (x < 0x10000) len += 3; else
		if (x < 0x10FFFF) len += 4; else len += 5;
	}
	std::string ret;
	ret.reserve(len);
	for (std::size_t i = 0; i < str.size(); ++i) {
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
	return ret; 
}

string std2string(const std::string& s) {
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
	string str;
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
	return str;
}

bool isSameObjRc(Flow* f1, Flow* f2) {
	if (f1->typeId() == f2->typeId()) {
		switch (f1->typeId()) {
			case TypeFx::VOID:   decRc(f1); decRc(f2); return true;
			case TypeFx::INT:    return equalRc<Int>(f1->getRc<Int>(), f2->getRc<Int>());
			case TypeFx::BOOL:   return equalRc<Bool>(f1->getRc<Bool>(), f2->getRc<Bool>());
			case TypeFx::DOUBLE: return equalRc<Double>(f1->getRc<Double>(), f2->getRc<Double>());
			case TypeFx::STRING: return equalRc<String*>(f1->getRc<String*>(), f2->getRc<String*>());
			case TypeFx::NATIVE: decRc(f1); decRc(f2); return (f1 == f2);
			default:             decRc(f1); decRc(f2); return (f1 == f2);
		}
	}
}

void appendEscaped(string& str, const string& x) {
	for (char16_t c : x) {
		switch (c) {
			case '"': str.append(u"\\\"");  break;
			case '\\': str.append(u"\\\\"); break;
			case '\n': str.append(u"\\n");  break;
			case '\t': str.append(u"\\t");  break;
			case '\r': str.append(u"\\r");  break;
			default: str += c; break;
		}
	}
}

void flow2stringComponents(Flow* v, string& str, Int i) {
	if (i > 0) {
		str.append(u", ");
	}
	switch (v->componentTypeId(i)) {
		case TypeFx::INT:
		case TypeFx::BOOL:
		case TypeFx::DOUBLE: {
			Flow* component = v->getFlowRc1(i);
			flow2string(component, str);
			decRc(component);
			break;
		}
		default: flow2string(v->getFlow(i), str);
	}
}

void flow2string(Flow* v, string& str) {
	switch (v->typeId()) {
		case TypeFx::VOID:   str.append(u"{}"); break;
		case TypeFx::INT:    str.append(int2string(v->get<Int>())); break;
		case TypeFx::BOOL:   str.append(bool2string(v->get<Bool>())); break;
		case TypeFx::DOUBLE: str.append(double2string(v->get<Double>(), true)); break;
		case TypeFx::STRING: {
			str.append(u"\""); appendEscaped(str, v->get<String*>()->str); str.append(u"\"");
			break;
		}
		case TypeFx::ARRAY: {
			str.append(u"[");
			Int size = v->size();
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
			Int size = v->size();
			for (Int i = 0; i < size; ++ i) {
				flow2stringComponents(v, str, i);
			}
			str.append(u")");
			break;
		}
	}
}

Int flowCompareComponents(Flow* v1, Flow* v2, Int i) {
	Int c = 0;
	switch (v1->componentTypeId(i)) {
		case TypeFx::INT:
		case TypeFx::BOOL:
		case TypeFx::DOUBLE: {
			Flow* component1 = v1->getFlowRc1(i);
			switch (v2->componentTypeId(i)) {
				case TypeFx::INT:
				case TypeFx::BOOL:
				case TypeFx::DOUBLE: {
					Flow* component2 = v2->getFlowRc1(i);
					c = flowCompare(component1, component2);
					decRc(component2);
					break;
				}
				default: {
					c = flowCompare(component1, v2->getFlow(i));
				}
			}
			decRc(component1);
			break;
		}
		default: {
			switch (v2->componentTypeId(i)) {
				case TypeFx::INT:
				case TypeFx::BOOL:
				case TypeFx::DOUBLE: {
					Flow* component2 = v2->getFlowRc1(i);
					c = flowCompare(v1->getFlow(i), component2);
					decRc(component2);
					break;
				}
				default: {
					c = flowCompare(v1->getFlow(i), v2->getFlow(i));
				}
			}
		}
	}
	return c;
}

Int flowCompare(Flow* v1, Flow* v2) {
	if (v1->typeId() != v2->typeId()) {
		return compare<Int>(v1->typeId(), v2->typeId());
	} else {
		switch (v1->typeId()) {
			case TypeFx::VOID:   return 0;
			case TypeFx::INT:    return compare<Int>(v1->get<Int>(), v2->get<Int>());
			case TypeFx::BOOL:   return compare<Bool>(v1->get<Bool>(), v2->get<Bool>());
			case TypeFx::DOUBLE: return compare<Double>(v1->get<Double>(), v2->get<Double>());
			case TypeFx::STRING: return compare<String*>(v1->get<String*>(), v2->get<String*>());
			case TypeFx::ARRAY: {
				Int c1 = compare<Int>(v1->size(), v2->size());
				if (c1 != 0) {
					return c1;
				} else {
					Int size = v1->size();
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
				case TypeFx::STRUCT: {
					Int c1 = RTTI::typeName(v1->typeId()).compare(RTTI::typeName(v2->typeId()));
					if (c1 != 0) {
						return c1;
					} else {
						Int size = v1->size();
						for (Int i = 0; i < size; ++ i) {
							Int c2 = flowCompareComponents(v1, v2, i);
							if (c2 != 0) {
								return c2;
							}
						}
						return 0;
					}
				}
			}
		}
	}
}

/*
template<typename T> struct Hash { inline size_t operator() (T n) const { return hash(FNV_offset_basis, n); } };

const uint32_t FNV_offset_basis = 0x811C9DC5;
const uint32_t FNV_prime = 16777619;

template<typename T> uint32_t hash(uint32_t h, T v);
template<> inline uint32_t hash(uint32_t h, Bool v) { 
	return (h ^ static_cast<uint8_t>(v)) * FNV_prime; 
}
template<> inline uint32_t hash(uint32_t h, Int v) {
	uint32_t v1 = static_cast<uint32_t>(v);
	h = (h ^ ( v1        & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 8)  & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 16) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 24) & 0xFF)) * FNV_prime;
	return h;
}
template<> inline uint32_t hash(uint32_t h, uint64_t v1) { 
	h = (h ^ ( v1        & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 8)  & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 16) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 24) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 32) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 40) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 48) & 0xFF)) * FNV_prime;
	h = (h ^ ((v1 >> 56) & 0xFF)) * FNV_prime;
	return h;
}
template<> inline uint32_t hash(uint32_t h, Double v) { 
	return hash<uint64_t>(h, static_cast<uint64_t>(v));
}
template<> inline uint32_t hash(uint32_t h, void* v) { 
	return hash<uint64_t>(h, reinterpret_cast<uint64_t>(v));
}
template<> inline uint32_t hash(uint32_t h, const void* v) { 
	return hash<uint64_t>(h, reinterpret_cast<uint64_t>(v));
}
template<> inline uint32_t hash(uint32_t h, String* v) {
	for (char16_t c : v->str) {
		h = (h ^ ( c       & 0xFF)) * FNV_prime;
		h = (h ^ ((c >> 8) & 0xFF)) * FNV_prime;
	}
	return h; 
}
template<> inline uint32_t hash(uint32_t h, Native* n) { 
	return hash<uint64_t>(h, reinterpret_cast<uint64_t>(n));
}
template<> uint32_t hash(uint32_t h, Flow* n);

template<> uint32_t hash(uint32_t h, Flow* v) {
	uint32_t ret = 0;
	switch (v->typeId()) {
		case TypeFx::INT:    ret = hash(h, v->get<Int>()); break;
		case TypeFx::BOOL:   ret = hash(h, v->get<Bool>()); break;
		case TypeFx::DOUBLE: ret = hash(h, v->get<Double>()); break;
		case TypeFx::STRING: ret = hash(h, v->get<String*>()); break;
		case TypeFx::ARRAY: {
			for (Int i = 0; i < v->size(); ++i) {
				incRc(v);
				h = hash(h, v->getFlowRc(i));
			}
			ret = h;
			break;
		}
		case TypeFx::REF:
			ret = hash(h, reinterpret_cast<uint64_t>(v->getFlowRc(0)));
			break;
		case TypeFx::FUNC:
			ret = hash(h, reinterpret_cast<uint64_t>(v));
			break;
		case TypeFx::NATIVE: 
			ret = hash(h, v->get<Native*>());
			break;
		default: {
			h = hash(h, v->typeId());
			for (Int i = 0; i < v->size(); ++ i) {
				incRc(v);
				h = hash(h, v->getFlowRc(i));
			}
			ret = h;
			break;
		}
	}
	return ret;
}
*/


}
