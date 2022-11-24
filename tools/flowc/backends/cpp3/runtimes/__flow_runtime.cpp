#include "__flow_runtime.hpp"

// C++ runtime for flow

namespace flow {

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

const char* type2s(Int type) { 
	switch (type) {
		case Type::INT:    return "int";
		case Type::BOOL:   return "bool";
		case Type::DOUBLE: return "double";
		case Type::STRING: return "string";
		case Type::ARRAY:  return "array";
		case Type::REF:    return "ref";
		case Type::FUNC:   return "function";
		case Type::NATIVE: return "native";
		default:           return "struct";
	} 
}

bool AFlow::isSameObj(Flow f) const { 
	if (type() != f->type()) {
		return false;
	} else {
		switch (type()) {
			case Type::INT:    return getInt() == f->getInt();
			case Type::BOOL:   return getBool() == f->getBool();
			case Type::DOUBLE: return getDouble() == f->getDouble();
			case Type::STRING: return getString()->str == f->getString()->str;
			case Type::NATIVE: return getNative()->nat == f->getNative()->nat;
			default:           return this == f.ptr;
		}
	}
}

void flow2string(Flow v, string& str) {
	switch (v->type()) {
		case Type::INT:    str.append(int2string(v->getInt())); break;
		case Type::BOOL:   str.append(bool2string(v->getBool())); break;
		case Type::DOUBLE: str.append(double2string(v->getDouble())); break;
		case Type::STRING: {
			str.append(u"\"");
			for (char16_t c : v->getString()->str) {
				switch (c) {
					case '"': str.append(u"\\\"");  break;
					case '\\': str.append(u"\\\\"); break;
					case '\n': str.append(u"\\n");  break;
					case '\t': str.append(u"\\t");  break;
					case '\r': str.append(u"\\r");  break;
					default: str += c; break;
				}
			}
			str.append(u"\"");
			break;
		}
		case Type::ARRAY: {
			PVec a = v->getAVec();
			str.append(u"[");
			bool first = true;
			for (Int i = 0; i < a->size(); ++i) {
				if (!first) {
					str.append(u", ");
				}
				flow2string(a->getFlowItem(i), str);
				first = false;
			}
			str.append(u"]");
			break;
		}
		case Type::REF: {
			str.append(u"ref ");
			flow2string(v->getARef()->getFlowRef(), str);
			break;
		}
		case Type::FUNC: {
			str.append(u"<function>"); 
			break;
		}
		case Type::NATIVE: {
			str.append(u"<native>");
			break;
		}
		default: {
			PStr s = v->getAStr();
			str.append(s->name()->str);
			str.append(u"(");
			bool first = true;
			for (Int i = 0; i < s->size(); ++ i) {
				if (!first) {
					str.append(u", ");
				}
				flow2string(s->getFlowField(i), str);
				first = false;
			}
			str.append(u")");
			break;
		}
	}
}

Int compareFlow(Flow v1, Flow v2) {
	if (v1->type() != v2->type()) {
		return Compare<Int>::cmp(v1->type(), v2->type());
	} else {
		switch (v1->type()) {
			case Type::INT:    return Compare<Int>::cmp(v1->getInt(), v2->getInt());
			case Type::BOOL:   return Compare<Bool>::cmp(v1->getBool(), v2->getBool());
			case Type::DOUBLE: return Compare<Double>::cmp(v1->getDouble(), v2->getDouble());
			case Type::STRING: return v1->getString()->str.compare(v2->getString()->str);
			case Type::ARRAY: {
				PVec a1 = v1->getAVec();
				PVec a2 = v2->getAVec();
				Int c1 = Compare<Int>::cmp(a1->size(), a2->size());
				if (c1 != 0) {
					return c1;
				} else {
					for (Int i = 0; i < a1->size(); ++ i) {
						Int c2 = compareFlow(a1->getFlowItem(i), a2->getFlowItem(i));
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case Type::REF: {
				PRef r1 = v1->getARef();
				PRef r2 = v2->getARef();
				return compareFlow(r1->getFlowRef(), r2->getFlowRef());
			}
			case Type::FUNC: {
				PFun f1 = v1->getAFun();
				PFun f2 = v2->getAFun();
				return Compare<const void*>::cmp(f1.ptr, f2.ptr);
			}
			case Type::NATIVE: {
				Native n1 = v1->getNative();
				Native n2 = v2->getNative();
				return Compare<Void*>::cmp(n1->nat, n2->nat);
			}
			default: {
				case Type::STRUCT: {
					PStr s1 = v1->getAStr();
					PStr s2 = v2->getAStr();
					Int c1 = s1->name()->str.compare(s2->name()->str);
					if (c1 != 0) {
						return c1;
					} else {
						for (Int i = 0; i < s1->size(); ++ i) {
							Int c2 = compareFlow(s1->getFlowField(i), s2->getFlowField(i));
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

template<> uint32_t hash(uint32_t h, Flow v) {
	switch (v->type()) {
		case Type::INT:    return hash(h, v->getInt());
		case Type::BOOL:   return hash(h, v->getBool());
		case Type::DOUBLE: return hash(h, v->getDouble());
		case Type::STRING: return hash(h, v->getString());
		case Type::ARRAY: {
			PVec a = v->getAVec();
			for (Int i = 0; i < a->size(); ++i) {
				h = hash(h, a->getFlowItem(i));
			}
			return h;
		}
		case Type::REF:
			return hash(h, reinterpret_cast<uint64_t>(v->getARef()->getFlowRef().ptr));
		case Type::FUNC:
			return hash(h, reinterpret_cast<uint64_t>(v->getAFun().ptr));
		case Type::NATIVE: 
			return hash(h, v->getNative());
		default: {
			PStr s = v->getAStr();
			h = hash(h, s->name());
			for (Int i = 0; i < s->size(); ++ i) {
				h = hash(h, s->getFlowField(i));
			}
			return h;
		}
	}
}

}
