#include "__flow_runtime.hpp"

// C++ runtime for flow

namespace flow {

/*
std::atomic<std::size_t> allocated_bytes = 0;
std::size_t max_heap_size = 2u * 1024u * 1024u * 1024u; // 1 Gb by default

AllocStats* alloc_stats = nullptr;

void AllocStats::print() {
	std::cout << "Allocation stats: " << std::endl;
	for (auto p : alloc_stats) {
		std::cout << "sizeof " << p.first << " allocated " << p.second << " times" << std::endl;
	}
}

void initMaxHeapSize(int argc, const char* argv[]) {
	for (int i = 0; i < argc; ++i) {
		std::string arg(argv[i]);
		std::size_t eq_ind = arg.find("=");
		if (eq_ind == std::string::npos) {
			std::string key = arg.substr(0, eq_ind);
			std::string val = arg.substr(eq_ind + 1, arg.size() - eq_ind - 1);
			if (key == "heap-size") {
				max_heap_size = std::stoi(val);
			}
		}
	}
}
*/

String* double2string(Double x) { 
	static std::ostringstream os; 
	os << std::setprecision(12) << x;
	std::string str = os.str();
	os.str("");
	os.clear();
	std::size_t point_pos = str.find('.');
	if (point_pos == std::string::npos) {
		return new String(str); 
	} else {
		bool is_integer = true;
		for (std::size_t i = point_pos + 1; i < str.length() && is_integer; ++ i) {
			char ch = str.at(i);
			is_integer = !('1' < ch && ch < '9');
		}
		if (is_integer) {
			return new String(str.substr(0, point_pos)); 
		} else {
			return new String(str); 
		}
	}
}

std::string String::toStd() const {
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

String::String(const std::string& s) {
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

bool Flow::isSameObj(Flow* f) { 
	if (type() != f->type()) {
		return false;
	} else {
		switch (type()) {
			case Type::INT:    return toInt() == f->toInt();
			case Type::BOOL:   return toBool() == f->toBool();
			case Type::DOUBLE: return toDouble() == f->toDouble();
			case Type::STRING: return toString()->str == f->toString()->str;
			case Type::NATIVE: return toNative()->nat == f->toNative()->nat;
			default:           return this == f;
		}
	}
}

void flow2string(Flow* v, String* os) {
	switch (v->type()) {
		case Type::INT:    os->str.append(int2string(v->toInt())->str); break;
		case Type::BOOL:   os->str.append(bool2string(v->toBool())->str); break;
		case Type::DOUBLE: os->str.append(double2string(v->toDouble())->str); break;
		case Type::STRING: {
			os->str.append(u"\"");
			for (char16_t c : v->toString()->str) {
				switch (c) {
					case '"': os->str.append(u"\\\"");  break;
					case '\\': os->str.append(u"\\\\"); break;
					case '\n': os->str.append(u"\\n");  break;
					case '\t': os->str.append(u"\\t");  break;
					case '\r': os->str.append(u"\\r");  break;
					default: os->str += c; break;
				}
			}
			os->str.append(u"\"");
			break;
		}
		case Type::ARRAY: {
			AArr* a = v->toAArr();
			os->str.append(u"[");
			bool first = true;
			for (Int i = 0; i < a->size(); ++i) {
				if (!first) {
					os->str.append(u", ");
				}
				flow2string(a->getFlow(i), os);
				first = false;
			}
			os->str.append(u"]");
			break;
		}
		case Type::REF: {
			os->str.append(u"ref ");
			flow2string(v->toARef()->getFlow(), os);
			break;
		}
		case Type::FUNC: {
			os->str.append(u"<function>"); 
			break;
		}
		case Type::NATIVE: {
			os->str.append(u"<native>");
			break;
		}
		default: {
			AStr* s = v->toAStr();
			os->str.append(s->name()->str);
			os->str.append(u"(");
			bool first = true;
			for (Int i = 0; i < s->size(); ++ i) {
				if (!first) {
					os->str.append(u", ");
				}
				flow2string(s->getFlow(i), os);
				first = false;
			}
			os->str.append(u")");
			break;
		}
	}
}

Int compareFlow(Flow* v1, Flow* v2) {
	if (v1->type() != v2->type()) {
		return Compare<Int>::cmp(v1->type(), v2->type());
	} else {
		switch (v1->type()) {
			case Type::INT:    return Compare<Int>::cmp(v1->toInt(), v2->toInt());
			case Type::BOOL:   return Compare<Bool>::cmp(v1->toBool(), v2->toBool());
			case Type::DOUBLE: return Compare<Double>::cmp(v1->toDouble(), v2->toDouble());
			case Type::STRING: return v1->toString()->str.compare(v2->toString()->str);
			case Type::ARRAY: {
				AArr* a1 = v1->toAArr();
				AArr* a2 = v2->toAArr();
				Int c1 = Compare<Int>::cmp(a1->size(), a2->size());
				if (c1 != 0) {
					return c1;
				} else {
					for (Int i = 0; i < a1->size(); ++ i) {
						Int c2 = compareFlow(a1->getFlow(i), a2->getFlow(i));
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case Type::REF: {
				ARef* r1 = v1->toARef();
				ARef* r2 = v2->toARef();
				return compareFlow(r1->getFlow(), r2->getFlow());
			}
			case Type::FUNC: {
				AFun* f1 = v1->toAFun();
				AFun* f2 = v2->toAFun();
				return Compare<void*>::cmp(f1, f2);
			}
			case Type::NATIVE: {
				Native* n1 = v1->toNative();
				Native* n2 = v2->toNative();
				return Compare<Void*>::cmp(n1->nat, n2->nat);
			}
			default: {
				case Type::STRUCT: {
					AStr* s1 = v1->toAStr();
					AStr* s2 = v2->toAStr();
					Int c1 = s1->name()->str.compare(s2->name()->str);
					if (c1 != 0) {
						return c1;
					} else {
						for (Int i = 0; i < s1->size(); ++ i) {
							Int c2 = compareFlow(s1->getFlow(i), s2->getFlow(i));
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

}
