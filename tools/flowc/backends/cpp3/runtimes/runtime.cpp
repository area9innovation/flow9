#include "__flow_runtime.hpp"

// C++ runtime for flow

namespace flow {

std::string toStdString(String str) { 
	std::size_t len = 0;
	for (std::size_t i = 0; i < str->size(); ++i) {
		char16_t ch = str->at(i);
		uint32_t x = ch;
		if (0xD800 <= ch && ch <= 0xDBFF) {
			x = ((ch & 0x3FF) << 10) + (str->at(++i) & 0x3FF) + 0x10000;
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
		if (0xD800 <= ch && ch <= 0xDBFF) {
			x = ((ch & 0x3FF) << 10) + (str->at(++i) & 0x3FF) + 0x10000;
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

		if ((b1 & 0xFC) == 0xF8 && i < len - 4) {
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
		} else if ((b1 & 0xF8) == 0xF0 && i < len - 3) {
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
		} else if ((b1 & 0xF0) == 0xE0 && i < len - 2) {
			uint8_t b2 = s.at(i + 1);
			uint8_t b3 = s.at(i + 2);
			i += 2;

			char16_t h1 = (b1 & 0xF)  << 12;
			char16_t h2 = (b2 & 0x3F) << 6;
			char16_t h3 = 0x3F & b3;

			char16_t h = h1 | h2 | h3;

			str.push_back(h);
		} else if ((b1 & 0xE0) == 0xC0 && i < len - 1) {
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
		case Type::STRUCT: return "struct";
		case Type::ARRAY:  return "array";
		case Type::REF:    return "ref";
		case Type::FUNC:   return "function";
		case Type::NATIVE: return "native";
		default:           return "unknown";
	} 
}

Type Flow::type() const { 
	switch (val.index()) {
		case Type::INT:    return Type::INT;
		case Type::BOOL:   return Type::BOOL;
		case Type::DOUBLE: return Type::DOUBLE;
		case Type::STRING: return Type::STRING;
		case Type::STRUCT: return Type::STRUCT;
		case Type::ARRAY:  return Type::ARRAY;
		case Type::REF:    return Type::REF;
		case Type::FUNC:   return Type::FUNC;
		case Type::NATIVE: return Type::NATIVE;
		default:           return Type::NATIVE;
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
			case Type::STRUCT: return toStruct().get() == f.toStruct().get();
			case Type::ARRAY:  return toArray().get() == f.toArray().get();
			case Type::REF:    return toReference().get() == f.toReference().get();
			case Type::FUNC:   return toFunction().get() == f.toFunction().get();
			case Type::NATIVE: return toNative<Void>().get() == f.toNative<Void>().get();
			default:           return false;
		}
	}
}

void flow2string(Flow v, String os, bool init) {
	switch (v.type()) {
		case Type::INT:    os->append(fromStdString(std::to_string(v.toInt()))); break;
		case Type::BOOL:   os->append((v.toBool() ? u"true" : u"false")); break;
		case Type::DOUBLE: os->append(fromStdString(std::to_string(v.toDouble()))); break;
		case Type::STRING: {
			if (!init) {
				os->append(u"\"");
				for (char16_t c : *v.toString()) {
					switch (c) {
						case '"': os->append(u"\\\"");      break;
						case '\\': os->append(u"\\\\");     break;
						case '\n': os->append(u"\\n");      break;
						case '\t': os->append(u"\\t");      break;
						//case '\r': os->append("\\u000d");  break;
						case '\r': os->append(u"\\r");      break;
						default: *os += c; break;
					}
				}
				os->append(u"\"");
			} else {
				os->append(*v.toString());
			}
			break;
		}
		case Type::STRUCT: {
			Ptr<AStruct> s = v.toStruct();
			os->append(*s->name());
			os->append(u"(");
			Arr<Flow> fields = s->fields();
			bool first = true;
			for (Flow f : fields->vect) {
				if (!first) {
					os->append(u", ");
				}
				flow2string(f, os, false);
				first = false;
			}
			os->append(u")");
			break;
		}
		case Type::ARRAY: {
			Arr<Flow> a = v.toArray()->elements();
			os->append(u"[");
			bool first = true;
			for (Flow e : a->vect) {
				if (!first) {
					os->append(u", ");
				}
				flow2string(e, os, false);
				first = false;
			}
			os->append(u"]");
			break;
		}
		case Type::REF: {
			os->append(u"ref ");
			flow2string(v.toReference()->reference(), os, false);
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
			case Type::STRUCT: {
				Ptr<AStruct> s1 = v1.toStruct();
				Ptr<AStruct> s2 = v2.toStruct();
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
			case Type::ARRAY: {
				Ptr<AArray> a1 = v1.toArray();
				Ptr<AArray> a2 = v2.toArray();
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
				Ptr<AReference> r1 = v1.toReference();
				Ptr<AReference> r2 = v2.toReference();
				return compareFlow(r1->reference(), r2->reference());
			}
			case Type::FUNC: {
				Ptr<AFunction> f1 = v1.toFunction();
				Ptr<AFunction> f2 = v2.toFunction();
				return Compare<void*>::cmp(f1.get(), f2.get());
			}
			case Type::NATIVE: {
				Ptr<Void> n1 = v1.toNative<Void>();
				Ptr<Void> n2 = v2.toNative<Void>();
				return Compare<Void*>::cmp(n1.get(), n2.get());
			}
			default: {
				std::cerr << "illegal type: " << v1.type() << std::endl;
				return 0;
			}
		}
	}
}

}
