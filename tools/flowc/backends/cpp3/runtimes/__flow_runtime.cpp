#include "__flow_runtime.hpp"

// C++ runtime for flow

namespace flow {


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

String double2string(Double x) { 
	static std::ostringstream os; 
	os << std::scientific << x;
	std::string str = os.str();
	os.str("");
	os.clear();
	std::size_t point_pos = str.find('.');
	if (point_pos == std::string::npos) {
		return makeString(str); 
	} else {
		bool is_integer = true;
		for (std::size_t i = point_pos + 1; i < str.length() && is_integer; ++ i) {
			char ch = str.at(i);
			is_integer = !('1' < ch && ch < '9');
		}
		if (is_integer) {
			return makeString(str.substr(0, point_pos)); 
		} else {
			return makeString(str); 
		}
	}
}

std::string toStdString(String str) { 
	std::size_t len = 0;
	for (std::size_t i = 0; i < str->size(); ++i) {
		char16_t ch = str->at(i);
		uint32_t x = ch;
		if (0xD800 <= ch && ch <= 0xDBFF && i + 1 < str->size()) {
			char16_t ch1 = str->at(i + 1);
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
	for (std::size_t i = 0; i < str->size(); ++i) {
		char16_t ch = str->at(i);
		uint32_t x = ch; 
		if (0xD800 <= ch && ch <= 0xDBFF && i + 1 < str->size()) {
			char16_t ch1 = str->at(i + 1);
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

string fromStdString(const std::string& s) {
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

bool Flow::isSameObj(Flow f) const { 
	if (type() != f.type()) {
		return false;
	} else {
		switch (type()) {
			case Type::INT:    return toInt() == f.toInt();
			case Type::BOOL:   return toBool() == f.toBool();
			case Type::DOUBLE: return toDouble() == f.toDouble();
			case Type::STRING: return *toString() == *f.toString();
			case Type::NATIVE: return toNative<Void>().get() == f.toNative<Void>().get();
			default:           return val.get() == f.val.get();
		}
	}
}

void flow2string(Flow v, String os) {
	switch (v.type()) {
		case Type::INT:    os->append(*int2string(v.toInt())); break;
		case Type::BOOL:   os->append(*bool2string(v.toBool())); break;
		case Type::DOUBLE: os->append(*double2string(v.toDouble())); break;
		case Type::STRING: {
			os->append(u"\"");
			for (char16_t c : *v.toString()) {
				switch (c) {
					case '"': os->append(u"\\\"");  break;
					case '\\': os->append(u"\\\\"); break;
					case '\n': os->append(u"\\n");  break;
					case '\t': os->append(u"\\t");  break;
					case '\r': os->append(u"\\r");  break;
					default: *os += c; break;
				}
			}
			os->append(u"\"");
			break;
		}
		case Type::ARRAY: {
			Arr<Flow> a = v.val.dynamicCast<AArray>()->elements();
			os->append(u"[");
			bool first = true;
			for (Flow e : a->vect) {
				if (!first) {
					os->append(u", ");
				}
				flow2string(e, os);
				first = false;
			}
			os->append(u"]");
			break;
		}
		case Type::REF: {
			os->append(u"ref ");
			flow2string(v.val.dynamicCast<AReference>()->reference(), os);
			break;
		}
		case Type::FUNC: {
			os->append(u"<function>"); 
			break;
		}
		case Type::NATIVE: {
			os->append(u"<native>");
			break;
		}
		default: {
			Ptr<AStruct> s = v.val.dynamicCast<AStruct>();
			os->append(*s->name());
			os->append(u"(");
			Arr<Flow> fields = s->fields();
			bool first = true;
			for (Flow f : fields->vect) {
				if (!first) {
					os->append(u", ");
				}
				flow2string(f, os);
				first = false;
			}
			os->append(u")");
			break;
		}
	}
}

Int compareFlow(Flow v1, Flow v2) {
	if (v1.type() != v2.type()) {
		return Compare<Int>::cmp(v1.type(), v2.type());
	} else {
		switch (v1.type()) {
			case Type::INT:    return Compare<Int>::cmp(v1.toInt(), v2.toInt());
			case Type::BOOL:   return Compare<Bool>::cmp(v1.toBool(), v2.toBool());
			case Type::DOUBLE: return Compare<Double>::cmp(v1.toDouble(), v2.toDouble());
			case Type::STRING: return v1.toString()->compare(*v2.toString());
			case Type::ARRAY: {
				Ptr<AArray> a1 = v1.val.dynamicCast<AArray>();
				Ptr<AArray> a2 = v2.val.dynamicCast<AArray>();
				Int c1 = Compare<Int>::cmp(a1->size(), a2->size());
				if (c1 != 0) {
					return c1;
				} else {
					Arr<Flow> es1 = a1->elements();
					Arr<Flow> es2 = a2->elements();
					for (Int i = 0; i < es1->size(); ++ i) {
						Int c2 = compareFlow(es1->vect.at(i), es2->vect.at(i));
						if (c2 != 0) {
							return c2;
						}
					}
					return 0;
				}
			}
			case Type::REF: {
				Ptr<AReference> r1 = v1.val.dynamicCast<AReference>();
				Ptr<AReference> r2 = v2.val.dynamicCast<AReference>();
				return compareFlow(r1->reference(), r2->reference());
			}
			case Type::FUNC: {
				Ptr<AFunction> f1 = v1.val.dynamicCast<AFunction>();
				Ptr<AFunction> f2 = v2.val.dynamicCast<AFunction>();
				return Compare<void*>::cmp(f1.get(), f2.get());
			}
			case Type::NATIVE: {
				Ptr<ANative> n1 = v1.val.dynamicCast<ANative>();
				Ptr<ANative> n2 = v2.val.dynamicCast<ANative>();
				return Compare<Void*>::cmp(n1->nat.get(), n2->nat.get());
			}
			default: {
				case Type::STRUCT: {
					Ptr<AStruct> s1 = v1.val.dynamicCast<AStruct>();
					Ptr<AStruct> s2 = v2.val.dynamicCast<AStruct>();
					Int c1 = s1->name()->compare(*s2->name());
					if (c1 != 0) {
						return c1;
					} else {
						Arr<Flow> fs1 = s1->fields();
						Arr<Flow> fs2 = s2->fields();
						for (Int i = 0; i < fs1->size(); ++ i) {
							Int c2 = compareFlow(fs1->vect.at(i), fs2->vect.at(i));
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
