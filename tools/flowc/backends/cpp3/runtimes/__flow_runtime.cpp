#include "__flow_runtime.hpp"

// C++ runtime for flow

namespace flow {

const string RTTI::type_names[] = {
	u"unknown", u"void",   u"int",   u"bool", u"double", 
	u"string",  u"native", u"array", u"ref",  u"function"
};

string double2string(Double x) { 
	static std::ostringstream os; 
	os << std::setprecision(12) << x;
	std::string str = os.str();
	os.str("");
	os.clear();
	std::size_t point_pos = str.find('.');
	if (point_pos == std::string::npos) {
		return std2string(str);
	} else {
		bool is_integer = true;
		for (std::size_t i = point_pos + 1; i < str.length() && is_integer; ++ i) {
			char ch = str.at(i);
			is_integer = !('1' < ch && ch < '9');
		}
		if (is_integer) {
			return std2string(str.substr(0, point_pos)); 
		} else {
			return std2string(str); 
		}
	}
}

std::string string2std(const string& str) {
	std::size_t len = 0;
	for (std::size_t i = 0; i < str.size(); ++i) {
		char16_t ch = str.at(i);
		uint32_t x = ch;
		if (0xD800 <= ch && ch <= 0xDBFF && i + 1 < str.size()) {
			char16_t ch1 = str.at(i + 1);
			if (0xDC00 <= ch1 && ch1 <= 0xDFFF) {
				// surrogate pair detected
				i += 1;
				x = ((ch & 0x3FF) << 10) + (ch1 & 0x3FF) + 0x10000;
			}
		}
		if (x <= 0x7F) len += 1; else 
		if (x <= 0x7FF) len += 2; else 
		if (x <= 0xFFFF) len += 3; else 
		if (x <= 0x1FFFFF) len += 4; else 
		if (x <= 0x3FFFFFF) len += 5; else
		throw std::runtime_error("broken utf encoding");
	}
	std::string ret;
	ret.reserve(len);
	for (std::size_t i = 0; i < str.size(); ++i) {
		char16_t ch = str.at(i);
		uint32_t x = ch; 
		if (0xD800 <= ch && ch <= 0xDBFF && i + 1 < str.size()) {
			char16_t ch1 = str.at(i + 1);
			if (0xDC00 <= ch1 && ch1 <= 0xDFFF) {
				// surrogate pair detected
				i += 1;
				x = ((ch & 0x3FF) << 10) + (ch1 & 0x3FF) + 0x10000;
			}
		}
		if (x <= 0x7F) {
			ret += x;
		} else if (x <= 0x7FF) {
			ret += (0xC0 | ((x >> 6) & 0x3F));
			ret += (0x80 | (x & 0x3F));
		} else if (x <= 0xFFFF) {
			ret += (0xE0 | ((x >> 12) & 0x3F));
			ret += (0x80 | ((x >> 6)  & 0x3F));
			ret += (0x80 | (x & 0x3F));
		} else if (x <= 0x1FFFFF) {
			ret += (0xF0 | ((x >> 18) & 0x3F));
			ret += (0x80 | ((x >> 12) & 0x3F));
			ret += (0x80 | ((x >> 6)  & 0x3F));
			ret += (0x80 | (x & 0x3F));
		} else if (x <= 0x3FFFFFF) {
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
			h = h - 0x10000;
			str.push_back((char16_t) ((h >> 10)   + 0xD800));
			str.push_back((char16_t) ((h & 0x3FF) + 0xDC00));
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
			h = h - 0x10000;
			str.push_back((char16_t) ((h >> 10)   + 0xD800));
			str.push_back((char16_t) ((h & 0x3FF) + 0xDC00));
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

bool isSameObj(Flow* f1, Flow* f2) {
	bool ret = false;
	if (f1->typeId() == f2->typeId()) {
		switch (f1->typeId()) {
			case TypeFx::VOID:   ret = true; break;
			case TypeFx::INT:    ret = (f1->get<Int>() == f2->get<Int>()); break;
			case TypeFx::BOOL:   ret = (f1->get<Bool>() == f2->get<Bool>()); break;
			case TypeFx::DOUBLE: ret = (f1->get<Double>() == f2->get<Double>()); break;
			case TypeFx::STRING: ret = (f1->get<String*>()->str == f2->get<String*>()->str); break;
			case TypeFx::NATIVE: ret = (f1 == f2); break;
			default:             ret = (f1 == f2); break;
		}
	}
	return ret;
}

void appendEscaped(String* x, string& str) {
	for (char16_t c : x->str) {
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

void flow2string(Flow* v, string& str) {
	switch (v->typeId()) {
		case TypeFx::VOID:   str.append(u"{}"); break;
		case TypeFx::INT:    str.append(int2string(v->get<Int>())); break;
		case TypeFx::BOOL:   str.append(bool2string(v->get<Bool>())); break;
		case TypeFx::DOUBLE: str.append(double2string(v->get<Double>())); break;
		case TypeFx::STRING: {
			str.append(u"\""); appendEscaped(v->get<String*>(), str); str.append(u"\"");
			break;
		}
		case TypeFx::ARRAY: {
			str.append(u"[");
			bool first = true;
			for (Int i = 0; i < v->size(); ++i) {
				if (!first) {
					str.append(u", ");
				}
				Flow* f = v->getFlow(i);
				flow2string(f, str);
				rc(f, -1);
				first = false;
			}
			str.append(u"]");
			break;
		}
		case TypeFx::REF: {
			str.append(u"ref ");
			Flow* f = v->getFlow(0);
			flow2string(f, str);
			rc(f, -1);
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
			bool first = true;
			for (Int i = 0; i < v->size(); ++ i) {
				if (!first) {
					str.append(u", ");
				}
				Flow* f = v->getFlow(i);
				flow2string(f, str);
				rc(f, -1);
				first = false;
			}
			str.append(u")");
			break;
		}
	}
}

String* flow2string(Flow* f) { 
	string os; 
	flow2string(f, os);
	return new String(os); 
}

Int compareFlow(Flow* v1, Flow* v2) {
	Int ret = 0;
	if (v1->typeId() != v2->typeId()) {
		ret = compare<Int>(v1->typeId(), v2->typeId());
	} else {
		switch (v1->typeId()) {
			case TypeFx::VOID:   ret = 0; break;
			case TypeFx::INT:    ret = compare<Int>(v1->get<Int>(), v2->get<Int>()); break;
			case TypeFx::BOOL:   ret = compare<Bool>(v1->get<Bool>(), v2->get<Bool>()); break;
			case TypeFx::DOUBLE: ret = compare<Double>(v1->get<Double>(), v2->get<Double>()); break;
			case TypeFx::STRING: ret = v1->get<String*>()->str.compare(v2->get<String*>()->str); break;
			case TypeFx::ARRAY: {
				Int c1 = compare<Int>(v1->size(), v2->size());
				if (c1 != 0) {
					ret = c1;
				} else {
					for (Int i = 0; i < v1->size(); ++ i) {
						Int c2 = compareFlow(v1->getFlow(i), v2->getFlow(i));
						if (c2 != 0) {
							ret = c2;
							break;
						}
					}
					ret = 0;
				}
				break;
			}
			case TypeFx::REF: {
				Int c = compareFlow(v1->getFlow(0), v2->getFlow(0));
				ret = c;
				break;
			}
			case TypeFx::FUNC: {
				ret = compare<void*>(v1, v2);
				break;
			}
			case TypeFx::NATIVE: {
				ret = compare<void*>(v1, v2);
				break;
			}
			default: {
				case TypeFx::STRUCT: {
					Int c1 = RTTI::typeName(v1->typeId()).compare(RTTI::typeName(v2->typeId()));
					if (c1 != 0) {
						ret = c1;
					} else {
						for (Int i = 0; i < v1->size(); ++ i) {
							Int c2 = compareFlow(v1->getFlow(i), v2->getFlow(i));
							if (c2 != 0) {
								ret = c2;
								break;
							}
						}
						ret = 0;
					}
				}
				break;
			}
		}
	}
	return ret;
}

/*

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
	return hash<uint64_t>(h, reinterpret_cast<uint64_t>(n->nat));
}
template<> uint32_t hash(uint32_t h, Flow* n);

template<typename T> struct Hash { inline size_t operator() (T n) const { return hash(FNV_offset_basis, n); } };


template<> uint32_t hash(uint32_t h, Flow* v) {
	uint32_t ret = 0;
	switch (v->typeId()) {
		case TypeFx::INT:    ret = hash(h, v->get<Int>()); break;
		case TypeFx::BOOL:   ret = hash(h, v->get<Bool>()); break;
		case TypeFx::DOUBLE: ret = hash(h, v->get<Double>()); break;
		case TypeFx::STRING: ret = hash(h, v->get<String*>()); break;
		case TypeFx::ARRAY: {
			AVec* a = v->get<AVec*>();
			for (Int i = 0; i < a->size(); ++i) {
				h = hash(h, a->getFlowItem(i));
			}
			ret = h;
			break;
		}
		case TypeFx::REF:
			ret = hash(h, reinterpret_cast<uint64_t>(v->get<ARef*>()->getFlowRef().ptr));
			break;
		case TypeFx::FUNC:
			ret = hash(h, reinterpret_cast<uint64_t>(v->get<AFun*>().ptr));
			break;
		case TypeFx::NATIVE: 
			ret = hash(h, v->get<Native*>());
			break;
		default: {
			AStr* s = v->get<AStr*>();
			h = hash(h, s->name());
			for (Int i = 0; i < s->size(); ++ i) {
				h = hash(h, s->getFlowField(i));
			}
			ret = h;
			break;
		}
	}
	return ret;
}

*/

}
